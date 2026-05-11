import SwiftUI

// MARK: - View models
// CM-prefixed to keep these display-layer types separate from the data-layer
// `BusStop` defined in `Models/BusStop.swift`.
struct CMBusStop: Identifiable {
    let id = UUID()
    let name: String
    let code: String
    let walkMinutes: Int
    let walkMeters: Int
    let services: [CMBusService]
    let hasLiveData: Bool
}

struct CMBusService: Identifiable {
    let id = UUID()
    let number: String
    let destination: String
    let nextMinutes: Int?
    let followingMinutes: Int?
}

// MARK: - Screen
struct BusStopsView: View {
    @Environment(\.dismiss) private var dismiss

    let stops: [CMBusStop]
    let nearbyLocation: String
    let minutesAgo: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, CMSpacing.screenHorizontal)
                    .padding(.top, 4)

                title
                    .padding(.horizontal, CMSpacing.screenHorizontal)
                    .padding(.top, 6)

                CMSearchBar(placeholder: "Search stop, bus number")
                    .padding(.horizontal, CMSpacing.screenHorizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 18)

                LazyVStack(spacing: CMSpacing.cardGap) {
                    ForEach(stops) { stop in
                        BusStopCard(stop: stop)
                    }
                }
                .padding(.horizontal, CMSpacing.screenHorizontal)
                .padding(.bottom, 100)
            }
        }
        .background(Color(.secondarySystemBackground).ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(.secondarySystemBackground), in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            LiveStatusPill(minutesAgo: minutesAgo)
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Bus stops")
                .font(.title)
                .fontWeight(.medium)
                .kerning(-0.5)

            HStack(spacing: 4) {
                Image(systemName: "mappin")
                    .font(.system(size: 11))
                Text("Near \(nearbyLocation)")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Bus stop card
struct BusStopCard: View {
    let stop: CMBusStop

    @State private var isExpanded = false

    private let collapsedLimit = 3

    private var visibleServices: [CMBusService] {
        guard !isExpanded, stop.services.count > collapsedLimit else { return stop.services }
        return Array(stop.services.prefix(collapsedLimit))
    }

    private var hiddenCount: Int { max(0, stop.services.count - collapsedLimit) }

    var body: some View {
        CMCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(stop.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if stop.hasLiveData {
                        WalkDistanceLabel(walkMinutes: stop.walkMinutes, meters: stop.walkMeters)
                    } else {
                        WalkDistanceLabel(
                            walkMinutes: stop.walkMinutes,
                            meters: stop.walkMeters,
                            extraSuffix: " · \(stop.services.count) services"
                        )
                    }
                }
                Spacer()
                if stop.hasLiveData {
                    Text("Stop \(stop.code)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if stop.hasLiveData {
                Divider()
                    .padding(.top, 12)

                VStack(spacing: CMSpacing.rowGap) {
                    ForEach(Array(visibleServices.enumerated()), id: \.offset) { _, svc in
                        BusArrivalRow(
                            busNumber: svc.number,
                            destination: svc.destination,
                            nextMinutes: svc.nextMinutes,
                            followingMinutes: svc.followingMinutes
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - Preview
#Preview {
    NavigationStack {
        BusStopsView(
            stops: [
                CMBusStop(
                    name: "Opp Tanjong Pagar Stn",
                    code: "03217",
                    walkMinutes: 3,
                    walkMeters: 278,
                    services: [
                        CMBusService(number: "10", destination: "Tampines Int", nextMinutes: 0, followingMinutes: 12),
                        CMBusService(number: "75", destination: "Marine Parade", nextMinutes: 3, followingMinutes: 11),
                        CMBusService(number: "131", destination: "Lor 1 Geylang", nextMinutes: 7, followingMinutes: 14),
                    ],
                    hasLiveData: true
                ),
                CMBusStop(
                    name: "Tanjong Pagar Stn Exit C",
                    code: "03218",
                    walkMinutes: 4,
                    walkMeters: 310,
                    services: [
                        CMBusService(number: "10", destination: "Tampines Int", nextMinutes: 2, followingMinutes: 9),
                        CMBusService(number: "57", destination: "Bt Panjang Int", nextMinutes: 6, followingMinutes: 18),
                        CMBusService(number: "100", destination: "St Michael's Ter", nextMinutes: 9, followingMinutes: 21),
                        CMBusService(number: "131", destination: "Lor 1 Geylang", nextMinutes: 12, followingMinutes: 25),
                        CMBusService(number: "162", destination: "Yishun Int", nextMinutes: 14, followingMinutes: 28),
                        CMBusService(number: "186", destination: "Clementi Int", nextMinutes: 18, followingMinutes: 32),
                        CMBusService(number: "851", destination: "Yishun Int", nextMinutes: 22, followingMinutes: 40),
                    ],
                    hasLiveData: true
                ),
                CMBusStop(
                    name: "Aft Maxwell Rd",
                    code: "03219",
                    walkMinutes: 6,
                    walkMeters: 460,
                    services: Array(repeating: CMBusService(number: "—", destination: "—", nextMinutes: nil, followingMinutes: nil), count: 4),
                    hasLiveData: false
                ),
            ],
            nearbyLocation: "Tanjong Pagar",
            minutesAgo: 1
        )
    }
}
