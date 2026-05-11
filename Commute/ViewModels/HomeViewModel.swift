import SwiftUI
import CoreLocation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    enum LoadingState: Equatable {
        case idle
        case locating
        case fetchingStops(loaded: Int)
        case loadingArrivals
        case ready
        case failed(String)
    }

    var loadingState: LoadingState = .idle
    var nearbyBusStops: [BusStopWithArrivals] = []
    var nearbyMRT: NearbyStation?
    var dataMode: DataMode = .demo
    var locationLabel: String = "Near you"
    var lastSuccessfulRefresh: Date?

    enum DataMode { case live, demo }

    struct BusStopWithArrivals: Identifiable, Hashable {
        let stop: BusStop
        let arrivals: [BusArrival]
        var id: String { stop.id }
    }

    struct NearbyStation: Hashable {
        let station: MRTStation
        let status: LineStatus
    }

    private let lta: LTAService
    private let mock: MockDataService
    private let repo: BusStopsRepository
    private let location: LocationService

    init(
        lta: LTAService = .shared,
        mock: MockDataService = .shared,
        repo: BusStopsRepository = .shared,
        location: LocationService? = nil
    ) {
        self.lta = lta
        self.mock = mock
        self.repo = repo
        self.location = location ?? LocationService.shared
    }

    @MainActor
    func load() async {
        // Skip if data is already loaded — prevents state-transition churn
        // when the view re-appears (e.g. popping back from LiveTracking),
        // which would otherwise rebuild the List and lose scroll position.
        guard loadingState != .ready else { return }
        await runFlow(forceRefreshStops: false)
    }

    @MainActor
    func refresh() async {
        await runFlow(forceRefreshStops: false)
    }

    @MainActor
    func refreshStopsDataset() async {
        await runFlow(forceRefreshStops: true)
    }

    @MainActor
    private func runFlow(forceRefreshStops: Bool) async {
        // 1. Ensure stops dataset is loaded (streaming progress)
        let alreadyFresh = await repo.hasFreshData
        if forceRefreshStops || !alreadyFresh {
            loadingState = .fetchingStops(loaded: 0)
            do {
                for try await loaded in repo.loadAllStops(forceRefresh: forceRefreshStops) {
                    loadingState = .fetchingStops(loaded: loaded)
                }
            } catch {
                loadingState = .failed("Couldn't load bus stops: \(error.localizedDescription)")
                return
            }
        }

        // 2. Resolve location
        loadingState = .locating
        guard location.isAuthorized else {
            location.requestAuthorization()
            loadingState = .failed("Location access is needed to find nearby stops.")
            return
        }
        let userLocation: CLLocation
        do {
            userLocation = try await location.currentLocation()
        } catch {
            loadingState = .failed(error.localizedDescription)
            return
        }
        locationLabel = "Near you"

        // 3. Compute nearest stops (already sorted by distance)
        let nearestStops = await repo.nearest(to: userLocation, count: 10)
        guard !nearestStops.isEmpty else {
            loadingState = .failed("No bus stops found nearby.")
            return
        }

        // 4. Fetch live arrivals for each in parallel, preserving distance order
        loadingState = .loadingArrivals
        let arrivalsByStop: [String: [BusArrival]] = await withTaskGroup(
            of: (String, [BusArrival]).self
        ) { group in
            for stop in nearestStops {
                group.addTask { [lta] in
                    let result = (try? await lta.busArrivals(at: stop.id, force: true)) ?? []
                    return (stop.id, result)
                }
            }
            var dict: [String: [BusArrival]] = [:]
            for await (id, arrivals) in group { dict[id] = arrivals }
            return dict
        }

        let live = nearestStops.map { stop in
            BusStopWithArrivals(stop: stop, arrivals: arrivalsByStop[stop.id] ?? [])
        }
        let anyArrivalsLive = live.contains { !$0.arrivals.isEmpty }
        var anyLive = anyArrivalsLive
        nearbyBusStops = live

        // 5. Nearest MRT (static dataset) + live line status from train alerts
        if let station = MRTStationsRepository.shared.nearest(to: userLocation) {
            let alerts = try? await lta.trainAlerts()
            let status = Self.lineStatus(for: station, alerts: alerts)
            if alerts != nil { anyLive = true }
            nearbyMRT = NearbyStation(station: station, status: status)
        } else {
            nearbyMRT = nil
        }

        dataMode = anyLive ? .live : .demo
        if anyLive { lastSuccessfulRefresh = Date() }
        loadingState = .ready
    }

    private static func lineStatus(for station: MRTStation, alerts: LTATrainAlertValue?) -> LineStatus {
        guard let alerts else {
            return LineStatus(line: station.line, severity: .normal, message: "All lines running normally")
        }
        if alerts.status == 1 {
            return LineStatus(line: station.line, severity: .normal, message: "All lines running normally")
        }
        let lineCode = station.line.ltaTrainLine
        let affecting = alerts.affectedSegments.first { $0.line.uppercased() == lineCode }
        guard let affecting else {
            return LineStatus(line: station.line, severity: .normal, message: "\(station.line.fullName) · Normal service")
        }
        let stationsAffected = affecting.stations
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let hits = stationsAffected.contains(station.id)
        let summary = alerts.message.first?.content ?? "Service disruption on \(station.line.fullName)."
        return LineStatus(
            line: station.line,
            severity: hits ? .danger : .warning,
            message: summary
        )
    }
}
