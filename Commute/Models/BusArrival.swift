import Foundation
import CoreLocation

enum CrowdLevel: String, Codable {
    case seats, standing, limited, unknown

    var label: String {
        switch self {
        case .seats: "Seats"
        case .standing: "Standing"
        case .limited: "Limited"
        case .unknown: "—"
        }
    }
}

enum BusType: String, Codable {
    case singleDeck = "SD"
    case doubleDeck = "DD"
    case bendy = "BD"
    case unknown = "?"

    var label: String {
        switch self {
        case .singleDeck: "Single-deck"
        case .doubleDeck: "Double-deck"
        case .bendy: "Bendy"
        case .unknown: "—"
        }
    }

    var shortLabel: String { rawValue }

    /// SF Symbol shown alongside the minute count in arrival chips per
    /// redesign spec §4. Bendy reuses `bus.fill` (no dedicated SF Symbol);
    /// the full word "Bendy" is spelled out only in the bus's expanded
    /// detail view for accessibility / first-time users.
    var symbol: String? {
        switch self {
        case .singleDeck: "bus.fill"
        case .doubleDeck: "bus.doubledecker.fill"
        case .bendy:      "bus.fill"
        case .unknown:    nil
        }
    }
}

struct BusArrival: Identifiable, Hashable {
    let id = UUID()
    let serviceNo: String
    let destination: String
    let destinationCode: String?
    let operatorName: String
    let nextArrivalAt: Date?
    let nextArrivalCrowd: CrowdLevel
    let nextArrivalType: BusType
    let nextArrivalIsScheduled: Bool
    let nextArrivalLatitude: Double?
    let nextArrivalLongitude: Double?
    let followingArrivalAt: Date?
    let followingArrivalCrowd: CrowdLevel
    let followingArrivalType: BusType
    let followingArrivalIsScheduled: Bool

    var nextArrivalMinutes: Int? { Self.minutes(from: nextArrivalAt) }
    var followingArrivalMinutes: Int? { Self.minutes(from: followingArrivalAt) }

    var nextArrivalSeconds: Int? {
        guard let nextArrivalAt else { return nil }
        return max(0, Int(nextArrivalAt.timeIntervalSinceNow))
    }

    var nextArrivalCoordinate: CLLocationCoordinate2D? {
        guard let lat = nextArrivalLatitude, let lon = nextArrivalLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Convert an absolute arrival timestamp into a display-minute count that
    /// matches what `LiveTrackingView` shows: any time within 30 s collapses
    /// to "Arr" (returned as `0`), and longer waits round **up** so the same
    /// bus shows the same number on every screen. (We were previously
    /// flooring here, which produced "1 min" on Home for a bus the tracking
    /// page was already calling "2 min".)
    private static func minutes(from date: Date?) -> Int? {
        guard let date else { return nil }
        let seconds = date.timeIntervalSinceNow
        if seconds <= 30 { return 0 }
        return Int(ceil(seconds / 60.0))
    }
}
