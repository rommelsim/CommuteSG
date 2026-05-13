import SwiftUI
import WidgetKit
import CoreLocation

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Binding var selectedTab: MainTab
    @State private var viewModel = HomeViewModel()
    @State private var navigation = HomeNavigation()
    @State private var editingPlace: SavedPlace.Kind?
    @State private var previewingShortcut: ShortcutPreviewState?
    @State private var stopSheet: StopSheetData?
    @State private var mrtSheet: MRTStation?
    @State private var heroWeather: HeroContext.Weather = HeroContext.Weather(symbol: "sun.max.fill", text: "—")
    @State private var heroJourney: HeroContext.Journey?
    /// Soonest persisted ETA per `[stopCode][serviceNo]`, loaded from the
    /// App Group snapshot at init so Home renders last-known ETAs instantly
    /// on cold launch instead of flashing blank chips. Replaced as soon as
    /// the live LTA fetch lands. Stored as absolute dates so minute counts
    /// recompute on each render — stale entries fade out naturally.
    @State private var pinnedSnapshotByStop: [String: [String: Date]] =
        Self.loadPinnedSnapshot()

    private static func loadPinnedSnapshot() -> [String: [String: Date]] {
        guard let snap = SharedSnapshot.readPinnedArrivals() else { return [:] }
        var out: [String: [String: Date]] = [:]
        for (code, arrivals) in snap.arrivalsByStop {
            var perService: [String: Date] = [:]
            for a in arrivals {
                if let date = a.nextArrivalAt { perService[a.serviceNo] = date }
            }
            out[code] = perService
        }
        return out
    }

    /// Full live-arrival payload for each pinned bus stop, keyed by stop
    /// code. Pinned items may sit far outside `viewModel.nearbyBusStops`, so
    /// we hit LTA directly per pinned code. Stored as full `[BusArrival]`
    /// (not just minutes) so that pinned **bus chips** can also resolve their
    /// ETA against pinned-stop arrivals — e.g. if you pin bus 122 *and*
    /// Kent Ridge Ter, the bus chip can answer "when is 122 at Kent Ridge?"
    /// even when neither sits inside the nearby radius.
    @State private var pinnedStopArrivals: [String: [BusArrival]] = [:]
    /// True once `refreshPinnedStopETAs` has completed at least one pass.
    /// Before then we can't tell "no upcoming bus" from "still loading", so
    /// the chips render blank; after, an empty result becomes "No service".
    @State private var pinnedFetchCompleted = false

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
                    HomeHero(context: heroContext)
                    savedDestinations
                    pinnedStopsSection
                    nearbyTransitHeader
                    mrtSection
                    nearbyTransitGroup
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
                await refreshPinnedStopETAs(force: true)
            }
            .task {
                await viewModel.load()
                await refreshWeatherAndJourney()
                await refreshPinnedStopETAs(force: false)
            }
            // Keep pinned ETAs live while Home is visible. 30 s matches the
            // LTA arrivals refresh cadence; the LTAService cache absorbs
            // redundant calls. Task is cancelled automatically on disappear.
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 30 * 1_000_000_000)
                    await refreshPinnedStopETAs(force: true)
                }
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
                Task { await refreshPinnedStopETAs(force: false) }
            }
            .onChange(of: appState.favoriteLineCodes) { _, _ in
                publishPinnedSnapshot()
            }
            // When the app returns from background (e.g. overnight sleep),
            // the in-flight `.task` loops are suspended and `Task.sleep`
            // resumes from where it paused — meaning nearby/arrivals/hero
            // data would stay frozen at last night's snapshot until the
            // next manual pull-to-refresh. Re-run the full refresh chain
            // on every active transition so morning launches show live data.
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task {
                    await viewModel.refresh()
                    await refreshWeatherAndJourney()
                    await refreshPinnedStopETAs(force: true)
                }
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
            Text("Where to?")
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(Color.cfTextPrimary)
            Spacer()
            Button {
                navigation.go(.profile)
            } label: {
                Text(avatarInitial)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.cfTextPrimary)
                    .frame(width: 32, height: 32)
                    .background(Color.cfHairlineStrong, in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Profile")
        }
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
                .font(.system(size: 15, weight: .semibold))
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
            if !LocationService.shared.isAuthorized {
                locationDeniedCard
            } else {
                ErrorCard(message: message) { Task { await viewModel.refresh() } }
                    .glassSurface(cornerRadius: 18)
            }
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

    private var locationDeniedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.appWarning)
                Text("Location access is off")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.cfTextPrimary)
            }
            Text("Allow location for Commute in Settings to see nearby stops, trains, and arrivals.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.cfTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                if let url = URL(string: "app-settings:") {
                    openURL(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.appInfo, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: 18)
    }

    @ViewBuilder
    private var mrtSection: some View {
        // Hide MRT entirely when location is denied — the dedicated banner in
        // nearbyTransitGroup already explains the situation; a second card
        // would just nag.
        if case .failed = viewModel.loadingState, !LocationService.shared.isAuthorized {
            EmptyView()
        } else {
        switch viewModel.loadingState {
        case .locating, .fetchingStops, .loadingArrivals:
            NearbyMRTSkeleton()
        case .idle, .ready, .failed:
            if let mrt = viewModel.nearbyMRT {
                NearbyMRTCard(nearby: mrt) { mrtSheet = mrt.station }
            } else if case .ready = viewModel.loadingState {
                HStack(spacing: 10) {
                    Image(systemName: "tram.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.cfTextTertiary)
                    Text("No MRT station nearby")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.cfTextSecondary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassSurface(cornerRadius: 14, fill: Color.cfGlassFillSoft)
            }
        }
        }
    }

    // MARK: - Pinned section (favorited buses + stops)

    /// Bus stops the user has starred. Resolved synchronously from the
    /// MainActor `BusStopNameCache` (populated by `BusStopsRepository`).
    /// Unknown codes (cache not warm yet) are dropped silently.
    private var pinnedStops: [BusStop] {
        appState.favoriteBusStopCodes
            .compactMap { BusStopNameCache.shared.stop(forCode: $0) }
            .sorted { lhs, rhs in
                // Soonest arrival first; unknown/no-service sorted to the end
                // (Int.max sentinel). Tie-break alphabetically so the order
                // is stable when multiple chips are e.g. all "No service".
                let l = soonestETA(atPinnedStop: lhs.id) ?? Int.max
                let r = soonestETA(atPinnedStop: rhs.id) ?? Int.max
                return (l, lhs.name) < (r, rhs.name)
            }
    }

    /// Bus service numbers the user has starred (e.g. "156", "282").
    private var pinnedBusNumbers: [String] {
        appState.favoriteLineCodes.sorted { lhs, rhs in
            // Soonest arrival first; fall back to numeric-aware service-
            // number sort for ties / no-service entries so "10" precedes
            // "100".
            let l = soonestETA(forService: lhs) ?? Int.max
            let r = soonestETA(forService: rhs) ?? Int.max
            return (l, Int(lhs) ?? .max, lhs) < (r, Int(rhs) ?? .max, rhs)
        }
    }

    @ViewBuilder
    private var pinnedStopsSection: some View {
        if !pinnedStops.isEmpty || !pinnedBusNumbers.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.appAmber)
                    Text("PINNED")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(Color.cfTextSecondary)
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
        let eta = soonestETA(atPinnedStop: stop.id)
        let walk = walkMinutes(to: stop)
        return Button {
            stopSheet = StopSheetData(stop: stop, arrivals: pinnedStopArrivals[stop.id] ?? [])
        } label: {
            HStack(spacing: 8) {
                BusStopIcon(size: 14, color: Color.cfTextSecondary, strokeWidth: 2.2)
                Text(stop.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.cfTextPrimary)
                    .lineLimit(1)
                if let walk {
                    HStack(spacing: 2) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 9, weight: .semibold))
                        Text("\(walk)m")
                            .font(.system(size: 10, weight: .semibold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(Color.cfTextTertiary)
                }
                etaTrailing(eta: eta)
            }
            .padding(.horizontal, 12)
            .frame(height: pinnedChipHeight)
            .glassSurface(cornerRadius: 12, fill: Color.cfGlassFillSoft)
        }
        .buttonStyle(CardButtonStyle(pressedScale: 0.95))
        .accessibilityLabel("Pinned stop \(stop.name)")
        .contextMenu {
            Button(role: .destructive) {
                appState.toggleFavoriteBusStop(stop.id)
            } label: {
                Label("Unpin", systemImage: "star.slash")
            }
        }
    }

    private func pinnedBusChip(_ serviceNo: String) -> some View {
        let eta = soonestETA(forService: serviceNo)
        return Button { handlePinnedBus(serviceNo) } label: {
            HStack(spacing: 8) {
                ServiceChip(service: serviceNo, size: .sm)
                etaTrailing(eta: eta)
            }
            .padding(.horizontal, 12)
            .frame(height: pinnedChipHeight)
            .glassSurface(cornerRadius: 12, fill: Color.cfGlassFillSoft)
        }
        .buttonStyle(CardButtonStyle(pressedScale: 0.92))
        .accessibilityLabel(
            eta.map { "Pinned bus \(serviceNo), arriving in \($0) minutes" }
                ?? "Pinned bus \(serviceNo)"
        )
        .contextMenu {
            Button(role: .destructive) {
                appState.toggleFavoriteLine(serviceNo)
            } label: {
                Label("Unpin", systemImage: "star.slash")
            }
        }
    }

    /// Trailing ETA chunk shared by both pinned chips. Three visual states:
    ///   - waiting for first fetch    → render nothing (avoid premature "No service")
    ///   - fetch done, ETA available  → green if ≤3 min, secondary otherwise
    ///   - fetch done, no ETA         → muted "No service"
    @ViewBuilder
    private func etaTrailing(eta: Int?) -> some View {
        if let eta {
            Text(eta == 0 ? "Arr" : "\(eta) min")
                .font(.system(size: 11, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(eta <= 3 ? Color.appSuccess : Color.cfTextSecondary)
        } else if pinnedFetchCompleted {
            Text("No service")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.cfTextTertiary)
        }
    }


    /// Tapping a pinned bus opens live tracking from whichever stop has the
    /// soonest arrival for this service — pinned stops first (the user has
    /// declared interest in those), then nearby stops as a fallback. If
    /// nothing's scheduled anywhere we know about, surface a quiet toast.
    private func handlePinnedBus(_ serviceNo: String) {
        struct Hit { let arrival: BusArrival; let stopCode: String; let minutes: Int }

        var hits: [Hit] = []
        for (code, arrivals) in pinnedStopArrivals {
            for a in arrivals where a.serviceNo == serviceNo {
                hits.append(Hit(arrival: a, stopCode: code, minutes: a.nextArrivalMinutes ?? .max))
            }
        }
        for entry in viewModel.nearbyBusStops {
            for a in entry.arrivals where a.serviceNo == serviceNo {
                hits.append(Hit(arrival: a, stopCode: entry.stop.id, minutes: a.nextArrivalMinutes ?? .max))
            }
        }

        if let best = hits.min(by: { $0.minutes < $1.minutes }) {
            navigation.go(.tracking(best.arrival, busStopCode: best.stopCode))
        } else {
            Task { @MainActor in
                ToastCenter.shared.show(.info("Bus \(serviceNo) not arriving soon"))
            }
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

    /// Fetch live arrivals for every pinned stop in parallel and publish the
    /// full per-stop arrival list. Pinned stops may be far outside the
    /// nearby radius, so we hit LTA directly. `LTAService` caches per stop
    /// for a few seconds; `force: true` (pull-to-refresh) bypasses cache.
    private func refreshPinnedStopETAs(force: Bool) async {
        let codes = appState.favoriteBusStopCodes
        guard !codes.isEmpty else {
            pinnedStopArrivals = [:]
            pinnedFetchCompleted = true
            return
        }
        var next: [String: [BusArrival]] = [:]
        await withTaskGroup(of: (String, [BusArrival]).self) { group in
            for code in codes {
                group.addTask {
                    let arrivals = (try? await LTAService.shared.busArrivals(
                        at: code, serviceNo: nil, force: force
                    )) ?? []
                    return (code, arrivals)
                }
            }
            for await (code, arrivals) in group {
                next[code] = arrivals
            }
        }
        pinnedStopArrivals = next
        pinnedFetchCompleted = true

        // Persist a minimal snapshot (service + absolute date only) so the
        // next cold launch can render last-known ETAs immediately.
        var snap: [String: [PinnedArrivalsSnapshot.Arrival]] = [:]
        for (code, arrivals) in next {
            snap[code] = arrivals.map {
                PinnedArrivalsSnapshot.Arrival(serviceNo: $0.serviceNo, nextArrivalAt: $0.nextArrivalAt)
            }
        }
        SharedSnapshot.writePinnedArrivals(
            PinnedArrivalsSnapshot(arrivalsByStop: snap, updatedAt: Date())
        )
        pinnedSnapshotByStop = Self.loadPinnedSnapshot()
    }

    /// Walking-time estimate from the user's current location to a pinned
    /// stop. Returns nil if either side is unknown (cache miss / no location
    /// fix), in which case the chip just omits the walk pill.
    private func walkMinutes(to stop: BusStop) -> Int? {
        guard let coord = stop.coordinate,
              let here = LocationService.shared.lastLocation else { return nil }
        let stopLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        let meters = Int(here.distance(from: stopLoc))
        return StopsAdapters.walkMinutes(forMeters: meters)
    }

    /// Minutes-from-now for an absolute arrival date, mirroring
    /// `BusArrival.nextArrivalMinutes` rounding. Returns nil for past times.
    private static func minutesFromNow(_ date: Date) -> Int? {
        let s = date.timeIntervalSinceNow
        guard s > -30 else { return nil }                // past, drop
        if s < 30 { return 0 }                            // "Arr"
        return Int((s / 60).rounded(.up))
    }

    /// Soonest next-arrival minutes at a pinned stop across all services.
    /// Prefers live data; falls back to the persisted snapshot.
    private func soonestETA(atPinnedStop code: String) -> Int? {
        if let live = pinnedStopArrivals[code] {
            return live.compactMap { $0.nextArrivalMinutes }.min()
        }
        if let snap = pinnedSnapshotByStop[code] {
            return snap.values.compactMap { Self.minutesFromNow($0) }.min()
        }
        return nil
    }

    /// Soonest ETA for a service across pinned-stop arrivals (live or
    /// snapshot) then nearby-stop arrivals.
    private func soonestETA(forService serviceNo: String) -> Int? {
        let liveHits = pinnedStopArrivals.values
            .flatMap { $0 }
            .filter { $0.serviceNo == serviceNo }
            .compactMap { $0.nextArrivalMinutes }
        let snapHits = pinnedSnapshotByStop.values
            .compactMap { $0[serviceNo] }
            .compactMap(Self.minutesFromNow)
        let nearbyHits = viewModel.nearbyBusStops
            .flatMap { $0.arrivals }
            .filter { $0.serviceNo == serviceNo }
            .compactMap { $0.nextArrivalMinutes }
        return (liveHits + snapHits + nearbyHits).min()
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
