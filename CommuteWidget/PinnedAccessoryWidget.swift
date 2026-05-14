import SwiftUI
import WidgetKit

/// Lock-screen accessory widget — circular and rectangular variants. Shows
/// the user's first pinned bus + stop. ETA isn't in `PinnedItemsSnapshot`
/// today (snapshot writer doesn't fetch arrivals), so the rectangular
/// variant surfaces stop name + a "Tap to track" affordance instead of a
/// stale countdown.
struct PinnedAccessoryWidget: Widget {
    let kind: String = "PinnedAccessoryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PinnedItemsProvider()) { entry in
            PinnedAccessoryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Pinned · Lock screen")
        .description("Quick glance at your first pinned bus on the Lock Screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

// Reuses the timeline provider declared in `PinnedItemsWidget.swift`.
private struct PinnedItemsProvider: TimelineProvider {
    func placeholder(in context: Context) -> PinnedItemsEntry {
        PinnedItemsEntry(date: Date(), snapshot: nil)
    }
    func getSnapshot(in context: Context, completion: @escaping (PinnedItemsEntry) -> Void) {
        completion(PinnedItemsEntry(date: Date(), snapshot: SharedSnapshot.readPinned()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PinnedItemsEntry>) -> Void) {
        let entry = PinnedItemsEntry(date: Date(), snapshot: SharedSnapshot.readPinned())
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600))))
    }
}

private struct PinnedAccessoryView: View {
    let entry: PinnedItemsEntry
    @Environment(\.widgetFamily) private var family

    private var firstBus: String? { entry.snapshot?.busNumbers.first }
    private var firstStop: PinnedItemsSnapshot.Stop? { entry.snapshot?.stops.first }

    var body: some View {
        switch family {
        case .accessoryCircular:    circular
        case .accessoryRectangular: rectangular
        default:                    EmptyView()
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "star.fill")
                    .font(.system(size: 9, weight: .bold))
                    .widgetAccentable()
                Text(firstBus ?? "—")
                    .font(.system(size: 14, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .widgetAccentable()
            }
        }
    }

    private var rectangular: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("PINNED")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.6)
                }
                .widgetAccentable()
                if let bus = firstBus {
                    Text("Bus \(bus)")
                        .font(.system(size: 14, weight: .bold))
                        .widgetAccentable()
                } else {
                    Text("No pin")
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(firstStop?.name ?? "Open Commute to pin a stop")
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}
