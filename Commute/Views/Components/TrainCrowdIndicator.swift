import SwiftUI

/// Two-level "typical for this time" crowd indicator. Renders as a slim
/// horizontal **strip** of station bars by default; tapping any bar morphs
/// into a **Popular Times**-style detail with 24 hourly bars for the chosen
/// station. Always labelled "Typical for this time" — never "Live."
///
/// Per the commuter-advocate handoff this is shown in two places: MRT
/// station detail (here) and inline on route results below the legs row.
struct TrainCrowdIndicator: View {
    let line: MRTLine
    /// Stations along the saved route, in travel order.
    let stations: [Station]
    /// Code of the user's stop — gets the white-ring marker. nil hides it.
    let userStopCode: String?

    @State private var state: ViewState = .strip

    enum ViewState: Equatable {
        case strip
        case detail(stationCode: String)
    }

    enum Tier {
        case low, moderate, high

        var opacity: Double {
            switch self {
            case .low:      0.20
            case .moderate: 0.55
            case .high:     1.00
            }
        }

        var label: String {
            switch self {
            case .low:      "Quiet"
            case .moderate: "Typical"
            case .high:     "Busy"
            }
        }
    }

    /// Snapshot for one station: current-hour tier + the 24h hourly tiers
    /// used by the detail view's Popular Times bars.
    struct Station: Identifiable, Hashable {
        let code: String
        let name: String
        let currentTier: Tier
        let hourly: [Tier]   // 24 entries, midnight..23:00

        var id: String { code }

        static func == (lhs: Station, rhs: Station) -> Bool { lhs.code == rhs.code }
        func hash(into h: inout Hasher) { h.combine(code) }
    }

    /// Worst tier across all stations on the strip — surfaced as the
    /// header's at-a-glance label ("Low" / "Moderate" / "Busy").
    private var overallTier: Tier? {
        if stations.contains(where: { $0.currentTier == .high })     { return .high }
        if stations.contains(where: { $0.currentTier == .moderate }) { return .moderate }
        if stations.isEmpty { return nil }
        return .low
    }

    static func tier(forPercent pct: Int) -> Tier {
        switch pct {
        case 65...:    .high
        case 38..<65:  .moderate
        default:       .low
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Group {
                switch state {
                case .strip:
                    strip
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                case .detail(let code):
                    if let s = stations.first(where: { $0.code == code }) {
                        detail(for: s)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.cfHairline, lineWidth: 0.5)
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            if case .detail = state {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        state = .strip
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                        Text("All stations")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Color.cfTextSecondary)
                }
                .buttonStyle(.plain)
                Spacer()
            } else {
                Text("Crowd · Typical for this time")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.cfTextSecondary)
                Spacer()
                if let overall = overallTier {
                    Text(overall.label)
                        .font(.system(size: 11, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.cfTextPrimary.opacity(overall.opacity == 1.0 ? 1.0 : 0.6))
                }
            }
        }
    }

    // MARK: - Strip

    private var strip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(stations) { s in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            state = .detail(stationCode: s.code)
                        }
                    } label: {
                        stationBar(s)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(s.name): \(s.currentTier.label)")
                }
            }
            .frame(height: 64)

            scaleLegend

            if let userStop = stations.first(where: { $0.code == userStopCode }) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 5, height: 5)
                        .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 2))
                    Text("Your boarding station — \(userStop.code)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.cfTextSecondary)
                }
            }
        }
    }

    /// "Low — gradient bar — High" legend per v2 prototype: removes ambiguity
    /// about what bar opacity encodes without adding any new colours.
    private var scaleLegend: some View {
        HStack(spacing: 8) {
            Text("Low")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.cfTextTertiary)
            LinearGradient(
                colors: [line.background.opacity(0.20),
                         line.background.opacity(1.0)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 3)
            .clipShape(Capsule())
            Text("High")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.cfTextTertiary)
        }
    }

    private func stationBar(_ s: Station) -> some View {
        // Per v2 prototype: bar grows upward from a baseline; the user-stop
        // marker is a dot **below** the bar (not overlaid on it), with a
        // soft white halo so it reads at a glance.
        VStack(spacing: 4) {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(line.background.opacity(s.currentTier.opacity))
                .frame(height: barHeight(for: s.currentTier))
            Circle()
                .fill(s.code == userStopCode ? Color.white : Color.cfTextTertiary.opacity(0.4))
                .frame(width: 5, height: 5)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(s.code == userStopCode ? 0.25 : 0),
                                lineWidth: 2)
                )
            Text(String(s.code.suffix(3)))
                .font(.system(size: 8, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(s.code == userStopCode
                                 ? Color.cfTextPrimary
                                 : Color.cfTextTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func barHeight(for t: Tier) -> CGFloat {
        switch t {
        case .low:      14
        case .moderate: 28
        case .high:     42
        }
    }

    // MARK: - Detail (Popular Times)

    private func detail(for s: Station) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(s.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.cfTextPrimary)
                if s.code == userStopCode {
                    Text("Your stop")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.appInfoBg, in: Capsule())
                        .foregroundStyle(Color.appInfo)
                }
                Spacer()
                Text(currentHourLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.cfTextSecondary)
            }

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<24, id: \.self) { h in
                    let t = s.hourly.indices.contains(h) ? s.hourly[h] : .low
                    let isNow = h == Calendar.current.component(.hour, from: Date())
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(isNow ? line.background : Color.cfHairlineStrong.opacity(t.opacity))
                        .frame(height: hourBarHeight(t))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 44, alignment: .bottom)

            Text("\(currentHourLabel): \(s.currentTier.label)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.cfTextSecondary)
        }
    }

    private func hourBarHeight(_ t: Tier) -> CGFloat {
        switch t {
        case .low:      10
        case .moderate: 24
        case .high:     40
        }
    }

    private var currentHourLabel: String {
        let h = Calendar.current.component(.hour, from: Date())
        let next = (h + 1) % 24
        let f: (Int) -> String = { hr in
            let suffix = hr < 12 ? "AM" : "PM"
            let display = hr % 12 == 0 ? 12 : hr % 12
            return "\(display) \(suffix)"
        }
        return "\(f(h))–\(f(next))"
    }
}
