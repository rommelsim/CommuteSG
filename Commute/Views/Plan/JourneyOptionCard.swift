import SwiftUI

struct JourneyOptionCard: View {
    let option: JourneyOption
    var isBest: Bool = false
    var isBestScore: Bool = false
    var score: CommuteScore? = nil
    let departureMode: PlanViewModel.DepartureMode
    let action: () -> Void

    private static let teal = Color(red: 0.08, green: 0.72, blue: 0.65)

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                topRow
                miniTimeline
                metaRow
                if let crowdStation = crowdStationCode {
                    InlineCrowdStrip(crowd: option.crowd, stationCode: crowdStation)
                }
                if let score {
                    Divider().background(Color.cfHairline)
                    CommuteScoreFooter(score: score)
                }
            }
            .padding(Spacing.cardInner)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(borderTintBackground)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(borderStroke,
                            lineWidth: (isBestScore || isBest) ? 1.25 : 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .buttonStyle(CardButtonStyle())
    }

    private var borderTintBackground: Color {
        if isBestScore { return Self.teal.opacity(0.08) }
        if isBest      { return Color.appInfoBg }
        return Color.appSurface
    }

    private var borderStroke: Color {
        if isBestScore { return Self.teal }
        if isBest      { return Color.appInfo }
        return Color.cfHairline
    }

    // MARK: - Top row: depart → arrive · duration / fare / Best

    private var topRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            HStack(spacing: 6) {
                Text(timeLabel(departureDate))
                    .font(.appHeading)
                    .foregroundStyle(Color.cfTextPrimary)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: departureDate)
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.cfTextTertiary)
                Text(timeLabel(arrivalDate))
                    .font(.appHeading)
                    .foregroundStyle(Color.cfTextPrimary)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: arrivalDate)
            }
            Text("· \(option.durationMinutes) min")
                .font(.appBody)
                .foregroundStyle(Color.cfTextSecondary)
                .contentTransition(.numericText())
                .animation(.snappy, value: option.durationMinutes)
            Spacer(minLength: 6)
            if isBestScore {
                Text("Best score")
                    .font(.appMicroStrong)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Self.teal)
                    .foregroundStyle(Color.white)
                    .clipShape(Capsule())
            } else if isBest {
                Text("Best")
                    .font(.appMicroStrong)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.appInfo)
                    .foregroundStyle(Color.white)
                    .clipShape(Capsule())
            }
            Text(String(format: "$%.2f", option.fareSGD))
                .font(.appBodyMedium)
                .foregroundStyle(Color.cfTextPrimary)
                .contentTransition(.numericText())
                .animation(.snappy, value: option.fareSGD)
        }
    }

    private var departureDate: Date {
        switch departureMode {
        case .now:
            option.departure()
        case .leaveAt(let date):
            date
        case .arriveBy(let date):
            date.addingTimeInterval(TimeInterval(-option.durationMinutes * 60))
        }
    }

    private var arrivalDate: Date {
        switch departureMode {
        case .now:
            option.arrival()
        case .leaveAt(let date):
            date.addingTimeInterval(TimeInterval(option.durationMinutes * 60))
        case .arriveBy(let date):
            date
        }
    }

    // MARK: - Mini timeline (proportional bar of segments)

    private var miniTimeline: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(Array(option.segments.enumerated()), id: \.offset) { _, seg in
                    timelineSegment(seg)
                        .frame(width: width(for: seg, total: geo.size.width))
                }
            }
        }
        .frame(height: 28)
    }

    @ViewBuilder
    private func timelineSegment(_ seg: JourneyOption.Segment) -> some View {
        switch seg {
        case .walk:
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.appSurface2)
                Image(systemName: "figure.walk")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.cfTextSecondary)
            }
        case .mrt(let line, _):
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(line.background)
                Text(line.code)
                    .font(.appMicroStrong)
                    .foregroundStyle(line.foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 4)
            }
        case .bus(let no, _):
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.cfTextPrimary.opacity(0.85))
                HStack(spacing: 3) {
                    Image(systemName: "bus.fill")
                        .font(.system(size: 9, weight: .semibold))
                    Text(no)
                        .font(.appMicroStrong)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(Color.appSurface)
                .padding(.horizontal, 4)
            }
        }
    }

    /// Walk segments are visually compact (just an icon) so we give them a fixed
    /// width. The remaining space is split proportionally among ride segments by
    /// minutes — that keeps narrow walks from squashing the line/bus labels.
    private func width(for seg: JourneyOption.Segment, total: CGFloat) -> CGFloat {
        let walkWidth: CGFloat = 26
        let segmentCount = option.segments.count
        let spacingTotal = CGFloat(max(0, segmentCount - 1)) * 2
        let available = max(0, total - spacingTotal)

        if seg.isWalk { return walkWidth }

        let walkCount = option.segments.filter { $0.isWalk }.count
        let walksTotal = CGFloat(walkCount) * walkWidth
        let flex = max(0, available - walksTotal)

        let rideMinutes = option.segments
            .filter { !$0.isWalk }
            .reduce(0) { $0 + $1.minutes }
        guard rideMinutes > 0 else { return 0 }

        return flex * CGFloat(seg.minutes) / CGFloat(rideMinutes)
    }

    // MARK: - Meta row: walk / transfers / crowd

    private var metaRow: some View {
        HStack(spacing: 12) {
            metaItem(symbol: "figure.walk", text: "\(option.walkMinutes) min walk")
            metaItem(
                symbol: option.transferCount == 0 ? "arrow.forward" : "arrow.triangle.swap",
                text: option.transferCount == 0 ? "Direct" : "\(option.transferCount) transfer\(option.transferCount > 1 ? "s" : "")"
            )
            Spacer(minLength: 4)
            crowdItem
        }
    }

    private func metaItem(symbol: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.cfTextSecondary)
            Text(text)
                .font(.appCaption)
                .foregroundStyle(Color.cfTextSecondary)
                .contentTransition(.numericText())
                .animation(.snappy, value: text)
        }
    }

    private var crowdItem: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(crowdColor)
            Text(crowdLabel)
                .font(.appCaptionStrong)
                .foregroundStyle(crowdColor)
        }
    }

    private var crowdColor: Color {
        switch option.crowd {
        case .standing: Color.appWarning
        case .limited:  Color.appDanger
        default:        Color.appSuccess
        }
    }

    /// Pulls the user's first MRT leg's station code so the inline crowd
    /// strip can label "Low crowd · CC23". Falls back to the first bus
    /// service code when the trip has no rail leg, or nil for walk-only.
    private var crowdStationCode: String? {
        for seg in option.segments {
            if case let .mrt(line, _) = seg { return line.code }
            if case let .bus(no, _) = seg { return no }
        }
        return nil
    }

    private var crowdLabel: String {
        switch option.crowd {
        case .seats:    "Seats"
        case .standing: "Standing"
        case .limited:  "Crowded"
        case .unknown:  "—"
        }
    }

    // MARK: - Helpers

    private func timeLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }
}
