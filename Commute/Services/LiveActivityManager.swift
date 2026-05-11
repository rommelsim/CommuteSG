import Foundation
import ActivityKit

/// Manages a single in-flight `BusTrackingActivity`. The main app calls
/// `start(for:)` when the user taps "Track on Lock Screen" in
/// `LiveTrackingView`, then `update(...)` on every poll, and `end(...)`
/// when the bus arrives or the user dismisses tracking.
///
/// On iOS < 16.2, `ActivityKit` symbols are unavailable — but our
/// deployment target is iOS 17.0 so this is always usable.
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private(set) var current: Activity<BusTrackingActivity>?

    private init() {}

    /// True when Live Activities are allowed by the user / system.
    var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// True when we currently have an active tracking activity for this
    /// service+stop pair. Used to flip the toggle in `LiveTrackingView`
    /// across view re-creations.
    func isActive(for serviceNo: String, stopCode: String?) -> Bool {
        guard let current else { return false }
        return current.attributes.serviceNo == serviceNo
            && current.attributes.stopCode == (stopCode ?? "")
    }

    func start(
        serviceNo: String,
        destination: String,
        stopName: String,
        stopCode: String,
        etaMinutes: Int?,
        isLive: Bool,
        crowdLevel: String
    ) {
        // Only one tracking activity at a time — replace any in-flight one.
        if current != nil { Task { await endActiveActivity() } }

        guard isAvailable else { return }

        let attributes = BusTrackingActivity(
            serviceNo: serviceNo,
            destination: destination,
            stopName: stopName,
            stopCode: stopCode
        )
        let state = BusTrackingActivity.State(
            etaMinutes: etaMinutes,
            isLive: isLive,
            crowdLevel: crowdLevel,
            lastUpdated: Date()
        )
        let content = ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(15 * 60)
        )

        do {
            current = try Activity<BusTrackingActivity>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            SoundEffect.playSuccess()
            ToastCenter.shared.show(.success(
                "Tracking Bus \(serviceNo) on Lock Screen",
                symbol: "bolt.heart.fill"
            ))
        } catch {
            current = nil
            SoundEffect.playWarning()
            ToastCenter.shared.show(.warning(
                "Couldn't start Live Activity",
                symbol: "exclamationmark.triangle.fill"
            ))
        }
    }

    func update(etaMinutes: Int?, isLive: Bool, crowdLevel: String) async {
        guard let activity = current else { return }
        let state = BusTrackingActivity.State(
            etaMinutes: etaMinutes,
            isLive: isLive,
            crowdLevel: crowdLevel,
            lastUpdated: Date()
        )
        let content = ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(15 * 60)
        )
        await activity.update(content)
    }

    /// End the activity. iOS shows it for ~4 hours on the Lock Screen
    /// after `.dismissalPolicy(.default)` unless we use `.immediate`.
    func endActiveActivity() async {
        guard let activity = current else { return }
        let finalState = activity.content.state
        let content = ActivityContent(state: finalState, staleDate: nil)
        await activity.end(content, dismissalPolicy: .immediate)
        current = nil
        ToastCenter.shared.show(.info("Tracking stopped", symbol: "bolt.slash"))
    }
}
