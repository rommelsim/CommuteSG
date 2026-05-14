import ActivityKit
import SwiftUI
import WidgetKit

/// Train-arrival Live Activity. Compact + minimal in the Dynamic Island,
/// expanded on long-press, and a dark-card lock-screen view with the next
/// arrival hero plus a crowd pip strip.
struct TrainArrivalLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrainArrivalActivity.self) { context in
            TrainLockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.78))
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 10) {
                        MRTLinePillDynamic(code: context.attributes.stationCode)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Towards \(context.attributes.towardsDestination)")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(1)
                            Text("\(context.attributes.stationName) · \(context.attributes.lineName)")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.45))
                                .lineLimit(1)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: "tram")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.55))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        TrainArrivalChip(minutes: context.state.nextMinutes, isNext: true)
                        ForEach(Array(context.state.followingMinutes.prefix(2).enumerated()), id: \.offset) { _, m in
                            TrainArrivalChip(minutes: m, isNext: false)
                        }
                        Spacer()
                        CrowdPipsView(level: context.state.crowdLevel)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                MRTLinePillDynamic(code: context.attributes.stationCode)
            } compactTrailing: {
                Text("\(context.state.nextMinutes)m")
                    .font(.caption).fontWeight(.bold).monospacedDigit()
                    .foregroundStyle(LATheme.liveGreen)
            } minimal: {
                Text("\(context.state.nextMinutes)")
                    .font(.caption2).fontWeight(.bold).monospacedDigit()
                    .foregroundStyle(LATheme.liveGreen)
            }
        }
    }
}

private struct TrainLockScreenView: View {
    let attributes: TrainArrivalActivity
    let state: TrainArrivalActivity.State

    var body: some View {
        HStack(spacing: 14) {
            MRTLinePillDynamic(code: attributes.stationCode)
                .scaleEffect(1.1)

            VStack(alignment: .leading, spacing: 3) {
                Text("Commute · Live")
                    .font(.caption2).foregroundStyle(.white.opacity(0.45))
                Text("Towards \(attributes.towardsDestination)")
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                Text("\(attributes.stationName) · \(attributes.lineName)")
                    .font(.caption2).foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(state.nextMinutes)")
                    .font(.largeTitle).fontWeight(.bold).monospacedDigit()
                    .foregroundStyle(LATheme.liveGreen)
                Text("min")
                    .font(.caption2).foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

struct TrainArrivalChip: View {
    let minutes: Int
    let isNext: Bool
    var body: some View {
        VStack(spacing: 2) {
            Text(isNext ? "Next" : "Then")
                .font(.system(size: 8))
                .foregroundStyle(.white.opacity(0.4))
            Text("\(minutes)m")
                .font(.caption).fontWeight(.bold).monospacedDigit()
                .foregroundStyle(isNext ? LATheme.liveGreen : .white.opacity(0.65))
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(isNext ? LATheme.liveGreen.opacity(0.15) : Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

struct CrowdPipsView: View {
    let level: TrainArrivalActivity.CrowdLevel

    private var filledCount: Int {
        switch level {
        case .low: 1
        case .moderate: 2
        case .high: 3
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Text("Crowd")
                .font(.caption2).foregroundStyle(.white.opacity(0.35))
            HStack(spacing: 2) {
                ForEach(0..<3) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < filledCount ? Color.white.opacity(0.7) : Color.white.opacity(0.12))
                        .frame(width: 10, height: 10)
                }
            }
            Text(level.rawValue.capitalized)
                .font(.caption2).foregroundStyle(.white.opacity(0.45))
        }
    }
}

struct MRTLinePillDynamic: View {
    let code: String
    var body: some View {
        Text(code)
            .font(.caption).fontWeight(.bold)
            .foregroundStyle(.white)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(LATheme.lineColor(for: code))
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}
