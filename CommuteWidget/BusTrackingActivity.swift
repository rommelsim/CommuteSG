import Foundation
import ActivityKit

/// Live Activity describing an in-progress bus journey toward a stop. The
/// **same file is used by both the main app target and the widget extension
/// target** — Xcode "Target Membership" must include both. The activity
/// attribute (immutable) holds the route header; the content state
/// (mutable) is what the main app updates each refresh while tracking.
struct BusTrackingActivity: ActivityAttributes {
    public typealias ContentState = State

    public struct State: Codable, Hashable {
        /// Minutes until the bus reaches the user's stop. `nil` means we
        /// don't have a live ETA right now (LTA dropout / scheduled).
        public var etaMinutes: Int?
        /// Whether the displayed ETA came from real-time GPS or schedule.
        public var isLive: Bool
        /// Current crowd state — `seats`, `standing`, `limited`, `unknown`.
        public var crowdLevel: String
        /// Last time the main app pushed a content-state update.
        public var lastUpdated: Date

        public init(
            etaMinutes: Int?,
            isLive: Bool,
            crowdLevel: String,
            lastUpdated: Date
        ) {
            self.etaMinutes = etaMinutes
            self.isLive = isLive
            self.crowdLevel = crowdLevel
            self.lastUpdated = lastUpdated
        }
    }

    /// Bus service number (e.g. "14", "184").
    public let serviceNo: String
    /// Destination short label (e.g. "→ Bedok Interchange").
    public let destination: String
    /// User's stop name (e.g. "Blk 416").
    public let stopName: String
    /// User's stop code (e.g. "84009").
    public let stopCode: String

    public init(
        serviceNo: String,
        destination: String,
        stopName: String,
        stopCode: String
    ) {
        self.serviceNo = serviceNo
        self.destination = destination
        self.stopName = stopName
        self.stopCode = stopCode
    }
}
