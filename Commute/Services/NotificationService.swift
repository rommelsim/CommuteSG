import Foundation
import UserNotifications

/// Owns all UNUserNotificationCenter interaction for the app — permission
/// flow + scheduling the three notification kinds the design supports:
/// leave-now nudge, "arriving" time-sensitive alert, and line disruption.
///
/// All public methods short-circuit when the user has switched off the
/// in-app `notificationsEnabled` toggle, so callers don't need to
/// double-check. The OS-level permission is a separate gate that the
/// service requests on first toggle-on.
@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    /// Per-process dedup so we don't ping the user repeatedly for the
    /// same arriving bus or the same live disruption across refreshes.
    private var firedArrivals = Set<String>()
    private var firedDisruptions = Set<String>()

    private init() {}

    /// Mirror of `AppState.notificationsEnabled`. Reading from defaults
    /// directly lets services call us without holding an AppState
    /// reference. Stays in sync because `AppState` writes the same key.
    private var userOptedIn: Bool {
        UserDefaults.standard.object(forKey: "commute.notifications") as? Bool ?? true
    }

    // MARK: - Authorization

    /// Call once on app launch. If the user has previously granted
    /// permission, this is a no-op; if denied, we leave them in Settings.
    func bootstrap() async {
        _ = await center.notificationSettings()
    }

    /// Request OS-level permission. Returns whether the user granted it.
    /// Time-sensitive delivery is granted by the matching entitlement (see
    /// `Commute.entitlements`) rather than an `authorizationOptions` flag,
    /// which was deprecated in iOS 15.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(
                options: [.alert, .sound, .badge]
            )
        } catch {
            return false
        }
    }

    /// `true` when the OS has granted us alert permission. The in-app
    /// toggle is a separate user preference — both must be on for us to
    /// actually post.
    func isSystemAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    // MARK: - Posting

    /// Leave-now nudge — fires at (eta − walk) minutes from now, so the
    /// user gets an alert with exactly enough time to walk to the stop.
    /// Cancels any prior leave-now nudge for this service first.
    func scheduleLeaveNow(
        serviceNo: String,
        stopName: String,
        etaMinutes: Int,
        walkMinutes: Int
    ) async {
        guard userOptedIn else { return }
        guard await ensurePermission() else { return }

        let leadTime = max(0, etaMinutes - walkMinutes)
        let id = leaveNowID(serviceNo: serviceNo)
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = "Leave now to catch the \(serviceNo)"
        content.body = "Bus arriving at \(stopName) in \(etaMinutes) min · \(walkMinutes) min walk"
        content.sound = .default
        content.interruptionLevel = .active
        content.threadIdentifier = "bus.\(serviceNo)"

        // Fire immediately when ETA <= walk time (we're already late); else
        // schedule for the moment they need to start walking.
        let trigger: UNNotificationTrigger?
        if leadTime <= 0 {
            trigger = nil
        } else {
            trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(leadTime * 60),
                repeats: false
            )
        }

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    /// Time-sensitive "bus is here" alert. Deduped per service+stop for
    /// this session — calling it twice for the same arrival is a no-op.
    func postArriving(
        serviceNo: String,
        stopName: String,
        stopCode: String,
        destination: String,
        crowdLevel: String
    ) async {
        guard userOptedIn else { return }
        let key = "\(serviceNo)@\(stopCode)"
        guard !firedArrivals.contains(key) else { return }
        guard await ensurePermission() else { return }
        firedArrivals.insert(key)

        let content = UNMutableNotificationContent()
        content.title = "\(serviceNo) is arriving at \(stopName)"
        content.body = "To \(destination) · \(crowdHint(crowdLevel))"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.threadIdentifier = "bus.\(serviceNo)"

        let request = UNNotificationRequest(
            identifier: arrivingID(serviceNo: serviceNo, stopCode: stopCode),
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    /// Disruption alert (e.g. "Delays on North-South Line"). The signature
    /// argument should be stable across refreshes so we only fire once
    /// per real-world incident.
    func postDisruption(
        signature: String,
        lineName: String,
        body: String
    ) async {
        guard userOptedIn else { return }
        guard !firedDisruptions.contains(signature) else { return }
        guard await ensurePermission() else { return }
        firedDisruptions.insert(signature)

        let content = UNMutableNotificationContent()
        content.title = "Delays on \(lineName)"
        content.body = body
        content.sound = .default
        content.interruptionLevel = .active
        content.threadIdentifier = "alerts.lines"

        let request = UNNotificationRequest(
            identifier: "disruption.\(signature)",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    // MARK: - Cancellation / cleanup

    func cancelLeaveNow(forServiceNo serviceNo: String) {
        center.removePendingNotificationRequests(
            withIdentifiers: [leaveNowID(serviceNo: serviceNo)]
        )
    }

    /// Reset the per-process arrival dedup. Call when the user starts
    /// tracking a new bus so we don't suppress its first arrival alert.
    func resetArrivalDedup(forServiceNo serviceNo: String, stopCode: String) {
        firedArrivals.remove("\(serviceNo)@\(stopCode)")
    }

    /// Drop every queued and delivered notification, plus all per-session
    /// dedup state. Used by the in-app "Reset" wipe so notifications from
    /// a previous session don't bleed into the freshly-onboarded state.
    func resetAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        firedArrivals.removeAll()
        firedDisruptions.removeAll()
    }

    // MARK: - Helpers

    private func ensurePermission() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return await requestAuthorization()
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    private func leaveNowID(serviceNo: String) -> String {
        "leaveNow.\(serviceNo)"
    }

    private func arrivingID(serviceNo: String, stopCode: String) -> String {
        "arriving.\(serviceNo).\(stopCode)"
    }

    private func crowdHint(_ raw: String) -> String {
        switch raw.lowercased() {
        case "seats": "seats available"
        case "standing": "standing room only"
        case "limited": "packed"
        default: "boarding now"
        }
    }
}
