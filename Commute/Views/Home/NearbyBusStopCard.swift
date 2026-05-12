import SwiftUI

/// One stop's section inside the grouped "Nearby transit" container.
///
/// Tap zones (inner zones win, all with `CardButtonStyle` press animation):
///   • Anywhere in the section that isn't a more specific control →
///     opens the bus-stop detail sheet (`onTapStop`). Whole card scales.
///   • Each bus row (chip + ETA, two narrow buttons) → opens live
///     tracking for that bus (`onTapBus`). Just the row scales.
///   • The walk-time / chevron pill on the right of the header → toggles
///     expand/collapse inline. Just the pill scales.
///   • The "+N more" link → expands.
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
        Button {
            onTapStop()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                ForEach(Array(visibleArrivals.enumerated()), id: \.offset) { _, arrival in
                    busRow(arrival)
                }

                if !isExpanded && hiddenCount > 0 {
                    moreButton
                } else {
                    Spacer().frame(height: 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(CardButtonStyle(pressedScale: 0.985))
    }

    private var header: some View {
        HStack(spacing: 8) {
            BusStopIcon(size: 13, color: Color.cfTextSecondary, strokeWidth: 2.2)
            VStack(alignment: .leading, spacing: 1) {
                Text(stop.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.cfTextPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if !stop.road.isEmpty {
                    Text(stop.road)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.cfTextTertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            Spacer(minLength: 8)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.cfTextTertiary)
                    Text("\(walkMinutes) min")
                        .font(.system(size: 12, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.cfTextSecondary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.cfTextMuted)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.vertical, 8)
                .padding(.leading, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(CardButtonStyle(pressedScale: 0.92))
        }
    }

    /// Bus row uses TWO narrow buttons (chip on the left, ETA cluster on the
    /// right). The middle Spacer is plain layout — taps there have no inner
    /// button to consume them, so they fall through to the outer Button and
    /// open the stop sheet. Each tap target keeps a 44pt-tall hit area.
    private func busRow(_ arrival: BusArrival) -> some View {
        HStack(spacing: 10) {
            Button { onTapBus(arrival) } label: {
                ServiceChip(service: arrival.serviceNo, size: .sm)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(CardButtonStyle(pressedScale: 0.92))
            .accessibilityLabel("Track bus \(arrival.serviceNo)")

            Spacer(minLength: 0)

            Button { onTapBus(arrival) } label: {
                HStack(spacing: 6) {
                    if arrival.nextArrivalCrowd == .limited {
                        CrowdPeople(level: .high, size: 10)
                    }
                    ETAView(
                        urgent: (arrival.nextArrivalMinutes ?? Int.max) <= 1,
                        value: arrival.nextArrivalMinutes.map(String.init) ?? "—",
                        size: .sm
                    )
                }
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(CardButtonStyle(pressedScale: 0.92))
            .accessibilityHidden(true)  // duplicate of the chip button for VoiceOver
        }
        .padding(.horizontal, 16)
    }

    private var moreButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { isExpanded = true }
        } label: {
            Text("+\(hiddenCount) more")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.cfTextMuted)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(CardButtonStyle(pressedScale: 0.95))
    }
}
