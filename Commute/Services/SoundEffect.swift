import Foundation
import AudioToolbox

/// Subtle success / error cues paired with the haptic feedback we already
/// fire elsewhere. Uses iOS's built-in system sounds so we don't ship audio
/// assets — and respects the system silent switch automatically (system
/// sounds via `AudioServicesPlaySystemSound` are silent when the ringer is
/// off, which is the polite default for confirmation cues).
enum SoundEffect {
    /// A short tink, used for confirmations like "place saved", "starring
    /// a stop", or "Live Activity started".
    static func playSuccess() {
        // 1057 = "Tink" — the lightest of the system sounds, near-imperceptible
        // when the ringer is on, fully silenced otherwise. Same one Reminders
        // and Calendar use for completion confirmations.
        AudioServicesPlaySystemSound(1057)
    }

    /// A slightly heavier alert tone, reserved for moments where the user
    /// triggered a meaningful state change but it failed (e.g. Live Activity
    /// rejected by the system). Currently unused but here for consistency
    /// with `playSuccess`.
    static func playWarning() {
        // 1521 = "ReceivedMessage" — short, distinct, slightly heavier.
        AudioServicesPlaySystemSound(1521)
    }

    /// A soft keyboard-style tap, used for "deselect" or "remove" actions
    /// like un-starring a stop. Quieter than `playSuccess` so the unsave
    /// doesn't feel as celebratory as the save.
    static func playTap() {
        // 1104 = a soft keyboard tap, used in iOS for selection cues.
        AudioServicesPlaySystemSound(1104)
    }
}
