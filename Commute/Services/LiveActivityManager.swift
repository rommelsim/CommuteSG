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
        followingMinutes: [Int] = [],
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
            followingMinutes: followingMinutes,
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
            // New tracking session — clear any past "arrived" dedup so the
            // next 0-min update can fire its alert.
            NotificationService.shared.resetArrivalDedup(
                forServiceNo: serviceNo,
                stopCode: stopCode
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

    func update(etaMinutes: Int?, followingMinutes: [Int] = [], isLive: Bool, crowdLevel: String) async {
        guard let activity = current else { return }
        let state = BusTrackingActivity.State(
            etaMinutes: etaMinutes,
            followingMinutes: followingMinutes,
            isLive: isLive,
            crowdLevel: crowdLevel,
            lastUpdated: Date()
        )
        let content = ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(15 * 60)
        )
        await activity.update(content)

        // Fire the time-sensitive "arriving" alert exactly once per tracked
        // arrival — the service handles dedup so back-to-back 0/1-min
        // updates don't ping the user repeatedly.
        if let eta = etaMinutes, eta <= 1 {
            await NotificationService.shared.postArriving(
                serviceNo: activity.attributes.serviceNo,
                stopName: activity.attributes.stopName,
                stopCode: activity.attributes.stopCode,
                destination: activity.attributes.destination,
                crowdLevel: crowdLevel
            )
        }
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

    // MARK: - Train arrival

    private(set) var currentTrain: Activity<TrainArrivalActivity>?

    func startTrain(
        stationCode: String,
        stationName: String,
        lineName: String,
        towardsDestination: String,
        initialState: TrainArrivalActivity.State
    ) {
        guard isAvailable else { return }
        if currentTrain != nil { Task { await endTrain() } }

        let attributes = TrainArrivalActivity(
            stationCode: stationCode,
            stationName: stationName,
            lineName: lineName,
            towardsDestination: towardsDestination
        )
        let content = ActivityContent(
            state: initialState,
            staleDate: Date().addingTimeInterval(120)
        )
        do {
            currentTrain = try Activity<TrainArrivalActivity>.request(
                attributes: attributes,
                content: content,
                pushType: nil  // local-update fallback; switch to .token when backend exists
            )
        } catch {
            currentTrain = nil
        }
    }

    func updateTrain(state: TrainArrivalActivity.State) async {
        guard let activity = currentTrain else { return }
        await activity.update(ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(120)
        ))
    }

    func endTrain() async {
        guard let activity = currentTrain else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        currentTrain = nil
    }

    // MARK: - Journey

    private(set) var currentJourney: Activity<JourneyActivity>?

    func startJourney(
        destinationName: String,
        initialState: JourneyActivity.State
    ) {
        guard isAvailable else { return }
        if currentJourney != nil { Task { await endJourney() } }

        let attributes = JourneyActivity(destinationName: destinationName)
        let content = ActivityContent(
            state: initialState,
            staleDate: Date().addingTimeInterval(300)
        )
        do {
            currentJourney = try Activity<JourneyActivity>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            currentJourney = nil
        }
    }

    func updateJourney(state: JourneyActivity.State) async {
        guard let activity = currentJourney else { return }
        await activity.update(ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(300)
        ))
    }

    func endJourney() async {
        guard let activity = currentJourney else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        currentJourney = nil
    }
}
