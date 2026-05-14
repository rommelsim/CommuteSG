import SwiftUI
import WidgetKit
import ActivityKit

/// Bus-tracking Live Activity. Lock-screen banner + Dynamic Island compact
/// / minimal / expanded states. Layout choices respond to in-product
/// feedback rather than the v2 prototype verbatim:
/// - Lock screen drops the obvious "Commute · Live Activity" caption — the
///   space goes to the user's stop name + walk time, which is what the
///   user actually needs while walking.
/// - Compact pill packs the bus number + ETA *and* a 1-letter stop hint;
///   the prototype's bare ETA loses too much context when several services
///   are in flight.
/// - Expanded uses a full-width header (no leading/trailing region split)
///   so long destination names don't truncate or overflow the bus pill.
struct BusTrackingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BusTrackingActivity.self) { context in
            LockScreenBanner(context: context)
                .activityBackgroundTint(.black.opacity(0.78))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(deepLinkURL(for: context))
        } dynamicIsland: { context in
            DynamicIsland {
                // Full-width header in the .center region. Avoids the
                // .leading/.trailing split that was clipping the bus pill
                // and overflowing "Live" into the stop name.
                DynamicIslandExpandedRegion(.center) {
                    ExpandedHeader(context: context)
                        .padding(.horizontal, 4)
                        .padding(.top, 2)
                        .widgetURL(deepLinkURL(for: context))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        ArrivalsStrip(
                            nextMinutes: context.state.etaMinutes,
                            following: context.state.followingMinutes
                        )
                        BusCrowdRow(crowdLevel: context.state.crowdLevel)
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 2)
                }
            } compactLeading: {
                // Just the bus pill — stop name was getting truncated to
                // garbage in the ~16pt compact slot. Stop context lives in
                // the expanded view (long-press) where there's room.
                BusPillDark(serviceNo: context.attributes.serviceNo)
            } compactTrailing: {
                Text(compactETA(context.state.etaMinutes))
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundStyle(LiveActivityPalette.green)
            } minimal: {
                // Minimal is a single ~24pt circle — used when something
                // else (music, timer) owns the main compact region. Pack
                // bus number + ETA together so the user can still tell
                // which route this is, not just "some number is ticking".
                MinimalPill(
                    serviceNo: context.attributes.serviceNo,
                    etaMinutes: context.state.etaMinutes
                )
            }
        }
    }

    private func compactETA(_ m: Int?) -> String {
        guard let m else { return "—" }
        return m <= 0 ? "ARR" : "\(m)m"
    }

    /// Deep-link tap target. Lock-screen tap and Dynamic Island tap (in
    /// every state — compact/minimal/expanded — when set on `.widgetURL`)
    /// route to `commute://stop/<stopCode>`. The main app's `.onOpenURL`
    /// pushes the bus-stop detail screen, which is one tap from live
    /// tracking — full reconstruction of a `BusArrival` from snapshot
    /// data isn't worth the complexity.
    private func deepLinkURL(for context: ActivityViewContext<BusTrackingActivity>) -> URL? {
        let code = context.attributes.stopCode
        guard !code.isEmpty else { return URL(string: "commute://") }
        return URL(string: "commute://stop/\(code)")
    }
}

/// Tightly packed bus-number + ETA for the Dynamic Island `minimal` slot.
/// Two lines stacked because the slot is taller than it is wide; horizontal
/// "91·2" was hitting the round clip mask and getting cut on both sides.
private struct MinimalPill: View {
    let serviceNo: String
    let etaMinutes: Int?

