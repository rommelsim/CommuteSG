import SwiftUI

/// Home-screen nearby MRT card. CM design language (CMCard + MRTLinePill +
/// WalkDistanceLabel). Preserves the line-status row from the old card so
/// "Delays on East-West Line" stays glanceable on Home.
struct NearbyMRTCard: View {
    let nearby: HomeViewModel.NearbyStation
    let action: () -> Void

    private var walkMinutes: Int {
        StopsAdapters.walkMinutes(forMeters: nearby.station.distanceMeters ?? 0)
    }

    private var codes: [String] {
        StopsAdapters.codes(for: nearby.station)
    }

    var body: some View {
        Button(action: action) {
            CMCard {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(nearby.station.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        WalkDistanceLabel(
                            walkMinutes: walkMinutes,
                            meters: nearby.station.distanceMeters ?? 0
                        )
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(codes, id: \.self) { code in
                            MRTLinePill(code: code)
                        }
                    }
                }

                Divider()
                    .padding(.top, 12)

                HStack(spacing: 6) {
                    Image(systemName: statusSymbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(statusColor)
                    Text(nearby.status.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.top, 12)
            }
        }
        .buttonStyle(.plain)
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
        case .normal:  Color.cmLive
        case .warning: Color.appWarning
        case .danger:  Color.appDanger
        }
    }
}
