import SwiftUI
import CoreLocation
import Observation

@MainActor
@Observable
final class SearchViewModel {
    var query: String = "" {
        didSet { scheduleSearch() }
    }
    var busStopResults: [BusStop] = []
    var mrtResults: [MRTStation] = []
    var isSearching = false

    private var searchTask: Task<Void, Never>?
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
        isSearching = false
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
