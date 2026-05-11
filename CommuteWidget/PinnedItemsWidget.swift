import SwiftUI
import WidgetKit

/// Home-screen widget that surfaces the user's pinned (starred) bus stops
/// and bus service numbers. Reads `PinnedItemsSnapshot` written by the
/// main app from the shared App Group; if the snapshot is missing, shows
/// an "Open Commute and star a stop" prompt.
struct PinnedItemsWidget: Widget {
    let kind: String = "PinnedItemsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PinnedItemsProvider()) { entry in
            PinnedItemsWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(.systemBackground)
                }
        }
        .configurationDisplayName("Pinned · Buses & stops")
        .description("Quick access to your starred stops and bus services.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Entry / Provider

struct PinnedItemsEntry: TimelineEntry {
    let date: Date
    let snapshot: PinnedItemsSnapshot?
}

private struct PinnedItemsProvider: TimelineProvider {
    func placeholder(in context: Context) -> PinnedItemsEntry {
        PinnedItemsEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (PinnedItemsEntry) -> Void) {
        completion(PinnedItemsEntry(date: Date(), snapshot: SharedSnapshot.readPinned()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PinnedItemsEntry>) -> Void) {
        let entry = PinnedItemsEntry(date: Date(), snapshot: SharedSnapshot.readPinned())
        // Pinned data only changes when the user toggles a star, which the
        // app reload-triggers explicitly. Re-poll every hour as a safety net.
        let next = Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - View

struct PinnedItemsWidgetView: View {
    let entry: PinnedItemsEntry
    @Environment(\.widgetFamily) private var family

    private var hasContent: Bool {
        guard let s = entry.snapshot else { return false }
        return !s.stops.isEmpty || !s.busNumbers.isEmpty
    }

    var body: some View {
        if let snap = entry.snapshot, hasContent {
            switch family {
            case .systemSmall:  small(snap)
            case .systemMedium: medium(snap)
            default:            large(snap)
            }
        } else {
            emptyState
        }
    }

    // MARK: Sections

    private func header(_ subtitle: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "star.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(red: 0.73, green: 0.46, blue: 0.09))
            Text("PINNED")
                .font(.system(size: 9, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            Spacer()
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func subsectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 8, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(.tertiary)
    }

    // MARK: Small (155×155) — top 3 mixed

    private func small(_ s: PinnedItemsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            header("")
            ForEach(Array(topItems(s, limit: 3).enumerated()), id: \.offset) { _, item in
                row(item)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Medium (329×155) — split bus / stop columns

    private func medium(_ s: PinnedItemsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            header(summary(s))
            HStack(alignment: .top, spacing: 12) {
                if !s.busNumbers.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        subsectionLabel("Buses")
                        ForEach(s.busNumbers.prefix(3), id: \.self) { busChip($0) }
                    }
                }
                if !s.stops.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        subsectionLabel("Stops")
                        ForEach(s.stops.prefix(3), id: \.code) { stopRow($0) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Large (329×345) — full lists

    private func large(_ s: PinnedItemsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header(summary(s))
            if !s.busNumbers.isEmpty {
                subsectionLabel("Buses")
                FlowLayout(spacing: 6) {
                    ForEach(s.busNumbers, id: \.self) { busChip($0) }
                }
            }
            if !s.stops.isEmpty {
                subsectionLabel("Stops")
                    .padding(.top, s.busNumbers.isEmpty ? 0 : 4)
                ForEach(s.stops.prefix(8), id: \.code) { stopRow($0) }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Atoms

    private func busChip(_ number: String) -> some View {
        Text(number)
            .font(.system(size: 12, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(.primary)
            .frame(minWidth: 36, minHeight: 22)
            .padding(.horizontal, 8)
            .background(Color.primary.opacity(0.06), in: Capsule(style: .continuous))
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5))
    }

    private func stopRow(_ stop: PinnedItemsSnapshot.Stop) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "signpost.right.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(stop.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }

    /// Used by the small layout: mix buses + stops (buses first, capped).
    private enum Item: Hashable {
        case bus(String)
        case stop(PinnedItemsSnapshot.Stop)
    }

    private func topItems(_ s: PinnedItemsSnapshot, limit: Int) -> [Item] {
        var items: [Item] = []
        items.append(contentsOf: s.busNumbers.map(Item.bus))
        items.append(contentsOf: s.stops.map(Item.stop))
        return Array(items.prefix(limit))
    }

    @ViewBuilder
    private func row(_ item: Item) -> some View {
        switch item {
        case .bus(let n):  HStack(spacing: 6) { busChip(n); Text("Bus").font(.system(size: 10)).foregroundStyle(.secondary); Spacer() }
        case .stop(let s): stopRow(s)
        }
    }

    private func summary(_ s: PinnedItemsSnapshot) -> String {
        let bn = s.busNumbers.count
        let sn = s.stops.count
        switch (bn, sn) {
        case (0, _): return "\(sn) stop\(sn == 1 ? "" : "s")"
        case (_, 0): return "\(bn) bus\(bn == 1 ? "" : "es")"
        default:     return "\(bn + sn) items"
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "star")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.secondary)
            Text("Nothing pinned")
                .font(.system(size: 13, weight: .bold))
            Text("Star a stop or bus in Commute to pin it here.")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Tiny flow layout (chip wrapping for the large size)
// Local to this widget so we don't drag in a shared Layout module.

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sv.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
