import Foundation

/// Linear phases of an end-to-end active trip, mirroring the prototype's
/// step 2 → step 7. Each phase maps 1:1 to a Live Activity theme and a
/// distinct on-device card layout. Phases only ever advance forward; the
/// session is discarded on `end()` rather than rewinding.
enum TripPhase: String, Codable, CaseIterable, Sendable {
    /// User is walking from current location to the boarding stop.
    case walkingToStop
    /// Bus is one or two minutes out; "look up" urgent card.
    case busArriving
    /// User is on the bus heading toward the alight stop.
    case riding
    /// One stop before alight; "press the bell" urgent card.
    case alightNext
    /// Off the bus, walking the last leg to the destination.
    case finalWalk
    /// Trip complete — terminal state shown briefly before clear.
    case arrived
}
