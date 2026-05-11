import Foundation
import CoreLocation

/// Picks the best nearby bus that goes toward a saved destination.
///
/// Strategy:
///   1. Geocode the destination address (cached) to get a coordinate.
///   2. Find the N bus stops nearest that coordinate (the destination's
///      "stop neighbourhood").
///   3. For each candidate arrival at the user's current stop, look up the
///      bus's onward route via `BusRoutesRepository`. If any onward stop is
///      in the destination neighbourhood, that bus is a match.
///   4. Return the soonest matching arrival.
///
/// This is not a real journey planner — it doesn't handle transfers, walking
/// segments, or multi-leg trips. It answers a narrower question: "of the
/// buses about to arrive here, which one (if any) goes to roughly where I
/// want to go?"
@MainActor
final class JourneySuggester {
    static let shared = JourneySuggester()

    private var geocodeCache: [String: CLLocationCoordinate2D] = [:]

    /// Best matching arrival, or nil if no candidate goes near the destination
    /// (or the address can't be geocoded).
    func suggest(
        destinationAddress: String,
        from arrivals: [BusArrival],
        userStopCode: String,
        searchRadiusMeters: Double = 600
    ) async -> BusArrival? {
        let address = destinationAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty else { return nil }

        guard let destCoord = await coordinate(for: address) else { return nil }
        let destLocation = CLLocation(latitude: destCoord.latitude, longitude: destCoord.longitude)

        // Stops near the destination form the "arrival neighbourhood".
        let neighbourhood = await BusStopsRepository.shared.nearest(to: destLocation, count: 12)
        let destStopCodes = Set(
            neighbourhood
                .filter { ($0.distanceMeters ?? .max) <= Int(searchRadiusMeters) }
                .map(\.id)
        )
        guard !destStopCodes.isEmpty else { return nil }

        // Sort candidate arrivals by ETA so we naturally return the soonest match.
        let sorted = arrivals.sorted {
            ($0.nextArrivalMinutes ?? .max) < ($1.nextArrivalMinutes ?? .max)
        }

        for arrival in sorted where arrival.nextArrivalMinutes != nil {
            let onward = await BusRoutesRepository.shared.upcomingStops(
                serviceNo: arrival.serviceNo,
                currentStopCode: userStopCode,
                destinationCode: arrival.destinationCode,
                limit: 60
            )
            if onward.contains(where: { destStopCodes.contains($0.busStopCode) }) {
                return arrival
            }
        }
        return nil
    }

    private func coordinate(for address: String) async -> CLLocationCoordinate2D? {
        if let cached = geocodeCache[address] { return cached }
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString("\(address), Singapore")
            guard let coord = placemarks.first?.location?.coordinate else { return nil }
            geocodeCache[address] = coord
            return coord
        } catch {
            return nil
        }
    }
}
