import SwiftUI
import CoreLocation

// MARK: - "See all nearby MRT" container
// Loads the N nearest MRT stations from the user's current location, then
// renders the design-system `MRTStationsView`. Owns its own minimal load
// state so the design view stays a pure layout component.
struct AllMRTStationsScreen: View {
    var count: Int = 12

    @State private var stations: [CMMRTStation] = []
    @State private var nearbyLocation: String = "you"
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading && stations.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.secondarySystemBackground).ignoresSafeArea())
            } else {
                MRTStationsView(stations: stations, nearbyLocation: nearbyLocation)
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
            self.isLoading = false
        }
    }
}

// MARK: - "See all nearby bus stops" container
// Receives the already-loaded list of bus stops from `HomeViewModel` so the
// list reflects exactly what the home screen has cached, with no extra
// network round-trip on push.
struct AllBusStopsScreen: View {
    let entries: [HomeViewModel.BusStopWithArrivals]
    var nearbyLocation: String = "you"

    private var mappedStops: [CMBusStop] {
        entries.map { StopsAdapters.make(from: $0.stop, arrivals: $0.arrivals) }
    }

    var body: some View {
        BusStopsView(stops: mappedStops, nearbyLocation: nearbyLocation)
    }
}
