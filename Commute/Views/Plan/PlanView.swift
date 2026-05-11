import SwiftUI

struct PlanView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = PlanViewModel()
    @State private var navigation = HomeNavigation()
    @State private var editingField: JourneyPickerSheet.Field?
    @State private var customDate: Date = Date().addingTimeInterval(15 * 60)
    @State private var showingCustomDate = false

    var body: some View {
        @Bindable var nav = navigation
        @Bindable var vm = viewModel

        NavigationStack(path: $nav.path) {
            ScrollView {
                VStack(spacing: Spacing.s16) {
                    fromToPanel
                        .padding(.horizontal, Spacing.screen)
                    timePill
                        .padding(.horizontal, Spacing.screen)
                    if !quickDestinations.isEmpty {
                        quickDestinationStrip
                    }
                    Divider()
                        .background(Color.appBorder)
                        .padding(.horizontal, Spacing.screen)
                        .padding(.top, 4)
                    FilterPills(
                        options: PlanViewModel.Filter.allCases,
                        label: { $0.label },
                        selection: $vm.filter
                    )
                    options
                        .padding(.horizontal, Spacing.screen)
                        .padding(.top, 4)
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(Color.appSurface)
            .navigationTitle("Plan journey")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: HomeRoute.self) { route in
                destination(for: route)
            }
            .sheet(item: $editingField) { field in
                JourneyPickerSheet(
                    field: field,
                    initialText: field == .from ? viewModel.fromText : viewModel.toText
                ) { picked in
                    switch field {
                    case .from: viewModel.fromText = picked
                    case .to:   viewModel.toText = picked
                    }
                }
                .environment(appState)
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingCustomDate) {
                customDateSheet
                    .presentationDetents([.height(360)])
            }
            .onChange(of: appState.pendingPlanDestination) { _, newValue in
                if let target = newValue?.trimmingCharacters(in: .whitespaces), !target.isEmpty {
                    viewModel.toText = target
                    appState.pendingPlanDestination = nil
                    navigation.popToRoot()
                }
            }
            .task {
                if let target = appState.pendingPlanDestination?
                    .trimmingCharacters(in: .whitespaces), !target.isEmpty {
                    viewModel.toText = target
                    appState.pendingPlanDestination = nil
                }
            }
        }
    }

    // MARK: - From/To panel

    private var fromToPanel: some View {
        ZStack(alignment: .trailing) {
            VStack(spacing: 0) {
                fieldRow(
                    leading: fromLeading,
                    label: "From",
                    value: viewModel.fromText,
                    isPlaceholder: viewModel.fromIsCurrentLocation
                ) {
                    editingField = .from
                }
                Divider()
                    .background(Color.appBorder)
                    .padding(.leading, 44)
                fieldRow(
                    leading: AnyView(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.appDestination)
                            .frame(width: 10, height: 10)
                    ),
                    label: "To",
                    value: viewModel.toText,
                    isPlaceholder: false
                ) {
                    editingField = .to
                }
            }
            .background(Color.appSurface2)
            .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                    .stroke(Color.appBorder, lineWidth: 0.5)
            )

            Button {
                withAnimation(.snappy(duration: 0.25)) { viewModel.swap() }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.appText)
                    .frame(width: 36, height: 36)
                    .background(Color.appSurface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.appBorder, lineWidth: 0.5))
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
                        .foregroundStyle(Color.appText3)
                    Text(value)
                        .font(.appBodyMedium)
                        .foregroundStyle(isPlaceholder ? Color.appText2 : Color.appText)
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
                .foregroundStyle(Color.appText)
                .padding(.vertical, 7)
                .padding(.horizontal, 12)
                .background(Color.appSurface2)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
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
                        viewModel.toText = place.address
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: place.kind.symbol)
                                .font(.system(size: 11, weight: .semibold))
                            Text("To \(place.label.lowercased())")
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
        VStack(spacing: Spacing.cardGap) {
            ForEach(viewModel.options) { opt in
                JourneyOptionCard(option: opt, departureMode: viewModel.departureMode) {
                    navigation.go(.journey(
                        opt,
                        mode: viewModel.departureMode,
                        fromText: viewModel.fromText,
                        toText: viewModel.toText
                    ))
                }
            }
            HStack(spacing: 6) {
                LiveBadge(mode: .demo)
                Text("Plan results aren't covered by LTA's public API yet.")
                    .font(.appMicro)
                    .foregroundStyle(Color.appText3)
            }
            .padding(.top, 4)
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
        case .tracking(let arrival, let busStopCode):
            LiveTrackingView(arrival: arrival, busStopCode: busStopCode)
        case .journey(let opt, let mode, let from, let to):
            JourneyDetailView(option: opt, mode: mode, fromText: from, toText: to)
        }
    }
}
