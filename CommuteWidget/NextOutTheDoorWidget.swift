import SwiftUI
import WidgetKit

/// Home-screen widget that mirrors the main app's "Next out the door" hero
/// card. Reads `NextOutTheDoorSnapshot` written by the main app from the
/// shared App Group; if missing or stale (>30 min) shows a quiet "Open
/// Commute" prompt. Time-of-day gradient flips with the snapshot's context.
struct NextOutTheDoorWidget: Widget {
    let kind: String = "NextOutTheDoorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextOutTheDoorProvider()) { entry in
            NextOutTheDoorWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    HeroPaletteWidget(context: entry.snapshot?.timeContext ?? .midday).gradient
                }
        }
        .configurationDisplayName("Next out the door")
        .description("Your next ride home or to work, at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Entry / Provider

struct NextOutTheDoorEntry: TimelineEntry {
    let date: Date
    let snapshot: NextOutTheDoorSnapshot?
}

private struct NextOutTheDoorProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextOutTheDoorEntry {
        NextOutTheDoorEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (NextOutTheDoorEntry) -> Void) {
        completion(NextOutTheDoorEntry(date: Date(), snapshot: SharedSnapshot.readNextOutTheDoor()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextOutTheDoorEntry>) -> Void) {
        let entry = NextOutTheDoorEntry(date: Date(), snapshot: SharedSnapshot.readNextOutTheDoor())
        // Re-query in 5 min so the ETA copy stays roughly current even if
        // the main app hasn't been opened. The app reload-triggers us on
        // its own refresh so this is a safety net.
        let next = Date().addingTimeInterval(5 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - View

struct NextOutTheDoorWidgetView: View {
    let entry: NextOutTheDoorEntry
    @Environment(\.widgetFamily) private var family

    private var isFresh: Bool {
        guard let s = entry.snapshot else { return false }
        return Date().timeIntervalSince(s.updatedAt) < 30 * 60
    }

    var body: some View {
        if let snap = entry.snapshot, isFresh {
            switch family {
            case .systemSmall:  small(snap)
            case .systemMedium: medium(snap)
            default:            large(snap)
            }
        } else {
            staleState
        }
    }

    // MARK: Small (155×155)

    private func small(_ s: NextOutTheDoorSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            topLabel(s)
            Spacer(minLength: 0)
            Text(s.headline)
                .font(.system(size: 17, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            if let bus = s.bus, let eta = s.etaMinutes {
                HStack(spacing: 6) {
                    chip(bus)
                    Text("in \(eta)m")
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.white.opacity(0.85))
                }
            }
        }
    }

    // MARK: Medium (329×155)

    private func medium(_ s: NextOutTheDoorSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            topLabel(s)
            Text(s.headline)
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            if let subhead = formatSubhead(s) {
                Text(subhead)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.70))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if let bus = s.bus {
                journeyRow(bus: bus, dest: s.destination, label: s.destinationLabel, fromStop: s.fromStop)
            }
        }
    }

    // MARK: Large (329×345)

    private func large(_ s: NextOutTheDoorSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            topLabel(s)
            Text(s.headline)
                .font(.system(size: 26, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(.white)
                .lineLimit(2)
            if let subhead = formatSubhead(s) {
                Text(subhead)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.70))
                    .lineLimit(2)
            }
            if let bus = s.bus, s.destinationLabel != nil {
                Divider()
                    .background(Color.white.opacity(0.12))
                    .padding(.top, 6)
                journeyRow(bus: bus, dest: s.destination, label: s.destinationLabel, fromStop: s.fromStop)
                    .padding(.top, 4)
            }
            Spacer(minLength: 0)
            if s.totalTripMinutes != nil || s.arriveByLabel != nil {
                statsStrip(s)
            }
        }
    }

    // MARK: Pieces

    private func topLabel(_ s: NextOutTheDoorSnapshot) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(red: 0.46, green: 0.86, blue: 0.50))
                .frame(width: 6, height: 6)
            Text(s.labelTop.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Color.white.opacity(0.55))
                .lineLimit(1)
        }
    }

    private func chip(_ service: String) -> some View {
        Text(service)
            .font(.system(size: 12, weight: .bold))
            .monospacedDigit()
            .tracking(-0.1)
            .foregroundStyle(Color(red: 0.06, green: 0.09, blue: 0.16))
            .frame(width: 44, height: 22)
            .background(Color.white.opacity(0.95), in: Capsule(style: .continuous))
    }

    private func journeyRow(bus: String, dest: String?, label: String?, fromStop: String?) -> some View {
        HStack(spacing: 6) {
            chip(bus)
            Image(systemName: "arrow.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.45))
            if let dest {
                Text(dest)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            if let label {
                Text("·")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.40))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.60))
            }
            Spacer(minLength: 4)
            if let fromStop {
                Text("from \(fromStop)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .lineLimit(1)
            }
        }
    }

    private func statsStrip(_ s: NextOutTheDoorSnapshot) -> some View {
        HStack(spacing: 0) {
            if let total = s.totalTripMinutes {
                statCell(label: "Total trip", value: "\(total)", unit: "min")
                divider
            }
            if let arrive = s.arriveByLabel {
                statCell(label: "Arrive by", value: arrive, unit: nil)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func statCell(label: String, value: String, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.45))
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                if let unit {
                    Text(unit)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(width: 1)
    }

    private func formatSubhead(_ s: NextOutTheDoorSnapshot) -> String? {
        if let bus = s.bus, let eta = s.etaMinutes, let slack = s.slack {
            return "Catch \(bus) in \(eta) min · \(slack)"
        }
        return nil
    }

    private var staleState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: diagnostic.symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
            Text(diagnostic.title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
            Text(diagnostic.detail)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.65))
                .lineLimit(3)
            Spacer(minLength: 0)
        }
    }

    /// Diagnose WHY the widget has nothing to render so the user knows what
    /// to fix. Three failure modes:
    ///   1. App Group suite not available → entitlement missing on a target
    ///   2. Snapshot key missing → main app hasn't written one yet
    ///   3. Snapshot present but >30 min old → main app hasn't refreshed
    private var diagnostic: (symbol: String, title: String, detail: String) {
        let suite = UserDefaults(suiteName: SharedSnapshot.appGroupID)
        if suite == nil {
            return ("exclamationmark.triangle.fill",
                    "App Group missing",
                    "Tick \(SharedSnapshot.appGroupID) on both targets in Signing & Capabilities.")
        }
        if entry.snapshot == nil {
            return ("tram.fill",
                    "Open Commute",
                    "Launch the app once so it can publish the snapshot.")
        }
        return ("clock.arrow.circlepath",
                "Snapshot stale",
                "Open Commute to refresh.")
    }
}

// MARK: - Hero palette (duplicated from main-app Tokens.swift for the
// widget target — the design system isn't a shared module yet)

private struct HeroPaletteWidget {
    let context: NextOutTheDoorSnapshot.TimeContext

    var stops: [Color] {
        switch context {
        case .morning:
            return [Color(red: 0.118, green: 0.227, blue: 0.373),
                    Color(red: 0.176, green: 0.353, blue: 0.541),
                    Color(red: 0.227, green: 0.435, blue: 0.659)]
        case .midday:
            return [Color(red: 0.278, green: 0.333, blue: 0.412),
                    Color(red: 0.392, green: 0.455, blue: 0.545)]
        case .evening:
            return [Color(red: 0.259, green: 0.145, blue: 0.376),
                    Color(red: 0.478, green: 0.231, blue: 0.361),
                    Color(red: 0.776, green: 0.408, blue: 0.282)]
        case .night:
            return [Color(red: 0.039, green: 0.055, blue: 0.102),
                    Color(red: 0.102, green: 0.122, blue: 0.180)]
        case .weekend:
            return [Color(red: 0.176, green: 0.290, blue: 0.243),
                    Color(red: 0.290, green: 0.435, blue: 0.353)]
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: stops, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
