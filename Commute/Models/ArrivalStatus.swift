import SwiftUI

/// Drives the arrival chip's tint per redesign spec §3. Crowd is encoded
/// separately via the corner bars on `ArrivalPill`, so the chip's colour is
/// reserved for time-relationship signal: imminent / normal / delayed /
/// cancelled. `delayed` has no auto-derived source today (LTA's bus arrivals
/// API doesn't expose a delay flag) — wire it in when signal becomes available.
enum ArrivalStatus {
    case imminent
    case normal
    case delayed
    case cancelled

    /// Tint blended into the chip's glass background. `nil` = clear glass.
    var tint: Color? {
        switch self {
        case .imminent:  Color.appSuccess.opacity(0.32)
        case .normal:    nil
        case .delayed:   Color.appWarning.opacity(0.30)
        case .cancelled: Color.appDanger.opacity(0.26)
        }
    }

    /// Foreground colour that reads cleanly against the tint.
    var foreground: Color {
        switch self {
        case .imminent:  Color.appSuccessStrong
        case .normal:    Color.appText
        case .delayed:   Color.appWarningStrong
        case .cancelled: Color.appDangerStrong
        }
    }

    /// SF Symbol shown alongside the minute count for non-normal states.
    /// Returns `nil` for `.normal` so the chip stays clean in the common case.
    var statusSymbol: String? {
        switch self {
        case .imminent:  nil
        case .normal:    nil
        case .delayed:   "clock.badge.exclamationmark"
        case .cancelled: "xmark.circle"
        }
    }

    /// Default mapping from minute count alone. ≤ 2 min ⇒ imminent ("Now"),
    /// `nil` ⇒ cancelled (last bus left / no service).
    static func from(minutes: Int?) -> ArrivalStatus {
        guard let minutes else { return .cancelled }
        if minutes <= 2 { return .imminent }
        return .normal
    }

    /// Spec §3 label rules: ≤ 2 min ⇒ "Now", otherwise "{n} min". `~` prefix
    /// retained for scheduled (non-realtime) arrivals so they remain visually
    /// distinguishable from live ETAs.
    static func label(minutes: Int?, scheduled: Bool = false) -> String {
        guard let minutes else { return "—" }
        if minutes <= 2 { return "Now" }
        let prefix = scheduled ? "~" : ""
        return "\(prefix)\(minutes) min"
    }
}
