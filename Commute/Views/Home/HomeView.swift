import SwiftUI
import WidgetKit
import CoreLocation

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
                    pinnedStopsSection
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
                Task {
                    await refreshHeroJourney()
                    // Re-publish pinned snapshot here too — by the time
                    // nearbyBusStops populates, BusStopNameCache is warm,
                    // which means the lookup in publishPinnedSnapshot can
                    // actually resolve favorited codes to BusStop objects.
                    publishPinnedSnapshot()
                }
            }
            // Re-publish whenever the favorites set changes (e.g. user
            // taps a star on a detail screen) so the widget reflects the
            // change without waiting for the next Home appearance.
            .onChange(of: appState.favoriteBusStopCodes) { _, _ in
                publishPinnedSnapshot()
            }
            .onChange(of: appState.favoriteLineCodes) { _, _ in
                publishPinnedSnapshot()
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
                    .foregroundStyle(Color.cfTextTertiary)
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
                    .foregroundStyle(Color.cfTextPrimary)
                    .frame(width: 32, height: 32)
                    .background(Color.cfHairlineStrong, in: Circle())
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
                    .foregroundStyle(Color.cfTextTertiary)
                Text("Search station, bus, address")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.cfTextTertiary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassSurface(cornerRadius: 16, fill: Color.cfGlassFillStrong)
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
                    .foregroundStyle(Color.cfTextSecondary)
                    .frame(width: 28, height: 28)
                    .background(Color.cfChipFill, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.cfTextPrimary)
                    Text(address.isEmpty ? "Tap to set address" : address)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.cfTextSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(cornerRadius: 12, fill: Color.cfGlassFillSoft)
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
            .glassSurface(cornerRadius: 999, fill: Color.cfGlassFillSoft)
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
                            Divider().background(Color.cfHairline)
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

    // MARK: - Pinned section (favorited buses + stops)

    /// Bus stops the user has starred. Resolved synchronously from the
    /// MainActor `BusStopNameCache` (populated by `BusStopsRepository`).
    /// Unknown codes (cache not warm yet) are dropped silently.
    private var pinnedStops: [BusStop] {
        appState.favoriteBusStopCodes
            .compactMap { BusStopNameCache.shared.stop(forCode: $0) }
            .sorted { $0.name < $1.name }
    }

    /// Bus service numbers the user has starred (e.g. "156", "282").
    private var pinnedBusNumbers: [String] {
        appState.favoriteLineCodes.sorted { lhs, rhs in
            // Numeric-aware sort so "10" comes before "100".
            (Int(lhs) ?? .max, lhs) < (Int(rhs) ?? .max, rhs)
        }
    }

    @ViewBuilder
    private var pinnedStopsSection: some View {
        if !pinnedStops.isEmpty || !pinnedBusNumbers.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.appAmber)
                    Text("Pinned")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.cfTextPrimary)
                }

                if !pinnedBusNumbers.isEmpty {
                    pinnedSubsection(label: "Buses") {
                        ForEach(pinnedBusNumbers, id: \.self) { number in
                            pinnedBusChip(number)
                        }
                    }
                }

                if !pinnedStops.isEmpty {
                    pinnedSubsection(label: "Stops") {
                        ForEach(pinnedStops) { stop in
                            pinnedStopChip(stop)
                        }
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    /// One labelled sub-section inside the Pinned area. Uppercase caption
    /// label (matches the CM section-header style) above a horizontal scroll
    /// of chips.
    @ViewBuilder
    private func pinnedSubsection<Content: View>(
        label: String,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Color.cfTextTertiary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    content()
                }
            }
            .scrollClipDisabled()
        }
    }

    /// Visual height shared by every pinned chip so buses and stops read as
    /// peers in the horizontal rail.
    private let pinnedChipHeight: CGFloat = 44

    private func pinnedStopChip(_ stop: BusStop) -> some View {
        Button {
            stopSheet = StopSheetData(stop: stop, arrivals: [])
        } label: {
            HStack(spacing: 8) {
                BusStopIcon(size: 14, color: Color.cfTextSecondary, strokeWidth: 2.2)
                Text(stop.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.cfTextPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(height: pinnedChipHeight)
            .glassSurface(cornerRadius: 12, fill: Color.cfGlassFillSoft)
        }
        .buttonStyle(CardButtonStyle(pressedScale: 0.95))
        .accessibilityLabel("Pinned stop \(stop.name)")
    }

    private func pinnedBusChip(_ serviceNo: String) -> some View {
        Button { handlePinnedBus(serviceNo) } label: {
            HStack(spacing: 8) {
                ServiceChip(service: serviceNo, size: .sm)
                Text("Bus")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(Color.cfTextTertiary)
            }
            .padding(.horizontal, 12)
            .frame(height: pinnedChipHeight)
            .glassSurface(cornerRadius: 12, fill: Color.cfGlassFillSoft)
        }
        .buttonStyle(CardButtonStyle(pressedScale: 0.92))
        .accessibilityLabel("Pinned bus \(serviceNo)")
    }

    /// Tapping a pinned bus opens its live tracking from the nearest stop
    /// where it's currently arriving. If no nearby stop has live data for
    /// this service, surface a quiet toast instead — silently doing nothing
    /// would feel broken.
    private func handlePinnedBus(_ serviceNo: String) {
        for entry in viewModel.nearbyBusStops {
            if let arrival = entry.arrivals.first(where: { $0.serviceNo == serviceNo }) {
                navigation.go(.tracking(arrival, busStopCode: entry.stop.id))
                return
            }
        }
        Task { @MainActor in
            ToastCenter.shared.show(.info("Bus \(serviceNo) not arriving nearby"))
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
        publishHeroSnapshot()
        publishPinnedSnapshot()
    }

    /// Mirror the hero state into the App Group so the home-screen widget
    /// can render the same card without re-running journey logic.
    private func publishHeroSnapshot() {
        let ctx = heroContext
        let snap = NextOutTheDoorSnapshot(
            timeContext: NextOutTheDoorSnapshot.TimeContext(rawValue: ctx.time.rawValue) ?? .midday,
            labelTop: ctx.labelTop,
            headline: ctx.headline,
            bus: ctx.journey?.bus,
            etaMinutes: ctx.journey?.etaMinutes,
            slack: ctx.journey?.slack,
            destination: ctx.journey?.destination,
            destinationLabel: ctx.journey?.destinationLabel,
            fromStop: ctx.journey?.fromStop,
            totalTripMinutes: ctx.journey?.totalTripMinutes,
            arriveByLabel: ctx.journey?.arriveByLabel,
            updatedAt: Date()
        )
        SharedSnapshot.writeNextOutTheDoor(snap)
        WidgetCenter.shared.reloadTimelines(ofKind: "NextOutTheDoorWidget")
    }

    /// Mirror the user's pinned (starred) stops and bus numbers into the
    /// App Group so the Pinned widget can render them. Re-publishes on
    /// every Home appearance so the widget catches changes made on detail
    /// screens (where stars get toggled).
    private func publishPinnedSnapshot() {
        let stops = appState.favoriteBusStopCodes
            .compactMap { code -> PinnedItemsSnapshot.Stop? in
                guard let stop = BusStopNameCache.shared.stop(forCode: code) else { return nil }
                return PinnedItemsSnapshot.Stop(code: stop.id, name: stop.name)
            }
            .sorted { $0.name < $1.name }
        let buses = appState.favoriteLineCodes.sorted { lhs, rhs in
            (Int(lhs) ?? .max, lhs) < (Int(rhs) ?? .max, rhs)
        }
        let snap = PinnedItemsSnapshot(stops: stops, busNumbers: buses, updatedAt: Date())
        SharedSnapshot.writePinned(snap)
        WidgetCenter.shared.reloadTimelines(ofKind: "PinnedItemsWidget")
    }

    private func refreshHeroWeather() async {
        // The first hero refresh can race ahead of `viewModel.load()` —
        // when that happens `lastLocation` is still nil and we used to
        // bail out, leaving the weather chip stuck at the "—" placeholder.
        // Pull a fresh fix on demand so the chip resolves even on cold
        // entry to Home.
        let location: CLLocation?
        if let cached = LocationService.shared.lastLocation {
            location = cached
        } else if LocationService.shared.isAuthorized {
            location = try? await LocationService.shared.currentLocation()
        } else {
            location = nil
        }
        guard let location else { return }
        if let w = await WeatherProvider.shared.current(at: location) {
            heroWeather = w
        }
    }

    /// Pick a journey to surface in the hero. Two-tier strategy:
    ///   1. Ask `JourneySuggester` for a bus at the user's nearest stop that
    ///      actually routes to the relevant saved place (Work in the
    ///      morning, Home in the evening/night). If we get a real match,
    ///      use it.
    ///   2. Otherwise fall back to the next nearby bus and frame it as the
    ///      start of the journey toward the saved place. This avoids a
    ///      blank hero when the saved address isn't directly served by any
    ///      visible bus (common for office buildings, residential blocks
    ///      that need a transfer, etc.) — better to show the user "what's
    ///      leaving next" than nothing.
    /// Returns nil only when there's no saved place for the current time
    /// of day or no nearby bus data at all.
    private func refreshHeroJourney() async {
        // Time of day picks a preferred destination; if it isn't filled in
        // we fall back to the other saved place so the hero still surfaces
        // a real ETA for users who only completed one address.
        let preferredKind: SavedPlace.Kind = {
            switch timeContext {
            case .morning, .midday: .work
            case .evening, .night, .weekend: .home
            }
        }()
        let fallbackKind: SavedPlace.Kind = preferredKind == .work ? .home : .work

        func filledAddress(_ kind: SavedPlace.Kind) -> String? {
            let raw = appState.savedPlaces.first(where: { $0.kind == kind })?.address ?? ""
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        }

        let resolved: (String, SavedPlace.Kind)? =
            filledAddress(preferredKind).map { ($0, preferredKind) }
            ?? filledAddress(fallbackKind).map { ($0, fallbackKind) }

        guard let (address, kind) = resolved,
              let firstStop = viewModel.nearbyBusStops.first
        else {
            heroJourney = nil
            return
        }
        let label = kind == .work ? "Work" : "Home"

        // Tier 1: try for a routed match.
        if let arrival = await JourneySuggester.shared.suggest(
                destinationAddress: address,
                from: firstStop.arrivals,
                userStopCode: firstStop.stop.id),
           let eta = arrival.nextArrivalMinutes {
            heroJourney = makeJourney(
                arrival: arrival,
                eta: eta,
                fromStop: firstStop.stop.name,
                destinationLabel: label,
                destinationFallback: address,
                exactMatch: true
            )
            return
        }

        // Tier 2: best-effort fallback — show the first nearby bus framed
        // toward the saved destination. We don't claim it routes there
        // exactly; the slack copy reads "next bus from <stop>" so the user
        // knows it's a heading suggestion, not a guaranteed route.
        if let firstArrival = firstStop.arrivals.first,
           let eta = firstArrival.nextArrivalMinutes {
            heroJourney = makeJourney(
                arrival: firstArrival,
                eta: eta,
                fromStop: firstStop.stop.name,
                destinationLabel: label,
                destinationFallback: address,
                exactMatch: false
            )
            return
        }

        heroJourney = nil
    }

    private func makeJourney(
        arrival: BusArrival,
        eta: Int,
        fromStop: String,
        destinationLabel: String,
        destinationFallback: String,
        exactMatch: Bool
    ) -> HeroContext.Journey {
        let destinationName = StopsAdapters
            .destinationLabel(for: arrival)
            .ifEmpty(destinationFallback)
        let slack: String = {
            if timeContext == .night { return "Last service tonight" }
            if exactMatch { return "\(max(eta - 2, 1)) min to spare" }
            return "Next bus from \(fromStop)"
        }()
        let totalTrip = max(eta + 12, 18)
        return HeroContext.Journey(
            bus: arrival.serviceNo,
            etaMinutes: eta,
            slack: slack,
            destination: destinationName,
            destinationLabel: destinationLabel,
            fromStop: fromStop,
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
