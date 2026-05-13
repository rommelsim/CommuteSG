import Foundation

/// Composite "Commute Score" for a route result. Three sub-scores (time,
/// crowd, cost) combine into a 0–100 overall via the handoff-specified
/// weighting: time 35% / crowd 40% / cost 25%. Crowd is weighted highest
/// because it's the most underserved signal in existing transit apps.
struct CommuteScore: Hashable {
    let time: Int
    let crowd: Int
    let cost: Int
    let overall: Int

    enum Tier {
        case excellent  // 80–100
        case good       // 60–79
        case fair       // 40–59
        case poor       // <40
    }

    var tier: Tier {
        switch overall {
        case 80...:  .excellent
        case 60..<80: .good
        case 40..<60: .fair
        default:      .poor
        }
    }

    var tierHeadline: String {
        switch tier {
        case .excellent: "Low crowd · Good value"
        case .good:      "Slow, cheap, empty"
        case .fair:      "Fastest but packed"
        case .poor:      "Tough trip"
        }
    }

    static let weights = (time: 0.35, crowd: 0.40, cost: 0.25)

    /// Build scores for a single option, normalized against the full list so
    /// "fastest in this set" and "cheapest in this set" map to 100. Crowd is
    /// absolute — it doesn't depend on the other options.
    static func make(for option: JourneyOption, within list: [JourneyOption]) -> CommuteScore {
        let durations = list.map(\.durationMinutes)
        let fares = list.map(\.fareSGD)
        let minDur = max(durations.min() ?? 1, 1)
        let minFare = max(fares.min() ?? 0.01, 0.01)

        let timeScore = Int((Double(minDur) / Double(option.durationMinutes) * 100).rounded())
            .clamped(to: 0...100)
        let costScore = Int((minFare / max(option.fareSGD, 0.01) * 100).rounded())
            .clamped(to: 0...100)
        let crowdScore = crowdScore(for: option.crowd)

        let overallD =
            Double(timeScore)  * weights.time  +
            Double(crowdScore) * weights.crowd +
            Double(costScore)  * weights.cost
        let overall = Int(overallD.rounded()).clamped(to: 0...100)

        return CommuteScore(time: timeScore, crowd: crowdScore, cost: costScore, overall: overall)
    }

    private static func crowdScore(for level: CrowdLevel) -> Int {
        switch level {
        case .seats:    95
        case .standing: 60
        case .limited:  30
        case .unknown:  70
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
