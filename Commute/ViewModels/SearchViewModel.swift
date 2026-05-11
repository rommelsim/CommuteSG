import SwiftUI
import CoreLocation
import Observation

/// A geocoded address result — used when the user types a postal code or a
/// free-text address that's not a known bus stop or MRT station.
struct AddressResult: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// String representation suitable for storing in `fromText` / `toText`.
    var displayValue: String {
        subtitle.isEmpty ? title : "\(title), \(subtitle)"
    }
}

@MainActor
@Observable
final class SearchViewModel {
    var query: String = "" {
        didSet { scheduleSearch() }
    }
    var busStopResults: [BusStop] = []
    var mrtResults: [MRTStation] = []
    var addressResults: [AddressResult] = []
    var isSearching = false

    private var searchTask: Task<Void, Never>?
    private var geocodeCache: [String: [AddressResult]] = [:]
    private let stops: BusStopsRepository
    private let mrtRepo: MRTStationsRepository
    private let location: LocationService

    init(
        stops: BusStopsRepository = .shared,
        mrtRepo: MRTStationsRepository = .shared,
        location: LocationService? = nil
    ) {
        self.stops = stops
        self.mrtRepo = mrtRepo
        self.location = location ?? LocationService.shared
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            busStopResults = []
            mrtResults = []
            addressResults = []
            isSearching = false
            return
        }
        isSearching = true
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            await self?.runSearch(trimmed)
        }
    }

    private func runSearch(_ q: String) async {
        let needle = q.lowercased()
        let userLoc = location.lastLocation

        // Bus stops
        let allStops = await stops.stops
        let stopMatches = allStops.filter { stop in
            stop.name.lowercased().contains(needle) ||
            stop.id.contains(q) ||
            stop.road.lowercased().contains(needle)
        }
        let rankedStops = Self.rankBusStops(stopMatches, near: userLoc, query: needle)
        busStopResults = Array(rankedStops.prefix(25))

        // MRT
        let allMRT = mrtRepo.stations
        let mrtMatches = allMRT.filter { station in
            station.name.lowercased().contains(needle) ||
            station.id.lowercased().contains(needle) ||
            station.line.fullName.lowercased().contains(needle)
        }
        let rankedMRT = Self.rankMRT(mrtMatches, near: userLoc, query: needle)
        mrtResults = Array(rankedMRT.prefix(15))

        // Addresses (postal codes, road names, places of interest)
        await runGeocode(q)

        isSearching = false
    }

    private func runGeocode(_ q: String) async {
        let key = q.lowercased()
        if let cached = geocodeCache[key] {
            addressResults = cached
            return
        }

        // Skip if the query looks like a 5-digit bus stop code — those are
        // handled by the bus stop search. Geocoding 5 digits returns random
        // postal-code matches that confuse the user.
        if q.count == 5, q.allSatisfy(\.isNumber) {
            addressResults = []
            return
        }

        // Only geocode meaningful queries
        guard q.count >= 4 else {
            addressResults = []
            return
        }

        // Bias to Singapore so postal codes resolve correctly
        let queryText = q.localizedCaseInsensitiveContains("singapore") ? q : "\(q), Singapore"
        let geocoder = CLGeocoder()

        do {
            let placemarks = try await geocoder.geocodeAddressString(queryText)
            if Task.isCancelled { return }
            let results: [AddressResult] = placemarks.compactMap { pm in
                guard let coord = pm.location?.coordinate else { return nil }
                // Singapore-only — filter out international matches
                guard pm.isoCountryCode == "SG" else { return nil }
                let title = Self.formatTitle(pm, fallback: q)
                let subtitle = Self.formatSubtitle(pm)
                return AddressResult(
                    title: title,
                    subtitle: subtitle,
                    latitude: coord.latitude,
                    longitude: coord.longitude
                )
            }
            let top = Array(results.prefix(5))
            geocodeCache[key] = top
            addressResults = top
        } catch {
            // Cancelled or no matches — leave addressResults empty
            addressResults = []
        }
    }

    private static func formatTitle(_ pm: CLPlacemark, fallback: String) -> String {
        // Prefer a recognizable place name or road, then postal code, then the query
        if let name = pm.name, !name.isEmpty, name != pm.postalCode {
            return name
        }
        if let road = pm.thoroughfare, !road.isEmpty {
            return road
        }
        if let postal = pm.postalCode {
            return "Singapore \(postal)"
        }
        return fallback
    }

    private static func formatSubtitle(_ pm: CLPlacemark) -> String {
        var parts: [String] = []
        if let area = pm.subLocality ?? pm.locality {
            parts.append(area)
        }
        if let postal = pm.postalCode {
            parts.append("S(\(postal))")
        }
        return parts.joined(separator: " · ")
    }

    private static func rankBusStops(_ items: [BusStop], near location: CLLocation?, query: String) -> [BusStop] {
        items
            .map { stop -> (stop: BusStop, score: Double, dist: Double?) in
                var dist: Double?
                if let loc = location, let coord = stop.coordinate {
                    dist = loc.distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
                }
                let exactBoost: Double = stop.id == query ? -1_000_000 : 0
                let prefixBoost: Double = stop.name.lowercased().hasPrefix(query) ? -100 : 0
                let baseScore = dist ?? 1_000_000
                return (stop, baseScore + exactBoost + prefixBoost, dist)
            }
            .sorted { $0.score < $1.score }
            .map { entry in
                BusStop(
                    id: entry.stop.id,
                    name: entry.stop.name,
                    road: entry.stop.road,
                    distanceMeters: entry.dist.map { Int($0) },
                    coordinate: entry.stop.coordinate
                )
            }
    }

    private static func rankMRT(_ items: [MRTStation], near location: CLLocation?, query: String) -> [MRTStation] {
        let repo = MRTStationsRepository.shared
        return items
            .map { station -> (station: MRTStation, score: Double, dist: Double?) in
                var dist: Double?
                if let loc = location {
                    dist = repo.distance(from: loc, to: station.id)
                }
                let exactIdBoost: Double = station.id.lowercased() == query ? -1_000_000 : 0
                let prefixBoost: Double = station.name.lowercased().hasPrefix(query) ? -100 : 0
                let baseScore = dist ?? 1_000_000
                return (station, baseScore + exactIdBoost + prefixBoost, dist)
            }
            .sorted { $0.score < $1.score }
            .map { entry in
                MRTStation(
                    id: entry.station.id,
                    name: entry.station.name,
                    line: entry.station.line,
                    interchangeLines: entry.station.interchangeLines,
                    distanceMeters: entry.dist.map { Int($0) }
                )
            }
    }
}
