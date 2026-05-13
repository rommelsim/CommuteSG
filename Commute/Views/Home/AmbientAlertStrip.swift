import SwiftUI

/// Slim, ambient disruption pill shown on Home only when at least one MRT
/// line is currently affected. Hidden entirely (zero vertical space) when all
/// lines are normal — per the unified-nav handoff this replaces the standalone
/// Alerts tab as a contextual surface rather than a destination.
struct AmbientAlertStrip: View {
    let disruption: AlertsViewModel.LineDisruption
    let extraCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                LineBadge(line: disruption.line)
                VStack(alignment: .leading, spacing: 2) {
                    Text(headline)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.cfTextPrimary)
                        .lineLimit(1)
                    if extraCount > 0 {
                        Text("+\(extraCount) more line\(extraCount == 1 ? "" : "s") affected")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.cfTextSecondary)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.cfTextSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.appDangerBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.appDanger.opacity(0.25), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(disruption.line.fullName) disruption")
        .accessibilityHint("Opens line status")
    }

    private var headline: String {
        let stations = disruption.stations
        if stations.isEmpty {
            return "Delays on \(disruption.line.fullName)"
        }
        return "Delays between \(stations)"
    }
}
