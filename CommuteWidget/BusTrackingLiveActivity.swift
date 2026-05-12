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
            LockScreenView(context: context)
                .activityBackgroundTint(brandBlueDark)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .center, spacing: 4) {
                        Image(systemName: "bus.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.75))
                        Text("Commute")
                            .font(.system(size: 9, weight: .medium))
                            .tracking(0.4)
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    EtaBlock(
                        minutes: context.state.etaMinutes,
                        primarySize: 28,
                        unitSize: 13,
                        primaryColor: .white,
                        secondary: arrivalClockTime(for: context.state.etaMinutes),
                        secondaryColor: .white.opacity(0.6)
                    )
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            ServicePill(service: context.attributes.serviceNo, size: 13)
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(context.state.isLive ? liveGreen : Color.orange)
                                    .frame(width: 5, height: 5)
                                Text(context.state.isLive ? "LIVE" : "SCHED")
                                    .font(.system(size: 9, weight: .semibold))
                                    .tracking(0.5)
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                        Text(routeSubtitle(for: context))
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 0.5)
                            .padding(.bottom, 10)
                        HStack(alignment: .top, spacing: 0) {
                            statColumn(
                                label: "STOP",
                                value: stopCodeOrDash(for: context),
                                tint: .white
                            )
                            statDivider
                            statColumn(
                                label: "STATUS",
                                value: context.state.isLive ? "Live" : "Sched",
                                tint: context.state.isLive ? liveGreen : Color.orange
                            )
                            statDivider
                            statColumn(
                                label: "CROWD",
                                value: crowdShort(context.state.crowdLevel),
                                tint: crowdColor(context.state.crowdLevel),
                                leadingIcon: "person.2.fill"
                            )
                        }
                    }
                }
            } compactLeading: {
                ServicePill(service: context.attributes.serviceNo, size: 11)
            } compactTrailing: {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(compactPrimary(context.state.etaMinutes))
                        .font(.system(size: 15, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    if let m = context.state.etaMinutes, m > 0 {
                        Text("min")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            } minimal: {
                HStack(spacing: 3) {
                    Image(systemName: "bus.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(minimalPrimary(context.state.etaMinutes))
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
            }
            .keylineTint(brandBlueMid)
        }
    }

    // MARK: - Helpers

    private func compactPrimary(_ minutes: Int?) -> String {
        guard let m = minutes else { return "—" }
        if m == 0 { return "Arr" }
        return "\(m)"
    }

    private func minimalPrimary(_ minutes: Int?) -> String {
        guard let m = minutes else { return "—" }
        if m == 0 { return "•" }
        return "\(m)'"
    }

    private func routeSubtitle(for context: ActivityViewContext<BusTrackingActivity>) -> String {
        let from = context.attributes.stopName
        // Strip any leading "→" the destination string may already carry —
        // some callers format it as "→ 43009". Without this we render
        // "Bef Clementi Rd → → 43009".
        let to = context.attributes.destination
            .trimmingCharacters(in: .whitespaces)
            .drop(while: { $0 == "→" })
            .trimmingCharacters(in: .whitespaces)
        if from.isEmpty { return "→ \(to)" }
        return "\(from) → \(to)"
    }

    private func stopCodeOrDash(for context: ActivityViewContext<BusTrackingActivity>) -> String {
        let code = context.attributes.stopCode
        return code.isEmpty ? "—" : code
    }

    private func arrivalClockTime(for minutes: Int?) -> String? {
        guard let m = minutes, m > 0 else { return nil }
        let when = Date().addingTimeInterval(TimeInterval(m * 60))
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: when)
    }

    private func crowdShort(_ raw: String) -> String {
        switch raw.lowercased() {
        case "seats": "Seats"
        case "standing": "Standing"
        case "limited": "Packed"
        default: "—"
        }
    }

    private func crowdColor(_ raw: String) -> Color {
        switch raw.lowercased() {
        case "seats": liveGreen
        case "standing": Color(red: 0.98, green: 0.66, blue: 0.16)
        case "limited": Color(red: 0.95, green: 0.41, blue: 0.41)
        default: .white
        }
    }

    @ViewBuilder
    private func statColumn(label: String, value: String, tint: Color, leadingIcon: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.5))
            HStack(spacing: 4) {
                if let leadingIcon {
                    Image(systemName: leadingIcon)
                        .font(.system(size: 12))
                        .foregroundStyle(tint)
                }
                Text(value)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(tint)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.15))
            .frame(width: 0.5, height: 28)
            .padding(.horizontal, 10)
            .padding(.top, 2)
    }
}

