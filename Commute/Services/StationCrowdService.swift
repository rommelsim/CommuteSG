import Foundation

/// Live source of `StationCrowdSnapshot` for the Station Browser screen.
///
/// Pulls from two LTA endpoints in parallel per line:
///   • `PCDRealTime`         — current crowd (l/m/h/NA)
///   • `PCDRealTimeForecast` — forward 30-min slots, ~90 min lookahead
///
/// LTA's PCDRealTime refreshes every ~10 minutes; the caller polls at
/// 30s anyway so the snapshot reflects the most recent slot. Failures
/// are surfaced as `.unknown` per affected station — we never mock.
@MainActor
final class StationCrowdService {
    static let shared = StationCrowdService()
    private init() {}

    /// Train lines we query. LTA's `TrainLine` query takes 2-letter
    /// codes matching `MRTLine.rawValue` (uppercased).
    private static let lines: [MRTLine] = [.cc, .dt, .ew, .ns, .ne, .te, .ce]

    private let lta: LTAService = .shared

    /// Fetch a fresh batch covering every station in the catalogue.
    /// Stations missing from LTA's response (e.g. line not yet open or
    /// API hiccup) are returned with `currentTier == .unknown` and an
    /// empty forecast — never silently dropped.
    func fetchAllSnapshots(force: Bool = false) async -> [StationCrowdSnapshot] {
        // Parallel fan-out per line for both endpoints. `async let`
        // would also work but `withTaskGroup` keeps the partial-failure
        // semantics clearer: one line's outage doesn't poison the rest.
        let (currentByCode, forecastByCode) = await withTaskGroup(
            of: (line: MRTLine, current: [LTAStationCrowd], forecast: [LTAStationCrowdForecast]).self
        ) { group in
            for line in Self.lines {
                group.addTask { [lta] in
                    async let current = (try? await lta.stationCrowd(line: line.ltaCode, force: force)) ?? []
                    async let forecast = (try? await lta.stationCrowdForecast(line: line.ltaCode, force: force)) ?? []
                    return (line, await current, await forecast)
                }
            }
            var currents: [String: LTAStationCrowd] = [:]
            var forecasts: [String: LTAStationCrowdForecast] = [:]
            for await result in group {
                for entry in result.current { currents[entry.station] = entry }
                for entry in result.forecast { forecasts[entry.station] = entry }
            }
            return (currents, forecasts)
        }

        return MRTStationsRepository.shared.stations.map { station in
            let live = currentByCode[station.id]
            let fc = forecastByCode[station.id]
            return StationCrowdSnapshot(
                stationCode: station.id,
                stationName: station.name,
                line: station.line,
                currentTier: live.map { CrowdTier(ltaCode: $0.crowdLevel) } ?? .unknown,
                forecast: fc.map(Self.makeForecast(from:)) ?? []
            )
        }
    }

    // MARK: - Helpers

    /// Convert LTA's 30-min slot intervals into our `ForecastSlot` shape.
    /// Each slot's local-time hour/minute is extracted from the ISO-8601
    /// start timestamp. Slots in the past are dropped — by the time
    /// the user sees the sheet, those aren't useful information.
    private static func makeForecast(from forecast: LTAStationCrowdForecast) -> [StationCrowdSnapshot.ForecastSlot] {
        let now = Date()
        return forecast.interval.compactMap { interval in
            guard let date = isoFormatter.date(from: interval.start), date >= now.addingTimeInterval(-300) else {
                return nil
            }
            let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
            return StationCrowdSnapshot.ForecastSlot(
                startHour: comps.hour ?? 0,
                startMinute: comps.minute ?? 0,
                tier: CrowdTier(ltaCode: interval.crowdLevel)
            )
        }
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

private extension MRTLine {
    /// 2-letter `TrainLine` query value for LTA's PCD endpoints. Uses
    /// `CCL` / `DTL` / etc. — LTA's own naming, not `MRTLine.rawValue`.
    var ltaCode: String {
        switch self {
        case .cc: "CCL"
        case .dt: "DTL"
        case .ew: "EWL"
        case .ns: "NSL"
        case .ne: "NEL"
        case .te: "TEL"
        case .ce: "EWL"   // Changi extension rides on EWL data
        }
    }
}
