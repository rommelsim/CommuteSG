import SwiftUI

// MARK: - Time-of-day context
// Drives the hero's gradient, headline, suggested journey, and tone.
enum TimeContext: String {
    case morning, midday, evening, night, weekend

    static func current(now: Date = Date(), calendar: Calendar = .current) -> TimeContext {
        let weekday = calendar.component(.weekday, from: now)
        if weekday == 1 || weekday == 7 { return .weekend }
        let hour = calendar.component(.hour, from: now)
        switch hour {
        case 6..<11:  return .morning
        case 11..<16: return .midday
        case 16..<21: return .evening
        default:      return .night
        }
    }

    var palette: HeroPalette {
        switch self {
        case .morning: .morning
        case .midday:  .midday
        case .evening: .evening
        case .night:   .night
        case .weekend: .weekend
        }
    }
}

// MARK: - Hero context
// Composed from TimeContext + saved places + (optionally) the next nearby
// suggested bus. When `journey` is nil, the hero shows the headline + a
// gentle prompt; no journey row, no stats strip.
struct HeroContext {
    let time: TimeContext
    let greeting: String
    let headline: String
    let labelTop: String
    let prompt: String?
    let weather: Weather
    let journey: Journey?
    /// Set when a live MRT disruption is in effect; flips the hero into its
    /// "route affected" visual state (dark-red gradient, pulsing dot, headline
    /// replaced by the disruption line). Note that we can't yet verify the
    /// disruption affects *this user's* journey — that requires routing data
    /// we don't have — so this fires on any active disruption.
    var disruption: Disruption? = nil
    /// Active rerouted state — mutually exclusive with `disruption`. Set after
    /// the user accepts an in-card reroute CTA; flips the hero to the dark-
    /// green confirmation treatment with the new chips and an updated ETA.
    var rerouted: Rerouted? = nil

    struct Disruption {
        let lineName: String
        let lineCode: String
        let stations: String
        /// Optional in-card reroute CTA — when set the disrupted card shows
        /// "🔀 Alternative available → [route] · Saves ~N min · $X.XX".
        var reroute: RerouteOption? = nil
    }

    struct RerouteOption {
        /// Short route summary, e.g. "EW → CC" or "Bus 14 → MRT".
        let routeSummary: String
        let savesMinutes: Int
        let fareSGD: Double
    }

    struct Rerouted {
        let routeSummary: String
        let updatedArriveBy: String  // "6:53 pm"
    }

    struct Weather {
        let symbol: String   // SF Symbol name
        let text: String     // "24°C · Clear"
    }

    struct Journey {
        let bus: String
        let etaMinutes: Int
        let slack: String           // "1 min to spare" / "Last service tonight"
        let destination: String     // "Clementi"
        let destinationLabel: String  // "Home" / "Work"
        let fromStop: String        // "Blk 355"
        let totalTripMinutes: Int
        let arriveByLabel: String   // "6:53 pm"
        let alternative: Alternative?

        struct Alternative {
            let label: String       // "Faster than MRT"
            let value: String?      // "9 min" or nil → "After this"
        }
    }

    /// Builds a context for a given time. `userName`, `homePlace`, `workPlace`
    /// and `journey` are optional; sensible defaults when nil.
    static func make(
        time: TimeContext,
        userName: String?,
        homePlace: String?,
        workPlace: String?,
        journey: Journey? = nil,
        weather: Weather = Weather(symbol: "sun.max.fill", text: "—")
    ) -> HeroContext {
        let name = userName.flatMap { $0.isEmpty ? nil : $0 }

        switch time {
        case .morning:
            return HeroContext(
                time: time,
                greeting: greetingFor("Good morning", name),
                headline: journey != nil ? "Catch this for work" : "Heading out?",
                labelTop: "Next out the door",
                prompt: journey == nil ? "Tap a stop below to plan your trip" : nil,
                weather: weather,
                journey: journey
            )
        case .midday:
            return HeroContext(
                time: time,
                greeting: greetingFor("Hi", name),
                headline: journey != nil ? "Next out the door" : "Heading somewhere?",
                labelTop: "Right now",
                prompt: journey == nil ? "Tap a stop below to plan your trip" : nil,
                weather: weather,
                journey: journey
            )
        case .evening:
            return HeroContext(
                time: time,
                greeting: greetingFor("Good evening", name),
                headline: journey != nil ? "Walk now" : "Heading home?",
                labelTop: "Next out the door",
                prompt: journey == nil ? "Tap a stop below to plan your trip" : nil,
                weather: weather,
                journey: journey
            )
        case .night:
            return HeroContext(
                time: time,
                greeting: name.map { "Getting home, \($0)?" } ?? "Getting home?",
                headline: journey != nil ? "Catch the last bus" : "Late night",
                labelTop: journey != nil ? "Last out the door" : "Right now",
                prompt: journey == nil ? "Limited services after midnight" : nil,
                weather: weather,
                journey: journey
            )
        case .weekend:
            return HeroContext(
                time: time,
                greeting: greetingFor("Happy weekend", name),
                headline: journey != nil ? "Heading out" : "Nothing scheduled",
                labelTop: "Right now",
                prompt: journey == nil ? "Browse nearby stops for casual travel" : nil,
                weather: weather,
                journey: journey
            )
        }
    }