// MARK: - Lock Screen view

private struct LockScreenView: View {
    let context: ActivityViewContext<BusTrackingActivity>

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [brandBlueDark, brandBlueMid],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Decorative orbs (top-right + bottom-left), matching the mock
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 90, height: 90)
                .offset(x: 130, y: -60)
            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 60, height: 60)
                .offset(x: -40, y: 60)

            VStack(spacing: 10) {
                header

                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(heroMinutes)
                                .font(.system(size: 56, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .contentTransition(.numericText())
                                .animation(.snappy, value: context.state.etaMinutes)
                            if showsHeroUnit {
                                Text("min")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                        }
                        Text(arrivalSubtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        ServicePill(service: context.attributes.serviceNo, size: 15)
                        Text("to \(context.attributes.destination)")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }

                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 0.5)

                footer
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.white.opacity(0.95))
                    .frame(width: 26, height: 26)
                    .overlay(
                        Image(systemName: "bus.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(brandBlueDark)
                    )
                Text("Commute")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
            }
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(context.state.isLive ? liveGreen : Color.orange)
                    .frame(width: 6, height: 6)
                Text(context.state.isLive ? "LIVE" : "SCHED")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(0.4)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.65))
                Text(context.attributes.stopName)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(crowdColor(context.state.crowdLevel))
                Text(crowdLabel(context.state.crowdLevel))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(crowdColor(context.state.crowdLevel))
            }
        }
    }

    private var heroMinutes: String {
        guard let m = context.state.etaMinutes else { return "—" }
        if m == 0 { return "Arr" }
        return "\(m)"
    }

    private var showsHeroUnit: Bool {
        if let m = context.state.etaMinutes, m > 0 { return true }
        return false
    }

    private var arrivalSubtitle: String {
        guard let m = context.state.etaMinutes, m > 0 else {
            return context.state.isLive ? "Arriving now" : "Live updates paused"
        }
        let when = Date().addingTimeInterval(TimeInterval(m * 60))
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return "Arriving \(f.string(from: when))"
    }

    private func crowdLabel(_ raw: String) -> String {
        switch raw.lowercased() {
        case "seats": "Seats"
        case "standing": "Standing"
        case "limited": "Packed"
        default: "—"
        }
    }

    private func crowdColor(_ raw: String) -> Color {
        switch raw.lowercased() {
        case "seats": liveGreen
        case "standing": Color(red: 1.0, green: 0.78, blue: 0.35)
        case "limited": Color(red: 1.0, green: 0.55, blue: 0.55)
        default: .white.opacity(0.7)
        }
    }
}

// MARK: - Shared building blocks

/// White rounded pill carrying the bus service number — the mock's hero
/// affordance. Sizes are tuned so the same component works in the compact
/// island (size 11), expanded island (size 13) and lock screen (size 15).
private struct ServicePill: View {
    let service: String
    let size: CGFloat

    var body: some View {
        Text(service)
            .font(.system(size: size, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(Color.black)
            .padding(.horizontal, max(7, size * 0.6))
            .padding(.vertical, max(2, size * 0.22))
            .background(Color.white, in: RoundedRectangle(cornerRadius: max(6, size * 0.55), style: .continuous))
    }
}

/// Right-aligned ETA block with optional secondary line (e.g. clock time).
private struct EtaBlock: View {
    let minutes: Int?
    let primarySize: CGFloat
    let unitSize: CGFloat
    let primaryColor: Color
    let secondary: String?
    let secondaryColor: Color

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(primary)
                    .font(.system(size: primarySize, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(primaryColor)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: minutes)
                if showsUnit {
                    Text("min")
                        .font(.system(size: unitSize))
                        .foregroundStyle(primaryColor.opacity(0.7))
                }
            }
            if let secondary {
                Text(secondary)
                    .font(.system(size: 11))
                    .foregroundStyle(secondaryColor)
            }
        }
    }

    private var primary: String {
        guard let m = minutes else { return "—" }
        if m == 0 { return "Arr" }
        return "\(m)"
    }

    private var showsUnit: Bool {
        if let m = minutes, m > 0 { return true }
        return false
    }
}

// MARK: - Palette

/// Lock-screen gradient endpoints, matching `#1e4a8a` / `#2563ad`.
private let brandBlueDark = Color(red: 0.118, green: 0.290, blue: 0.541)
private let brandBlueMid  = Color(red: 0.145, green: 0.388, blue: 0.678)
/// "Live" dot + seats indicator — `#4ade80`.
private let liveGreen     = Color(red: 0.290, green: 0.871, blue: 0.502)
