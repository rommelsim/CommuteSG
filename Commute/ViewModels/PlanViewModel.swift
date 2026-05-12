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

    /// Both fields start empty so the planner doesn't claim a default trip
    /// the user didn't ask for. The From field is treated as "current
    /// location" implicitly when empty (see `effectiveFromText`); the To
    /// field empty → no journey options computed at all.
    static let defaultFrom = ""
    static let defaultTo = ""

    private(set) var fromText: String = "" {
        didSet { if oldValue != fromText { recompute() } }
    }
    private(set) var toText: String = "" {
        didSet { if oldValue != toText { recompute() } }
    }
    /// Coordinate for `fromText` when known (e.g. picked from a geocoded
    /// address). Lets the planner produce real durations instead of falling
    /// back to a fixed Clementi origin for unrecognized addresses.
    private(set) var fromCoordinate: CLLocationCoordinate2D?
    /// Coordinate for `toText` when known. Same rationale as above —
    /// otherwise non-MRT destinations all collapse to a Marina Bay fallback
    /// and produce identical routes regardless of what the user typed.
    private(set) var toCoordinate: CLLocationCoordinate2D?
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
        // No options on launch — user must pick a destination first.
        self.rawOptions = []
    }

    var hasDestination: Bool {
        !toText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Update the From field's text + coordinate atomically. Pass `coordinate`
    /// when the value came from a geocoded address result so the planner can
    /// use a real origin; pass nil for free-text or saved-place strings.
    func setFrom(_ text: String, coordinate: CLLocationCoordinate2D? = nil) {
        // Set coordinate first so the didSet on `fromText` triggers recompute()
        // with the new coord already in place.
        fromCoordinate = coordinate
        fromText = text
    }

    /// Same as `setFrom`, for the To field.
    func setTo(_ text: String, coordinate: CLLocationCoordinate2D? = nil) {
        toCoordinate = coordinate
        toText = text
    }

    func swap() {
        let fT = fromText, fC = fromCoordinate
        let tT = toText,   tC = toCoordinate
        setFrom(tT, coordinate: tC)
        setTo(fT, coordinate: fC)
    }

    /// Reset both fields back to empty. The didSet on `toText` triggers a
    /// recompute, which in turn empties `rawOptions`. UI re-renders with
    /// the empty state.
    func clear() {
        fromCoordinate = nil
        toCoordinate = nil
        fromText = ""
        toText = ""
    }

    var hasAnyValue: Bool {
        !fromText.isEmpty || !toText.isEmpty
    }

    func recompute() {
        // No destination → no options. Don't pretend to plan.
        guard hasDestination else {
            withAnimation(.smooth(duration: 0.25)) { rawOptions = [] }
            return
        }
        let effectiveFrom = fromText.isEmpty ? "Current location" : fromText
        let origin = fromCoordinate ?? LocationService.shared.lastLocation?.coordinate
        withAnimation(.smooth(duration: 0.25)) {
            rawOptions = mock.journeyOptions(
                from: effectiveFrom,
                to: toText,
                originHint: origin,
                destinationHint: toCoordinate
            )
        }
    }

    /// Empty From → routing uses the user's current GPS as origin.
    var fromIsCurrentLocation: Bool {
        fromText.isEmpty
            || fromText.localizedCaseInsensitiveCompare("Current location") == .orderedSame
    }
}
