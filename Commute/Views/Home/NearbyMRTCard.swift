import SwiftUI

/// Compact MRT row in the "Nearby transit" area. White-glass card with
/// station name + walk distance + station code pill (uses MRT line color),
/// hairline divider, then status row + crowd pill. Tap opens detail sheet.
struct NearbyMRTCard: View {
    let nearby: HomeViewModel.NearbyStation
    let action: () -> Void

    private var walkMinutes: Int {
        StopsAdapters.walkMinutes(forMeters: nearby.station.distanceMeters ?? 0)
    }

    private var lineColor: Color {
        // Use the new authentic palette via MRTLineToken
        MRTLineToken.from(code: nearby.station.id)?.color ?? .gray
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "tram.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.cfTextSecondary)
                    Text(nearby.station.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.cfTextPrimary)
                        .lineLimit(1)
                    Text("· \(walkMinutes) min walk")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.cfTextTertiary)
                    Spacer(minLength: 8)
                    stationCodePill
                }

                Divider()
                    .background(Color.cfChipFill)
                    .padding(.vertical, 10)

                HStack {
                    statusRow
                    Spacer()
                    crowdPill
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }

    private var stationCodePill: some View {
        Text(nearby.station.id)
            .font(.system(size: 11, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(lineColor, in: Capsule(style: .continuous))
    }

    private var statusRow: some View {
        HStack(spacing: 6) {
            Image(systemName: statusSymbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(statusColor)
            Text(statusText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.cfTextSecondary)
                .lineLimit(1)
        }
    }

    private var crowdPill: some View {
        HStack(spacing: 6) {
            // Mock moderate density — real density comes from
            // MRTStationDetailViewModel.crowdLevel which is fetched on
            // entering the detail screen, not on home.
            CrowdPeople(level: .med, size: 10)
            Text("Moderate")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.cfTextSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.cfHairline, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var statusSymbol: String {
        switch nearby.status.severity {
        case .normal:  "checkmark"
        case .warning: "exclamationmark.triangle.fill"
        case .danger:  "exclamationmark.octagon.fill"
        }
    }

    private var statusColor: Color {
        switch nearby.status.severity {
        case .normal:  Color.cfStatusOk
        case .warning: Color.appWarning
        case .danger:  Color.appDanger
        }
    }

    private var statusText: String {
        // Compact "EWL running normally"-style status; falls back to the
        // long status message for warning/danger.
        switch nearby.status.severity {
        case .normal:
            let prefix = String(nearby.station.id.prefix { $0.isLetter }).uppercased()
            return "\(prefix)L running normally"
        case .warning, .danger:
            return nearby.status.message
        }
    }
}
