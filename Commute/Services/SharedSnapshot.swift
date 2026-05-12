import Foundation

/// Shared snapshot the main app writes and the widget extension reads. The
/// payload is a small Codable struct serialized as JSON into the App Group's
/// UserDefaults under a single key. App Group ID must match what's set in
/// **both** target capabilities — defaults to `group.com.rommelsim.commute`
/// (override via `APP_GROUP_ID` build setting if you use a different ID).
public struct MRTStatusSnapshot: Codable, Hashable {
    public struct Line: Codable, Hashable {
        public let code: String     // "EW", "NS", …
        public let name: String     // "East-West Line"
        public let isDisrupted: Bool
        public init(code: String, name: String, isDisrupted: Bool) {
            self.code = code
            self.name = name
            self.isDisrupted = isDisrupted
        }
    }
    public let lines: [Line]
    public let updatedAt: Date

    public init(lines: [Line], updatedAt: Date) {
        self.lines = lines
        self.updatedAt = updatedAt
    }
}

/// Snapshot of the Home screen "Next out the door" hero card. Mirrors the
/// shape of `HeroContext` so the widget can render an identical-looking
/// dark gradient card without re-running the full journey-suggester logic.
public struct NextOutTheDoorSnapshot: Codable, Hashable {
    public enum TimeContext: String, Codable {
        case morning, midday, evening, night, weekend
    }
    public let timeContext: TimeContext
    public let labelTop: String          // "NEXT OUT THE DOOR" / "RIGHT NOW" / etc.
    public let headline: String          // "Walk now", "Catch this for work"
    public let bus: String?              // "282", nil when no journey suggested
    public let etaMinutes: Int?
    public let slack: String?            // "1 min to spare"
    public let destination: String?      // "Clementi"
    public let destinationLabel: String? // "Home" / "Work"
    public let fromStop: String?         // "Blk 355"
    public let totalTripMinutes: Int?
    public let arriveByLabel: String?    // "9:02 pm"
    public let updatedAt: Date

    public init(
        timeContext: TimeContext, labelTop: String, headline: String,
        bus: String?, etaMinutes: Int?, slack: String?,
        destination: String?, destinationLabel: String?, fromStop: String?,
        totalTripMinutes: Int?, arriveByLabel: String?, updatedAt: Date
    ) {
        self.timeContext = timeContext
        self.labelTop = labelTop
        self.headline = headline
        self.bus = bus
        self.etaMinutes = etaMinutes
        self.slack = slack
        self.destination = destination
        self.destinationLabel = destinationLabel
        self.fromStop = fromStop
        self.totalTripMinutes = totalTripMinutes
        self.arriveByLabel = arriveByLabel
        self.updatedAt = updatedAt
    }
}

public enum SharedSnapshot {
    /// App Group identifier — must match what's ticked on BOTH the Commute
    /// and CommuteWidgetExtension targets in Signing & Capabilities → App
    /// Groups. Override via Info.plist (`APP_GROUP_ID`) if needed.
    public static let appGroupID: String = {
        Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_ID") as? String
            ?? "group.com.transitsg.shared"
    }()

    private static let mrtKey = "snapshot.mrtStatus.v1"
    private static let nextOutKey = "snapshot.nextOutTheDoor.v1"

    public static func writeMRT(_ snapshot: MRTStatusSnapshot) {
        guard let store = UserDefaults(suiteName: appGroupID),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        store.set(data, forKey: mrtKey)
    }

    public static func readMRT() -> MRTStatusSnapshot? {
        guard let store = UserDefaults(suiteName: appGroupID),
              let data = store.data(forKey: mrtKey) else { return nil }
        return try? JSONDecoder().decode(MRTStatusSnapshot.self, from: data)
    }

    public static func writeNextOutTheDoor(_ snapshot: NextOutTheDoorSnapshot) {
        guard let store = UserDefaults(suiteName: appGroupID),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        store.set(data, forKey: nextOutKey)
    }

    public static func readNextOutTheDoor() -> NextOutTheDoorSnapshot? {
        guard let store = UserDefaults(suiteName: appGroupID),
              let data = store.data(forKey: nextOutKey) else { return nil }
        return try? JSONDecoder().decode(NextOutTheDoorSnapshot.self, from: data)
    }

    // MARK: - Pinned items

    private static let pinnedKey = "snapshot.pinned.v1"
    private static let pinnedArrivalsKey = "snapshot.pinned.arrivals.v1"

    public static func writePinnedArrivals(_ snapshot: PinnedArrivalsSnapshot) {
        guard let store = UserDefaults(suiteName: appGroupID),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        store.set(data, forKey: pinnedArrivalsKey)
    }

    public static func readPinnedArrivals() -> PinnedArrivalsSnapshot? {
        guard let store = UserDefaults(suiteName: appGroupID),
              let data = store.data(forKey: pinnedArrivalsKey) else { return nil }
        return try? JSONDecoder().decode(PinnedArrivalsSnapshot.self, from: data)
    }

    public static func writePinned(_ snapshot: PinnedItemsSnapshot) {
        guard let store = UserDefaults(suiteName: appGroupID),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        store.set(data, forKey: pinnedKey)
    }

    public static func readPinned() -> PinnedItemsSnapshot? {
        guard let store = UserDefaults(suiteName: appGroupID),
              let data = store.data(forKey: pinnedKey) else { return nil }
        return try? JSONDecoder().decode(PinnedItemsSnapshot.self, from: data)
    }

    /// Wipe every snapshot the main app has published into the App Group.
    /// Called by the in-app "Reset" action so widgets stop showing
    /// stale personal data (pinned stops, journey hero) after a wipe.
    public static func clearAll() {
        guard let store = UserDefaults(suiteName: appGroupID) else { return }
        store.removeObject(forKey: mrtKey)
        store.removeObject(forKey: nextOutKey)
        store.removeObject(forKey: pinnedKey)
        store.removeObject(forKey: pinnedArrivalsKey)
    }
}

/// Lightweight snapshot of next-arrival timestamps at the user's pinned bus
/// stops. Persisted in the App Group so cold-launching Home can render
/// last-known ETAs instantly while the live LTA fetch is in flight. We only
/// store absolute `Date`s — minute counts are always recomputed at render
/// time, so a stale snapshot naturally falls off rather than freezing on a
/// wrong number.
public struct PinnedArrivalsSnapshot: Codable, Hashable {
    public struct Arrival: Codable, Hashable {
        public let serviceNo: String
        public let nextArrivalAt: Date?
        public init(serviceNo: String, nextArrivalAt: Date?) {
            self.serviceNo = serviceNo
            self.nextArrivalAt = nextArrivalAt
        }
    }
    /// Keyed by bus-stop code (e.g. "84009").
    public let arrivalsByStop: [String: [Arrival]]
    public let updatedAt: Date

    public init(arrivalsByStop: [String: [Arrival]], updatedAt: Date) {
        self.arrivalsByStop = arrivalsByStop
        self.updatedAt = updatedAt
    }
}

/// Snapshot of the user's pinned (starred) bus stops and bus service
/// numbers, written by the main app whenever the favorites set changes.
public struct PinnedItemsSnapshot: Codable, Hashable {
    public struct Stop: Codable, Hashable {
        public let code: String
        public let name: String
        public init(code: String, name: String) {
            self.code = code
            self.name = name
        }
    }
    public let stops: [Stop]
    public let busNumbers: [String]
    public let updatedAt: Date

    public init(stops: [Stop], busNumbers: [String], updatedAt: Date) {
        self.stops = stops
        self.busNumbers = busNumbers
        self.updatedAt = updatedAt
    }
}
