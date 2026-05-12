import SwiftUI
import Observation
import CoreLocation

/// Drives the Fare Calculator screen. The user picks a from/to point (any
/// combination of MRT station + bus stop), the great-circle distance becomes
/// the input to `FareCalculator.shared`, and the rest (mode / category /
/// payment / pre-peak) selects which row of the PTC table to read.
@Observable
final class FaresViewModel {
    // MARK: - Inputs

    var mode: FareMode = .mrtLrt {
        didSet { reconcilePaymentForMode() }
    }
    var category: FareCategory = .adult
    var payment: FarePayment = .card
    var fromEndpoint: FareEndpoint?
    var toEndpoint: FareEndpoint?
    /// User-toggled "I'm tapping in before 7:45 am on a weekday". Only
    /// meaningful when `mode == .mrtLrt`.
    var isPrePeak: Bool = false

    init() {}

    // MARK: - Outputs

    /// Both points picked? Used to gate the result tile.
    var hasBothEndpoints: Bool {
        fromEndpoint != nil && toEndpoint != nil
    }

    /// Great-circle distance between the picks, in km. Returns 0 if either
    /// point is missing.
    var distanceKm: Double {
        guard let from = fromEndpoint, let to = toEndpoint else { return 0 }
        let meters = from.location.distance(from: to.location)
        return meters / 1000
    }

    var bandLabel: String {
        FareCalculator.shared.findBand(km: distanceKm)
    }

    var fareCents: Int {
        guard hasBothEndpoints else { return 0 }
        return FareCalculator.shared.lookupFareCents(
            mode: mode,
            band: bandLabel,
            category: category,
            payment: payment,
            isWeekdayPrePeak: appliesPrePeak
        ) ?? 0
    }

    var fareString: String {
        Self.formatCents(fareCents)
    }

    /// Standard (non-pre-peak) fare for showing the early-bird saving.
    var standardFareCents: Int {
        guard hasBothEndpoints else { return 0 }
        return FareCalculator.shared.lookupFareCents(
            mode: mode,
            band: bandLabel,
            category: category,
            payment: payment,
            isWeekdayPrePeak: false
        ) ?? 0
    }

    var prePeakSavingsCents: Int {
        guard appliesPrePeak else { return 0 }
        return max(0, standardFareCents - fareCents)
    }

    var prePeakSavingsString: String {
        Self.formatCents(prePeakSavingsCents)
    }

    var appliesPrePeak: Bool {
        mode == .mrtLrt && isPrePeak
    }

    /// Effective date of the loaded PTC table, formatted for display.
    var effectiveDate: String {
        let raw = FareCalculator.shared.data.metadata.effectiveDate
        let inFmt = DateFormatter()
        inFmt.dateFormat = "yyyy-MM-dd"
        guard let date = inFmt.date(from: raw) else { return raw }
        let outFmt = DateFormatter()
        outFmt.dateStyle = .long
        return outFmt.string(from: date)
    }

    var distanceLabel: String {
        guard hasBothEndpoints else { return "Pick from and to" }
        let rounded = (distanceKm * 10).rounded() / 10
        return String(format: "%.1f km", rounded)
    }

    // MARK: - Mutations

    func swap() {
        let f = fromEndpoint
        fromEndpoint = toEndpoint
        toEndpoint = f
    }

    // MARK: - Helpers

    private func reconcilePaymentForMode() {
        if mode == .mrtLrt && payment == .cash { payment = .card }
        if mode != .mrtLrt && isPrePeak { isPrePeak = false }
    }

    static func formatCents(_ cents: Int) -> String {
        String(format: "$%.2f", Double(cents) / 100.0)
    }
}
