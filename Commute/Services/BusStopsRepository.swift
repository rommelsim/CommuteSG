import Foundation
import CoreLocation

/// Sync, MainActor-readable lookup of bus-stop names by code. Populated by
/// `BusStopsRepository` whenever its stop dataset loads or refreshes. Used
/// by views to resolve LTA destination codes (e.g. "11379") to stop names
/// (e.g. "Aljunied Stn") without an async hop.
@MainActor
final class BusStopNameCache {
    static let shared = BusStopNameCache()
    private var dict: [String: String] = [:]

    func name(forCode code: String) -> String? { dict[code] }

    func update(from stops: [BusStop]) {
        dict = Dictionary(uniqueKeysWithValues: stops.map { ($0.id, $0.name) })
    }
}

actor BusStopsRepository {
    static let shared = BusStopsRepository()

    private let lta: LTAService
    private let cacheURL: URL
    private let cacheTTL: TimeInterval = 30 * 24 * 3600  // 30 days

    private(set) var stops: [BusStop] = []
    private(set) var lastUpdated: Date?

    init(lta: LTAService = .shared) {
        self.lta = lta
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Commute", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("bus_stops.json")
        self.cacheURL = url
        if let payload = Self.readCache(at: url) {
            self.stops = payload.stops.map { row in
                BusStop(id: row.id, name: row.name, road: row.road, distanceMeters: nil,
                        coordinate: CLLocationCoordinate2D(latitude: row.lat, longitude: row.lon))
            }
            self.lastUpdated = payload.savedAt
            let snapshot = self.stops
            Task { @MainActor in BusStopNameCache.shared.update(from: snapshot) }
        }
    }

    var hasFreshData: Bool {
        guard let lastUpdated, !stops.isEmpty else { return false }
        return Date().timeIntervalSince(lastUpdated) < cacheTTL
    }

    var hasCachedData: Bool { !stops.isEmpty }

    /// Returns a stream of progress updates (cumulative count of stops loaded).
    /// If cache is fresh and forceRefresh is false, the stream finishes immediately.
    nonisolated func loadAllStops(forceRefresh: Bool = false) -> AsyncThrowingStream<Int, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.runLoad(forceRefresh: forceRefresh, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func runLoad(
        forceRefresh: Bool,
        continuation: AsyncThrowingStream<Int, Error>.Continuation
    ) async throws {
        if !forceRefresh, hasFreshData {
            continuation.yield(stops.count)
            return
        }

        var collected: [BusStop] = []
        var skip = 0
        let pageSize = 500
        while !Task.isCancelled {
            let page = try await lta.busStopsPage(skip: skip)
            if page.isEmpty { break }
            collected.append(contentsOf: page.map(Self.toBusStop(from:)))
            continuation.yield(collected.count)
            if page.count < pageSize { break }
            skip += page.count
        }

        guard !collected.isEmpty else { return }
        self.stops = collected
        self.lastUpdated = Date()
        saveToDisk()
        let snapshot = collected
        Task { @MainActor in BusStopNameCache.shared.update(from: snapshot) }
    }

    func nearest(to location: CLLocation, count: Int) -> [BusStop] {
        stops
            .compactMap { stop -> (BusStop, CLLocationDistance)? in
                guard let c = stop.coordinate else { return nil }
                let d = location.distance(from: CLLocation(latitude: c.latitude, longitude: c.longitude))
                return (stop, d)
            }
            .sorted { $0.1 < $1.1 }
            .prefix(count)
            .map { stop, dist in
                BusStop(id: stop.id, name: stop.name, road: stop.road,
                        distanceMeters: Int(dist), coordinate: stop.coordinate)
            }
    }

    // MARK: - Persistence

    private struct CachedRow: Codable {
        let id, name, road: String
        let lat, lon: Double
    }

    private struct CachedPayload: Codable {
        let savedAt: Date
        let stops: [CachedRow]
    }

    private static func readCache(at url: URL) -> CachedPayload? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CachedPayload.self, from: data)
    }

    private func saveToDisk() {
        let rows = stops.map {
            CachedRow(id: $0.id, name: $0.name, road: $0.road,
                      lat: $0.coordinate?.latitude ?? 0, lon: $0.coordinate?.longitude ?? 0)
        }
        let payload = CachedPayload(savedAt: lastUpdated ?? Date(), stops: rows)
        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: cacheURL, options: .atomic)
        }
    }

    private static func toBusStop(from x: LTABusStop) -> BusStop {
        BusStop(
            id: x.busStopCode,
            name: x.description,
            road: x.roadName,
            distanceMeters: nil,
            coordinate: CLLocationCoordinate2D(latitude: x.latitude, longitude: x.longitude)
        )
    }
}
