import Foundation

struct MRTStation: Identifiable, Hashable {
    let id: String              // station code, e.g. "EW5"
    let name: String
    let line: MRTLine
    let interchangeLines: [MRTLine]
    let distanceMeters: Int?

    var isInterchange: Bool { !interchangeLines.isEmpty }
}

struct StationExit: Identifiable, Hashable {
    let id: String              // letter, "A" / "B" / ...
    let name: String
    let amenities: [String]     // e.g. ["Lift", "Escalator"]
}

struct StationAmenity: Identifiable, Hashable {
    let id = UUID()
    let symbol: String          // SF Symbol name
    let label: String
    let value: String
}

struct LineStatus: Hashable {
    enum Severity { case normal, warning, danger }
    let line: MRTLine
    let severity: Severity
    let message: String
}

enum StationCrowdLevel: String, Hashable {
    case low, moderate, high, unknown

    static func parse(_ raw: String) -> StationCrowdLevel {
        switch raw.lowercased() {
        case "l": .low
        case "m": .moderate
        case "h": .high
        default:  .unknown
        }
    }

    var label: String {
        switch self {
        case .low:      "Low"
        case .moderate: "Moderate"
        case .high:     "High"
        case .unknown:  "Unknown"
        }
    }

    var filledBars: Int {
        switch self {
        case .low: 1
        case .moderate: 2
        case .high: 3
        case .unknown: 0
        }
    }
}

struct LiftMaintenance: Identifiable, Hashable {
    let id: String              // liftId or composite key
    let stationCode: String
    let liftDesc: String
}
