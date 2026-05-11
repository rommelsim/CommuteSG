import Foundation

/// Singapore public-transport fare calculator. Loads `fares.json` (the
/// PTC-published distance-banded fare table effective 27 Dec 2025) once at
/// first access and exposes:
///
/// 1. `findBand(km:)` — distance → band label
/// 2. `lookupFareCents(...)` — single-leg fare lookup
/// 3. `calculateFareCents(legs:category:payment:)` — full multi-leg journey
///    fare, applying PTC's 45-minute transfer-window collapse rule.
///
/// Currency throughout is **SGD cents** (integer); divide by 100 for dollars.
final class FareCalculator {
    static let shared = FareCalculator()

    let data: FareData

    private init() {
        guard let url = Bundle.main.url(forResource: "fares", withExtension: "json") else {
            fatalError("fares.json not found in bundle. Make sure it's in Commute/Resources/.")
        }
        do {
            let raw = try Data(contentsOf: url)
            self.data = try JSONDecoder().decode(FareData.self, from: raw)
        } catch {
            fatalError("Failed to decode fares.json: \(error)")
        }
    }

    // MARK: - Band lookup

    /// Map a distance in km to a PTC band label. Distances are rounded to
    /// 0.1 km first, matching the PTC table's resolution. Returns the cap
    /// band for anything above 40.2 km.
    func findBand(km: Double) -> String {
        let k = (km * 10).rounded() / 10
        if k <= 3.2 { return "Up to 3.2 km" }
        if k > 40.2 { return "Over 40.2 km" }
        for band in data.distanceBands {
            let upper = band.maxKm ?? .infinity
            if band.minKm <= k && k <= upper {
                return band.label
            }
        }
        return "Over 40.2 km"
    }

    // MARK: - Single-leg lookup

    /// Look up the fare in cents for a given mode / band / category /
    /// payment combination. Returns `nil` when the combination is invalid
    /// (e.g. cash on MRT/LRT — trains are card-only).
    func lookupFareCents(
        mode: FareMode,
        band: String,
        category: FareCategory,
        payment: FarePayment,
        isWeekdayPrePeak: Bool = false
    ) -> Int? {
        switch mode {
        case .trunkBus:
            let table = payment == .card
                ? data.modes.trunkBus.cardFaresByBand
                : data.modes.trunkBus.cashFaresByBand
            return table[band]?[category.rawValue]

        case .mrtLrt:
            // MRT/LRT is card-only.
            guard payment == .card else { return nil }
            let table = isWeekdayPrePeak
                ? data.modes.mrtLrt.faresByBand.morningPrePeak
                : data.modes.mrtLrt.faresByBand.standard
            return table[band]?[category.rawValue]

        case .feederBus:
            let table = payment == .card
                ? data.modes.feederBus.cardFlatFare
                : data.modes.feederBus.cashFlatFare
            return table[category.rawValue]

        case .expressBus:
            guard let row = data.modes.expressBus.faresByBand[band] else { return nil }
            if payment == .cash {
                return row["cash_all_categories"]
            }
            return row["\(category.rawValue)_card"]
        }
    }

    // MARK: - Multi-leg journey

    /// Compute the total fare across multiple legs, applying PTC's transfer
    /// rules: legs whose board-time is within 45 min of the previous leg's
    /// alight-time collapse into one fare-journey priced on total distance.
    func calculateFareCents(
        legs: [FareLeg],
        category: FareCategory,
        payment: FarePayment
    ) -> Int {
        let journeys = Self.groupIntoJourneys(legs)
        return journeys.reduce(0) { running, journey in
            let km = journey.reduce(0.0) { $0 + $1.distanceKm }
            let band = findBand(km: km)
            let mode = Self.decideJourneyMode(journey)
            let prePeak = Self.isWeekdayPrePeakStart(journey[0])
            let cents = lookupFareCents(
                mode: mode,
                band: band,
                category: category,
                payment: payment,
                isWeekdayPrePeak: prePeak
            ) ?? 0
            return running + cents
        }
    }

    // MARK: - Journey-grouping helpers

    /// Group sequential legs into fare-journeys using the 45-minute window.
    /// (Same-bus-service / same-station re-board rules from the PTC spec
    /// would also start a new journey but require service/station IDs we
    /// don't carry on `FareLeg` yet — those plug in here when surfaced.)
    private static func groupIntoJourneys(_ legs: [FareLeg]) -> [[FareLeg]] {
        var journeys: [[FareLeg]] = []
        for leg in legs {
            guard let lastJourney = journeys.last,
                  let lastLeg = lastJourney.last else {
                journeys.append([leg])
                continue
            }
            let minutesGap = leg.boardTime.timeIntervalSince(lastLeg.alightTime) / 60.0
            if minutesGap <= 45 {
                journeys[journeys.count - 1].append(leg)
            } else {
                journeys.append([leg])
            }
        }
        return journeys
    }

    /// Decide which mode prices a multi-leg journey:
    /// 1. Any express leg → express bus pricing.
    /// 2. Mixed bus + train → trunk bus.
    /// 3. All-same single mode → that mode.
    /// 4. Anything else → trunk bus.
    private static func decideJourneyMode(_ journey: [FareLeg]) -> FareMode {
        if journey.contains(where: { $0.mode == .expressBus }) { return .expressBus }
        let modes = Set(journey.map(\.mode))
        let hasTrain = modes.contains(.mrtLrt)
        let hasBus = modes.contains(.trunkBus) || modes.contains(.feederBus)
        if hasTrain && hasBus { return .trunkBus }
        if modes.count == 1, let only = modes.first { return only }
        return .trunkBus
    }

    /// Whether the given leg's board-time qualifies for the morning pre-peak
    /// MRT discount: weekday (Mon-Fri), before 07:45, mode is MRT/LRT.
    /// **Note**: public-holiday exclusion isn't wired up — pass an explicit
    /// override when you have a holiday calendar.
    private static func isWeekdayPrePeakStart(_ leg: FareLeg) -> Bool {
        guard leg.mode == .mrtLrt else { return false }
        let cal = Calendar(identifier: .gregorian)
        let weekday = cal.component(.weekday, from: leg.boardTime) // 1=Sun … 7=Sat
        if weekday == 1 || weekday == 7 { return false }
        let hour = cal.component(.hour, from: leg.boardTime)
        let minute = cal.component(.minute, from: leg.boardTime)
        return (hour * 60 + minute) < (7 * 60 + 45)
    }
}
