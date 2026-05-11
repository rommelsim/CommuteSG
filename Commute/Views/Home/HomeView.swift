import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Binding var selectedTab: MainTab
    @State private var viewModel = HomeViewModel()
    @State private var navigation = HomeNavigation()
    @State private var editingPlace: SavedPlace.Kind?
    @State private var showingSearch = false
    @State private var previewingShortcut: ShortcutPreviewState?
    @State private var stopSheet: StopSheetData?
    @State private var mrtSheet: MRTStation?
    @State private var heroWeather: HeroContext.Weather = HeroContext.Weather(symbol: "sun.max.fill", text: "—")
    @State private var heroJourney: HeroContext.Journey?

    private struct ShortcutPreviewState: Identifiable {
        let kind: SavedPlace.Kind
        let address: String
        var id: String { kind.rawValue }
    }

    private var timeContext: TimeContext { TimeContext.current() }

    var body: some View {
        @Bindable var nav = navigation

        NavigationStack(path: $nav.path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    titleRow
                    searchBar
                    HomeHero(context: heroContext)
                    savedDestinations
                    nearbyTransitHeader
                    nearbyTransitGroup
                    mrtSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .background(Color.cfPageBackground.ignoresSafeArea())
            .refreshable {
                await viewModel.refresh()
                await refreshWeatherAndJourney()
            }
            .task {
                await viewModel.load()
                await refreshWeatherAndJourney()
            }
            .onChange(of: viewModel.nearbyBusStops.count) { _, _ in
                Task { await refreshHeroJourney() }
            }
            .navigationDestination(for: HomeRoute.self) { route in
                destination(for: route)
            }
            .sheet(item: $editingPlace) { kind in
                // Editor is purely "set the address". After save, stay on
                // Home — the user can tap the shortcut later to plan a trip.
                PlaceEditorSheet(kind: kind)
                    .environment(appState)
            }
            .sheet(isPresented: $showingSearch) {
                SearchView()
                    .environment(appState)
            }
            .sheet(item: $previewingShortcut) { state in
                ShortcutPreviewSheet(
                    kind: state.kind,
                    address: state.address,
                    onPlanJourney: {
                        appState.pendingPlanDestination = state.address
                        selectedTab = .plan
                    },
                    onEditAddress: {
                        editingPlace = state.kind
                    }
                )
                .environment(appState)
                .presentationDetents([.large, .medium])
            }
            .fullScreenCover(item: $stopSheet) { data in
                NavigationStack {
                    BusStopDetailView(stop: data.stop, initialArrivals: data.arrivals)
                        .navigationDestination(for: HomeRoute.self) { route in
                            destination(for: route)
                        }
                }
                .environment(appState)
            }
            .fullScreenCover(item: $mrtSheet) { station in
                NavigationStack {
                    MRTStationDetailView(station: station)
                        .navigationDestination(for: HomeRoute.self) { route in
                            destination(for: route)
                        }
                }
                .environment(appState)
            }
        }
    }

    // MARK: - Sections

    private var titleRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(heroContext.greeting)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.50))
                Text("Where to?")
                    .font(.system(size: 22, weight: .bold))
                    .tracking(-0.3)
                    .foregroundStyle(Color.cfTextPrimary)
            }
            Spacer()
            Button {
                navigation.go(.profile)
            } label: {
                Text(avatarInitial)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: 0x1F2937))
                    .frame(width: 32, height: 32)
                    .background(Color.black.opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Profile")
        }
    }

    private var searchBar: some View {
        Button { showingSearch = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.40))
                Text("Search station, bus, address")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.40))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassSurface(cornerRadius: 16, fill: Color.white.opacity(0.80))
        }
        .buttonStyle(.plain)
    }

    private var savedDestinations: some View {
        HStack(spacing: 8) {
            compactShortcut(.home)
            compactShortcut(.work)
        }
    }

    private func compactShortcut(_ kind: SavedPlace.Kind) -> some View {
        let address = (appState.savedPlaces.first(where: { $0.kind == kind })?.address ?? "")
            .trimmingCharacters(in: .whitespaces)
        let symbol = kind == .home ? "house.fill" : "briefcase.fill"
        let title  = kind == .home ? "Home" : "Work"
        return Button {
            handleShortcut(kind, address: address)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.70))
                    .frame(width: 28, height: 28)
                    .background(Color.black.opacity(0.05), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.cfTextPrimary)
                    Text(address.isEmpty ? "Tap to set address" : address)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.55))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(cornerRadius: 12, fill: Color.white.opacity(0.70))
        }
        .buttonStyle(.plain)
    }

    private func handleShortcut(_ kind: SavedPlace.Kind, address: String) {
        if address.isEmpty {
            editingPlace = kind
        } else {
            previewingShortcut = ShortcutPreviewState(kind: kind, address: address)
        }
    }

    private var nearbyTransitHeader: some View {
        HStack {
            Text("Nearby transit")
                .font(.system(size: 14, weight: .bold))
                .tracking(-0.2)
                .foregroundStyle(Color.cfTextPrimary)
            Spacer()
            HStack(spacing: 4) {
                LiveDot(color: Color.cfLiveDot, size: 6)
                Text("Live · \(minutesAgoText)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.cfTextPrimary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .glassSurface(cornerRadius: 999, fill: Color.white.opacity(0.70))
        }
    }

    @ViewBuilder
    private var nearbyTransitGroup: some View {
        switch viewModel.loadingState {
        case .fetchingStops, .locating, .loadingArrivals:
            VStack(spacing: 10) {
                NearbyBusStopSkeleton()
                NearbyBusStopSkeleton()
            }
            .padding(2)
            .glassSurface(cornerRadius: 18)
        case .failed(let message):
            ErrorCard(message: message) { Task { await viewModel.refresh() } }
                .glassSurface(cornerRadius: 18)
        case .idle, .ready:
            if viewModel.nearbyBusStops.isEmpty {
                EmptyStateView(
                    symbol: "bus.fill",
                    title: "No bus stops nearby",
                    subtitle: "Pull to refresh or move to an area with more coverage.",
                    style: .neutral
                )
                .padding(14)
                .glassSurface(cornerRadius: 18)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.nearbyBusStops.enumerated()), id: \.element.id) { idx, entry in
                        if idx > 0 {
                            Divider().background(Color.black.opacity(0.04))
                                .padding(.horizontal, 16)
                        }
                        NearbyBusStopCard(
                            stop: entry.stop,
                            arrivals: entry.arrivals,
                            onTapStop: {
                                stopSheet = StopSheetData(stop: entry.stop, arrivals: entry.arrivals)
                            },
                            onTapBus: { arrival in
                                navigation.go(.tracking(arrival, busStopCode: entry.stop.id))
                            }
                        )
                    }
                }
                .glassSurface(cornerRadius: 18)
            }
        }
    }

    @ViewBuilder
    private var mrtSection: some View {
        if let mrt = viewModel.nearbyMRT {
            NearbyMRTCard(nearby: mrt) { mrtSheet = mrt.station }
        }
    }

    // MARK: - Hero context

    private var heroContext: HeroContext {
        let name = appState.userName.trimmingCharacters(in: .whitespaces)
        return HeroContext.make(
            time: timeContext,
            userName: name.isEmpty ? nil : name,
            homePlace: appState.savedPlaces.first { $0.kind == .home }?.address,
            workPlace: appState.savedPlaces.first { $0.kind == .work }?.address,
            journey: heroJourney,
            weather: heroWeather
        )
    }

    /// Refresh weather + journey suggestion together. Both are best-effort
    /// and silent on failure; the hero falls back to its placeholder state.
    private func refreshWeatherAndJourney() async {
        await refreshHeroWeather()
        await refreshHeroJourney()
    }

    private func refreshHeroWeather() async {
        guard let location = LocationService.shared.lastLocation else { return }
        if let w = await WeatherProvider.shared.current(at: location) {
            heroWeather = w
        }
    }

    /// Real journey suggestion: ask `JourneySuggester` for the soonest bus
    /// at the user's nearest stop that goes to the relevant saved place
    /// (Work in the morning, Home in the evening/night). Returns nil if no
    /// match — hero will simply hide the journey row.
    private func refreshHeroJourney() async {
        let kind: SavedPlace.Kind? = {
            switch timeContext {
            case .morning: .work
            case .evening, .night: .home
            default: nil
            }
        }()
        guard let kind,
              let address = appState.savedPlaces.first(where: { $0.kind == kind })?.address,
              !address.trimmingCharacters(in: .whitespaces).isEmpty,
              let firstStop = viewModel.nearbyBusStops.first
        else {
            heroJourney = nil
            return
        }
        let suggested = await JourneySuggester.shared.suggest(
            destinationAddress: address,
            from: firstStop.arrivals,
            userStopCode: firstStop.stop.id
        )
        guard let arrival = suggested,
              let eta = arrival.nextArrivalMinutes
        else {
            heroJourney = nil
            return
        }
        let destinationName = StopsAdapters.destinationLabel(for: arrival).ifEmpty(address)
        let slack: String = {
            if timeContext == .night { return "Last service tonight" }
            return "\(max(eta - 2, 1)) min to spare"
        }()
        let totalTrip = max(eta + 12, 18)  // estimate: walk + ride. Real routing later.
        heroJourney = HeroContext.Journey(
            bus: arrival.serviceNo,
            etaMinutes: eta,
            slack: slack,
            destination: destinationName,
            destinationLabel: kind == .work ? "Work" : "Home",
            fromStop: firstStop.stop.name,
            totalTripMinutes: totalTrip,
            arriveByLabel: arriveByLabel(in: totalTrip),
            alternative: nil
        )
    }

    private func arriveByLabel(in minutesFromNow: Int) -> String {
        let date = Date().addingTimeInterval(TimeInterval(minutesFromNow * 60))
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        let time = f.string(from: date)
        let hour = Calendar.current.component(.hour, from: date)
        return "\(time) \(hour < 12 ? "am" : "pm")"
    }

    private var minutesAgoText: String {
        guard let last = viewModel.lastSuccessfulRefresh else { return "now" }
        let m = max(0, Int(Date().timeIntervalSince(last) / 60))
        return "\(m)m"
    }

    private var avatarInitial: String {
        let trimmed = appState.userName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "•" : String(trimmed.prefix(1)).uppercased()
    }

    @ViewBuilder
    private func destination(for route: HomeRoute) -> some View {
        switch route {
        case .profile:
            ProfileView()
        case .busStop(let stop, let arrivals):
            BusStopDetailView(stop: stop, initialArrivals: arrivals)
        case .mrt(let station):
            MRTStationDetailView(station: station)
        case .tracking(let busArrival, let busStopCode):
            LiveTrackingView(arrival: busArrival, busStopCode: busStopCode)
        case .journey(let opt, let mode, let from, let to):
            JourneyDetailView(option: opt, mode: mode, fromText: from, toText: to)
        case .allMRTStations:
            AllMRTStationsScreen()
        case .allBusStops:
            AllBusStopsScreen(
                entries: viewModel.nearbyBusStops,
                lastRefresh: viewModel.lastSuccessfulRefresh
            )
        }
    }
}

/// Identifiable wrapper used for the bus-stop sheet presentation. Carries
/// the initial arrivals along with the stop so the sheet can populate
/// immediately while it kicks off its own LTA refresh.
struct StopSheetData: Identifiable {
    let stop: BusStop
    let arrivals: [BusArrival]
    var id: String { stop.id }
}

// MARK: - Routing

enum HomeRoute: Hashable {
    case profile
    case busStop(BusStop, [BusArrival])
    case mrt(MRTStation)
    case tracking(BusArrival, busStopCode: String?)
    case journey(JourneyOption, mode: PlanViewModel.DepartureMode, fromText: String, toText: String)
    case allMRTStations
    case allBusStops
}

@Observable
final class HomeNavigation {
    var path = NavigationPath()
    func go(_ route: HomeRoute) { path.append(route) }
    func popToRoot() { path = NavigationPath() }
}

private extension String {
    func ifEmpty(_ replacement: String) -> String { isEmpty ? replacement : self }
}
