import Foundation
import CoreLocation
import Observation

enum LocationError: LocalizedError {
    case denied
    case restricted
    case timeout
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .denied:           "Location access denied. Enable it in Settings."
        case .restricted:       "Location services are restricted on this device."
        case .timeout:          "Couldn't get your location in time. Try again."
        case .underlying(let e): e.localizedDescription
        }
    }
}

@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    var authorizationStatus: CLAuthorizationStatus
    var lastLocation: CLLocation?

    private let manager = CLLocationManager()
    private var continuations: [CheckedContinuation<CLLocation, Error>] = []

    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func currentLocation(timeout: TimeInterval = 10) async throws -> CLLocation {
        if let cached = lastLocation,
           Date().timeIntervalSince(cached.timestamp) < 60 {
            return cached
        }
        switch authorizationStatus {
        case .denied:     throw LocationError.denied
        case .restricted: throw LocationError.restricted
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default: break
        }

        return try await withCheckedThrowingContinuation { cont in
            continuations.append(cont)
            manager.requestLocation()
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                self?.failIfStillPending(LocationError.timeout)
            }
        }
    }

    private func failIfStillPending(_ error: Error) {
        guard !continuations.isEmpty else { return }
        let pending = continuations
        continuations.removeAll()
        for c in pending { c.resume(throwing: error) }
    }

    private func deliver(_ result: Result<CLLocation, Error>) {
        guard !continuations.isEmpty else { return }
        let pending = continuations
        continuations.removeAll()
        for c in pending { c.resume(with: result) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ mgr: CLLocationManager) {
        let status = mgr.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
        }
    }

    nonisolated func locationManager(_ mgr: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.lastLocation = loc
            self.deliver(.success(loc))
        }
    }

    nonisolated func locationManager(_ mgr: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.deliver(.failure(LocationError.underlying(error)))
        }
    }
}
