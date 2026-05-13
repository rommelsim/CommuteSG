import Foundation
import Observation

/// Owns the single active trip session, if any. UI observes
/// `activeSession` and reacts to phase changes; production triggers
/// (geofences, vehicle position, motion) will call `advance(to:)` once
/// wired in a later phase. For now transitions are driven manually so
/// screens can be built and exercised against a real state machine.
@Observable
@MainActor
final class TripCoordinator {
    /// The currently in-flight trip, or nil when no trip is active. Set
    /// via `start(_:)` and cleared via `end()`. UI binds to this and
    /// switches its root layout accordingly (Home vs. active-trip card).
    private(set) var activeSession: ActiveTripSession?

    /// Begin a new trip. Refuses if one is already in flight — callers
    /// must `end()` the prior session first. Returns true on success so
    /// the caller can decide whether to navigate forward.
    @discardableResult
    func start(_ session: ActiveTripSession) -> Bool {
        guard activeSession == nil else { return false }
        activeSession = session
        return true
    }

    /// Advance the active session to a new phase. Phase order is linear
    /// (walking → arriving → riding → alight → finalWalk → arrived) so
    /// backward transitions are ignored; the coordinator is the single
    /// source of truth and shouldn't be talked into a rewind by a stale
    /// trigger arriving out of order.
    func advance(to phase: TripPhase) {
        guard var session = activeSession else { return }
        guard phase.rank > session.phase.rank else { return }
        session.phase = phase
        session.phaseEnteredAt = Date()
        activeSession = session
    }

    /// Convenience for the debug "advance" affordance: move to the next
    /// phase in linear order, or end the trip if we're already at the
    /// terminal `arrived` state. Returns the new phase, or nil if the
    /// session was ended (or there was no session to begin with).
    @discardableResult
    func advanceToNext() -> TripPhase? {
        guard let session = activeSession else { return nil }
        switch session.phase {
        case .walkingToStop: advance(to: .busArriving);  return .busArriving
        case .busArriving:   advance(to: .riding);        return .riding
        case .riding:        advance(to: .alightNext);    return .alightNext
        case .alightNext:    advance(to: .finalWalk);     return .finalWalk
        case .finalWalk:     advance(to: .arrived);       return .arrived
        case .arrived:       end();                       return nil
        }
    }

    /// End the active trip without reaching `arrived` — the user tapped
    /// "End trip" in the bottom sheet, or the app detected the trip was
    /// abandoned. Clears the session outright; no terminal animation
    /// here, that's a UI concern.
    func end() {
        activeSession = nil
    }
}

private extension TripPhase {
    /// Linear ordering used to reject backward transitions.
    var rank: Int {
        switch self {
        case .walkingToStop: 0
        case .busArriving:   1
        case .riding:        2
        case .alightNext:    3
        case .finalWalk:     4
        case .arrived:       5
        }
    }
}
