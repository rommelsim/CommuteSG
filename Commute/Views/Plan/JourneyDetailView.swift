import SwiftUI

struct JourneyDetailView: View {
    let option: JourneyOption
    let mode: PlanViewModel.DepartureMode
    let fromText: String
    let toText: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryCard
                stepsList
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Color.appSurface)
        .navigationTitle("Journey")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                endpointRow(
                    leading: AnyView(Circle().fill(Color.appInfo).frame(width: 10, height: 10)),
                    label: "From",
                    value: fromText
                )
                Divider()
                    .background(Color.cfHairline)
                    .padding(.leading, 22)
                endpointRow(
                    leading: AnyView(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.appDestination)
                            .frame(width: 10, height: 10)
                    ),
                    label: "To",
                    value: toText
                )
            }

            Divider().background(Color.cfHairline)

            HStack(spacing: 14) {
                summaryStat(
                    label: "Depart",
                    value: timeLabel(departureDate)
                )
                summaryStat(
                    label: "Arrive",
                    value: timeLabel(arrivalDate)
                )
                summaryStat(
                    label: "Duration",
                    value: "\(option.durationMinutes) min"
                )
                summaryStat(
                    label: "Fare",
                    value: String(format: "$%.2f", option.fareSGD)
                )
            }
        }
        .padding(Spacing.cardInner)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface2)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .stroke(Color.cfHairline, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
    }

    private func endpointRow(leading: AnyView, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            leading.frame(width: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.appMicro)
                    .foregroundStyle(Color.cfTextTertiary)
                Text(value)
                    .font(.appBodyMedium)
                    .foregroundStyle(Color.cfTextPrimary)
            }
        }
    }

    private func summaryStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.appMicro)
                .foregroundStyle(Color.cfTextTertiary)
                .textCase(.uppercase)
                .tracking(0.4)
            Text(value)
                .font(.appBodyMedium)
                .foregroundStyle(Color.cfTextPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Steps

    private var stepsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Step by step")
                .font(.appCaptionStrong)
                .foregroundStyle(Color.cfTextTertiary)
                .textCase(.uppercase)
                .tracking(0.4)
                .padding(.bottom, 12)

            ForEach(Array(option.segments.enumerated()), id: \.offset) { idx, seg in
                stepRow(
                    seg,
                    isFirst: idx == 0,
                    isLast: idx == option.segments.count - 1
                )
            }
        }
    }

    private func stepRow(
        _ seg: JourneyOption.Segment,
        isFirst: Bool,
        isLast: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            indicatorColumn(for: seg, isLast: isLast)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(stepTitle(seg))
                    .font(.appBodyMedium)
                    .foregroundStyle(Color.cfTextPrimary)
                if let subtitle = stepSubtitle(seg, isFirst: isFirst, isLast: isLast) {
                    Text(subtitle)
                        .font(.appCaption)
                        .foregroundStyle(Color.cfTextSecondary)
                }
                Text("\(seg.minutes) min")
                    .font(.appMicro)
                    .foregroundStyle(Color.cfTextTertiary)
            }
            .padding(.bottom, isLast ? 0 : 20)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func indicatorColumn(for seg: JourneyOption.Segment, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            indicatorMark(for: seg)
            if !isLast {
                Rectangle()
                    .fill(Color.cfHairline)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func indicatorMark(for seg: JourneyOption.Segment) -> some View {
        switch seg {
        case .walk:
            Image(systemName: "figure.walk")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.cfTextSecondary)
                .frame(width: 24, height: 24)
                .background(Color.appSurface2)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.cfHairline, lineWidth: 0.5))
        case .mrt(let line, _):
            ZStack {
                Circle().fill(line.background)
                Image(systemName: "tram.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(line.foreground)
            }
            .frame(width: 24, height: 24)
        case .bus:
            ZStack {
                Circle().fill(Color.cfTextPrimary.opacity(0.85))
                Image(systemName: "bus.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.appSurface)
            }
            .frame(width: 24, height: 24)
        }
    }

    private func stepTitle(_ seg: JourneyOption.Segment) -> String {
        switch seg {
        case .walk:
            "Walk"
        case .mrt(let line, _):
            "Take \(line.fullName)"
        case .bus(let no, _):
            "Take Bus \(no)"
        }
    }

    private func stepSubtitle(
        _ seg: JourneyOption.Segment,
        isFirst: Bool,
        isLast: Bool
    ) -> String? {
        switch seg {
        case .walk:
            if isFirst { "From \(fromText)" }
            else if isLast { "To \(toText)" }
            else { "To the next stop" }
        case .mrt(let line, _):
            "\(line.code) line"
        case .bus:
            "Towards your destination"
        }
    }

    // MARK: - Helpers

    private var departureDate: Date {
        switch mode {
        case .now:           option.departure()
        case .leaveAt(let d): d
        case .arriveBy(let d): d.addingTimeInterval(TimeInterval(-option.durationMinutes * 60))
        }
    }

    private var arrivalDate: Date {
        switch mode {
        case .now:            option.arrival()
        case .leaveAt(let d): d.addingTimeInterval(TimeInterval(option.durationMinutes * 60))
        case .arriveBy(let d): d
        }
    }

    private func timeLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }
}
