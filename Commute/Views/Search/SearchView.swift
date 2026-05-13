import SwiftUI

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var viewModel = SearchViewModel()
    /// Detail sheets are presented from within Search itself (sheet-on-sheet)
    /// so the search list stays in place behind the card. Dismissing the
    /// detail returns the user to their search results — they don't lose
    /// their query or scroll position.
    @State private var stopSheet: StopSheetData?
    @State private var mrtSheet: MRTStation?
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 14)
                searchField
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
                Divider().background(Color.cfHairlineStrong)
                resultsBody
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .navigationBarHidden(true)
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
        case .alerts:
            EmptyView()
        case .mySpend:
            EmptyView()
        }
    }

    // MARK: - Top bar (custom, not NavigationBar)

    private var topBar: some View {
        ZStack {
            Text("Search")
                .font(.appSubTitle)
                .foregroundStyle(Color.cfTextPrimary)
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Text("Cancel")
                        .font(.appBodyMedium)
                        .foregroundStyle(Color.appInfo)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color(.systemBackground), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.cfHairline, lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.cfTextTertiary)
            TextField("Stop code, station name, or road", text: $viewModel.query)
                .focused($isFocused)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(.appBodyMedium)
                .foregroundStyle(Color.cfTextPrimary)
            if !viewModel.query.isEmpty {
                Button { viewModel.query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.cfTextMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Results body

    @ViewBuilder
    private var resultsBody: some View {
        if viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty {
            emptyState
        } else if viewModel.busStopResults.isEmpty
                    && viewModel.mrtResults.isEmpty
                    && viewModel.addressResults.isEmpty {
            ContentUnavailableView.search(text: viewModel.query)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    if !viewModel.mrtResults.isEmpty {
                        sectionHeader("MRT stations")
                        ForEach(Array(viewModel.mrtResults.enumerated()), id: \.element.id) { idx, station in
                            mrtRow(station)
                            if idx < viewModel.mrtResults.count - 1 {
                                rowDivider
                            }
                        }
                        sectionFooter
                    }
                    if !viewModel.busStopResults.isEmpty {
                        sectionHeader("Bus stops")
                        ForEach(Array(viewModel.busStopResults.enumerated()), id: \.element.id) { idx, stop in
                            busStopRow(stop)
                            if idx < viewModel.busStopResults.count - 1 {
                                rowDivider
                            }
                        }
                        sectionFooter
                    }
                }
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer().frame(height: 32)
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

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.appCaptionStrong)
            .tracking(0.6)
            .foregroundStyle(Color.cfTextTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 8)
    }

    private var sectionFooter: some View {
        Spacer().frame(height: 4)
    }

    private var rowDivider: some View {
        Divider()
            .background(Color.cfHairlineStrong)
            .padding(.horizontal, 20)
    }

    // MARK: - MRT row

    private func mrtRow(_ station: MRTStation) -> some View {
        Button { mrtSheet = station } label: {
            HStack(spacing: 12) {
                MRTCodePill(code: station.id)
                VStack(alignment: .leading, spacing: 2) {
                    Text(station.name)
                        .font(.appSubTitle)
                        .foregroundStyle(Color.cfTextPrimary)
                        .lineLimit(1)
                    Text(station.line.fullName)
                        .font(.appCaption)
                        .foregroundStyle(Color.cfTextTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if let m = station.distanceMeters {
                    Text(distanceLabel(m))
                        .font(.appLabelMedium)
                        .monospacedDigit()
                        .foregroundStyle(Color.cfTextTertiary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.cfTextMuted)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bus stop row

    private func busStopRow(_ stop: BusStop) -> some View {
        Button { stopSheet = StopSheetData(stop: stop, arrivals: []) } label: {
            HStack(spacing: 12) {
                Image(systemName: "bus.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.cfTextSecondary)
                    .frame(width: 36, height: 36)
                    .background(Color.cfHairline, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(stop.name)
                        .font(.appSubTitle)
                        .foregroundStyle(Color.cfTextPrimary)
                        .lineLimit(1)
                    Text("\(stop.id) · \(stop.road)")
                        .font(.appCaption)
                        .foregroundStyle(Color.cfTextTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if let m = stop.distanceMeters {
                    Text(distanceLabel(m))
                        .font(.appLabelMedium)
                        .monospacedDigit()
                        .foregroundStyle(Color.cfTextTertiary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.cfTextMuted)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MRT code pill (saturated, used only for MRT line ID)

private struct MRTCodePill: View {
    let code: String

    private var lineColor: Color {
        MRTLineToken.from(code: code)?.color ?? .gray
    }

    var body: some View {
        Text(code)
            .font(.appCaptionStrong)
            .monospacedDigit()
            .tracking(0.3)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(lineColor, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private func distanceLabel(_ meters: Int) -> String {
    meters < 1000 ? "\(meters)m" : String(format: "%.1fkm", Double(meters) / 1000)
}
