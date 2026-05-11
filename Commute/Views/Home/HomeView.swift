import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Binding var selectedTab: MainTab
    @State private var viewModel = HomeViewModel()
    @State private var navigation = HomeNavigation()
    @State private var editingPlace: SavedPlace.Kind?
    @State private var showingSearch = false
    @State private var previewingShortcut: ShortcutPreviewState?
    /// Sheet state for stop and MRT card presentations. The Home view stays
    /// visible behind a partial-height card so the tab bar never disappears
    /// the way it does with a full-screen navigation push.
    @State private var stopSheet: StopSheetData?
    @State private var mrtSheet: MRTStation?

    private struct ShortcutPreviewState: Identifiable {
        let kind: SavedPlace.Kind
        let address: String
        var id: String { kind.rawValue }
    }

    var body: some View {
        @Bindable var nav = navigation

        NavigationStack(path: $nav.path) {
            List {
                Section {
                    Group {
                        header
                        searchBar
                        shortcuts
                    }
                    .plainListRow()
                }

                switch viewModel.loadingState {
                case .fetchingStops, .locating, .loadingArrivals, .failed:
                    Section {
                        VStack(alignment: .leading, spacing: 0) {
                            SectionHeader(title: "Near you")
                            VStack(spacing: Spacing.cardGap) {
                                loadingOrErrorCard
                            }
                            .padding(.horizontal, Spacing.screen)
                        }
                        .plainListRow()
                    }
                case .idle, .ready:
                    ForEach(appState.nearbyOrder) { block in
                        Section(isExpanded: expansionBinding(for: block)) {
                            sectionRows(for: block)
                        } header: {
                            sectionLabel(for: block)
                                .textCase(nil)
                                .listRowInsets(EdgeInsets(
                                    top: 0,
                                    leading: Spacing.screen,
                                    bottom: Spacing.s10,
                                    trailing: Spacing.screen
                                ))
                        }
                    }
                }
            }
            .listStyle(.plain)
            .listSectionSpacing(.compact)
            .environment(\.defaultMinListRowHeight, 0)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .background(Color(.secondarySystemBackground))
            .refreshable { await viewModel.refresh() }
            .task { await viewModel.load() }
            .navigationDestination(for: HomeRoute.self) { route in
                destination(for: route)
            }
            .sheet(item: $editingPlace) { kind in
                PlaceEditorSheet(kind: kind) { saved in
                    if !saved.isEmpty {
                        appState.pendingPlanDestination = saved
                        selectedTab = .plan
                    }
                }
                .environment(appState)
                .presentationDetents([.height(260)])
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
            // Bus stop & MRT cards → translucent glass sheet per redesign
            // spec §2. The home screen blurs through the sheet via
            // `.thinMaterial`; the sheet's own corners are rounded by the
            // system at 28pt and the drag indicator is shown.
            .sheet(item: $stopSheet) { data in
                NavigationStack {
                    BusStopDetailView(stop: data.stop, initialArrivals: data.arrivals)
                        .navigationDestination(for: HomeRoute.self) { route in
                            destination(for: route)
                        }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.thinMaterial)
                .presentationCornerRadius(28)
                .environment(appState)
            }
            .sheet(item: $mrtSheet) { station in
                NavigationStack {
                    MRTStationDetailView(station: station)
                        .navigationDestination(for: HomeRoute.self) { route in
                            destination(for: route)
                        }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.thinMaterial)
                .presentationCornerRadius(28)
                .environment(appState)
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.s12) {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text(greetingLine)
                    .font(.appBody)
                    .foregroundStyle(Color.appText2)
                Text("Where to today?")
                    .font(.appTitle)
                    .tracking(-0.3)
                    .foregroundStyle(Color.appText)
            }
            Spacer(minLength: Spacing.s8)
            HStack(spacing: Spacing.s8) {
                LiveBadge(
                    mode: viewModel.dataMode == .live ? .live : .demo,
                    lastUpdated: viewModel.lastSuccessfulRefresh,
                    onRefresh: {
                        Task { await viewModel.refresh() }
                    }
                )
                Button {
                    navigation.go(.profile)
                } label: {
                    Text(avatarInitial)
                        .font(.appBodyMedium)
                        .foregroundStyle(Color.appInfo)
                        .frame(width: 28, height: 28)
                        .background(Color.appInfoBg)
                        .clipShape(Circle())
                }
                .buttonStyle(CardButtonStyle(pressedScale: 0.92))
                .accessibilityLabel("Profile")
            }
            .padding(.top, Spacing.s4)
        }
        .padding(.top, Spacing.s32)
        .padding(.bottom, Spacing.s24)
        .padding(.horizontal, Spacing.screen)
    }

    private var greetingLine: String {
        let trimmed = appState.userName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? timeBasedGreeting : "\(timeBasedGreeting), \(trimmed)"
    }

    private var avatarInitial: String {
        let trimmed = appState.userName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "•" : String(trimmed.prefix(1)).uppercased()
    }

    private var searchBar: some View {
        Button {
            showingSearch = true
        } label: {
            HStack(spacing: Spacing.s10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.appText2)
                Text("Search station, bus, address")
                    .font(.appBody)
                    .foregroundStyle(Color.appText3)
                Spacer()
            }
            .padding(.vertical, Spacing.s12)
            .padding(.horizontal, 14)
            .glassCard(cornerRadius: Radius.searchBar)
        }
        .buttonStyle(CardButtonStyle())
        .padding(.horizontal, Spacing.screen)
        .padding(.bottom, Spacing.s16)
    }

    private var shortcuts: some View {
        HStack(spacing: Spacing.s12) {
            ShortcutCard(
                kind: .home,
                etaLabel: shortcutLabel(for: .home),
                action: { handleShortcut(.home) }
            )
            ShortcutCard(
                kind: .work,
                etaLabel: shortcutLabel(for: .work),
                action: { handleShortcut(.work) }
            )
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.bottom, Spacing.s28)
    }

    private func shortcutLabel(for kind: SavedPlace.Kind) -> String {
        let trimmed = (appState.savedPlaces.first(where: { $0.kind == kind })?.address ?? "")
            .trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Tap to set address" : trimmed
    }

    private func handleShortcut(_ kind: SavedPlace.Kind) {
        let address = (appState.savedPlaces.first(where: { $0.kind == kind })?.address ?? "")
            .trimmingCharacters(in: .whitespaces)
        if address.isEmpty {
            editingPlace = kind
        } else {
            previewingShortcut = ShortcutPreviewState(kind: kind, address: address)
        }
    }

    @ViewBuilder
    private var loadingOrErrorCard: some View {
        switch viewModel.loadingState {
        case .fetchingStops, .locating, .loadingArrivals:
            // Shimmering placeholders that match the final card layout —
            // signals "loading, not broken" without the user staring at a
            // generic spinner.
            VStack(spacing: 12) {
                NearbyMRTSkeleton()
                NearbyBusStopSkeleton()
                NearbyBusStopSkeleton()
            }
        case .failed(let message):
            ErrorCard(message: message) {
                Task { await viewModel.refresh() }
            }
        default: EmptyView()
        }
    }

    @ViewBuilder
    private func sectionRows(for block: NearbyBlock) -> some View {
        switch block {
        case .mrt:
            mrtCards
                .padding(.horizontal, Spacing.screen)
                .padding(.bottom, Spacing.s8)
                .plainListRow()
            if viewModel.nearbyMRT != nil {
                seeAllLink(for: .mrt)
                    .padding(.horizontal, Spacing.screen)
                    .padding(.bottom, Spacing.s20)
                    .plainListRow()
            }
        case .busStops:
            ForEach(viewModel.nearbyBusStops) { entry in
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
                .padding(.horizontal, Spacing.screen)
                .padding(.bottom, Spacing.s12)
                .plainListRow()
            }
            if viewModel.nearbyBusStops.isEmpty {
                EmptyStateView(
                    symbol: "bus.fill",
                    title: "No bus stops nearby",
                    subtitle: "Pull to refresh or move to an area with more coverage.",
                    style: .neutral
                )
                .padding(.horizontal, Spacing.screen)
                .plainListRow()
            } else {
                seeAllLink(for: .busStops)
                    .padding(.horizontal, Spacing.screen)
                    .plainListRow()
            }
        }
    }

    private func sectionLabel(for block: NearbyBlock) -> some View {
        let isCollapsed = appState.collapsedSections.contains(block)
        return Button {
            withAnimation(.smooth(duration: 0.3)) {
                if isCollapsed {
                    appState.collapsedSections.remove(block)
                } else {
                    appState.collapsedSections.insert(block)
                }
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s8) {
                Text(block.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.appText)
                Spacer(minLength: Spacing.s8)
                if let meta = distanceMeta(for: block) {
                    Text(meta)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.appText2)
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.appText2)
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func expansionBinding(for block: NearbyBlock) -> Binding<Bool> {
        Binding(
            get: { !appState.collapsedSections.contains(block) },
            set: { newValue in
                if newValue {
                    appState.collapsedSections.remove(block)
                } else {
                    appState.collapsedSections.insert(block)
                }
            }
        )
    }

    private func distanceMeta(for block: NearbyBlock) -> String? {
        switch block {
        case .mrt:
            guard let m = viewModel.nearbyMRT?.station.distanceMeters else { return nil }
            return "\(m)m away"
        case .busStops:
            guard let m = viewModel.nearbyBusStops.first?.stop.distanceMeters else { return nil }
            return "\(m)m away"
        }
    }

    @ViewBuilder
    private var mrtCards: some View {
        if let mrt = viewModel.nearbyMRT {
            NearbyMRTCard(nearby: mrt) {
                mrtSheet = mrt.station
            }
        } else {
            Text("No MRT station found nearby.")
                .font(.appCaption)
                .foregroundStyle(Color.appText3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var busStopCards: some View {
        if viewModel.nearbyBusStops.isEmpty {
            Text("No bus stops found nearby.")
                .font(.appCaption)
                .foregroundStyle(Color.appText3)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ForEach(viewModel.nearbyBusStops) { entry in
                NearbyBusStopCard(
                    stop: entry.stop,
                    arrivals: entry.arrivals,
                    onTapStop: { navigation.go(.busStop(entry.stop, entry.arrivals)) },
                    onTapBus: { arrival in
                        navigation.go(.tracking(arrival, busStopCode: entry.stop.id))
                    }
                )
            }
        }
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

    @ViewBuilder
    private func seeAllLink(for block: NearbyBlock) -> some View {
        let title: String = {
            switch block {
            case .mrt: "See all nearby stations"
            case .busStops: "See all nearby stops"
            }
        }()
        Button {
            switch block {
            case .mrt: navigation.go(.allMRTStations)
            case .busStops: navigation.go(.allBusStops)
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .font(.appBodyMedium)
            .foregroundStyle(Color.appInfo)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Spacing.s8)
        }
        .buttonStyle(.plain)
    }
}

/// Identifiable wrapper used for the bus-stop sheet presentation. Carries the
/// initial arrivals along with the stop so the sheet can populate immediately
/// while it kicks off its own LTA refresh.
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

private extension HomeView {
    var timeBasedGreeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12:  return NSLocalizedString("Good morning", comment: "")
        case 12..<18: return NSLocalizedString("Good afternoon", comment: "")
        default:      return NSLocalizedString("Good evening", comment: "")
        }
    }
}

private extension View {
    func plainListRow() -> some View {
        self
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}
