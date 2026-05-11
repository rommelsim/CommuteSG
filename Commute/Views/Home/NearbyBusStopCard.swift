import SwiftUI

/// One stop's section inside the grouped "Nearby transit" container.
/// Header row (BusStopIcon + name + walk + chevron) tappable two ways:
/// the name area pushes the stop detail; the walk area expands inline.
/// Collapsed shows a single bus row (chip + ETA only — no destination on
/// home, that's stop-page info). Expanded shows all buses. Below the visible
/// bus(es), a quiet "+N more" link reveals the rest. Designed to sit
/// directly inside a `glassSurface()` container with hairline dividers
/// between siblings — has NO own background.
struct NearbyBusStopCard: View {
    let stop: BusStop
    let arrivals: [BusArrival]
    let onTapStop: () -> Void
    let onTapBus: (BusArrival) -> Void

    @State private var isExpanded = false

    private var visibleArrivals: [BusArrival] {
        isExpanded ? arrivals : Array(arrivals.prefix(1))
    }

    private var hiddenCount: Int { max(0, arrivals.count - 1) }

    private var walkMinutes: Int {
        StopsAdapters.walkMinutes(forMeters: stop.distanceMeters ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)

            ForEach(Array(visibleArrivals.enumerated()), id: \.offset) { _, arrival in
                busRow(arrival)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
            }

            if !isExpanded && hiddenCount > 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded = true }
                } label: {
                    Text("+\(hiddenCount) more")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.cfTextMuted)
                        .padding(.leading, 16 + 52)  // align with bus row content
                        .padding(.bottom, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else if isExpanded && hiddenCount > 0 {
                Spacer().frame(height: 6)
            } else {
                Spacer().frame(height: 4)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onTapStop()
            }) {
                HStack(spacing: 6) {
                    BusStopIcon(size: 13, color: Color.black.opacity(0.60), strokeWidth: 2.2)
                    Text(stop.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.cfTextPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.45))
                    Text("\(walkMinutes) min")
                        .font(.system(size: 12, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.black.opacity(0.65))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.cfTextMuted)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func busRow(_ arrival: BusArrival) -> some View {
        Button { onTapBus(arrival) } label: {
            HStack(spacing: 10) {
                ServiceChip(service: arrival.serviceNo, size: .sm)
                Spacer(minLength: 0)
                if arrival.nextArrivalCrowd == .limited {
                    CrowdPeople(level: .high, size: 10)
                }
                ETAView(
                    urgent: (arrival.nextArrivalMinutes ?? Int.max) <= 1,
                    value: arrival.nextArrivalMinutes.map(String.init) ?? "—",
                    size: .sm
                )
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Track bus \(arrival.serviceNo)")
    }
}
