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

public enum SharedSnapshot {
    /// App Group identifier. Override via Info.plist if needed.
    public static let appGroupID: String = {
        Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_ID") as? String
            ?? "group.com.rommelsim.commute"
    }()

    private static let mrtKey = "snapshot.mrtStatus.v1"

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
}
