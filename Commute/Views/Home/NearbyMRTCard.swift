import SwiftUI

struct NearbyMRTCard: View {
    let nearby: HomeViewModel.NearbyStation
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.s8) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.s8) {
                    LineBadge(line: nearby.station.line, code: nearby.station.id)
                        .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] + 4 }
                    Text("\(nearby.station.name) MRT")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.appText)
                    Spacer(minLength: Spacing.s8)
                    if let d = nearby.station.distanceMeters {
                        Text("\(d)m")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.appText3)
                    }
                }
                HStack(spacing: 6) {
                    Image(systemName: statusSymbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(statusColor)
                    Text(nearby.status.message)
                        .font(.system(size: 12))
                        .foregroundStyle(statusColor)
                        .lineLimit(2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: Radius.card)
        }
        .buttonStyle(CardButtonStyle())
    }

    private var statusSymbol: String {
        switch nearby.status.severity {
        case .normal:  "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .danger:  "exclamationmark.octagon.fill"
        }
    }

    private var statusColor: Color {
        switch nearby.status.severity {
        case .normal:  Color.appSuccess
        case .warning: Color.appWarning
        case .danger:  Color.appDanger
        }
    }
}
