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

    @State private var tilt = MotionTilt()

    /// How far each orb can drift in points at full tilt. Larger orb gets a
    /// stronger response — it sits "closer" to the surface so it parallaxes
    /// more obviously than the smaller one.
    private let bigOrbAmplitude: CGFloat = 22
    private let smallOrbAmplitude: CGFloat = 16

    var body: some View {
        ZStack {
            // Background gradient
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(context.time.palette.gradient)

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
                .padding(16)
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
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: Color(hex: 0x0F1729).opacity(0.40), radius: 14, x: 0, y: 12)
        .onAppear { tilt.start() }
        .onDisappear { tilt.stop() }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            topRow
                .padding(.bottom, 10)

            Text(context.headline)
                .font(.system(size: 26, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(Color.cfOnDarkPrimary)

            subhead
                .padding(.top, 2)
                .padding(.bottom, 12)

            if let journey = context.journey {
                Divider()
                    .background(Color.white.opacity(0.10))
                journeyRow(journey)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                statsStrip(journey)
            }
        }
    }

    private var topRow: some View {
        HStack(alignment: .center) {
            HStack(spacing: 6) {
                LiveDot(color: Color(red: 0.46, green: 0.86, blue: 0.50))
                Text(context.labelTop.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color.cfOnDarkMuted)
            }
            Spacer()
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

    @ViewBuilder
    private var subhead: some View {
        if context.journey == nil, let prompt = context.prompt {
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
