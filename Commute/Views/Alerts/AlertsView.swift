import SwiftUI

struct AlertsView: View {
    /// Owned and refreshed by `MainTabView` so the tab-bar badge can read the
    /// live disruption count without us needing a separate copy.
    let viewModel: AlertsViewModel

    /// Line the user tapped — drives the detail sheet.
    @State private var selectedLine: SelectedLine?

    /// Identifiable wrapper so `.sheet(item:)` works.
    private struct SelectedLine: Identifiable {
        let line: MRTLine
        let disruption: AlertsViewModel.LineDisruption?
        var id: String { line.code }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    lineStatusSection
                    if !viewModel.alerts.isEmpty {
                        activeAlertsSection
                    } else if viewModel.dataMode == .live {
                        allClearBanner
                    }
                    if viewModel.dataMode == .live {
                        sourceFootnote
                    }
                }
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(Color.appSurface)
            .refreshable { await viewModel.refresh(force: true) }
            .task { await viewModel.refresh() }
            .sheet(item: $selectedLine) { selected in
                LineStatusDetailSheet(line: selected.line, disruption: selected.disruption)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                // Title scoped to MRT — the data source (LTA's
                // TrainServiceAlerts endpoint) only covers train lines, so
                // saying "Alerts" alone misleads users into expecting bus
                // disruptions too. "Train service" makes the scope explicit.
                Text("Train service")
                    .font(.appTitle)
                    .tracking(-0.5)
                    .foregroundStyle(Color.cfTextPrimary)
                Text(headerSubtitle)
                    .font(.appMicro)
                    .foregroundStyle(Color.cfTextTertiary)
            }
            Spacer()
            LiveBadge(
                mode: viewModel.dataMode == .live ? .live : .demo,
                lastUpdated: viewModel.lastUpdated
            )
        }
        .padding(.top, 10)
        .padding(.horizontal, Spacing.screen)
    }

    private var headerSubtitle: String {
        if let updated = viewModel.lastUpdated {
            return "MRT line status · updated \(Self.timeFormatter.string(from: updated))"
        }
        return "MRT line status"
    }

    // MARK: - Line status grid

    private var lineStatusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Line status")
            // First load with no cached snapshot → show shimmering skeleton
            // rows so the user sees the section's shape immediately.
            if viewModel.isLoading && viewModel.disruptions.isEmpty && viewModel.alerts.isEmpty {
                LineStatusSkeleton()
                    .padding(.horizontal, Spacing.screen)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.orderedLines.enumerated()), id: \.offset) { idx, line in
                        let dis = viewModel.disruptions.first { $0.line == line }
                        Button {
                            selectedLine = SelectedLine(line: line, disruption: dis)
                        } label: {
                            LineStatusRow(line: line, disruption: dis)
                        }
                        .buttonStyle(CardButtonStyle(pressedScale: 0.985))
                        if idx != viewModel.orderedLines.count - 1 {
                            Divider()
                                .background(Color.cfHairline)
                                .padding(.leading, 60)
                        }
                    }
                }
                .background(Color.appSurface2)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .stroke(Color.cfHairline, lineWidth: 0.5)
                )
                .padding(.horizontal, Spacing.screen)
            }
        }
    }

    // MARK: - Active alerts

    private var activeAlertsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Active disruptions")
            VStack(spacing: 12) {
                ForEach(viewModel.alerts) { item in
                    AlertCard(item: item)
                }
            }
            .padding(.horizontal, Spacing.screen)
        }
    }

    // MARK: - All-clear banner (no disruptions, live data)

    private var allClearBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.appSuccess)
            VStack(alignment: .leading, spacing: 2) {
                Text("All MRT lines running normally")
                    .font(.appBodyMedium)
                    .foregroundStyle(Color.appSuccessStrong)
                Text("No active disruptions reported.")
                    .font(.appCaption)
                    .foregroundStyle(Color.appSuccessStrong.opacity(0.85))
            }
            Spacer()
        }
        .padding(Spacing.cardInner)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSuccessBg)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .padding(.horizontal, Spacing.screen)
    }

    // MARK: - Pieces

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.appCaptionStrong)
            .foregroundStyle(Color.cfTextTertiary)
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.horizontal, Spacing.screen)
    }

    private var sourceFootnote: some View {
        HStack(spacing: 6) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 10, weight: .medium))
            Text("Source: LTA DataMall · TrainServiceAlerts")
                .font(.appMicro)
        }
        .foregroundStyle(Color.cfTextTertiary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.screen)
        .padding(.top, 4)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()
}