    private static func greetingFor(_ base: String, _ name: String?) -> String {
        name.map { "\(base), \($0)" } ?? base
    }
}

// MARK: - Hero card
struct HomeHero: View {
    let context: HeroContext
    /// Fired when the user taps the in-card reroute CTA. The owning view is
    /// responsible for flipping `context.disruption` → `context.rerouted`.
    var onAcceptReroute: (() -> Void)? = nil

    @State private var tilt = MotionTilt()

    /// How far each orb can drift in points at full tilt. Larger orb gets a
    /// stronger response — it sits "closer" to the surface so it parallaxes
    /// more obviously than the smaller one.
    private let bigOrbAmplitude: CGFloat = 22
    private let smallOrbAmplitude: CGFloat = 16

    private var isDisrupted: Bool { context.disruption != nil && context.rerouted == nil }
    private var isRerouted: Bool { context.rerouted != nil }

    var body: some View {
        ZStack {
            // Background gradient — overridden to a dark-red wash when a
            // disruption is active so the affected state reads at a glance.
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(heroBackground)

            // Decorative orbs — drift with device tilt (liquid-glass feel)
            Circle()
                .fill(context.time.palette.orbTint)
                .frame(width: 96, height: 96)
                .offset(
                    x: 130 + CGFloat(tilt.x) * bigOrbAmplitude,
                    y: -64 + CGFloat(tilt.y) * bigOrbAmplitude
                )
            Circle()
                .fill(context.time.palette.orbTint)
                .frame(width: 80, height: 80)
                .offset(
                    x: -110 + CGFloat(tilt.x) * smallOrbAmplitude,
                    y:  80 + CGFloat(tilt.y) * smallOrbAmplitude
                )

            content
                .padding(context.journey == nil ? 12 : 16)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        // Subtle white hairline border so the card always has a defined
        // edge — the drop shadow below works in light mode but becomes
        // invisible against the dark-mode page background, leaving the
        // card visually unbounded. The border at 12% white reads gently
        // in light mode and gives a "raised" look in dark mode.
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(borderColor, lineWidth: (isDisrupted || isRerouted) ? 1 : 0.5)
        )
        .shadow(color: Color(hex: 0x0F1729).opacity(0.40), radius: 14, x: 0, y: 12)
        .onAppear { tilt.start() }
        .onDisappear { tilt.stop() }
    }

