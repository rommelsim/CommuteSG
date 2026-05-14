import SwiftUI

/// Top-level MRT crowd browser screen — live data from LTA DataMall.
struct StationBrowserView: View {
    /// Journey strip stops, caller-provided. Empty array hides the
    /// strip entirely. Bind to active-trip data when available; pass
    /// `[]` from surfaces without trip context.
    let journey: [JourneyNode]
    /// Code of the station whose card renders at the top ("Now at
    /// CC23"). Pass nil to omit the section (e.g. from `LiveTrackingView`
    /// where the user is on a bus, not at an MRT).
    let currentStationCode: String?

    @Environment(\.dismiss) private var dismiss

    @State private var snapshots: [StationCrowdSnapshot] = []
    @State private var loadState: LoadState = .loading
    @State private var pickedStation: StationCrowdSnapshot?
    /// Drives the 30s background refresh. LTA's PCDRealTime updates
    /// every ~10 min, but the forecast slots rotate every 30 min, so
    /// 30s feels right for keeping both fresh without thrashing.
    private let refreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private enum LoadState: Equatable {
        case loading        // first fetch in flight, no data yet
        case loaded         // at least one successful response
        case failed         // first fetch threw / returned empty
    }

    private var currentSnapshot: StationCrowdSnapshot? {
        guard let code = currentStationCode else { return nil }
        return snapshots.first(where: { $0.stationCode == code })
    }

    var body: some View {
        ZStack {
            scrollContent
            StationDetailSheet(snapshot: $pickedStation)
        }
        .background(Color.cfPageBackground.ignoresSafeArea())
        .navigationTitle("Station crowd")
        .navigationBarTitleDisplayMode(.inline)
        // Hijack the default chevron — when the sheet's open, the
        // back button should dismiss the sheet first, *then* pop on a
        // second tap. Without this iOS unwinds the whole screen even
        // when the user just wants to close the inspector card.
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: handleBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 15))
                    }
                    .foregroundStyle(Color.appInfo)
                }
            }
        }
        .task { await refresh() }
        .onReceive(refreshTimer) { _ in
            Task { await refresh() }
        }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !journey.isEmpty {
                    JourneyStripView(
                        nodes: journey,
                        destinationLabel: journey.last?.stationName
                    )
                }
                contentForState
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var contentForState: some View {
        switch loadState {
        case .loading where snapshots.isEmpty:
            loadingCard
        case .failed where snapshots.isEmpty:
            errorCard
        default:
            if let snap = currentSnapshot {
                CurrentCrowdCard(snapshot: snap)
            }
            StationChipsRow(
                snapshots: snapshots,
                currentStationCode: currentStationCode,
                onPick: { snap in pickedStation = snap }
            )
        }
    }

    private var loadingCard: some View {
        HStack(spacing: 10) {
            ProgressView().scaleEffect(0.8)
            Text("Loading live crowd data…")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.cfTextSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appSurface)
        )
    }

    private var errorCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Couldn't reach LTA")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.cfTextPrimary)
            Text("Check your network and try again — pull down to refresh.")
                .font(.system(size: 11))
                .foregroundStyle(Color.cfTextSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appSurface)
        )
    }

    /// Back-button handler. Closes the sheet first if one is open;
    /// otherwise pops the view off the navigation stack.
    private func handleBack() {
        if pickedStation != nil {
            withAnimation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.42)) {
                pickedStation = nil
            }
        } else {
            dismiss()
        }
    }

    // MARK: - Refresh

    private func refresh() async {
        if loadState != .loaded { loadState = .loading }
        let fresh = await StationCrowdService.shared.fetchAllSnapshots(force: true)
        // Animate so the pip + colour transitions on already-rendered
        // cards play smoothly when LTA returns a new tier.
        withAnimation(.easeOut(duration: 0.7)) {
            snapshots = fresh
        }
        loadState = fresh.isEmpty ? .failed : .loaded
    }
}
