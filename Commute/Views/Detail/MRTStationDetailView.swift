import SwiftUI

struct MRTStationDetailView: View {
    let station: MRTStation

    @Environment(AppState.self) private var appState
    @State private var viewModel: MRTStationDetailViewModel
    @State private var showStations = false

    init(station: MRTStation) {
        self.station = station
        _viewModel = State(initialValue: MRTStationDetailViewModel(station: station))
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 16)            // breathing room below the notch / status bar
            DetailHeader(
                center: {
                    HStack(spacing: 12) {
                        MRTLinePill(code: station.id)
                        Text(station.name)
                            .font(.appSubTitle)
                            .foregroundStyle(Color.cfTextPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .padding(.trailing, 8)
                    }
                },
                trailing: {
                    IconCircleButton(
                        symbol: isFavorite ? "star.fill" : "star",
                        foreground: isFavorite ? Color.appAmber : Color.cfTextPrimary
                    ) {
                        appState.toggleFavoriteLine(station.id)
                    }
                }
            )
            // GeometryReader wraps the ScrollView so we can force its
            // content to fill the card's visible height when content is
            // short (e.g. when crowd / lift sections are absent), keeping
            // the same "no dead space" rule as the bus-stop card.
            GeometryReader { geo in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        statusBanner
                        lineMap
                        if viewModel.crowdLevel != .unknown {
                            SectionLabel(text: "Platform crowd")
                            crowdCard
                        }
                        if !viewModel.liftMaintenance.isEmpty {
                            SectionLabel(text: "Lift maintenance")
                            liftMaintenanceList
                        }
                        demoFooter
                    }
                    .padding(.top, Spacing.s24)
                    .padding(.bottom, 24)
                    .frame(minHeight: geo.size.height, alignment: .top)
                }
                .scrollIndicators(.hidden)
                .scrollContentBackground(.hidden)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
    }

    private var isFavorite: Bool {
        appState.favoriteLineCodes.contains(station.id)
    }

    private var statusBanner: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusDotColor)
                .frame(width: 8, height: 8)
            Text(viewModel.status.message)
                .font(.appLabelMedium)
                .foregroundStyle(statusForeground)
                .lineLimit(2)
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .tintedGlassCard(cornerRadius: Radius.small, tint: statusTint)
        .padding(.horizontal, Spacing.screen)
    }

    private var statusDotColor: Color {
        switch viewModel.status.severity {
        case .normal:  Color.appSuccess
        case .warning: Color.appWarning
        case .danger:  Color.appDanger
        }
    }

    private var statusForeground: Color {
        switch viewModel.status.severity {
        case .normal:  Color.appSuccessStrong
        case .warning: Color.appWarningStrong
        case .danger:  Color.appDangerStrong
        }
    }

    private var statusTint: Color {
        switch viewModel.status.severity {
        case .normal:  Color.appSuccess.opacity(0.18)
        case .warning: Color.appWarning.opacity(0.18)
        case .danger:  Color.appDanger.opacity(0.18)
        }
    }

    private var crowdCard: some View {
        CMCard {
            HStack(spacing: 14) {
                CrowdBars(level: viewModel.crowdLevel)
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.crowdLevel.label)
                        .font(.appCardTitle)
                        .foregroundStyle(Color.cfTextPrimary)
                    Text("Updated every 10 min by LTA")
                        .font(.appMicro)
                        .foregroundStyle(Color.cfTextTertiary)
                }
                Spacer()
            }
        }
        .padding(.horizontal, Spacing.screen)
    }

    private var liftMaintenanceList: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.liftMaintenance.enumerated()), id: \.element.id) { idx, lift in
                if idx > 0 { Divider().background(Color.cfHairline) }
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.appWarningStrong)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lift.liftDesc)
                            .font(.appBodyMedium)
                            .foregroundStyle(Color.cfTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        if lift.id != "\(station.id)-0" {
                            Text("Lift \(lift.id)")
                                .font(.appMicro)
                                .foregroundStyle(Color.cfTextTertiary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
            }
        }
        .tintedGlassCard(cornerRadius: Radius.card, tint: Color.appWarning.opacity(0.18))
        .padding(.horizontal, Spacing.screen)
    }

    private var lineMap: some View {
        CMCard {
            VStack(alignment: .leading, spacing: 0) {
                Text(station.line.fullName)
                    .font(.appCaptionMedium)
                    .foregroundStyle(Color.cfTextSecondary)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 10)

                directionStrip
                    .padding(.horizontal, 4)
                    .padding(.bottom, 6)

                stationsRow
            }
            .padding(.vertical, 4)
        }
        .padding(.horizontal, Spacing.screen)
        .onAppear { showStations = true }
        .onChange(of: station.id) { _, _ in
            showStations = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.smooth(duration: 0.45)) { showStations = true }
            }
        }
    }

    @ViewBuilder
    private var directionStrip: some View {
        if let termini = MRTStationsRepository.shared.termini(for: station.line) {
            HStack(alignment: .center, spacing: 8) {
                directionPill(text: "to \(termini.toward.name)", systemImage: "arrow.left", side: .leading)
                Spacer(minLength: 8)
                directionPill(text: "to \(termini.fromward.name)", systemImage: "arrow.right", side: .trailing)
            }
        }
    }

    private func directionPill(text: String, systemImage: String, side: HorizontalEdge) -> some View {
        HStack(spacing: 4) {
            if side == .leading {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .bold))
                    .symbolEffect(.pulse, options: .repeating, value: showStations)
                Text(text)
            } else {
                Text(text)
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .bold))
                    .symbolEffect(.pulse, options: .repeating, value: showStations)
            }
        }
        .font(.appMicroStrong)
        .foregroundStyle(station.line.foreground)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .tintedGlassCapsule(tint: station.line.background.opacity(0.6))
    }

    private enum HorizontalEdge { case leading, trailing }

    private var stationsRow: some View {
        let nodes = MRTStationsRepository.shared.neighborhood(around: station, radius: 2)
        let currentIdx = nodes.firstIndex(where: { $0.isCurrent }) ?? 0
        return ZStack(alignment: .top) {
            // Connecting line
            GeometryReader { geo in
                Rectangle()
                    .fill(station.line.background)
                    .frame(width: max(0, geo.size.width - 48), height: 4)
                    .position(x: geo.size.width / 2, y: 18)
            }
            .frame(height: 76)

            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(nodes.enumerated()), id: \.element.station.id) { idx, entry in
                    StationNode(
                        station: entry.station,
                        isCurrent: entry.isCurrent,
                        line: station.line
                    )
                    .frame(maxWidth: .infinity)
                    .opacity(showStations ? 1 : 0)
                    .scaleEffect(showStations ? 1 : 0.85)
                    .animation(
                        .smooth(duration: 0.4)
                            .delay(Double(abs(idx - currentIdx)) * 0.06),
                        value: showStations
                    )
                }
            }
            .padding(.horizontal, 8)
        }
    }

    private var demoFooter: some View {
        HStack(spacing: 6) {
            LiveStatusPill(minutesAgo: 0)
            Text("Live train arrivals, exits and amenities aren't published by LTA.")
                .font(.appMicro)
                .foregroundStyle(Color.cfTextTertiary)
        }
        .padding(.horizontal, Spacing.screen)
    }
}

