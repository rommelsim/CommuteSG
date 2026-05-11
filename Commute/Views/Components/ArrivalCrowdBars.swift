import SwiftUI

/// A 3-bar mini gauge that mirrors how full a bus is. Lives in the corner of
/// `ArrivalPill` so the colour-coded crowd state has a redundant non-color
/// channel for accessibility / colour-blind users.
///
/// Named `ArrivalCrowdBars` (not `CrowdBars`) because `CrowdIndicator.swift`
/// already has a `CrowdBars` for the larger MRT-station crowd display, which
/// takes a different enum (`StationCrowdLevel`).
///
/// Filled bars by level:
/// - `.seats`    → 1 (smallest only)
/// - `.standing` → 2
/// - `.limited`  → 3
/// - `.unknown`  → 0 (all rendered at 35% opacity)
struct ArrivalCrowdBars: View {
    let level: CrowdLevel
    let color: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 1) {
            bar(height: 3, isFilled: level != .unknown)
            bar(height: 5, isFilled: level == .standing || level == .limited)
            bar(height: 7, isFilled: level == .limited)
        }
        .frame(height: 7, alignment: .bottom)
    }

    private func bar(height: CGFloat, isFilled: Bool) -> some View {
        RoundedRectangle(cornerRadius: 0.5)
            .fill(isFilled ? color : color.opacity(0.35))
            .frame(width: 1.5, height: height)
    }
}