// MARK: - Line status row

private struct LineStatusRow: View {
    let line: MRTLine
    let disruption: AlertsViewModel.LineDisruption?

    private var isDisrupted: Bool { disruption != nil }

    var body: some View {
        HStack(spacing: 12) {
            LineBadge(line: line, code: nil, emphasized: false)
            VStack(alignment: .leading, spacing: 2) {
                Text(line.fullName)
                    .font(.appBodyMedium)
                    .foregroundStyle(Color.cfTextPrimary)
                if let stations = disruption?.stations, !stations.isEmpty {
                    Text("Affected: \(stations)")
                        .font(.appMicro)
                        .foregroundStyle(Color.cfTextTertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
            statusPill
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.cfTextMuted)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
    }

    private var statusPill: some View {
        HStack(spacing: 4) {
            Image(systemName: isDisrupted ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 10, weight: .bold))
                .contentTransition(.symbolEffect(.replace.downUp))
            Text(isDisrupted ? "Delays" : "Normal")
                .font(.appMicroStrong)
                .contentTransition(.opacity)
        }
        .foregroundStyle(isDisrupted ? Color.appDanger : Color.appSuccess)
        .animation(.snappy, value: isDisrupted)
    }
}

// MARK: - Line status detail sheet
// Tapping any line row presents this. For disrupted lines it shows the
// affected stations + alternative transport (free bus / shuttle). For
// normal lines it confirms "All clear" so the tap isn't a dead-end.

private struct LineStatusDetailSheet: View {
    let line: MRTLine
    let disruption: AlertsViewModel.LineDisruption?
    @Environment(\.dismiss) private var dismiss

    private var isDisrupted: Bool { disruption != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard
                    if let disruption {
                        disruptionDetailCard(disruption)
                    } else {
                        allClearCard
                    }
                    Spacer(minLength: 12)
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.top, 16)
            }
            .background(Color.appSurface)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.appInfo)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var headerCard: some View {
        HStack(spacing: 14) {
            LineBadge(line: line, code: nil, emphasized: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(line.fullName)
                    .font(.appSubTitle)
                    .foregroundStyle(Color.cfTextPrimary)
                Text(isDisrupted ? "Service disruption in effect" : "Normal service")
                    .font(.appCaption)
                    .foregroundStyle(isDisrupted ? Color.appDangerStrong : Color.appSuccessStrong)
            }
            Spacer()
        }
    }

    private var allClearCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.appSuccess)
            VStack(alignment: .leading, spacing: 2) {
                Text("All stations operating normally")
                    .font(.appBodyMedium)
                    .foregroundStyle(Color.appSuccessStrong)
                Text("No active disruptions reported by LTA on this line.")
                    .font(.appCaption)
                    .foregroundStyle(Color.appSuccessStrong.opacity(0.85))
            }
            Spacer()
        }
        .padding(Spacing.cardInner)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSuccessBg)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private func disruptionDetailCard(_ d: AlertsViewModel.LineDisruption) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if !d.stations.isEmpty {
                detailRow(
                    icon: "exclamationmark.triangle.fill",
                    iconColor: Color.appDanger,
                    label: "Affected stations",
                    value: d.stations
                )
            }
            if let bus = d.freePublicBus {
                detailRow(
                    icon: "bus.fill",
                    iconColor: Color.appInfo,
                    label: "Free public bus",
                    value: bus
                )
            }
            if let shuttle = d.freeMRTShuttle {
                detailRow(
                    icon: "tram.fill",
                    iconColor: Color.appInfo,
                    label: "Free MRT shuttle",
                    value: shuttle
                )
            }
        }
        .padding(Spacing.cardInner)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appDangerBg)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private func detailRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.appMicroStrong)
                    .textCase(.uppercase)
                    .tracking(0.4)
                    .foregroundStyle(Color.cfTextTertiary)
                Text(value)
                    .font(.appBodyMedium)
                    .foregroundStyle(Color.cfTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }
}