// MARK: - Station node

private struct StationNode: View {
    let station: MRTStation
    let isCurrent: Bool
    let line: MRTLine

    var body: some View {
        VStack(spacing: 6) {
            marker
            Text(station.name)
                .font(.appMicroStrong)
                .foregroundStyle(isCurrent ? Color.cfTextPrimary : Color.cfTextSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.top, 4)
            Text(station.id + (station.interchangeLines.isEmpty ? "" : " · " + station.interchangeLines.map(\.code).joined(separator: " ")))
                .font(.appMicro)
                .foregroundStyle(Color.cfTextTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var marker: some View {
        if !station.interchangeLines.isEmpty {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.appSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(line.background, lineWidth: 2.5)
                    )
                    .frame(width: 14, height: 22)
                Circle()
                    .fill(station.interchangeLines.first?.background ?? Color.appAmber)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Color.appSurface, lineWidth: 2))
                    .offset(y: 4)
            }
            .frame(height: 26)
        } else if isCurrent {
            Circle()
                .fill(Color.appSurface)
                .overlay(Circle().stroke(line.background, lineWidth: 3))
                .frame(width: 16, height: 16)
                .padding(.top, 10)
                .frame(height: 26, alignment: .center)
        } else {
            Circle()
                .fill(line.background)
                .frame(width: 10, height: 10)
                .padding(.top, 13)
                .frame(height: 26, alignment: .center)
        }
    }
}

