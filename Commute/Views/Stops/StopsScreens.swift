import SwiftUI
import CoreLocation

// MARK: - "See all nearby MRT" container
struct AllMRTStationsScreen: View {
    var count: Int = 12
    var minutesAgo: Int = 0

    @State private var stations: [CMMRTStation] = []
    @State private var nearbyLocation: String = "you"
    @State private var isLoading = true
    @State private var loadedAt: Date?

    private var minutesSinceLoad: Int {
        guard let loadedAt else { return minutesAgo }
        return max(0, Int(Date().timeIntervalSince(loadedAt) / 60))
    }

    var body: some View {
        Group {
            if isLoading && stations.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.secondarySystemBackground).ignoresSafeArea())
            } else {
                MRTStationsView(
                    stations: stations,
                    nearbyLocation: nearbyLocation,
                    minutesAgo: minutesSinceLoad
                )
            }
        }
        .task { await load() }
    }

    private func load() async {
        let location = LocationService.shared
        guard location.isAuthorized,
              let user = try? await location.currentLocation() else {
            isLoading = false
            return
        }
        let nearest = MRTStationsRepository.shared.nearest(to: user, count: count)
        await MainActor.run {
            self.stations = nearest.map(StopsAdapters.make(from:))
            self.loadedAt = Date()
            self.isLoading = false
        }
    }
}

// MARK: - "See all nearby bus stops" container
struct AllBusStopsScreen: View {
    let entries: [HomeViewModel.BusStopWithArrivals]
    var nearbyLocation: String = "you"
    let lastRefresh: Date?

    private var mappedStops: [CMBusStop] {
        entries.map { StopsAdapters.make(from: $0.stop, arrivals: $0.arrivals) }
    }

    private var minutesAgo: Int {
        guard let lastRefresh else { return 0 }
        return max(0, Int(Date().timeIntervalSince(lastRefresh) / 60))
    }

    var body: some View {
        BusStopsView(
            stops: mappedStops,
            nearbyLocation: nearbyLocation,
            minutesAgo: minutesAgo
        )
    }
}
