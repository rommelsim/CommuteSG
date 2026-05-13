import Foundation

/// A single in-flight bus trip. Created when the user taps "Start trip" on
/// the journey preview and discarded when they arrive or end manually. All
/// fields are immutable except `phase` and `phaseEnteredAt`, which the
/// coordinator advances as production triggers fire.
struct ActiveTripSession: Identifiable, Sendable {
    let id: UUID
    let startedAt: Date

    let service: String
    let boardingStopCode: String
    let boardingStopName: String
    let alightStopCode: String
    let alightStopName: String
    let destinationLabel: String?

    var phase: TripPhase
    var phaseEnteredAt: Date

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        service: String,
        boardingStopCode: String,
        boardingStopName: String,
        alightStopCode: String,
        alightStopName: String,
        destinationLabel: String? = nil,
        phase: TripPhase = .walkingToStop,
        phaseEnteredAt: Date = Date()
    ) {
        self.id = id
        self.startedAt = startedAt
        self.service = service
        self.boardingStopCode = boardingStopCode
        self.boardingStopName = boardingStopName
        self.alightStopCode = alightStopCode
        self.alightStopName = alightStopName
        self.destinationLabel = destinationLabel
        self.phase = phase
        self.phaseEnteredAt = phaseEnteredAt
    }
}
