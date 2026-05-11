import Foundation

actor BusRoutesRepository {
    static let shared = BusRoutesRepository()

    struct RouteStop: Codable, Hashable {
        let serviceNo: String
        let direction: Int
        let stopSequence: Int
        let busStopCode: String
    }

    private let lta: LTAService
    private let cacheURL: URL
    private let cacheTTL: TimeInterval = 7 * 24 * 3600  // 7 days

    private(set) var routes: [RouteStop] = []
    private(set) var lastUpdated: Date?

    init(lta: LTAService = .shared) {
        self.lta = lta
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Commute", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("bus_routes.json")
        self.cacheURL = url
        if let payload = Self.readCache(at: url) {
            self.routes = payload.routes
            self.lastUpdated = payload.savedAt
        }
    }

    var hasFreshData: Bool {
        guard let lastUpdated, !routes.isEmpty else { return false }
        return Date().timeIntervalSince(lastUpdated) < cacheTTL
    }

    /// Stream cumulative count of route rows loaded.
    nonisolated func loadAll(forceRefresh: Bool = false) -> AsyncThrowingStream<Int, Error> {
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
            continuation.yield(routes.count)
            return
        }

        let pageSize = 500
        let parallelism = 5
        var collected: [RouteStop] = []
        var nextSkip = 0

        outer: while !Task.isCancelled {
            let starts = (0..<parallelism).map { nextSkip + ($0 * pageSize) }
            let pages = try await withThrowingTaskGroup(of: (Int, [LTABusRoute]).self) { group in
                for s in starts {
                    group.addTask {
                        let rows = try await self.lta.busRoutesPage(skip: s)
                        return (s, rows)
                    }
                }
                var results: [(Int, [LTABusRoute])] = []
                for try await pair in group { results.append(pair) }
                return results.sorted { $0.0 < $1.0 }
            }

            var advanced = false
            for (_, page) in pages {
                if page.isEmpty { continue }
                advanced = true
                collected.append(contentsOf: page.map(Self.toRouteStop(from:)))
            }
            continuation.yield(collected.count)

            let lastPage = pages.last
            if !advanced || lastPage?.1.count ?? 0 < pageSize { break outer }
            nextSkip = (lastPage?.0 ?? nextSkip) + pageSize
        }

        guard !collected.isEmpty else { return }
        self.routes = collected
        self.lastUpdated = Date()
        saveToDisk()
    }

    /// Returns the stops following the given current stop on this service's most likely direction.
    /// `destinationCode` (if provided) is used to disambiguate direction.
    func upcomingStops(
        serviceNo: String,
        currentStopCode: String,
        destinationCode: String?,
        limit: Int = 4
    ) -> [RouteStop] {
        let serviceRows = routes.filter { $0.serviceNo == serviceNo }
        guard !serviceRows.isEmpty else { return [] }

        let candidateDirections = Set(serviceRows.filter { $0.busStopCode == currentStopCode }.map(\.direction))
        guard !candidateDirections.isEmpty else { return [] }

        let chosenDirection: Int = {
            if let destinationCode, candidateDirections.count > 1 {
                for d in candidateDirections {
                    let route = serviceRows.filter { $0.direction == d }.sorted { $0.stopSequence < $1.stopSequence }
                    if route.last?.busStopCode == destinationCode { return d }
                }
            }
            // Pick the direction with the most stops left after currentStop.
            return candidateDirections
                .map { d -> (Int, Int) in
                    let route = serviceRows.filter { $0.direction == d }.sorted { $0.stopSequence < $1.stopSequence }
                    let idx = route.firstIndex(where: { $0.busStopCode == currentStopCode }) ?? route.endIndex
                    return (d, route.count - idx - 1)
                }
                .max(by: { $0.1 < $1.1 })?.0 ?? candidateDirections.first ?? 1
        }()

        let route = serviceRows
            .filter { $0.direction == chosenDirection }
            .sorted { $0.stopSequence < $1.stopSequence }
        guard let currentIdx = route.firstIndex(where: { $0.busStopCode == currentStopCode }) else { return [] }
        let next = route.dropFirst(currentIdx + 1).prefix(limit)
        return Array(next)
    }

    // MARK: - Persistence

    private struct CachedPayload: Codable {
        let savedAt: Date
        let routes: [RouteStop]
    }

    private static func readCache(at url: URL) -> CachedPayload? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CachedPayload.self, from: data)
    }

    private func saveToDisk() {
        let payload = CachedPayload(savedAt: lastUpdated ?? Date(), routes: routes)
        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: cacheURL, options: .atomic)
        }
    }

    private static func toRouteStop(from r: LTABusRoute) -> RouteStop {
        RouteStop(serviceNo: r.serviceNo, direction: r.direction,
                  stopSequence: r.stopSequence, busStopCode: r.busStopCode)
    }
}
