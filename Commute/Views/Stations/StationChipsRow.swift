import SwiftUI

/// "Browse stations" card — third section of the Station Browser. Owns:
///   • search bar with clear button (filters chips live)
///   • line filter pills: All / CC / DT / EW / NS / NE
///   • horizontal-scrolling chip strip with stagger-in animation
///
/// Filter / search state is local — caller hands in the full snapshot
/// list once and gets a tap callback for each chip selection.
struct StationChipsRow: View {
    let snapshots: [StationCrowdSnapshot]
    /// The user's current station — gets the white "current" card
    /// treatment on its chip. Pass nil to disable.
    var currentStationCode: String?
    let onPick: (StationCrowdSnapshot) -> Void

    @State private var query: String = ""
    @State private var filter: LineFilter = .all

    enum LineFilter: Hashable, CaseIterable {
        case all, cc, dt, ew, ns, ne

        var label: String {
            switch self {
            case .all: "All lines"
            case .cc:  "Circle"
            case .dt:  "Downtown"
            case .ew:  "East-West"
            case .ns:  "North-South"
            case .ne:  "North-East"
            }
        }

        var line: MRTLine? {
            switch self {
            case .all: nil
            case .cc:  .cc
            case .dt:  .dt
            case .ew:  .ew
            case .ns:  .ns
            case .ne:  .ne
            }
        }
    }

    private var filtered: [StationCrowdSnapshot] {
        var list = snapshots
        if let line = filter.line {
            list = list.filter { $0.line == line }
        }
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            list = list.filter {
                $0.stationCode.lowercased().contains(q)
                    || $0.stationName.lowercased().contains(q)
            }
        }
        return list
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel
                searchField
                filterPills
            }
            .padding(14)

            Divider()
                .background(Color.cfHairline)
                .padding(.horizontal, 14)

            chipStrip
                .padding(.top, 12)
                .padding(.bottom, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.cfHairline, lineWidth: 0.5)
        )
    }

    private var sectionLabel: some View {
        Text("Browse stations")
            .font(.system(size: 10, weight: .bold))
            .tracking(0.7)
            .textCase(.uppercase)
            .foregroundStyle(Color.cfTextTertiary)
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.cfTextPrimary.opacity(0.38))
            TextField("Station name or code…", text: $query)
                .font(.system(size: 14))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.cfTextPrimary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.cfTextPrimary.opacity(0.06))
        )
    }

    // MARK: - Filter pills

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(LineFilter.allCases, id: \.self) { f in
                    filterPill(f)
                }
            }
            .padding(.bottom, 2)
        }
    }

    private func filterPill(_ f: LineFilter) -> some View {
        let active = filter == f
        let line = f.line
        return Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                filter = f
            }
        } label: {
            HStack(spacing: 5) {
                if let line {
                    Circle()
                        .fill(line.background)
                        .frame(width: 7, height: 7)
                }
                Text(f.label)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(active ? Color.white : Color.cfTextSecondary)
            .background(activeBackground(for: f, line: line))
        }
        .buttonStyle(.plain)
    }

    /// Active pill takes the line colour. "All" falls back to a neutral
    /// near-black so it's visually distinct from any single line.
    @ViewBuilder
    private func activeBackground(for f: LineFilter, line: MRTLine?) -> some View {
        let active = filter == f
        Capsule()
            .fill(active
                  ? (line?.background ?? Color(red: 0.11, green: 0.11, blue: 0.12))
                  : Color.cfTextPrimary.opacity(0.07))
    }

    // MARK: - Chip strip

    @ViewBuilder
    private var chipStrip: some View {
        let list = filtered
        if list.isEmpty {
            Text("No stations found")
                .font(.system(size: 12))
                .foregroundStyle(Color.cfTextTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(list.enumerated()), id: \.element.id) { idx, snap in
                        StationChip(
                            snapshot: snap,
                            isCurrent: snap.stationCode == currentStationCode,
                            onTap: { onPick(snap) }
                        )
                        // Stagger entry — 24ms per chip per handoff.
                        .transition(.scale(scale: 0.82)
                                    .combined(with: .opacity)
                                    .animation(.spring(response: 0.28, dampingFraction: 0.7)
                                        .delay(Double(min(idx, 12)) * 0.024)))
                    }
                }
                .padding(.horizontal, 14)
            }
            // The whole strip animates on filter / query changes so
            // chips fade out + bounce back in together.
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: filter)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: query)
        }
    }
}

/// Single station chip — line dot, code, name, crowd tag.
private struct StationChip: View {
    let snapshot: StationCrowdSnapshot
    let isCurrent: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                Circle()
                    .fill(snapshot.line.background)
                    .frame(width: 10, height: 10)
                Text(snapshot.stationCode)
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color.cfTextPrimary)
                Text(snapshot.stationName)
                    .font(.system(size: 9))
                    .foregroundStyle(Color.cfTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 64)
                tagPill
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 11)
            .frame(minWidth: 70)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(isCurrent ? Color.appSurface : Color.cfTextPrimary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(isCurrent ? Color.cfHairline : Color.clear, lineWidth: 0.5)
            )
            .shadow(color: isCurrent ? Color.black.opacity(0.08) : .clear,
                    radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(snapshot.stationName), \(snapshot.currentTier.tag)")
    }

    private var tagPill: some View {
        Text(snapshot.currentTier.tag)
            .font(.system(size: 9, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(tagFg)
            .background(tagBg, in: RoundedRectangle(cornerRadius: 5))
    }

    private var tagBg: Color {
        switch snapshot.currentTier {
        case .low:      Color.appSuccess.opacity(0.14)
        case .moderate: Color.cfTextPrimary.opacity(0.08)
        case .busy:     Color.appDanger.opacity(0.14)
        case .unknown:  Color.cfTextPrimary.opacity(0.05)
        }
    }

    private var tagFg: Color {
        switch snapshot.currentTier {
        case .low:      Color.appSuccess
        case .moderate: Color.cfTextSecondary
        case .busy:     Color.appDanger
        case .unknown:  Color.cfTextTertiary
        }
    }
}

// Preview removed — service is now async + live, no synchronous fixture.
