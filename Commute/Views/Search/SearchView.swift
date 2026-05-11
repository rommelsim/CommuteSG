import SwiftUI

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var viewModel = SearchViewModel()
    /// Detail sheets are presented from within Search itself (sheet-on-sheet)
    /// so the search list stays in place behind the card. Dismissing the
    /// detail returns the user to their search results — they don't lose
    /// their query or scroll position the way a "dismiss-search-then-present"
    /// flow would.
    @State private var stopSheet: StopSheetData?
    @State private var mrtSheet: MRTStation?
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                    .padding(.horizontal, Spacing.screen)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                Divider().background(Color.appBorder)
                resultsList
            }
            .background(Color.appSurface)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.appInfo)
                }
            }
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
        .onAppear { isFocused = true }
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
        case .allMRTStations:
            AllMRTStationsScreen()
        case .allBusStops:
            EmptyView()
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.appText2)
            TextField("Stop code, station name, or road", text: $viewModel.query)
                .focused($isFocused)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(.appBody)
            if !viewModel.query.isEmpty {
                Button { viewModel.query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.appText3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color.appSurface2)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    @ViewBuilder
    private var resultsList: some View {
        if viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty {
            emptyState
        } else if viewModel.busStopResults.isEmpty && viewModel.mrtResults.isEmpty {
            ContentUnavailableView.search(text: viewModel.query)
        } else {
            List {
                if !viewModel.mrtResults.isEmpty {
                    Section("MRT stations") {
                        ForEach(viewModel.mrtResults) { station in
                            Button {
                                mrtSheet = station
                            } label: {
                                MRTResultRow(station: station)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if !viewModel.busStopResults.isEmpty {
                    Section("Bus stops") {
                        ForEach(viewModel.busStopResults) { stop in
                            Button {
                                stopSheet = StopSheetData(stop: stop, arrivals: [])
                            } label: {
                                BusStopResultRow(stop: stop)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.appSurface)
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer().frame(height: 24)
            EmptyStateView(
                symbol: "magnifyingglass",
                title: "Find a bus stop or MRT station",
                subtitle: "Try a station name, road, or 5-digit stop code.",
                style: .info
            )
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MRTResultRow: View {
    let station: MRTStation

    var body: some View {
        HStack(spacing: 12) {
            LineBadge(line: station.line, code: station.id, emphasized: false)
            VStack(alignment: .leading, spacing: 2) {
                Text(station.name)
                    .font(.appBodyMedium)
                    .foregroundStyle(Color.appText)
                Text(station.line.fullName)
                    .font(.appCaption)
                    .foregroundStyle(Color.appText2)
            }
            Spacer()
            if let m = station.distanceMeters {
                Text(distanceLabel(m))
                    .font(.appMicro)
                    .foregroundStyle(Color.appText3)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.appText3)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

private struct BusStopResultRow: View {
    let stop: BusStop

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bus.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.appText2)
                .frame(width: 28, height: 28)
                .background(Color.appSurface2)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(stop.name)
                    .font(.appBodyMedium)
                    .foregroundStyle(Color.appText)
                Text("\(stop.id) · \(stop.road)")
                    .font(.appCaption)
                    .foregroundStyle(Color.appText2)
                    .lineLimit(1)
            }
            Spacer()
            if let m = stop.distanceMeters {
                Text(distanceLabel(m))
                    .font(.appMicro)
                    .foregroundStyle(Color.appText3)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.appText3)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

private func distanceLabel(_ meters: Int) -> String {
    meters < 1000 ? "\(meters)m" : String(format: "%.1fkm", Double(meters) / 1000)
}
