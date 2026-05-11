import SwiftUI
import Observation

@MainActor
@Observable
final class LiveTrackingViewModel {
    struct UpcomingStop: Identifiable, Hashable {
        let id: String         // bus stop code
        let name: String
        let etaMinutes: Int?   // nil if unknown/skipped
        let etaScheduled: Bool
    }

    enum RoutesState: Equatable {
        case idle
        case loading(rowsLoaded: Int)
        case ready
        case unavailable(String)
    }

    var routesState: RoutesState = .idle
    var upcomingStops: [UpcomingStop] = []
    var isFetchingETAs = false

    private let serviceNo: String
    private let busStopCode: String?
    private let destinationCode: String?

    private let lta: LTAService
    private let routes: BusRoutesRepository
    private let stops: BusStopsRepository

    init(
        serviceNo: String,
        busStopCode: String?,
        destinationCode: String?,
        lta: LTAService = .shared,
        routes: BusRoutesRepository = .shared,
        stops: BusStopsRepository = .shared
    ) {
        self.serviceNo = serviceNo
        self.busStopCode = busStopCode
        self.destinationCode = destinationCode
        self.lta = lta
        self.routes = routes
        self.stops = stops
    }

    func loadInitial() async {
        let alreadyFresh = await routes.hasFreshData
        if !alreadyFresh {
            routesState = .loading(rowsLoaded: 0)
            do {
                for try await loaded in routes.loadAll() {
                    routesState = .loading(rowsLoaded: loaded)
                }
            } catch {
                routesState = .unavailable(error.localizedDescription)
                return
            }
        }
        routesState = .ready
        await refreshETAs()
    }

    /// We pull every remaining stop to the terminus from the route catalogue
    /// (capped at 60 because no Singapore service goes beyond that), but we
    /// only burn one LTA-API call per refresh on the first `etaWindow` stops
    /// — the rest are listed name-only so the user can see the full journey
    /// without us hammering the rate limit.
    private let upcomingLimit = 60
    private let etaWindow = 5

    func refreshETAs() async {
        guard case .ready = routesState, let busStopCode else { return }
        isFetchingETAs = true
        defer { isFetchingETAs = false }

        let upcoming = await routes.upcomingStops(
            serviceNo: serviceNo,
            currentStopCode: busStopCode,
            destinationCode: destinationCode,
            limit: upcomingLimit
        )
        guard !upcoming.isEmpty else {
            upcomingStops = []
            return
        }

        var resolved: [UpcomingStop] = []
        for (idx, routeStop) in upcoming.enumerated() {
            let name = await stopName(for: routeStop.busStopCode) ?? routeStop.busStopCode
            let (eta, scheduled): (Int?, Bool) = if idx < etaWindow {
                await fetchETA(for: routeStop.busStopCode)
            } else {
                (nil, false)
            }
            resolved.append(.init(
                id: routeStop.busStopCode,
                name: name,
                etaMinutes: eta,
                etaScheduled: scheduled
            ))
        }
        upcomingStops = resolved
    }

    private func stopName(for code: String) async -> String? {
        let allStops = await stops.stops
        return allStops.first(where: { $0.id == code })?.name
    }

    private func fetchETA(for stopCode: String) async -> (Int?, Bool) {
        do {
            let arrivals = try await lta.busArrivals(at: stopCode, serviceNo: serviceNo)
            guard let match = arrivals.first(where: { $0.serviceNo == serviceNo }) else { return (nil, false) }
            return (match.nextArrivalMinutes, match.nextArrivalIsScheduled)
        } catch {
            return (nil, false)
        }
    }
}
