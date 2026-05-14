import SwiftUI

/// Horizontally scrollable journey strip — top section of the Station
/// Browser. One dot per stop, connecting line drawn through the dot
/// row. Single neutral colour throughout per the v2 handoff: the line
/// doesn't change colour by state, only the dots do.
///
/// Dot states (`JourneyNode.State`):
///   • `done`     — small filled dot (60%-alpha primary)
///   • `current`  — large solid dot with halo
///   • `transfer` — ring outline (white fill, primary border)
///   • `upcoming` — small dot at low opacity
struct JourneyStripView: View {
    let nodes: [JourneyNode]
    /// Optional destination label rendered next to the section title
    /// (e.g. "Marina Bay Sands"). Drops out when nil.
    var destinationLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(nodes.enumerated()), id: \.element.id) { idx, node in
                        column(for: node, index: idx, total: nodes.count)
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.cfHairline, lineWidth: 0.5)
        )
    }

    private var header: some View {
        HStack {
            Text("Your journey")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.7)
                .textCase(.uppercase)
                .foregroundStyle(Color.cfTextTertiary)
            if let destinationLabel {
                Text(destinationLabel)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Color.cfTextTertiary)
            }
            Spacer()
        }
    }

    // MARK: - Layout constants
    //
    // Pinning the column width *and* the dot-row height keeps every
    // column geometrically identical. Without the fixed dot-row height
    // the 13pt current dot grew its row, dropping the connector line
    // below the smaller (9pt) sibling dots — see the audit screenshot
    // from 2026-05-14.

    private static let columnWidth: CGFloat = 70
    /// Tall enough to contain the largest dot (13pt) plus the 3pt halo
    /// ring around the current dot without clipping.
    private static let dotRowHeight: CGFloat = 20

    // MARK: - Per-stop column

    private func column(for node: JourneyNode, index: Int, total: Int) -> some View {
        VStack(spacing: 6) {
            dotRow(for: node, index: index, total: total)
            label(for: node)
        }
        .frame(width: Self.columnWidth)
    }

    /// Dot + flanking line segments. Drawn in a `ZStack` so the
    /// horizontal hairline sits behind a centred dot — no more
    /// per-dot-size alignment drift. The row uses a fixed height so
    /// every column produces an identical bounding box, regardless of
    /// which state's dot is inside.
    private func dotRow(for node: JourneyNode, index: Int, total: Int) -> some View {
        ZStack {
            // Two half-segments left + right of centre. Each can be
            // tinted independently so the "trail behind me" shows
            // darker once you've crossed a stop.
            HStack(spacing: 0) {
                segment(visible: index > 0,
                        color: leadingSegmentColor(state: node.state))
                segment(visible: index < total - 1,
                        color: trailingSegmentColor(state: node.state))
            }
            dot(for: node.state)
        }
        .frame(width: Self.columnWidth, height: Self.dotRowHeight)
    }

    private func label(for node: JourneyNode) -> some View {
        let isCurrent = node.state == .current
        return VStack(spacing: 1) {
            Text(node.stationCode)
                .font(.system(size: 9, weight: isCurrent ? .semibold : .regular).monospacedDigit())
                .foregroundStyle(isCurrent ? Color.cfTextPrimary : Color.cfTextTertiary)
            Text(node.stationName)
                .font(.system(size: 9, weight: isCurrent ? .medium : .regular))
                .foregroundStyle(isCurrent ? Color.cfTextPrimary : Color.cfTextSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: Self.columnWidth)
        }
    }

    // MARK: - Atoms

    @ViewBuilder
    private func dot(for state: JourneyNode.State) -> some View {
        switch state {
        case .done:
            Circle()
                .fill(Color.cfTextPrimary.opacity(0.4))
                .frame(width: 9, height: 9)
        case .current:
            // Halo doubles as a "I'm here" focus ring. Drawn as a
            // separate Circle so the inner solid stays exactly 13pt
            // (not 13 + 2× stroke insets).
            ZStack {
                Circle()
                    .fill(Color.cfTextPrimary.opacity(0.12))
                    .frame(width: 19, height: 19)
                Circle()
                    .fill(Color.cfTextPrimary)
                    .frame(width: 13, height: 13)
            }
        case .transfer:
            Circle()
                .strokeBorder(Color.cfTextPrimary.opacity(0.5), lineWidth: 2)
                .background(Circle().fill(Color.appSurface))
                .frame(width: 11, height: 11)
        case .upcoming:
            Circle()
                .fill(Color.cfTextPrimary.opacity(0.18))
                .frame(width: 9, height: 9)
        }
    }

    /// Hairline half-segment. `visible: false` renders fully clear so
    /// the line doesn't dangle past the first / last station while
    /// still consuming its half of the column for layout.
    private func segment(visible: Bool, color: Color) -> some View {
        Rectangle()
            .fill(visible ? color : .clear)
            .frame(height: 1.5)
            .frame(maxWidth: .infinity)
    }

    /// Left-of-dot segment colour. Darker when we've already passed
    /// this dot — the segment trailing a done dot, or leading into the
    /// current dot, all count as "behind me".
    private func leadingSegmentColor(state: JourneyNode.State) -> Color {
        switch state {
        case .done, .current: Color.cfTextPrimary.opacity(0.4)
        case .transfer, .upcoming: Color.cfHairline
        }
    }

    /// Right-of-dot segment colour. Only `.done` should bridge into
    /// the next dot as a "trail" — `.current`'s trailing edge is the
    /// boundary between behind-me and ahead-of-me, so it stays neutral.
    private func trailingSegmentColor(state: JourneyNode.State) -> Color {
        switch state {
        case .done: Color.cfTextPrimary.opacity(0.4)
        case .current, .transfer, .upcoming: Color.cfHairline
        }
    }
}

#if DEBUG
#Preview("Journey strip — Clementi → MBS") {
    JourneyStripView(
        nodes: [
            JourneyNode(stationCode: "CC21", stationName: "Holland V.",  line: .cc, state: .done),
            JourneyNode(stationCode: "CC22", stationName: "Buona Vista", line: .cc, state: .done),
            JourneyNode(stationCode: "CC23", stationName: "one-north",   line: .cc, state: .current),
            JourneyNode(stationCode: "CC24", stationName: "Kent Ridge",  line: .cc, state: .transfer),
            JourneyNode(stationCode: "DT16", stationName: "Bayfront",    line: .dt, state: .transfer),
            JourneyNode(stationCode: "DT20", stationName: "Marina Bay",  line: .dt, state: .upcoming)
        ],
        destinationLabel: "Marina Bay Sands"
    )
    .padding(16)
    .background(Color.cfPageBackground)
}
#endif
