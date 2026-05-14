import Foundation

/// Audio cues are intentionally disabled app-wide — feedback for user
/// actions comes through toasts + haptics instead. The methods are kept
/// as no-op stubs so any leftover call site still compiles; deleting the
/// enum entirely would mean chasing imports and historical references
/// across the codebase for no behavioural gain.
enum SoundEffect {
    static func playSuccess() {}
    static func playWarning() {}
    static func playTap() {}
    static func playBusPinToggle() {}
    static func playStopPinToggle() {}
}
