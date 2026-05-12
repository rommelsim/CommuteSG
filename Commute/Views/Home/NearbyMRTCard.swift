import SwiftUI

struct NearbyMRTCard: View {
    let nearby: HomeViewModel.NearbyStation
    let action: () -> Void

    private var walkMinutes: Int {
        StopsAdapters.walkMinutes(forMeters: nearby.station.distanceMeters ?? 0)
    }

    private var lineColor: Color {
        MRTLineToken.from(code: nearby.station.id)?.color ?? .gray
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(nearby.station.id)
                    .font(.system(size: 11, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(lineColor, in: Capsule(style: .continuous))

                Text(nearby.station.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.cfTextPrimary)
                    .lineLimit(1)

                Text("· \(walkMinutes) min walk")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.cfTextTertiary)
                    .lineLimit(1)

                Spacer(minLength: 6)

                if nearby.status.severity != .normal {
                    Image(systemName: nearby.status.severity == .danger
                          ? "exclamationmark.octagon.fill"
                          : "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(nearby.status.severity == .danger
                                         ? Color.appDanger
                                         : Color.appWarning)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.cfTextTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(cornerRadius: 14)
        }
        .buttonStyle(.plain)
    }
}
