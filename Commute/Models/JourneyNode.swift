import Foundation

/// One stop on the journey strip at the top of `StationBrowserView`.
///
/// Caller-driven by design (see handoff Q5): the browser screen takes a
/// `[JourneyNode]` rather than reaching into `TripCoordinator`. Lets us
/// drive the strip from real active-trip state in production *and* from
/// hand-rolled fixtures in previews + dev entry points.
struct JourneyNode: Hashable, Identifiable {
    let stationCode: String     // "CC23"
    let stationName: String     // "one-north"
    let line: MRTLine
    let state: State

    var id: String { stationCode }

    enum State: Hashable {
        case done       // already passed
        case current    // user is here now
        case transfer   // upcoming transfer / interchange
        case upcoming   // upcoming, non-transfer
    }
}
