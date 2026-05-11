import SwiftUI

struct NearbyBusStopCard: View {
    let stop: BusStop
    let arrivals: [BusArrival]
    let onTapStop: () -> Void
    let onTapBus: (BusArrival) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s10) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s8) {
                Image(systemName: "bus.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.appText2)
                Text(stop.name)
                    .font(.appCardTitle)
                    .foregroundStyle(Color.appText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: Spacing.s8)
                if let d = stop.distanceMeters {
                    Text("\(d)m")
                        .font(.appMicro)
                        .foregroundStyle(Color.appText3)
                }
            }
            if !arrivals.isEmpty {
                HStack(spacing: Spacing.s8) {
                    ForEach(arrivals.prefix(4)) { a in
                        Button { onTapBus(a) } label: {
                            ArrivalPill(
                                topLine: a.serviceNo,
                                bottomLine: ArrivalStatus.label(
                                    minutes: a.nextArrivalMinutes,
                                    scheduled: a.nextArrivalIsScheduled
                                ),
                                status: ArrivalStatus.from(minutes: a.nextArrivalMinutes),
                                busType: a.nextArrivalType,
                                crowdLevel: a.nextArrivalCrowd,
                                iconPlacement: .bottomLine
                            )
                        }
                        .buttonStyle(CardButtonStyle())
                        .accessibilityLabel("Track bus \(a.serviceNo)")
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: Radius.card)
        .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTapStop()
        }
    }
}
