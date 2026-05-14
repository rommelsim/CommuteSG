import Foundation
import ActivityKit

/// Widget-target copy of `TrainArrivalActivity`. See the `Commute/Models/`
/// twin for the canonical doc comments — keep both in sync.
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

    public let stationCode: String
    public let stationName: String
    public let lineName: String
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
