import SwiftUI

/// Score footer for a route result card: three labeled sub-score bars on the
/// left, an overall score ring on the right. Color tier on the ring (and the
/// tier headline) telegraphs how the route ranks at a glance.
struct CommuteScoreFooter: View {
    let score: CommuteScore

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                bar(label: "Time",  value: score.time,  color: Self.timeColor)
                bar(label: "Crowd", value: score.crowd, color: Self.crowdColor)
                bar(label: "Cost",  value: score.cost,  color: Self.costColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 2) {
                ScoreRing(score: score.overall, color: ringColor)
                    .frame(width: 44, height: 44)
                Text(score.tierHeadline)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.cfTextSecondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .frame(maxWidth: 110)
            }
        }
        .padding(.top, 4)
    }

    private func bar(label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.cfTextSecondary)
                .frame(width: 36, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.cfHairline)
                        .frame(height: 4)
                    Capsule()
                        .fill(color)
                        .frame(width: max(2, geo.size.width * CGFloat(value) / 100), height: 4)
                }
            }
            .frame(height: 4)
            Text("\(value)")
                .font(.system(size: 10, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color.cfTextPrimary)
                .frame(width: 22, alignment: .trailing)
        }
    }

    private var ringColor: Color {
        switch score.tier {
        case .excellent: Color(red: 0.08, green: 0.72, blue: 0.65)  // teal
        case .good:      Color(red: 0.39, green: 0.40, blue: 0.95)  // indigo
        case .fair:      Color(red: 0.96, green: 0.62, blue: 0.04)  // amber
        case .poor:      Color(red: 0.86, green: 0.20, blue: 0.20)  // red
        }
    }

    static let timeColor  = Color(red: 0.23, green: 0.51, blue: 0.96)  // blue
    static let crowdColor = Color(red: 0.13, green: 0.77, blue: 0.37)  // green
    static let costColor  = Color(red: 0.96, green: 0.62, blue: 0.04)  // amber
}

private struct ScoreRing: View {
    let score: Int
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.cfHairline, lineWidth: 4)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.snappy, value: score)
            Text("\(score)")
                .font(.system(size: 13, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color.cfTextPrimary)
                .contentTransition(.numericText())
                .animation(.snappy, value: score)
        }
    }
}
