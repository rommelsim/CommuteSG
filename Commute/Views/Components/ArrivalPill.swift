import SwiftUI

/// A bus-arrival chip whose **colour encodes arrival status** (per redesign
/// spec §3): green = imminent ("Now" / ≤ 2 min), neutral glass = normal,
/// amber = delayed, red = cancelled. Bus type appears as an SF Symbol next
/// to the minute count. Crowd remains in the corner as 3 small bars — that's
/// the one consistent meaning the bars carry app-wide.
///
/// `topLine` is the larger top label (service number on home cards, ETA on
/// detail rows); `bottomLine` is the smaller line below (ETA on home cards,
/// `nil` on detail rows). `iconPlacement` decides which line gets the
/// bus-type / status symbol — should be the line that shows the minute count.
struct ArrivalPill: View {
    let topLine: String
    let bottomLine: String?
    let status: ArrivalStatus
    let busType: BusType
    let crowdLevel: CrowdLevel
    let iconPlacement: IconPlacement

    enum IconPlacement { case topLine, bottomLine }

    init(
        topLine: String,
        bottomLine: String? = nil,
        status: ArrivalStatus,
        busType: BusType = .unknown,
        crowdLevel: CrowdLevel = .unknown,
        iconPlacement: IconPlacement = .topLine
    ) {
        self.topLine = topLine
        self.bottomLine = bottomLine
        self.status = status
        self.busType = busType
        self.crowdLevel = crowdLevel
        self.iconPlacement = iconPlacement
    }

    var body: some View {
        VStack(spacing: 2) {
            row(text: topLine, font: .appCardTitle, withIcon: iconPlacement == .topLine)
            if let bottomLine {
                row(text: bottomLine, font: .appMicro, withIcon: iconPlacement == .bottomLine)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .arrivalChipBackground(status: status, cornerRadius: Radius.small)
        .overlay(alignment: .topTrailing) {
            ArrivalCrowdBars(level: crowdLevel, color: barsColor)
                .padding(.top, 5)
                .padding(.trailing, 5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private func row(text: String, font: Font, withIcon: Bool) -> some View {
        HStack(spacing: 4) {
            if withIcon, let symbol = leadingSymbol {
                Image(systemName: symbol)
                    .font(font)
                    .foregroundStyle(status.foreground)
            }
            Text(text)
                .font(font)
                .foregroundStyle(status.foreground)
                .contentTransition(.numericText())
                .animation(.snappy, value: text)
        }
    }

    /// Status anomaly icon takes precedence over bus-type icon — delayed and
    /// cancelled chips highlight the anomaly; normal/imminent chips show the
    /// bus type when known.
    private var leadingSymbol: String? {
        status.statusSymbol ?? busType.symbol
    }

    private var barsColor: Color {
        switch crowdLevel {
        case .seats:    Color.crowdSeatsBars
        case .standing: Color.crowdStandingBars
        case .limited:  Color.crowdPackedBars
        case .unknown:  Color.crowdUnknownBars
        }
    }

    private var accessibilityLabel: String {
        var parts: [String] = [topLine]
        if let bottomLine {
            parts.append(bottomLine)
        }
        if busType != .unknown {
            parts.append(busType.label)
        }
        let crowd: String = switch crowdLevel {
        case .seats:    "seats available"
        case .standing: "standing room only"
        case .limited:  "limited standing"
        case .unknown:  "crowd unknown"
        }
        parts.append(crowd)
        return parts.joined(separator: ", ")
    }
}
