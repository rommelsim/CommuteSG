import Foundation
import ActivityKit

/// Live Activity describing an in-progress multi-leg journey toward a saved
/// destination. **Duplicated** in `CommuteWidget/` — see the twin file.
struct JourneyActivity: ActivityAttributes {
    public typealias ContentState = State

    public enum Mode: String, Codable, Hashable { case bus, train, walk }

    public struct Leg: Codable, Hashable {
        public let mode: Mode
        public let serviceCode: String?    // bus number / line code
        public let actionText: String      // "Board EW at Clementi"
        public let detailText: String?     // "5 stops · 12 min"
        public var minutesRemaining: Int

        public init(
            mode: Mode,
            serviceCode: String?,
            actionText: String,
            detailText: String?,
            minutesRemaining: Int
        ) {
            self.mode = mode
            self.serviceCode = serviceCode
            self.actionText = actionText
            self.detailText = detailText
            self.minutesRemaining = minutesRemaining
        }
    }

    public struct State: Codable, Hashable {
        public var totalMinutesRemaining: Int
        public var arrivalClockTime: Date
        public var currentLeg: Leg
        public var nextLeg: Leg?
        public var lastUpdated: Date

        public init(
            totalMinutesRemaining: Int,
            arrivalClockTime: Date,
            currentLeg: Leg,
            nextLeg: Leg?,
            lastUpdated: Date
        ) {
            self.totalMinutesRemaining = totalMinutesRemaining
            self.arrivalClockTime = arrivalClockTime
            self.currentLeg = currentLeg
            self.nextLeg = nextLeg
            self.lastUpdated = lastUpdated
        }
    }

    /// Destination short name, e.g. "One-North".
    public let destinationName: String

    public init(destinationName: String) {
        self.destinationName = destinationName
    }
}
