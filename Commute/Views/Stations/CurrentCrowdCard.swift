import SwiftUI

/// "Now at <code>" card — second section of the Station Browser.
/// Renders the user's current station's live crowd reading:
/// big station name, line name underneath, the 30pt crowd word,
/// a 5-pip bar, and an advice line.
///
/// Smooth value transitions per the handoff: word + advice fade
/// (0.4s ease), pips ease-out colour + spring height (0.7s).
struct CurrentCrowdCard: View {
    let snapshot: StationCrowdSnapshot

    private let pipHeights: [CGFloat] = [6, 9, 12, 15, 18]

    private var tier: CrowdTier { snapshot.currentTier }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Text(snapshot.stationName)
                .font(.system(size: 26, weight: .semibold))
                .tracking(-0.5)
                .foregroundStyle(Color.cfTextPrimary)
            Text(snapshot.line.fullName)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.cfTextSecondary)
                .padding(.bottom, 10)

            feelRow
                .padding(.bottom, 8)

            Text(tier.advice)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.cfTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .id(tier)
                .transition(.opacity)

        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.cfHairline, lineWidth: 0.5)
        )
    }

    private var header: some View {
        HStack {
            Text("Now at \(snapshot.stationCode)")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.7)
                .textCase(.uppercase)
                .foregroundStyle(Color.cfTextTertiary)
            Spacer()
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.appSuccess)
                    .frame(width: 6, height: 6)
                Text("Live")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Color.cfTextTertiary)
            }
        }
        .padding(.bottom, 4)
    }

    private var feelRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(tier.word)
                .font(.system(size: 30, weight: .semibold))
                .tracking(-0.4)
                .foregroundStyle(feelColor)
                .id(tier)
                .transition(.opacity)
            Spacer()
            pipBar
        }
        .animation(.easeOut(duration: 0.7), value: tier)
    }

    private var pipBar: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(i < tier.litPipCount ? feelColor : Color.cfTextPrimary.opacity(0.10))
                    .frame(width: 5, height: pipHeights[i])
            }
        }
        .animation(.easeOut(duration: 0.7), value: tier)
    }

    /// Tier → colour mapping. Uses semantic app tokens so light + dark
    /// modes work without bespoke overrides.
    private var feelColor: Color {
        switch tier {
        case .low:      Color.appSuccess
        case .moderate: Color.cfTextPrimary
        case .busy:     Color.appDanger
        case .unknown:  Color.cfTextTertiary
        }
    }
}

#if DEBUG
#Preview("Current crowd · Busy") {
    CurrentCrowdCard(
        snapshot: StationCrowdSnapshot(
            stationCode: "CC23",
            stationName: "one-north",
            line: .cc,
            currentTier: .busy,
            forecast: []
        )
    )
    .padding(16)
    .background(Color.cfPageBackground)
}
#endif