    private var content: some View {
        let reduced = context.journey == nil
        return VStack(alignment: .leading, spacing: 0) {
            topRow
                .padding(.bottom, reduced ? 6 : 10)

            Text(headlineText)
                .font(.system(size: reduced ? 20 : 26, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(Color.cfOnDarkPrimary)

            subhead
                .padding(.top, 2)
                .padding(.bottom, reduced ? 4 : 12)

            if let journey = context.journey {
                Divider()
                    .background(Color.white.opacity(0.10))
                journeyRow(journey)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                statsStrip(journey)
            }

            if let reroute = context.disruption?.reroute, !isRerouted {
                rerouteCTA(reroute)
                    .padding(.top, 12)
            }
            if let r = context.rerouted {
                rerouteConfirmStrip(r)
                    .padding(.top, 12)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            }
        }
    }

    private func rerouteCTA(_ r: HeroContext.RerouteOption) -> some View {
        Button { onAcceptReroute?() } label: {
            HStack(spacing: 8) {
                Text("🔀")
                Text("Alternative available")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.cfOnDarkPrimary)
                Spacer(minLength: 6)
                Text("\(r.routeSummary) · Saves ~\(r.savesMinutes) min · $\(String(format: "%.2f", r.fareSGD))")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.cfOnDarkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.cfOnDarkLabel)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reroute to \(r.routeSummary), saves about \(r.savesMinutes) minutes")
    }

    private func rerouteConfirmStrip(_ r: HeroContext.Rerouted) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(red: 0.46, green: 0.86, blue: 0.50))
            Text("Reroute confirmed · Updated ETA: \(r.updatedArriveBy)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.cfOnDarkPrimary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.10, green: 0.34, blue: 0.18).opacity(0.9),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(red: 0.46, green: 0.86, blue: 0.50).opacity(0.45),
                              lineWidth: 0.5)
        )
    }

    private var disruptedGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.10, green: 0.05, blue: 0.07),
                     Color(red: 0.42, green: 0.10, blue: 0.10)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var reroutedGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.04, green: 0.16, blue: 0.10),
                     Color(red: 0.09, green: 0.34, blue: 0.20)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var heroBackground: AnyShapeStyle {
        if isRerouted { return AnyShapeStyle(reroutedGradient) }
        if isDisrupted { return AnyShapeStyle(disruptedGradient) }
        return AnyShapeStyle(context.time.palette.gradient)
    }

    private var borderColor: Color {
        if isRerouted { return Color(red: 0.46, green: 0.86, blue: 0.50).opacity(0.65) }
        if isDisrupted { return Color(red: 0.95, green: 0.30, blue: 0.30).opacity(0.65) }
        return Color.white.opacity(0.12)
    }

    private var topRow: some View {
        HStack(alignment: .center) {
            HStack(spacing: 6) {
                if isDisrupted {
                    PulsingDot(color: Color(red: 0.98, green: 0.35, blue: 0.35))
                } else {
                    LiveDot(color: Color(red: 0.46, green: 0.86, blue: 0.50))
                }
                Text(topLabel.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color.cfOnDarkMuted)
            }
            Spacer()
            if context.weather.text != "—" {
                HStack(spacing: 4) {
                    Image(systemName: context.weather.symbol)
                        .font(.system(size: 10, weight: .semibold))
                    Text(context.weather.text)
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(Color.cfOnDarkSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
    }

    private var headlineText: String {
        if isRerouted { return "Rerouted around delays" }
        if let d = context.disruption { return "Disruption on \(d.lineName)" }
        return context.headline
    }

    private var topLabel: String {
        if isRerouted { return "Updated route" }
        if isDisrupted { return "Route affected" }
        return context.labelTop
    }

    @ViewBuilder
    private var subhead: some View {
        if let r = context.rerouted {
            Text("New route: \(r.routeSummary)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.cfOnDarkSecondary)
        } else if let d = context.disruption {
            Text(d.stations.isEmpty
                 ? "Trains affected — tap for status"
                 : "Trains between \(d.stations) — tap for status")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.cfOnDarkSecondary)
        } else if context.journey == nil, let prompt = context.prompt {
            Text(prompt)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.cfOnDarkSecondary)
        }
    }

    private func journeyRow(_ j: HeroContext.Journey) -> some View {
        HStack(spacing: 8) {
            ServiceChip(service: j.bus, size: .sm, onDark: true)
            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.cfOnDarkLabel)
            Text(j.destination)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.cfOnDarkPrimary)
                .lineLimit(1)
            Text("·")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.40))
            Text(j.destinationLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.cfOnDarkSecondary)
            Spacer(minLength: 8)
            Text("from \(j.fromStop)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.cfOnDarkMuted)
        }
    }

    private func statsStrip(_ j: HeroContext.Journey) -> some View {
        HStack(spacing: 0) {
            statCell(label: "Total trip", value: "\(j.totalTripMinutes)", unit: "min")
            divider
            statCell(label: "Arrive by", value: j.arriveByLabel, unit: nil)
            if let alt = j.alternative {
                divider
                statCell(label: alt.label, value: alt.value ?? "After this", unit: alt.value != nil ? "min" : nil)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func statCell(label: String, value: String, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.cfOnDarkLabel)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.cfOnDarkPrimary)
                if let unit {
                    Text(unit)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.cfOnDarkMuted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(width: 1)
    }
}

private struct PulsingDot: View {
    let color: Color
    @State private var animating = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .scaleEffect(animating ? 1.25 : 0.85)
            .opacity(animating ? 1.0 : 0.55)
            .animation(
                .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                value: animating
            )
            .onAppear { animating = true }
    }
}
