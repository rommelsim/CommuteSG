import SwiftUI
import WidgetKit

/// Reads the latest LTA TrainServiceAlerts snapshot the main app wrote to
/// the shared App Group, and renders one row per MRT line with a green/red
/// status pill. If the snapshot is missing or stale (>30 min), shows a
/// neutral "Open Commute to refresh" message.
struct MRTStatusWidget: Widget {
    let kind: String = "MRTStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MRTStatusProvider()) { entry in
            MRTStatusWidgetView(entry: entry)
                // iOS 17+ widgets must declare their background via
                // `.containerBackground(for: .widget)` — without it the
                // system rejects the widget with "Please adopt
                // containerBackgroundApi".
                .containerBackground(for: .widget) {
                    Color(.systemBackground)
                }
        }
        .configurationDisplayName("MRT line status")
        .description("Live disruptions on Singapore's MRT.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - Entry / Provider

struct MRTStatusEntry: TimelineEntry {
    let date: Date
    let snapshot: MRTStatusSnapshot?
}

private struct MRTStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> MRTStatusEntry {
        MRTStatusEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (MRTStatusEntry) -> Void) {
        completion(MRTStatusEntry(date: Date(), snapshot: SharedSnapshot.readMRT()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MRTStatusEntry>) -> Void) {
        let entry = MRTStatusEntry(date: Date(), snapshot: SharedSnapshot.readMRT())
        // Re-query in 15 min — the main app refreshes the snapshot every
        // time the user opens the Alerts tab, so this just covers the case
        // where the user hasn't opened the app for a while.
        let next = Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - View

struct MRTStatusWidgetView: View {
    let entry: MRTStatusEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let snapshot = entry.snapshot, isFresh(snapshot) {
            content(snapshot)
        } else {
            staleState
        }
    }

    private func isFresh(_ snap: MRTStatusSnapshot) -> Bool {
        Date().timeIntervalSince(snap.updatedAt) < 30 * 60
    }

    @ViewBuilder
    private func content(_ snap: MRTStatusSnapshot) -> some View {
        let disruptedCount = snap.lines.filter(\.isDisrupted).count
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("MRT")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                if disruptedCount == 0 {
                    statusBadge(text: "All clear", color: .green)
                } else {
                    statusBadge(text: "\(disruptedCount) disrupted", color: .red)
                }
            }
            ForEach(visibleLines(from: snap), id: \.code) { line in
                lineRow(line)
            }
            Spacer(minLength: 0)
            Text("Updated \(snap.updatedAt, style: .relative) ago")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .padding(14)
    }

    private func visibleLines(from snap: MRTStatusSnapshot) -> [MRTStatusSnapshot.Line] {
        // Medium fits ~4 rows; large fits all 7.
        let limit = family == .systemMedium ? 4 : snap.lines.count
        // Show disrupted lines first so the user sees problems at a glance.
        let sorted = snap.lines.sorted { lhs, rhs in
            if lhs.isDisrupted != rhs.isDisrupted { return lhs.isDisrupted }
            return lhs.code < rhs.code
        }
        return Array(sorted.prefix(limit))
    }

    private func lineRow(_ line: MRTStatusSnapshot.Line) -> some View {
        HStack(spacing: 8) {
            Text(line.code)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(lineColor(line.code))
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            Text(line.name)
                .font(.system(size: 12))
                .lineLimit(1)
            Spacer()
            Image(systemName: line.isDisrupted ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(line.isDisrupted ? .red : .green)
        }
    }

    private func lineColor(_ code: String) -> Color {
        switch code {
        case "EW": Color(red: 0/255, green: 150/255, blue: 69/255)
        case "NS": Color(red: 212/255, green: 46/255, blue: 18/255)
        case "NE": Color(red: 153/255, green: 0/255, blue: 170/255)
        case "CC", "CE": Color(red: 250/255, green: 158/255, blue: 13/255)
        case "DT": Color(red: 0/255, green: 94/255, blue: 196/255)
        case "TE": Color(red: 157/255, green: 89/255, blue: 24/255)
        default:   Color.gray
        }
    }

    private func statusBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color)
            .clipShape(Capsule())
    }

    private var staleState: some View {
        VStack(spacing: 6) {
            Image(systemName: "tram.fill")
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
            Text("Open Commute to refresh")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(14)
    }
}
