import SwiftUI
import Observation

@MainActor
@Observable
final class MRTStationDetailViewModel {
    var status: LineStatus
    var crowdLevel: StationCrowdLevel = .unknown
    var liftMaintenance: [LiftMaintenance] = []
    var isLoading = false
    var dataMode: HomeViewModel.DataMode = .demo

    private let lta: LTAService
    private let station: MRTStation

    init(station: MRTStation, lta: LTAService = .shared) {
        self.station = station
        self.lta = lta
        self.status = LineStatus(
            line: station.line,
            severity: .normal,
            message: "\(station.line.fullName) · Normal service"
        )
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        var anyLive = false

        async let alertsTask = lta.trainAlerts()
        async let crowdTask  = lta.stationCrowd(line: station.line.ltaTrainLine)
        async let liftsTask  = lta.facilitiesMaintenance()

        // Status banner from train alerts
        if let alerts = try? await alertsTask {
            status = Self.deriveStatus(for: station, from: alerts)
            anyLive = true
        }

        // Crowd density for this station code
        if let crowdValues = try? await crowdTask {
            let entry = crowdValues.first { $0.station == station.id }
            crowdLevel = entry.map { StationCrowdLevel.parse($0.crowdLevel) } ?? .unknown
            anyLive = true
        }

        // Lift maintenance affecting this station
        if let lifts = try? await liftsTask {
            liftMaintenance = lifts
                .filter { $0.stationCode == station.id }
                .enumerated()
                .map { idx, raw in
                    LiftMaintenance(
                        id: raw.liftId ?? "\(station.id)-\(idx)",
                        stationCode: raw.stationCode,
                        liftDesc: raw.liftDesc
                    )
                }
            anyLive = true
        }

        dataMode = anyLive ? .live : .demo
    }

    private static func deriveStatus(for station: MRTStation, from alerts: LTATrainAlertValue) -> LineStatus {
        let line = station.line
        let normal = LineStatus(
            line: line,
            severity: .normal,
            message: "\(line.fullName) · Normal service"
        )

        if alerts.status == 1 { return normal }

        let lineCode = line.ltaTrainLine
        let affecting = alerts.affectedSegments.first { seg in
            seg.line.uppercased() == lineCode
        }
        guard let affecting else { return normal }

        let stationsAffected = affecting.stations
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let hits = stationsAffected.contains(station.id)
        let summary = alerts.message.first?.content ?? "Service disruption on \(line.fullName)."

        return LineStatus(
            line: line,
            severity: hits ? .danger : .warning,
            message: summary
        )
    }
}
