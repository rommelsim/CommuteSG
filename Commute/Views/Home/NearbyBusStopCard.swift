import SwiftUI

/// Home-screen nearby bus stop card. Uses the CM design language (CMCard +
/// BusArrivalRow). Tap on the header opens the bus stop detail sheet; tap on
/// an arrival row jumps to live tracking. Collapses to 3 services per the
/// design language; "Show N more" expands inline.
struct NearbyBusStopCard: View {
    let stop: BusStop
    let arrivals: [BusArrival]
    let onTapStop: () -> Void
    let onTapBus: (BusArrival) -> Void

    @State private var isExpanded = false

    private let collapsedLimit = 3

    private var visibleArrivals: [BusArrival] {
        guard !isExpanded, arrivals.count > collapsedLimit else { return arrivals }
        return Array(arrivals.prefix(collapsedLimit))
    }

    private var hiddenCount: Int { max(0, arrivals.count - collapsedLimit) }

    private var walkMinutes: Int {
        StopsAdapters.walkMinutes(forMeters: stop.distanceMeters ?? 0)
    }

    var body: some View {
        CMCard {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onTapStop()
            }) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stop.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        WalkDistanceLabel(
                            walkMinutes: walkMinutes,
                            meters: stop.distanceMeters ?? 0
                        )
                    }
                    Spacer()
                    Text("Stop \(stop.id)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !arrivals.isEmpty {
                Divider()
                    .padding(.top, 12)

                VStack(spacing: CMSpacing.rowGap) {
                    ForEach(Array(visibleArrivals.enumerated()), id: \.offset) { _, arrival in
                        Button {
                            onTapBus(arrival)
                        } label: {
                            BusArrivalRow(
                                busNumber: arrival.serviceNo,
                                destination: StopsAdapters.destinationLabel(for: arrival),
                                nextMinutes: arrival.nextArrivalMinutes,
                                followingMinutes: arrival.followingArrivalMinutes
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Track bus \(arrival.serviceNo)")
                    }

                    if hiddenCount > 0 {
                        Button(action: { withAnimation { isExpanded.toggle() } }) {
                            HStack(spacing: 6) {
                                Text(isExpanded
                                     ? "Show fewer services"
                                     : "Show \(hiddenCount) more service\(hiddenCount == 1 ? "" : "s")")
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12))
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.cmAccent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                }
                .padding(.top, CMSpacing.rowGap)
            }
        }
    }
}
