import SwiftUI
import MapKit
import CoreLocation

struct BusStopDetailView: View {
    let stop: BusStop
    let initialArrivals: [BusArrival]

    @Environment(AppState.self) private var appState
    @State private var arrivals: [BusArrival]
    @State private var dataMode: HomeViewModel.DataMode = .demo
    @State private var lastRefresh: Date? = nil
    @State private var filter: BusFilter = .all
    @State private var mapPosition: MapCameraPosition = .automatic

    enum BusFilter: String, CaseIterable, Hashable {
        case all, saved
        var label: String { self == .all ? "All buses" : "Saved" }
    }

    private let lta: LTAService = .shared

    init(stop: BusStop, initialArrivals: [BusArrival]) {
        self.stop = stop
        self.initialArrivals = initialArrivals
        self._arrivals = State(initialValue: initialArrivals)
        if let coord = stop.coordinate {
            self._mapPosition = State(initialValue: .region(
                Self.fitRegion(stop: coord, buses: initialArrivals.compactMap { $0.nextArrivalCoordinate })
            ))
        }
    }

    /// Build a map region tight enough to show the stop and every supplied
    /// bus coordinate, with a comfortable padding factor so markers aren't
    /// flush with the edge of the map.
    private static func fitRegion(
        stop: CLLocationCoordinate2D,
        buses: [CLLocationCoordinate2D]
    ) -> MKCoordinateRegion {
        let allLats = [stop.latitude] + buses.map(\.latitude)
        let allLngs = [stop.longitude] + buses.map(\.longitude)
        let minLat = allLats.min() ?? stop.latitude
        let maxLat = allLats.max() ?? stop.latitude
        let minLng = allLngs.min() ?? stop.longitude
        let maxLng = allLngs.max() ?? stop.longitude
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.6, 0.005),
            longitudeDelta: max((maxLng - minLng) * 1.6, 0.005)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    var body: some View {
        VStack(spacing: 0) {
            DetailHeader(
                center: {
                    DetailHeaderTitle(title: stop.name, meta: "Stop \(stop.id) · \(stop.road)")
                },
                trailing: {
                    IconCircleButton(
                        symbol: isFavorite ? "star.fill" : "star",
                        foreground: isFavorite ? Color.appAmber : Color.appText
                    ) {
                        appState.toggleFavoriteBusStop(stop.id)
                    }
                }
            )
            // GeometryReader wraps the ScrollView so we can force its
            // content to fill the visible card height when content is
            // short — eliminates the dead space at the bottom of the card
            // when "No buses arriving" is the only thing in the list.
            GeometryReader { geo in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        miniMap
                        HStack {
                            FilterPills(
                                options: BusFilter.allCases,
                                label: { $0.label },
                                selection: $filter
                            )
                            Spacer(minLength: 0)
                            LiveStatusPill(minutesAgo: minutesSinceRefresh)
                                .onTapGesture {
                                    Task { await refresh(force: true) }
                                }
                                .padding(.trailing, Spacing.screen)
                        }
                        busList
                    }
                    .padding(.top, Spacing.s24)
                    .padding(.bottom, 24)
                    .frame(minHeight: geo.size.height, alignment: .top)
                }
                .scrollIndicators(.hidden)
                .scrollContentBackground(.hidden)
                .refreshable { await refresh(force: true) }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await refresh(force: false) }
    }

    private var isFavorite: Bool {
        appState.favoriteBusStopCodes.contains(stop.id)
    }

    // MARK: - Refresh

    private func refresh(force: Bool) async {
        do {
            let live = try await lta.busArrivals(at: stop.id, force: force)
            if !live.isEmpty {
                arrivals = live
                dataMode = .live
                lastRefresh = Date()
            } else {
                arrivals = initialArrivals
                dataMode = .demo
            }
        } catch {
            arrivals = initialArrivals
            dataMode = .demo
        }
    }

    private var filteredArrivals: [BusArrival] {
        switch filter {
        case .all: arrivals
        case .saved: arrivals.filter { appState.favoriteLineCodes.contains($0.serviceNo) }
        }
    }

    private var minutesSinceRefresh: Int {
        guard let lastRefresh else { return 0 }
        return max(0, Int(Date().timeIntervalSince(lastRefresh) / 60))
    }

    // MARK: - Map (interactive, with bus markers + recenter)

    private var miniMap: some View {
        ZStack(alignment: .topTrailing) {
            if let coord = stop.coordinate {
                Map(position: $mapPosition) {
                    Annotation(stop.name, coordinate: coord, anchor: .bottom) {
                        ZStack {
                            Circle()
                                .fill(Color.appInfo)
                                .frame(width: 28, height: 28)
                            Image(systemName: "bus.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                    }
                    ForEach(busesOnMap, id: \.id) { entry in
                        Annotation("Bus \(entry.serviceNo)", coordinate: entry.coordinate, anchor: .center) {
                            busMarker(serviceNo: entry.serviceNo)
                        }
                    }
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                // Re-fit the camera whenever the stop coord lands or buses
                // shift so far-away buses stay on screen.
                .onChange(of: arrivalsCoordinatesKey, initial: true) { _, _ in refitMap(target: coord) }

                recenterButton(target: coord)
            } else {
                Color.clear
            }
        }
        .frame(height: 180)
        // Edge-to-edge inside the sheet, framed only by an 18pt rounded
        // corner + 0.5px hairline glass stroke per redesign spec §2.
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.7), lineWidth: 0.5)
        )
        .padding(.horizontal, Spacing.s8)
    }

    /// Stable key for `.onChange` — concatenates each arrival's bus
    /// coordinate so the modifier fires whenever any bus moves.
    private var arrivalsCoordinatesKey: String {
        arrivals
            .map { a -> String in
                let lat = a.nextArrivalLatitude ?? 0
                let lng = a.nextArrivalLongitude ?? 0
                return "\(a.serviceNo):\(lat),\(lng)"
            }
            .joined(separator: "|")
    }

    private func refitMap(target: CLLocationCoordinate2D) {
        let busCoords = busesOnMap.map(\.coordinate)
        let region = Self.fitRegion(stop: target, buses: busCoords)
        withAnimation(.smooth(duration: 0.4)) {
            mapPosition = .region(region)
        }
    }

    private func recenterButton(target: CLLocationCoordinate2D) -> some View {
        IconCircleButton(symbol: "scope", foreground: Color.appInfo) {
            refitMap(target: target)
        }
        .accessibilityLabel("Recenter map on \(stop.name) and all buses")
        .padding(10)
    }

    /// Buses with a real-time coordinate from LTA — drawn as markers on the map.
    /// `id` is keyed on `serviceNo` (which is unique per stop) so the markers
    /// reuse identity across polls instead of blinking on each refresh.
    private var busesOnMap: [BusOnMap] {
        arrivals.compactMap { arrival in
            guard let coord = arrival.nextArrivalCoordinate else { return nil }
            return BusOnMap(id: arrival.serviceNo, serviceNo: arrival.serviceNo, coordinate: coord)
        }
    }

    private func busMarker(serviceNo: String) -> some View {
        Text(serviceNo)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.appWarningStrong)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white, lineWidth: 1))
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
    }

    // MARK: - List

    private var busList: some View {
        VStack(spacing: Spacing.cardGap) {
            ForEach(filteredArrivals) { arrival in
                NavigationLink(value: HomeRoute.tracking(arrival, busStopCode: stop.id)) {
                    BusServiceRow(
                        arrival: arrival,
                        isFavorite: appState.favoriteLineCodes.contains(arrival.serviceNo),
                        onToggleFavorite: {
                            appState.toggleFavoriteLine(arrival.serviceNo)
                        }
                    )
                }
                .buttonStyle(CardButtonStyle())
            }
            if filteredArrivals.isEmpty {
                // Wrap the empty state in spacers + a generous min-height so
                // it visually centers in the card's remaining area instead
                // of clinging to the top with a gulf of dead space below.
                VStack(spacing: 0) {
                    Spacer(minLength: 24)
                    EmptyStateView(
                        symbol: filter == .saved ? "star" : "bus.fill",
                        title: filter == .saved ? "No saved buses yet" : "No buses arriving",
                        subtitle: filter == .saved
                            ? "Tap the star next to any bus to save it for quick access."
                            : "Pull to refresh, or check back in a moment.",
                        style: .neutral
                    )
                    Spacer(minLength: 24)
                }
                .frame(minHeight: 360)
            }
        }
        .padding(.horizontal, Spacing.screen)
    }
}

// MARK: - Bus marker source

private struct BusOnMap: Identifiable {
    let id: String
    let serviceNo: String
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Service row
// CM design: each service is a CMCard wrapping a BusArrivalRow with a
// trailing favorite star. Crowd / bus-type chips are intentionally omitted —
// they're surfaced on the live tracking screen reached by tapping the row.

private struct BusServiceRow: View {
    let arrival: BusArrival
    let isFavorite: Bool
    let onToggleFavorite: () -> Void

    var body: some View {
        CMCard {
            HStack(alignment: .center, spacing: 10) {
                BusArrivalRow(
                    busNumber: arrival.serviceNo,
                    destination: arrival.destinationCode ?? arrival.destination,
                    nextMinutes: arrival.nextArrivalMinutes,
                    followingMinutes: arrival.followingArrivalMinutes
                )
                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isFavorite ? Color.appAmber : Color.appText3)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: isFavorite)
            }
        }
    }
}
