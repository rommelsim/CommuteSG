import SwiftUI

/// Personal spend dashboard for fare visibility. Runs against
/// `MockSpendData.fixture` until SimplyGo / EZ-Link integration is wired up
/// (handoff open question #1). All layout matches the advocate-feature spec.
struct MyCommuteSpendView: View {
    private let data = MockSpendData.fixture
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero
                chartCard
                prePeakCallout
                insights
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Color.cfPageBackground.ignoresSafeArea())
        .navigationTitle("My commute spend")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("This month")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Color.white.opacity(0.65))
            Text(format(data.currentMonth.totalCents))
                .font(.system(size: 40, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color.white)
            Text("\(data.currentMonth.tripCount) trips · day \(data.daysIntoMonth)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.75))

            HStack(spacing: 10) {
                statTile(label: "vs last month",
                         value: vsLastMonthString,
                         tint: vsLastMonthIsUp ? Color(red: 0.96, green: 0.62, blue: 0.04) : Color(red: 0.13, green: 0.77, blue: 0.37))
                statTile(label: "potential savings",
                         value: format(data.prePeakWeeklySavingCents * 4),
                         tint: Color(red: 0.13, green: 0.77, blue: 0.37))
            }
            .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var heroGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.05, green: 0.08, blue: 0.27),
                     Color(red: 0.12, green: 0.23, blue: 0.54),
                     Color(red: 0.11, green: 0.30, blue: 0.82)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var vsLastMonthIsUp: Bool {
        guard let prev = data.previousMonth else { return false }
        return data.currentMonth.totalCents > prev.totalCents
    }

    private var vsLastMonthString: String {
        guard let prev = data.previousMonth else { return "—" }
        let diff = data.currentMonth.totalCents - prev.totalCents
        let arrow = diff >= 0 ? "▲" : "▼"
        return "\(arrow) \(format(abs(diff)))"
    }

    private func statTile(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.7))
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Last 6 months")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.cfTextPrimary)
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(data.months) { m in
                    monthBar(m)
                }
            }
            .frame(height: 110)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func monthBar(_ m: MockSpendData.Month) -> some View {
        let maxCents = data.months.map(\.totalCents).max() ?? 1
        let h = max(8, CGFloat(m.totalCents) / CGFloat(maxCents) * 90)
        return VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(m.isCurrent
                      ? Color(red: 0.23, green: 0.51, blue: 0.96)
                      : Color.cfHairlineStrong)
                .frame(height: h)
                .frame(maxWidth: .infinity)
            Text(m.label)
                .font(.system(size: 10, weight: m.isCurrent ? .bold : .medium))
                .foregroundStyle(m.isCurrent ? Color.cfTextPrimary : Color.cfTextSecondary)
        }
    }

    // MARK: - Pre-peak callout

    @ViewBuilder
    private var prePeakCallout: some View {
        if data.prePeakEligibleTrips > 0 {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sunrise.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 0.96, green: 0.62, blue: 0.04))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shift \(data.prePeakEligibleTrips) trips to pre-peak")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.cfTextPrimary)
                    Text("Tap in before 7:45 am on weekdays to save automatically.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.cfTextSecondary)
                }
                Spacer(minLength: 8)
                Text("~\(format(data.prePeakWeeklySavingCents)) / wk")
                    .font(.system(size: 11, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Color(red: 0.96, green: 0.62, blue: 0.04))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.96, green: 0.62, blue: 0.04).opacity(0.15),
                                in: Capsule())
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 0.96, green: 0.62, blue: 0.04).opacity(0.10))
            )
        }
    }

    // MARK: - Insights

    private var insights: some View {
        VStack(spacing: 10) {
            insightCard(
                tint: Color(red: 0.13, green: 0.77, blue: 0.37),
                symbol: "leaf.fill",
                title: "Saving tip",
                body: "Switch your Mon / Wed / Fri morning trips to pre-peak to save ~\(format(data.prePeakWeeklySavingCents)) per week."
            )
            insightCard(
                tint: Color(red: 0.96, green: 0.62, blue: 0.04),
                symbol: "exclamationmark.triangle.fill",
                title: "Heads up",
                body: "Fares are up 4% since the December PTC revision — your monthly average is trending higher."
            )
            insightCard(
                tint: Color(red: 0.23, green: 0.51, blue: 0.96),
                symbol: "chart.line.uptrend.xyaxis",
                title: "Projection",
                body: "On track for ~\(format(data.projectionCents)) this month. With pre-peak switches: ~\(format(data.projectionWithPrePeakCents))."
            )
        }
    }

    private func insightCard(tint: Color, symbol: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.cfTextPrimary)
                Text(body)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.cfTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tint.opacity(0.25), lineWidth: 0.5)
        )
    }

    // MARK: - Helpers

    private func format(_ cents: Int) -> String {
        String(format: "$%.2f", Double(cents) / 100.0)
    }
}
