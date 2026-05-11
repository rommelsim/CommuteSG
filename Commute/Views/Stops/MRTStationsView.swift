import SwiftUI

// MARK: - View models
// CM-prefixed to keep these display-layer types separate from the data-layer
// `MRTStation` / `TrainArrival` defined in `Models/`.
struct CMMRTStation: Identifiable {
    let id = UUID()
    let name: String
    let codes: [String]
    let walkMinutes: Int
    let walkMeters: Int
    let arrivalsByLine: [String: [CMTrainArrival]]
}

struct CMTrainArrival {
    let towardsDestination: String
    let nextClockTime: String
    let minutesUntil: Int
}

// MARK: - Screen
struct MRTStationsView: View {
    @Environment(\.dismiss) private var dismiss

    let stations: [CMMRTStation]
    let nearbyLocation: String
    let minutesAgo: Int

    private let filters = ["Nearest", "All lines", "Favourites"]
    @State private var selectedFilter = "Nearest"

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.horizontal, CMSpacing.screenHorizontal)
                        .padding(.top, 4)

                    title
                        .padding(.horizontal, CMSpacing.screenHorizontal)
                        .padding(.top, 6)

                    CMSearchBar(placeholder: "Search station")
                        .padding(.horizontal, CMSpacing.screenHorizontal)
                        .padding(.top, 16)

                    filterChips
                        .padding(.top, 14)

                    LazyVStack(spacing: CMSpacing.cardGap) {
                        ForEach(stations) { station in
                            StationCard(station: station)
                        }
                    }
                    .padding(.horizontal, CMSpacing.screenHorizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 100)
                }
            }
            .background(Color(.secondarySystemBackground).ignoresSafeArea())
            .navigationBarBackButtonHidden(true)
        }
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
            Text("MRT stations")
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

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(filters, id: \.self) { f in
                    CMFilterChip(
                        label: f,
                        isSelected: f == selectedFilter,
                        action: { selectedFilter = f }
                    )
                }
            }
            .padding(.horizontal, CMSpacing.screenHorizontal)
        }
    }
}

// MARK: - Station card
struct StationCard: View {
    let station: CMMRTStation

    var body: some View {
        CMCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(station.name)
                        .font(.body)
                        .fontWeight(.medium)
                    WalkDistanceLabel(
                        walkMinutes: station.walkMinutes,
                        meters: station.walkMeters
                    )
                }
                Spacer()
                HStack(spacing: 4) {
                    ForEach(station.codes, id: \.self) { code in
                        MRTLinePill(code: code)
                    }
                }
            }

            ForEach(station.codes.compactMap { code in
                station.arrivalsByLine[String(code.prefix { $0.isLetter })]
                    .map { (code, $0) }
            }, id: \.0) { (code, arrivals) in
                arrivalsSection(forCode: code, arrivals: arrivals)
            }
        }
    }

    @ViewBuilder
    private func arrivalsSection(forCode code: String, arrivals: [CMTrainArrival]) -> some View {
        VStack(alignment: .leading, spacing: CMSpacing.rowGap) {
            Divider()
                .padding(.top, 12)

            CMSectionHeader(title: lineName(forCode: code))
                .padding(.top, 2)

            ForEach(Array(arrivals.enumerated()), id: \.offset) { _, arr in
                TrainArrivalRow(
                    destination: arr.towardsDestination,
                    nextClockTime: arr.nextClockTime,
                    minutesUntil: arr.minutesUntil
                )
            }
        }
    }

    private func lineName(forCode code: String) -> String {
        let prefix = String(code.prefix { $0.isLetter }).uppercased()
        switch prefix {
        case "NS": return "North South Line"
        case "EW": return "East West Line"
        case "CC", "CE": return "Circle Line"
        case "NE": return "North East Line"
        case "DT": return "Downtown Line"
        case "TE": return "Thomson-East Coast Line"
        case "CG": return "Changi Airport Line"
        default:   return "Line \(prefix)"
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        MRTStationsView(
            stations: [
                CMMRTStation(
                    name: "Tanjong Pagar",
                    codes: ["EW15"],
                    walkMinutes: 5,
                    walkMeters: 443,
                    arrivalsByLine: [
                        "EW": [
                            CMTrainArrival(towardsDestination: "Pasir Ris", nextClockTime: "4:29 pm", minutesUntil: 2),
                            CMTrainArrival(towardsDestination: "Tuas Link", nextClockTime: "4:31 pm", minutesUntil: 4)
                        ]
                    ]
                ),
                CMMRTStation(
                    name: "Outram Park",
                    codes: ["EW16", "NE3", "TE17"],
                    walkMinutes: 9,
                    walkMeters: 720,
                    arrivalsByLine: [:]
                ),
                CMMRTStation(
                    name: "Maxwell",
                    codes: ["TE16"],
                    walkMinutes: 11,
                    walkMeters: 880,
                    arrivalsByLine: [:]
                ),
            ],
            nearbyLocation: "Tanjong Pagar",
            minutesAgo: 1
        )
    }
}