    var body: some View {
        VStack(spacing: 0) {
            Text(serviceNo)
                .font(.system(size: 9, weight: .bold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(etaText)
                .font(.system(size: 10, weight: .bold).monospacedDigit())
                .foregroundStyle(LiveActivityPalette.green)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 2)
    }

    private var etaText: String {
        guard let m = etaMinutes else { return "—" }
        return m <= 0 ? "ARR" : "\(m)m"
    }
}

// MARK: - Lock-screen banner

private struct LockScreenBanner: View {
    let context: ActivityViewContext<BusTrackingActivity>

    var body: some View {
        HStack(spacing: 14) {
            // Bus pill instead of a generic gradient app-icon — surfaces
            // the route number, which is the strongest at-a-glance cue.
            BusPillDark(serviceNo: context.attributes.serviceNo)
                .scaleEffect(1.4)
                .frame(width: 48, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                // Top line is the trip headline: where this bus is going.
                Text("→ \(context.attributes.destination)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                // Sub line replaces the "Commute · Live Activity" caption
                // with the practically useful info: which stop + live status.
                HStack(spacing: 6) {
                    Text(context.attributes.stopName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                    if context.state.isLive {
                        Circle()
                            .fill(LiveActivityPalette.green)
                            .frame(width: 5, height: 5)
                        Text("Live")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))
                    } else {
                        Text("· Scheduled")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text(heroETA)
                    .font(.system(size: 30, weight: .bold).monospacedDigit())
                    .foregroundStyle(isArriving ? LiveActivityPalette.greenBright
                                                : LiveActivityPalette.green)
                if !isArriving {
                    Text("min")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var heroETA: String {
        guard let m = context.state.etaMinutes else { return "—" }
        return m <= 0 ? "ARR" : "\(m)"
    }

    private var isArriving: Bool {
        (context.state.etaMinutes ?? 99) <= 0
    }
}

// MARK: - Expanded header

private struct ExpandedHeader: View {
    let context: ActivityViewContext<BusTrackingActivity>

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            BusPillDark(serviceNo: context.attributes.serviceNo)
            VStack(alignment: .leading, spacing: 2) {
                Text("→ \(context.attributes.destination)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(context.attributes.stopName)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            // Live dot stays compact so it can't overflow.
            HStack(spacing: 4) {
                Circle()
                    .fill(context.state.isLive ? LiveActivityPalette.green : Color.orange)
                    .frame(width: 6, height: 6)
                Text(context.state.isLive ? "Live" : "Sched")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
    }
}

// MARK: - Reusable building blocks

/// White-text bus pill for dark Live Activity surfaces. The in-app
/// `ServicePill` uses a different palette — keep both rather than
/// branch one component on a flag.
struct BusPillDark: View {
    let serviceNo: String
    var body: some View {
        Text(serviceNo)
            .font(.system(size: 12, weight: .bold).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

private struct ArrivalsStrip: View {
    let nextMinutes: Int?
    let following: [Int]

    var body: some View {
        HStack(spacing: 6) {
            slot(label: "NEXT", minutes: nextMinutes, isFirst: true)
            slot(label: "THEN", minutes: following.first, isFirst: false)
            slot(label: "AFTER", minutes: following.dropFirst().first, isFirst: false)
        }
    }

    @ViewBuilder
    private func slot(label: String, minutes: Int?, isFirst: Bool) -> some View {
        if let m = minutes {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
                Text(m <= 0 ? "ARR" : "\(m)m")
                    .font(.system(size: isFirst ? 17 : 14, weight: .bold).monospacedDigit())
                    .foregroundStyle(isFirst ? LiveActivityPalette.green
                                             : .white.opacity(0.55))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isFirst ? LiveActivityPalette.green.opacity(0.10)
                                  : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isFirst ? LiveActivityPalette.green.opacity(0.20)
                                          : Color.clear, lineWidth: 0.5)
            )
        } else {
            VStack(spacing: 2) {
                Text("—")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.30))
                Text("No further")
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.25))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            )
        }
    }
}

/// Bus crowd indicator. **Not** "platform crowd" — that's a train concept.
/// For a single bus this describes the bus's own loading: seats free vs
/// standing-only vs packed. Mapping comes from `CrowdLevel.label` in the
/// app target ("Seats" / "Standing" / "Limited").
private struct BusCrowdRow: View {
    let crowdLevel: String

    private var filledCount: Int {
        switch crowdLevel.lowercased() {
        case "limited":  3
        case "standing": 2
        case "seats":    1
        default:         0
        }
    }

    private var label: String {
        switch crowdLevel.lowercased() {
        case "limited":  "Packed"
        case "standing": "Standing"
        case "seats":    "Seats free"
        default:         "—"
        }
    }

    private var labelColor: Color {
        switch crowdLevel.lowercased() {
        case "limited":  Color(red: 0.94, green: 0.27, blue: 0.27)
        case "standing": Color(red: 0.96, green: 0.62, blue: 0.04)
        case "seats":    LiveActivityPalette.green
        default:         .white.opacity(0.45)
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("Bus crowd")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.35))
            HStack(spacing: 3) {
                ForEach(0..<3) { i in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(i < filledCount ? labelColor.opacity(0.85)
                                              : Color.white.opacity(0.10))
                        .frame(width: 13, height: 13)
                }
            }
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(labelColor)
            Spacer(minLength: 0)
        }
    }
}

/// Shared palette for Live Activity surfaces only. Brighter green than the
/// in-app palette because it sits on a forced-dark canvas.
enum LiveActivityPalette {
    static let green       = Color(red: 0.133, green: 0.773, blue: 0.369)
    static let greenBright = Color(red: 0.306, green: 0.824, blue: 0.627)
}
