import SwiftUI

/// Per `commute-surfaces-v2.html` §4: a 4-bar greyscale signal-strength
/// readout for crowd on route-result cards. Greyscale on purpose — the
/// route card already carries the line colour in its leg chips, so the
/// crowd signal stays neutral. Always labelled "Typical X:XX pm" since
/// the underlying data is historical (LTA Passenger Volume), not live.
struct InlineCrowdStrip: View {
    let crowd: CrowdLevel
    /// Station code the crowd reading is for, e.g. "CC23".
    let stationCode: String

    private var filledCount: Int {
        switch crowd {
        case .seats:    1
        case .standing: 3
        case .limited:  4
        case .unknown:  2
        }
    }

    private var crowdLabel: String {
        switch crowd {
        case .seats:    "Low crowd"
        case .standing: "High crowd"
        case .limited:  "Crowded"
        case .unknown:  "Typical"
        }
    }

    private var isHighIntensity: Bool {
        crowd == .standing || crowd == .limited
    }

    var body: some View {
        HStack(spacing: 6) {
            bars
            Text("\(crowdLabel) · \(stationCode)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.cfTextSecondary)
            Spacer(minLength: 0)
            Text("Typical \(currentHourLabel)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.cfTextTertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.cfTextPrimary.opacity(isHighIntensity ? 0.06 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.cfTextPrimary.opacity(isHighIntensity ? 0.11 : 0.08),
                              lineWidth: 0.5)
        )
        .accessibilityLabel("\(crowdLabel) at \(stationCode), typical for this time")
    }

    private var bars: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                let h: CGFloat = [6, 9, 12, 14][i]
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(barFill(for: i))
                    .frame(width: 4, height: h)
            }
        }
        .frame(height: 14)
    }

    private func barFill(for i: Int) -> Color {
        guard i < filledCount else { return Color.cfTextPrimary.opacity(0.15) }
        return Color.cfTextPrimary.opacity(isHighIntensity ? 0.85 : 0.35)
    }

    private var currentHourLabel: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: Date())
    }
}
