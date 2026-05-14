import Foundation
import ActivityKit

/// Live Activity describing the next train arrival(s) at a station the user
/// is currently waiting at. **Duplicated** in `CommuteWidget/` so the widget
/// extension target can decode the same payload — Xcode synchronized groups
/// won't share files across roots, so the file lives in both places.
struct TrainArrivalActivity: ActivityAttributes {
    public typealias ContentState = State

    public enum CrowdLevel: String, Codable, Hashable {
        case low, moderate, high
    }

    public struct State: Codable, Hashable {
        public var nextMinutes: Int
        public var followingMinutes: [Int]
        public var crowdLevel: CrowdLevel
        public var lastUpdated: Date

        public var isStale: Bool {
            Date().timeIntervalSince(lastUpdated) > 120
        }

        public init(
            nextMinutes: Int,
            followingMinutes: [Int],
            crowdLevel: CrowdLevel,
            lastUpdated: Date
        ) {
            self.nextMinutes = nextMinutes
            self.followingMinutes = followingMinutes
            self.crowdLevel = crowdLevel
            self.lastUpdated = lastUpdated
        }
    }

    /// Station code, e.g. "EW23".
    public let stationCode: String
    /// Station name, e.g. "Clementi".
    public let stationName: String
    /// Line full name, e.g. "East-West Line".
    public let lineName: String
    /// Direction label, e.g. "Tuas Link".
    public let towardsDestination: String

    public init(
        stationCode: String,
        stationName: String,
        lineName: String,
        towardsDestination: String
    ) {
        self.stationCode = stationCode
        self.stationName = stationName
        self.lineName = lineName
        self.towardsDestination = towardsDestination
    }
}
