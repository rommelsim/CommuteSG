import SwiftUI
import CoreLocation

/// Lightweight fare overlay invoked from the "$ Check a fare" pill inside the
/// planner. Sits as a bottom-anchored glass card (compact detent) so the user
/// stays in planner context — per the unified-nav handoff, fare is *contextual*,
/// not a destination. Pre-fills from/to from the planner and shows an instant
/// adult-card fare; the "Adjust" disclosure expands category/payment toggles.
struct FareOverlaySheet: View {
    let fromText: String
    let toText: String
    let fromCoord: CLLocationCoordinate2D?
    let toCoord: CLLocationCoordinate2D?

    @State private var category: FareCategory = .adult
    @State private var payment: FarePayment = .card
    @State private var adjustExpanded = false
    @Environment(\.dismiss) private var dismiss

    private var distanceKm: Double {
        guard let f = fromCoord, let t = toCoord else { return 0 }
        let a = CLLocation(latitude: f.latitude, longitude: f.longitude)
        let b = CLLocation(latitude: t.latitude, longitude: t.longitude)
        return a.distance(from: b) / 1000
    }

    private var fareCents: Int? {
        guard fromCoord != nil, toCoord != nil else { return nil }
        let band = FareCalculator.shared.findBand(km: distanceKm)
        return FareCalculator.shared.lookupFareCents(
            mode: .mrtLrt,
            band: band,
            category: category,
            payment: payment,
            isWeekdayPrePeak: false
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            fromToRow
            resultTile
            adjustSection
        }
        .padding(20)
        .background(Color.cfPageBackground)
        .presentationDetents(adjustExpanded ? [.medium] : [.height(340)])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack {
            Text("Check a fare")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.cfTextPrimary)
            Spacer()
            Button("Done") { dismiss() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.appInfo)
        }
    }

    private var fromToRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "circle")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.cfTextSecondary)
                Text(fromText.isEmpty ? "From" : fromText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(fromText.isEmpty ? Color.cfTextSecondary : Color.cfTextPrimary)
                    .lineLimit(1)
            }
            HStack(spacing: 8) {
                Image(systemName: "mappin")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.cfTextSecondary)
                Text(toText.isEmpty ? "To" : toText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(toText.isEmpty ? Color.cfTextSecondary : Color.cfTextPrimary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: 12, fill: Color.cfGlassFillSoft)
    }

    @ViewBuilder
    private var resultTile: some View {
        if let cents = fareCents {
            VStack(alignment: .leading, spacing: 4) {
                Text(FaresViewModel.formatCents(cents))
                    .font(.system(size: 30, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.cfTextPrimary)
                Text("\(String(format: "%.1f km", distanceKm)) · \(category.label) · \(payment.label)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.cfTextSecondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.appInfoBg)
            )
            .contentTransition(.numericText())
            .animation(.snappy, value: cents)
        } else {
            Text("Pick a from and to in the planner for an instant fare.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.cfTextSecondary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.cfGlassFillSoft)
                )
        }
    }

    private var adjustSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.snappy) { adjustExpanded.toggle() }
            } label: {
                HStack {
                    Text("Adjust")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.cfTextPrimary)
                    Spacer()
                    Image(systemName: adjustExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.cfTextSecondary)
                }
            }
            .buttonStyle(.plain)

            if adjustExpanded {
                segmented(title: "Card type",
                          selection: $category,
                          options: FareCategory.allCases,
                          label: { $0.label })
                segmented(title: "Payment",
                          selection: $payment,
                          options: [.card],
                          label: { $0.label })
            }
        }
    }

    private func segmented<T: Hashable>(
        title: String,
        selection: Binding<T>,
        options: [T],
        label: @escaping (T) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.cfTextSecondary)
            HStack(spacing: 6) {
                ForEach(options, id: \.self) { opt in
                    Button {
                        selection.wrappedValue = opt
                    } label: {
                        Text(label(opt))
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(selection.wrappedValue == opt
                                               ? Color.appInfoBg
                                               : Color.cfGlassFillSoft)
                            )
                            .foregroundStyle(selection.wrappedValue == opt
                                             ? Color.appInfo
                                             : Color.cfTextPrimary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
    }
}
