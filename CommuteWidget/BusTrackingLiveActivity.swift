import SwiftUI
import WidgetKit
import ActivityKit

/// Live Activity surface — Lock Screen card + Dynamic Island compact /
/// expanded / minimal presentations. Uses the shared `BusTrackingActivity`
/// attributes (the source file is added to both the main app target and
/// this widget extension target via Target Membership).
struct BusTrackingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BusTrackingActivity.self) { context in
            // Lock Screen + Notification banner.
            LockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.7))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.attributes.serviceNo)
                            .font(.system(size: 18, weight: .bold))
                    } icon: {
                        Image(systemName: "bus.fill")
                            .foregroundStyle(.blue)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Label {
                        Text(etaText(context.state.etaMinutes))
                            .font(.system(size: 18, weight: .semibold))
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "clock")
                            .foregroundStyle(.blue)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.secondary)
                        Text("To \(context.attributes.stopName)")
                            .font(.system(size: 13))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        crowdPill(context.state.crowdLevel)
                    }
                }
            } compactLeading: {
                Image(systemName: "bus.fill")
                    .foregroundStyle(.blue)
            } compactTrailing: {
                Text(etaText(context.state.etaMinutes))
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "bus.fill")
                    .foregroundStyle(.blue)
            }
            .keylineTint(.blue)
        }
    }

    private func etaText(_ minutes: Int?) -> String {
        guard let m = minutes else { return "—" }
        if m == 0 { return "Arr" }
        return "\(m) min"
    }

    @ViewBuilder
    private func crowdPill(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(crowdColor(label).opacity(0.18))
            .foregroundStyle(crowdColor(label))
            .clipShape(Capsule())
    }

    private func crowdColor(_ label: String) -> Color {
        switch label.lowercased() {
        case "seats":          .green
        case "standing":       .orange
        case "limited":        .red
        default:               .gray
        }
    }
}

// MARK: - Lock Screen view

private struct LockScreenView: View {
    let context: ActivityViewContext<BusTrackingActivity>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.blue)
                        .frame(width: 36, height: 36)
                    Image(systemName: "bus.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bus \(context.attributes.serviceNo)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Text("To \(context.attributes.stopName)")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
                Spacer()
                liveDot
            }

            HStack(alignment: .lastTextBaseline) {
                Text(etaPrimary)
                    .font(.system(size: 36, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text(etaUnit)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                crowdBadge
            }

            HStack(spacing: 4) {
                Text("Updated")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
                Text(context.state.lastUpdated, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(14)
    }

    private var etaPrimary: String {
        guard let m = context.state.etaMinutes else { return "—" }
        if m == 0 { return "Arr" }
        return "\(m)"
    }

    private var etaUnit: String {
        guard let m = context.state.etaMinutes, m > 0 else { return "" }
        return "min"
    }

    private var liveDot: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(context.state.isLive ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
            Text(context.state.isLive ? "Live" : "Demo")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var crowdBadge: some View {
        Text(context.state.crowdLevel)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.2))
            .clipShape(Capsule())
    }
}
