import Foundation

/// Fixture-only fare spend history used to populate `MyCommuteSpendView`.
/// Real data here requires SimplyGo / EZ-Link auth (handoff open question #1).
/// Until that lands, the screen runs against this hardcoded six-month window.
struct MockSpendData {
    struct Month: Identifiable, Hashable {
        let id = UUID()
        let label: String          // "Dec", "Jan", ...
        let totalCents: Int
        let tripCount: Int
        let isCurrent: Bool
    }

    let months: [Month]
    /// Days elapsed in the current month, used in the hero.
    let daysIntoMonth: Int
    /// Pre-peak-eligible trips identified in the current month — driver of
    /// the amber callout. Zero hides the callout.
    let prePeakEligibleTrips: Int
    let prePeakWeeklySavingCents: Int
    /// Optional projection for end-of-month total based on current pace.
    let projectionCents: Int
    let projectionWithPrePeakCents: Int

    var currentMonth: Month { months.last! }
    var previousMonth: Month? { months.dropLast().last }

    static let fixture: MockSpendData = .init(
        months: [
            .init(label: "Dec", totalCents: 4280, tripCount: 38, isCurrent: false),
            .init(label: "Jan", totalCents: 4760, tripCount: 42, isCurrent: false),
            .init(label: "Feb", totalCents: 4520, tripCount: 40, isCurrent: false),
            .init(label: "Mar", totalCents: 5180, tripCount: 46, isCurrent: false),
            .init(label: "Apr", totalCents: 5460, tripCount: 48, isCurrent: false),
            .init(label: "May", totalCents: 3120, tripCount: 28, isCurrent: true)
        ],
        daysIntoMonth: 13,
        prePeakEligibleTrips: 4,
        prePeakWeeklySavingCents: 192,
        projectionCents: 5780,
        projectionWithPrePeakCents: 4920
    )
}
