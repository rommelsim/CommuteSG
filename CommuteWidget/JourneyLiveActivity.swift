import ActivityKit
import SwiftUI
import WidgetKit

/// Multi-leg journey Live Activity. Compact = current-leg mode glyph + minutes
/// remaining; expanded = current leg, total time, and a peek of the next leg.
struct JourneyLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: JourneyActivity.self) { context in
            JourneyLockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.78))
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("To \(context.attributes.destinationName)")
                            .font(.caption2).foregroundStyle(.white.opacity(0.5))
                        Text(context.state.currentLeg.actionText)
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundStyle(.white).lineLimit(1)
                        if let detail = context.state.currentLeg.detailText {
                            Text(detail)
                                .font(.caption2).foregroundStyle(.white.opacity(0.55))
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(context.state.totalMinutesRemaining)")
                            .font(.title2).fontWeight(.bold).monospacedDigit()
                            .foregroundStyle(.white)
                        Text("min left")
                            .font(.caption2).foregroundStyle(.white.opacity(0.45))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if let next = context.state.nextLeg {
                            Text("Then: \(next.actionText)")
                                .font(.caption2).foregroundStyle(.white.opacity(0.5))
                                .lineLimit(1)
                        } else {
                            Text("Final leg")
                                .font(.caption2).foregroundStyle(.white.opacity(0.4))
                        }
                        Spacer()
                        Text("Arrive \(context.state.arrivalClockTime, format: .dateTime.hour().minute())")
                            .font(.caption2).foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: legSymbol(context.state.currentLeg.mode))
                    .font(.caption).foregroundStyle(.white)
            } compactTrailing: {
                Text("\(context.state.totalMinutesRemaining)m")
                    .font(.caption).fontWeight(.bold).monospacedDigit()
                    .foregroundStyle(.white)
            } minimal: {
                Text("\(context.state.totalMinutesRemaining)")
                    .font(.caption2).fontWeight(.bold).monospacedDigit()
                    .foregroundStyle(.white)
            }
        }
    }

    private func legSymbol(_ mode: JourneyActivity.Mode) -> String {
        switch mode {
        case .bus: "bus"
        case .train: "tram"
        case .walk: "figure.walk"
        }
    }
}

private struct JourneyLockScreenView: View {
    let attributes: JourneyActivity
    let state: JourneyActivity.State

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ARRIVING")
                        .font(.caption2).tracking(0.6)
                        .foregroundStyle(.white.opacity(0.5))
                    Text("\(attributes.destinationName) · \(state.arrivalClockTime, format: .dateTime.hour().minute())")
                        .font(.subheadline).fontWeight(.medium).foregroundStyle(.white)
                }
                Spacer()
                Text("\(state.totalMinutesRemaining) min")
                    .font(.title3).fontWeight(.medium).monospacedDigit()
                    .foregroundStyle(.white)
            }

            Divider().overlay(Color.white.opacity(0.12))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.currentLeg.actionText)
                        .font(.subheadline).fontWeight(.medium).foregroundStyle(.white)
                    if let detail = state.currentLeg.detailText {
                        Text(detail).font(.caption2).foregroundStyle(.white.opacity(0.55))
                    }
                }
                Spacer()
                Text("\(state.currentLeg.minutesRemaining)m")
                    .font(.headline).fontWeight(.bold).monospacedDigit()
                    .foregroundStyle(LATheme.liveGreen)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}
