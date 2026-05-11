import Foundation
import AudioToolbox
import AVFoundation

/// Subtle success / error cues paired with the haptic feedback we already
/// fire elsewhere. Most cues use iOS's built-in system sounds (no asset
/// shipping, auto-silenced by the ringer switch). The pin-toggle cues are
/// instead synthesized on-the-fly as short major-chord arpeggios — iOS
/// doesn't ship a stock sound that's both gentle and recognizably positive.
enum SoundEffect {
    /// A short, generic confirmation cue (Tink).
    static func playSuccess() { AudioServicesPlaySystemSound(1057) }

    /// Reserved for unused error cases — slightly heavier alert tone.
    static func playWarning() { AudioServicesPlaySystemSound(1521) }

    /// A soft keyboard-style tap, used for selection cues.
    static func playTap() { AudioServicesPlaySystemSound(1104) }

    /// Pin / unpin a bus service number — quick rising major-3rd arpeggio
    /// (C5 → E5). Reads as "small win". Same sound for pin and unpin;
    /// direction is carried by the toast + haptic.
    static func playBusPinToggle() {
        CheeringSynth.shared.play(.busPin)
    }

    /// Pin / unpin a bus stop — fuller rising major-chord arpeggio
    /// (C5 → E5 → G5). Reads as "saved a destination". Distinct from the
    /// bus tone so you can tell what you just pinned without looking.
    static func playStopPinToggle() {
        CheeringSynth.shared.play(.stopPin)
    }
}

// MARK: - Cheering synth
//
// Renders short, cheerful tones via AVAudioEngine. Buffers are cached after
// first generation. Audio session is `.ambient + .mixWithOthers`:
//   • Ringer switch silences us (matches `AudioServicesPlaySystemSound`).
//   • Music / podcasts keep playing — we mix in, don't interrupt.
//
// Buffers are scheduled WITHOUT `.interrupts` so a quick second tap doesn't
// kill the first sound mid-decay; subsequent buffers queue and play right
// after, producing a natural overlap rather than an abrupt cut.

private final class CheeringSynth: @unchecked Sendable {
    static let shared = CheeringSynth()

    enum Tone {
        case busPin   // C5 → E5 (major third)
        case stopPin  // C5 → E5 → G5 (major chord)
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private var cache: [String: AVAudioPCMBuffer] = [:]
    private var prepared = false
    private let lock = NSLock()

    private init() {
        self.format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
            ?? AVAudioFormat()
    }

    func play(_ tone: Tone) {
        lock.lock()
        defer { lock.unlock() }
        prepareIfNeeded()
        guard prepared else { return }
        let key = String(describing: tone)
        if cache[key] == nil { cache[key] = makeBuffer(for: tone) }
        guard let buf = cache[key] else { return }
        if !player.isPlaying { player.play() }
        // No `.interrupts` — let in-flight playback decay naturally so the
        // tail doesn't cut off mid-animation if the user pins twice quickly.
        player.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
    }

    private func prepareIfNeeded() {
        guard !prepared else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true, options: [])
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
            prepared = true
        } catch {
            // Engine failed to start — playback will silently no-op.
        }
    }

    // MARK: - Buffer synthesis

    private func makeBuffer(for tone: Tone) -> AVAudioPCMBuffer? {
        switch tone {
        case .busPin:
            return arpeggio(notes: [523.25, 659.25],            // C5, E5
                            noteDuration: 0.18,
                            stepGap: 0.05,
                            tail: 0.20)
        case .stopPin:
            return arpeggio(notes: [523.25, 659.25, 783.99],    // C5, E5, G5
                            noteDuration: 0.18,
                            stepGap: 0.06,
                            tail: 0.22)
        }
    }

    /// Synthesize a sequence of overlapping notes. Each note has its own
    /// soft attack + exponential decay envelope. Total duration =
    /// (notes.count - 1) · stepGap + noteDuration + tail. The trailing
    /// `tail` lets the final note's decay fade out completely so playback
    /// doesn't cut off audibly.
    private func arpeggio(notes: [Double], noteDuration: Double, stepGap: Double, tail: Double) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        guard sampleRate > 0, !notes.isEmpty else { return nil }
        let totalDuration = Double(notes.count - 1) * stepGap + noteDuration + tail
        let frameCount = AVAudioFrameCount(sampleRate * totalDuration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount

        let attackTime: Double = 0.008   // 8ms ramp — no click
        let decayRate: Double = 8.0      // tau ≈ 125ms — gradual fade
        let amplitude: Float = 0.30

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            var sample: Float = 0
            for (idx, freq) in notes.enumerated() {
                let noteStart = Double(idx) * stepGap
                let noteT = t - noteStart
                if noteT < 0 { continue }
                let attackEnv = min(1.0, noteT / attackTime)
                let decayEnv = exp(-noteT * decayRate)
                let envelope = Float(attackEnv * decayEnv)
                // Use noteT (time since this note started) for the sine so
                // each note begins at sin(0)=0 — no boundary click.
                sample += Float(sin(2 * .pi * freq * noteT)) * envelope * amplitude
            }
            channel[frame] = sample
        }
        return buffer
    }
}
