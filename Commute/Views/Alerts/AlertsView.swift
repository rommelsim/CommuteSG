import SwiftUI

struct AlertsView: View {
    /// Owned and refreshed by `MainTabView` so the tab-bar badge can read the
    /// live disruption count without us needing a separate copy.
    let viewModel: AlertsViewModel

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
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("MRT alerts")
                    .font(.appTitle)
                    .tracking(-0.5)
                    .foregroundStyle(Color.appText)
                if let updated = viewModel.lastUpdated {
                    Text("Updated \(Self.timeFormatter.string(from: updated))")
                        .font(.appMicro)
                        .foregroundStyle(Color.appText3)
                }
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
                        LineStatusRow(
                            line: line,
                            disruption: viewModel.disruptions.first { $0.line == line }
                        )
                        if idx != viewModel.orderedLines.count - 1 {
                            Divider()
                                .background(Color.appBorder)
                                .padding(.leading, 60)
                        }
                    }
                }
                .background(Color.appSurface2)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .stroke(Color.appBorder, lineWidth: 0.5)
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
            .foregroundStyle(Color.appText3)
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
        .foregroundStyle(Color.appText3)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                LineBadge(line: line, code: nil, emphasized: false)
                Text(line.fullName)
                    .font(.appBodyMedium)
                    .foregroundStyle(Color.appText)
                Spacer()
                statusPill
            }
            if let disruption {
                disruptionDetail(disruption)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
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

    private func disruptionDetail(_ d: AlertsViewModel.LineDisruption) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !d.stations.isEmpty {
                Text("Affected: \(d.stations)")
                    .font(.appCaption)
                    .foregroundStyle(Color.appDangerStrong)
            }
            if let bus = d.freePublicBus {
                Text("Free bus boarding at: \(bus)")
                    .font(.appCaption)
                    .foregroundStyle(Color.appText2)
            }
            if let shuttle = d.freeMRTShuttle {
                Text("Free shuttle: \(shuttle)")
                    .font(.appCaption)
                    .foregroundStyle(Color.appText2)
            }
        }
        .padding(.leading, 44)
    }
}
