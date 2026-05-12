import SwiftUI
import Observation

@Observable
final class AlertsViewModel {
    /// Disruption data per line, derived from LTA's `AffectedSegments`.
    struct LineDisruption: Hashable {
        let line: MRTLine
        let direction: String
        let stations: String
        let freePublicBus: String?
        let freeMRTShuttle: String?
    }

    var alerts: [TransitAlert] = []
    var disruptions: [LineDisruption] = []
    var lastUpdated: Date?
    var isLoading = false
    var dataMode: HomeViewModel.DataMode = .demo

    private let lta: LTAService
    private let mock: MockDataService

    init(lta: LTAService = .shared, mock: MockDataService = .shared) {
        self.lta = lta
        self.mock = mock
        self.alerts = mock.alerts().filter { $0.kind == .mrt }
    }

    @MainActor
    func refresh(force: Bool = false) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let raw = try await lta.trainAlerts(force: force)
            disruptions = raw.affectedSegments.compactMap { Self.mapDisruption($0) }
            let liveAlerts = try await lta.trainAlertsAsTransitAlerts()
            // When status == 1 LTA still returns an "all clear" success alert
            // via the mapper; we drop it because the line-status grid already
            // conveys "all lines normal" visually.
            alerts = liveAlerts
                .filter { $0.severity != .success }
                .sorted { $0.severity.rank < $1.severity.rank }
            dataMode = .live
            lastUpdated = Date()
            writeWidgetSnapshot()
            await notifyDisruptions()
        } catch {
            disruptions = []
            alerts = mock.alerts().filter { $0.kind == .mrt }
            dataMode = .demo
        }
    }

    /// Push a system notification for each disruption we haven't already
    /// notified about this session. Dedup happens inside the service via
    /// a stable signature (line code + affected stations), so re-running
    /// `refresh()` against an unchanged incident is a no-op.
    private func notifyDisruptions() async {
        for d in disruptions {
            let signature = "\(d.line.code).\(d.stations)"
            await NotificationService.shared.postDisruption(
                signature: signature,
                lineName: d.line.fullName,
                body: disruptionBody(for: d)
            )
        }
    }

    private func disruptionBody(for d: LineDisruption) -> String {
        let stations = d.stations.isEmpty ? "trains" : "trains between \(d.stations)"
        let dir = d.direction.isEmpty ? "" : " (\(d.direction))"
        return "Delays affecting \(stations)\(dir). Tap for details."
    }

    /// Mirror the current line statuses to the App Group so the MRT Status
    /// widget can render even when the app isn't running.
    private func writeWidgetSnapshot() {
        let lines = orderedLines.map { line in
            MRTStatusSnapshot.Line(
                code: line.code,
                name: line.fullName,
                isDisrupted: isLineDisrupted(line)
            )
        }
        SharedSnapshot.writeMRT(.init(lines: lines, updatedAt: Date()))
    }

    /// Whether a given line is currently affected by a disruption.
    func isLineDisrupted(_ line: MRTLine) -> Bool {
        disruptions.contains { $0.line == line }
    }

    /// Lines (in LTA's display order) — keep the order stable across renders.
    var orderedLines: [MRTLine] {
        [.ew, .ns, .ne, .cc, .dt, .te, .ce]
    }

    private static func mapDisruption(_ segment: LTAAffectedSegment) -> LineDisruption? {
        guard let line = MRTLine.fromLTACode(segment.line) else { return nil }
        return LineDisruption(
            line: line,
            direction: segment.direction,
            stations: segment.stations,
            freePublicBus: segment.freePublicBus.isEmpty ? nil : segment.freePublicBus,
            freeMRTShuttle: segment.freeMRTShuttle.isEmpty ? nil : segment.freeMRTShuttle
        )
    }
}

extension MRTLine {
    /// Map LTA's `Line` code (e.g. "EWL", "CGL") back to our enum.
    static func fromLTACode(_ raw: String) -> MRTLine? {
        let upper = raw.uppercased()
        return MRTLine.allCases.first { $0.ltaTrainLine == upper }
    }
}

private extension TransitAlert.Severity {
    var rank: Int {
        switch self {
        case .danger:  0
        case .warning: 1
        case .info:    2
        case .success: 3
        }
    }
}
