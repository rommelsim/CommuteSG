import SwiftUI
import WidgetKit
import AppIntents

/// Static, no-data widget — shows three deep-link tiles into the main app's
/// most-used screens. Avoids App Groups / network entirely so the widget is
/// 100% bug-free at runtime; it's just a launcher.
struct QuickActionsWidget: Widget {
    let kind: String = "QuickActionsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TickProvider()) { _ in
            QuickActionsWidgetView()
                // iOS 17+ requires widgets to declare their background via
                // `.containerBackground(for: .widget)`. Without this we trip
                // the "Please adopt containerBackgroundApi" warning and the
                // widget is rejected from the gallery.
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.27, blue: 0.55),
                            Color(red: 0.03, green: 0.16, blue: 0.36)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("Commute · Quick actions")
        .description("Jump straight to Plan, Fares, or Alerts.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Provider (no data; just a single placeholder entry)

private struct TickEntry: TimelineEntry {
    let date: Date
}

private struct TickProvider: TimelineProvider {
    func placeholder(in context: Context) -> TickEntry { TickEntry(date: Date()) }

    func getSnapshot(in context: Context, completion: @escaping (TickEntry) -> Void) {
        completion(TickEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TickEntry>) -> Void) {
        // Static widget — refresh once per hour to let SwiftUI re-render any
        // theme changes; no real data depends on this.
        let next = Date().addingTimeInterval(3600)
        completion(Timeline(entries: [TickEntry(date: Date())], policy: .after(next)))
    }
}

// MARK: - View

private struct QuickActionsWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            small
        default:
            medium
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "tram.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text("Commute")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 0)
            Link(destination: deepLink(.plan)) {
                actionRow(symbol: "point.topleft.down.curvedto.point.bottomright.up", label: "Plan")
            }
            Link(destination: deepLink(.alerts)) {
                actionRow(symbol: "bell.fill", label: "Alerts")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "tram.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text("Commute")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("Singapore transit")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            HStack(spacing: 10) {
                Link(destination: deepLink(.plan)) {
                    bigTile(symbol: "point.topleft.down.curvedto.point.bottomright.up", label: "Plan")
                }
                Link(destination: deepLink(.fares)) {
                    bigTile(symbol: "function", label: "Fares")
                }
                Link(destination: deepLink(.alerts)) {
                    bigTile(symbol: "bell.fill", label: "Alerts")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func actionRow(symbol: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.white.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
    }

    private func bigTile(symbol: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private enum Tab: String { case plan, fares, alerts }

    private func deepLink(_ tab: Tab) -> URL {
        URL(string: "commute://\(tab.rawValue)")!
    }
}
