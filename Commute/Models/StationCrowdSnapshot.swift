import Foundation

/// One station's crowd reading — live current tier plus a short
/// forward forecast — for the Station Browser screen and its sheet.
///
/// **Live data only.** Backed by LTA DataMall's `PCDRealTime` (current)
/// and `PCDRealTimeForecast` (next ~90 min in 30-min slots). LTA does
/// not expose 24-hour historical data via the JSON APIs — only via
/// the `PCDByStation` ZIP download — so the older "Typical for this
/// time" 24h profile has been retired. We render only what's real.
struct StationCrowdSnapshot: Hashable, Identifiable {
    let stationCode: String      // "CC23"
    let stationName: String      // "one-north"
    let line: MRTLine
    /// Current tier from PCDRealTime. `.unknown` when LTA returned
    /// "NA" for this station (data temporarily unavailable).
    let currentTier: CrowdTier
    /// Forward-looking slots from PCDRealTimeForecast. Empty when the
    /// endpoint returned no data for this station; the sheet's
    /// timeline degrades gracefully to "Forecast unavailable".
    let forecast: [ForecastSlot]

    var id: String { stationCode }

    struct ForecastSlot: Hashable {
        let startHour: Int          // 0…23 hour-of-day in local time
        let startMinute: Int        // 0 or 30 (LTA emits 30-min slots)
        let tier: CrowdTier
    }
}

/// Crowd tiers that map 1:1 onto LTA's `CrowdLevel` field. Four cases
/// rather than three because LTA's "NA" is meaningfully distinct from
/// any data point — surfacing it lets the UI say "data unavailable"
/// rather than misrepresenting an unknown as low.
enum CrowdTier: Hashable, CaseIterable {
    case low
    case moderate
    case busy
    case unknown

    /// Parse LTA's `CrowdLevel` string. Unknown / NA / empty → `.unknown`.
    init(ltaCode: String) {
        switch ltaCode.lowercased() {
        case "l": self = .low
        case "m": self = .moderate
        case "h": self = .busy
        default:  self = .unknown
        }
    }

    var word: String {
        switch self {
        case .low:      "Low crowd"
        case .moderate: "Moderate"
        case .busy:     "Busy"
        case .unknown:  "Unknown"
        }
    }

    var tag: String {
        switch self {
        case .low:      "Low"
        case .moderate: "Moderate"
        case .busy:     "Busy"
        case .unknown:  "—"
        }
    }

    var advice: String {
        switch self {
        case .low:      "Comfortable boarding expected. Easy to find space."
        case .moderate: "Moderate crowd. Should be fine to board."
        case .busy:     "Platform filling up. Consider waiting for the next train."
        case .unknown:  "Crowd data is temporarily unavailable for this station."
        }
    }

    /// Lit pip count out of 5. `.unknown` lights none — we want the
    /// row to read as empty rather than misleadingly low.
    var litPipCount: Int {
        switch self {
        case .low:      1
        case .moderate: 3
        case .busy:     5
        case .unknown:  0
        }
    }
}
