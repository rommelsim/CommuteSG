import Foundation
import CoreMotion
import Observation

/// Lightweight wrapper over `CMMotionManager` that publishes a smoothed
/// device-tilt vector for parallax effects. Values are in `[-1, 1]`:
///   `x`: -1 = phone tilted to the left, +1 = right
///   `y`: -1 = top edge tipped forward, +1 = back
///
/// A simple low-pass filter softens sensor jitter so the orbs glide rather
/// than judder. The motion sensors don't require Info.plist privacy strings
/// (those are only needed for CMPedometer / historical data).
@MainActor
@Observable
final class MotionTilt {
    private(set) var x: Double = 0
    private(set) var y: Double = 0

    private let manager = CMMotionManager()
    private let queue: OperationQueue = {
        let q = OperationQueue()
        q.qualityOfService = .userInteractive
        return q
    }()

    /// Smoothing factor in `(0, 1]`. Smaller = smoother but laggier.
    private let alpha: Double = 0.18

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let motion else { return }
            let gx = motion.gravity.x
            let gy = motion.gravity.y
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.x = self.x * (1 - self.alpha) + gx * self.alpha
                self.y = self.y * (1 - self.alpha) + gy * self.alpha
            }
        }
    }

    func stop() {
        if manager.isDeviceMotionActive {
            manager.stopDeviceMotionUpdates()
        }
    }
}
