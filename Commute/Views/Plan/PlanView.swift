import SwiftUI

struct PlanView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = PlanViewModel()
    @State private var navigation = HomeNavigation()
    @State private var editingField: JourneyPickerSheet.Field?
    @State private var customDate: Date = Date().addingTimeInterval(15 * 60)
    @State private var showingCustomDate = false
    @State private var showingFareOverlay = false

    var body: some View {
        @Bindable var nav = navigation
        @Bindable var vm = viewModel

        NavigationStack(path: $nav.path) {
            ScrollView {
                VStack(spacing: Spacing.s16) {
                    header
                    fromToPanel
                        .padding(.horizontal, Spacing.screen)
                    checkFarePill
                        .padding(.horizontal, Spacing.screen)
                    if viewModel.hasAnyValue {
                        clearAllButton
                            .padding(.horizontal, Spacing.screen)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    if viewModel.hasDestination {
                        timePill
                            .padding(.horizontal, Spacing.screen)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    if !quickDestinations.isEmpty {
                        quickDestinationStrip
                    }
                    if viewModel.hasDestination {
                        Divider()
                            .background(Color.cfHairline)
                            .padding(.horizontal, Spacing.screen)
                            .padding(.top, 4)
                            .transition(.opacity)
                        FilterPills(
                            options: PlanViewModel.Filter.allCases,
                            label: { $0.label },
                            selection: $vm.filter,
                            smartDefault: PlanViewModel.Filter.smartDefault()
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                        if vm.filter == PlanViewModel.Filter.smartDefault(),
                           let hint = PlanViewModel.Filter.smartHint() {
                            Text(hint)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.cfTextSecondary)
                                .padding(.horizontal, Spacing.screen)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .transition(.opacity)
                        }
                        options
                            .padding(.horizontal, Spacing.screen)
                            .padding(.top, 4)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        emptyState
                            .padding(.top, 28)
                            .transition(.opacity)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
                .animation(.smooth(duration: 0.32), value: viewModel.hasDestination)
                .animation(.snappy(duration: 0.20), value: viewModel.hasAnyValue)
            }
            .scrollIndicators(.hidden)
            .background(Color.appSurface)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: HomeRoute.self) { route in
                destination(for: route)
            }
            .sheet(item: $editingField) { field in
                JourneyPickerSheet(
                    field: field,
                    initialText: field == .from ? viewModel.fromText : viewModel.toText
                ) { picked, coord in
                    switch field {
                    case .from: viewModel.setFrom(picked, coordinate: coord)
                    case .to:   viewModel.setTo(picked, coordinate: coord)
                    }
                }
                .environment(appState)
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingCustomDate) {
                customDateSheet
                    .presentationDetents([.height(360)])
            }
            .sheet(isPresented: $showingFareOverlay) {
                FareOverlaySheet(
                    fromText: viewModel.fromText,
                    toText: viewModel.toText,
                    fromCoord: viewModel.fromCoordinate,
                    toCoord: viewModel.toCoordinate
                )
                .environment(appState)
            }
            .onChange(of: appState.pendingPlanDestination) { _, newValue in
                if let target = newValue?.trimmingCharacters(in: .whitespaces), !target.isEmpty {
                    viewModel.setTo(target)
                    appState.pendingPlanDestination = nil
                    navigation.popToRoot()
                }
            }
            .task {
                if let target = appState.pendingPlanDestination?
                    .trimmingCharacters(in: .whitespaces), !target.isEmpty {
                    viewModel.setTo(target)
                    appState.pendingPlanDestination = nil
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Plan a journey")
                .font(.appTitle)
                .tracking(-0.5)
                .foregroundStyle(Color.cfTextPrimary)
            Text("Pick a starting point and where you're going")
                .font(.appLabel)
                .foregroundStyle(Color.cfTextSecondary)
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.top, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - From/To panel

    private var fromToPanel: some View {
        ZStack(alignment: .trailing) {
            VStack(spacing: 0) {
                fieldRow(
                    leading: fromLeading,
                    label: "From",
                    value: viewModel.fromText,
                    placeholder: "Your current location",
                    isPlaceholder: viewModel.fromIsCurrentLocation
                ) {
                    editingField = .from
                }
                Divider()
                    .background(Color.cfHairline)
                    .padding(.leading, 44)
                fieldRow(
                    leading: AnyView(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.appDestination)
                            .frame(width: 10, height: 10)
                    ),
                    label: "To",
                    value: viewModel.toText,
                    placeholder: "Where to?",
                    isPlaceholder: !viewModel.hasDestination
                ) {
                    editingField = .to
                }
            }
            .background(Color.appSurface2)
            .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                    .stroke(Color.cfHairline, lineWidth: 0.5)
            )

            Button {
                withAnimation(.snappy(duration: 0.25)) { viewModel.swap() }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.cfTextPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.appSurface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.cfHairline, lineWidth: 0.5))
                    .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 1)
            }
            .buttonStyle(CardButtonStyle(pressedScale: 0.9))
            .accessibilityLabel("Swap from and to")
            .padding(.trailing, 14)
            .sensoryFeedback(.impact(weight: .light), trigger: viewModel.fromText)
        }
    }

    private var fromLeading: AnyView {
        AnyView(
            Group {
                if viewModel.fromIsCurrentLocation {
                    Image(systemName: "location.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 14, height: 14)
                        .background(Color.appInfo)
                        .clipShape(Circle())
                } else {
                    Circle().fill(Color.appInfo).frame(width: 10, height: 10)
                }
            }
        )
    }

    private func fieldRow(
        leading: AnyView,
        label: String,
        value: String,
        placeholder: String,
        isPlaceholder: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                leading
                    .frame(width: 14)
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.appMicro)
                        .foregroundStyle(Color.cfTextTertiary)
                    Text(isPlaceholder ? placeholder : value)
                        .font(.appBodyMedium)
                        .foregroundStyle(isPlaceholder ? Color.cfTextTertiary : Color.cfTextPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .padding(.trailing, 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// "Clear all" link — only visible when at least one field is populated.
    /// Animates in with a small slide as the user fills the planner.
    private var clearAllButton: some View {
        HStack {
            Spacer()
            Button {
                viewModel.clear()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Clear all")
                        .font(.appLabelMedium)
                }
                .foregroundStyle(Color.cfTextSecondary)
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(CardButtonStyle(pressedScale: 0.92))
            .sensoryFeedback(.impact(weight: .light), trigger: viewModel.hasAnyValue)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color.cfTextMuted)
            Text("Where would you like to go?")
                .font(.appBodyMedium)
                .foregroundStyle(Color.cfTextSecondary)
            Text("Tap **To** above to pick a destination, or jump straight to a saved place.")
                .font(.appCaption)
                .foregroundStyle(Color.cfTextTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                editingField = .to
            } label: {
                Text("Choose destination")
                    .font(.appLabelMedium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color.appInfo, in: Capsule())
            }
            .buttonStyle(CardButtonStyle(pressedScale: 0.95))
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Fare overlay pill

    private var checkFarePill: some View {
        HStack {
            Button {
                showingFareOverlay = true
            } label: {
                HStack(spacing: 6) {
                    Text("$")
                        .font(.system(size: 13, weight: .bold))
                    Text("Check a fare")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.cfGlassFillSoft))
                .foregroundStyle(Color.cfTextPrimary)
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    // MARK: - Time pill

    private var timePill: some View {
        HStack {
            Menu {
                Button {
                    viewModel.departureMode = .now
                } label: {
                    Label("Leave now", systemImage: "clock.fill")
                }
                Button {
                    customDate = Date().addingTimeInterval(15 * 60)
                    showingCustomDate = true
                    pendingMode = .leave
                } label: {
                    Label("Leave at…", systemImage: "clock.arrow.circlepath")
                }
                Button {
                    customDate = Date().addingTimeInterval(60 * 60)
                    showingCustomDate = true
                    pendingMode = .arrive
                } label: {
                    Label("Arrive by…", systemImage: "flag.checkered")
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.departureMode.icon)
                        .font(.system(size: 12, weight: .semibold))
                    Text(viewModel.departureMode.shortLabel)
                        .font(.appLabelMedium)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(Color.cfTextPrimary)
                .padding(.vertical, 7)
                .padding(.horizontal, 12)
                .background(Color.appSurface2)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.cfHairline, lineWidth: 0.5))
            }
            Spacer()
        }
    }

    // Capture which mode the date sheet should produce
    @State private var pendingMode: PendingDateMode = .leave
    private enum PendingDateMode { case leave, arrive }

    private var customDateSheet: some View {
        NavigationStack {
            VStack(spacing: 12) {
                DatePicker(
                    pendingMode == .leave ? "Leave at" : "Arrive by",
                    selection: $customDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .padding(.horizontal, Spacing.screen)
                .padding(.top, 16)

                Spacer()
            }
            .background(Color.appSurface)
            .navigationTitle(pendingMode == .leave ? "Leave at" : "Arrive by")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showingCustomDate = false }
                        .foregroundStyle(Color.appInfo)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Set") {
                        viewModel.departureMode = pendingMode == .leave
                            ? .leaveAt(customDate)
                            : .arriveBy(customDate)
                        showingCustomDate = false
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.appInfo)
                }
            }
        }
    }

    // MARK: - Quick destinations

    private var quickDestinations: [SavedPlace] {
        appState.savedPlaces
            .filter { !$0.address.trimmingCharacters(in: .whitespaces).isEmpty }
            .filter {
                $0.address.localizedCaseInsensitiveCompare(viewModel.toText) != .orderedSame
            }
    }

    private var quickDestinationStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickDestinations) { place in
                    Button {
                        viewModel.setTo(place.address)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: place.kind.symbol)
                                .font(.system(size: 11, weight: .semibold))
                            // `place.label` is stored as English ("Home" / "Work")
                            // — pre-localize it via NSLocalizedString so the
                            // template substitution produces "前往 首页" rather
                            // than "前往 Home" in Chinese.
                            Text("To \(NSLocalizedString(place.label, comment: ""))")
                                .font(.appLabelMedium)
                        }
                        .foregroundStyle(place.kind == .work ? Color.appPurple : Color.appInfo)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 12)
                        .background(place.kind == .work ? Color.appPurpleBg : Color.appInfoBg)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(CardButtonStyle())
                }
            }
            .padding(.horizontal, Spacing.screen)
        }
    }

    // MARK: - Options

    private var options: some View {
        let opts = viewModel.options
        let scores: [UUID: CommuteScore] = Dictionary(
            uniqueKeysWithValues: opts.map { ($0.id, CommuteScore.make(for: $0, within: opts)) }
        )
        let bestScoreID: UUID? = scores.max(by: { $0.value.overall < $1.value.overall })?.key
        return VStack(spacing: Spacing.cardGap) {
            ForEach(Array(opts.enumerated()), id: \.element.id) { idx, opt in
                JourneyOptionCard(
                    option: opt,
                    isBest: idx == 0 && opt.id != bestScoreID,
                    isBestScore: opt.id == bestScoreID,
                    score: scores[opt.id],
                    departureMode: viewModel.departureMode
                ) {
                    navigation.go(.journey(
                        opt,
                        mode: viewModel.departureMode,
                        fromText: viewModel.fromText,
                        toText: viewModel.toText
                    ))
                }
            }
            // Static info pill — was a `LiveBadge(mode: .demo)` which
            // showed a perpetual "Connecting…" spinner because the demo
            // state has no terminal "loaded" condition. Plain info text
            // is honest: results are estimates, full stop.
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 10, weight: .medium))
                Text("Estimated routes — LTA's public API doesn't include journey planning yet.")
                    .font(.appMicro)
            }
            .foregroundStyle(Color.cfTextTertiary)
            .padding(.top, 4)
        }
        .animation(.smooth(duration: 0.25), value: viewModel.filter)
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
        case .tracking(let arrival, let busStopCode):
            LiveTrackingView(arrival: arrival, busStopCode: busStopCode)
        case .trackingDeepLink(let serviceNo, let stopCode):
            TrackingDeepLinkView(serviceNo: serviceNo, stopCode: stopCode)
        case .journey(let opt, let mode, let from, let to):
            JourneyDetailView(option: opt, mode: mode, fromText: from, toText: to)
        case .allMRTStations:
            AllMRTStationsScreen()
        case .allBusStops:
            EmptyView()
        case .alerts:
            EmptyView()
        case .mySpend:
            MyCommuteSpendView()
        case .stationBrowser(let journey, let currentCode):
            StationBrowserView(journey: journey, currentStationCode: currentCode)
        }
    }
}
