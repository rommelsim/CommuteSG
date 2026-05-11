import SwiftUI
import Observation
import CoreLocation

@MainActor
@Observable
final class PlanViewModel {
    enum Filter: String, CaseIterable {
        case fastest, cheapest, lessWalk

        var label: String {
            switch self {
            case .fastest:  "Fastest"
            case .cheapest: "Cheapest"
            case .lessWalk: "Less walk"
            }
        }
    }

    enum DepartureMode: Hashable {
        case now
        case leaveAt(Date)
        case arriveBy(Date)

        var shortLabel: String {
            switch self {
            case .now:           "Leaving now"
            case .leaveAt(let d): "Leave \(Self.timeFormatter.string(from: d))"
            case .arriveBy(let d): "Arrive by \(Self.timeFormatter.string(from: d))"
            }
        }

        var icon: String {
            switch self {
            case .now:      "clock.fill"
            case .leaveAt:  "clock.arrow.circlepath"
            case .arriveBy: "flag.checkered"
            }
        }

        private static let timeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
            return f
        }()
    }

    static let defaultFrom = "Current location"
    static let defaultTo = "Marina Bay Sands"

    var fromText: String = PlanViewModel.defaultFrom {
        didSet { if oldValue != fromText { recompute() } }
    }
    var toText: String = PlanViewModel.defaultTo {
        didSet { if oldValue != toText { recompute() } }
    }
    var filter: Filter = .fastest
    var departureMode: DepartureMode = .now
    private(set) var rawOptions: [JourneyOption]

    /// Sorted view of `rawOptions` based on the active filter. The first
    /// option in the returned array is the "best" pick under that filter.
    var options: [JourneyOption] {
        rawOptions.sorted { a, b in
            switch filter {
            case .fastest:  return a.durationMinutes < b.durationMinutes
            case .cheapest: return a.fareSGD < b.fareSGD
            case .lessWalk: return a.walkMinutes < b.walkMinutes
            }
        }
    }

    private let mock: MockDataService

    init(mock: MockDataService = .shared) {
        self.mock = mock
        self.rawOptions = mock.journeyOptions(
            from: Self.defaultFrom,
            to: Self.defaultTo,
            originHint: LocationService.shared.lastLocation?.coordinate
        )
    }

    func swap() {
        let oldFrom = fromText
        let oldTo = toText
        fromText = oldTo
        toText = oldFrom
    }

    func recompute() {
        let originHint = LocationService.shared.lastLocation?.coordinate
        withAnimation(.smooth(duration: 0.25)) {
            rawOptions = mock.journeyOptions(from: fromText, to: toText, originHint: originHint)
        }
    }

    var fromIsCurrentLocation: Bool {
        fromText.localizedCaseInsensitiveCompare("Current location") == .orderedSame
    }
}
