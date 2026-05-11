import SwiftUI

struct FaresView: View {
    @State private var viewModel = FaresViewModel()
    @State private var pickingField: FareEndpointPicker.Field?
    private let ltaFareCalculatorURL = URL(string: "https://www.lta.gov.sg/content/ltagov/en/map/fare-calculator.html")!

    var body: some View {
        @Bindable var vm = viewModel

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    modeSection(vm)
                    fromToSection
                    categorySection(vm)
                    paymentSection(vm)
                    if viewModel.mode == .mrtLrt {
                        prePeakSection(vm)
                    }
                    fareResult
                    breakdown
                    if viewModel.appliesPrePeak {
                        prePeakSavingsCard
                    }
                    ltaLink
                    sourceFootnote
                }
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(Color.appSurface)
            .animation(.snappy, value: viewModel.mode)
            .animation(.snappy, value: viewModel.isPrePeak)
            .animation(.snappy, value: viewModel.fromEndpoint)
            .animation(.snappy, value: viewModel.toEndpoint)
            .sheet(item: $pickingField) { field in
                FareEndpointPicker(field: field) { picked in
                    switch field {
                    case .from: viewModel.fromEndpoint = picked
                    case .to:   viewModel.toEndpoint = picked
                    }
                }
                .presentationDetents([.large])
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Fare calculator")
                .font(.appTitle)
                .tracking(-0.5)
                .foregroundStyle(Color.appText)
            Text("Official PTC fares · effective \(viewModel.effectiveDate)")
                .font(.appLabel)
                .foregroundStyle(Color.appText2)
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.top, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Mode (4-segment)

    private func modeSection(_ vm: FaresViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Mode")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FareMode.allCases, id: \.self) { m in
                        modeChip(m, vm: vm)
                    }
                }
                .padding(.horizontal, Spacing.screen)
            }
            .sensoryFeedback(.selection, trigger: vm.mode)
        }
    }

    private func modeChip(_ m: FareMode, vm: FaresViewModel) -> some View {
        let isActive = vm.mode == m
        return Button {
            vm.mode = m
        } label: {
            HStack(spacing: 6) {
                Image(systemName: m.symbol)
                    .font(.system(size: 12, weight: .semibold))
                Text(m.label)
                    .font(.appLabelMedium)
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .background(isActive ? Color.appText : Color.appSurface)
            .foregroundStyle(isActive ? Color.appSurface : Color.appText)
            .overlay(
                Capsule().stroke(isActive ? Color.clear : Color.appBorderStrong, lineWidth: 0.5)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Distance slider

    // MARK: - From / To picker

    private var fromToSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionLabel("Route")
                Spacer()
                Text(viewModel.distanceLabel)
                    .font(.appLabelStrong)
                    .foregroundStyle(viewModel.hasBothEndpoints ? Color.appText : Color.appText3)
                    .padding(.horizontal, Spacing.screen)
                    .contentTransition(.numericText())
            }
            ZStack(alignment: .trailing) {
                VStack(spacing: 0) {
                    endpointRow(
                        leading: AnyView(Circle().fill(Color.appInfo).frame(width: 10, height: 10)),
                        label: "From",
                        endpoint: viewModel.fromEndpoint
                    ) {
                        pickingField = .from
                    }
                    Divider()
                        .background(Color.appBorder)
                        .padding(.leading, 44)
                    endpointRow(
                        leading: AnyView(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.appDestination)
                                .frame(width: 10, height: 10)
                        ),
                        label: "To",
                        endpoint: viewModel.toEndpoint
                    ) {
                        pickingField = .to
                    }
                }
                .background(Color.appSurface2)
                .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                        .stroke(Color.appBorder, lineWidth: 0.5)
                )

                Button {
                    withAnimation(.snappy(duration: 0.25)) { viewModel.swap() }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.appText)
                        .frame(width: 36, height: 36)
                        .background(Color.appSurface)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.appBorder, lineWidth: 0.5))
                        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Swap from and to")
                .padding(.trailing, 14)
                .disabled(viewModel.fromEndpoint == nil && viewModel.toEndpoint == nil)
            }
            .padding(.horizontal, Spacing.screen)
        }
    }

    private func endpointRow(
        leading: AnyView,
        label: String,
        endpoint: FareEndpoint?,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                leading.frame(width: 14)
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.appMicro)
                        .foregroundStyle(Color.appText3)
                    Text(endpoint?.label ?? "Pick a station or stop")
                        .font(.appBodyMedium)
                        .foregroundStyle(endpoint == nil ? Color.appText2 : Color.appText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let secondary = endpoint?.secondary {
                        Text(secondary)
                            .font(.appCaption)
                            .foregroundStyle(Color.appText3)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .padding(.trailing, 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Category pills

    private func categorySection(_ vm: FaresViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Card type")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FareCategory.allCases, id: \.self) { c in
                        chipButton(label: c.label, isActive: vm.category == c) {
                            vm.category = c
                        }
                    }
                }
                .padding(.horizontal, Spacing.screen)
            }
            .sensoryFeedback(.selection, trigger: vm.category)
        }
    }

    // MARK: - Payment toggle

    private func paymentSection(_ vm: FaresViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Payment")
            HStack(spacing: 8) {
                ForEach(FarePayment.allCases, id: \.self) { p in
                    let disabled = (p == .cash && !vm.mode.acceptsCash)
                    chipButton(label: p.label, isActive: vm.payment == p, disabled: disabled) {
                        if !disabled { vm.payment = p }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.screen)
            if !vm.mode.acceptsCash {
                Text("MRT/LRT is card-only.")
                    .font(.appMicro)
                    .foregroundStyle(Color.appText3)
                    .padding(.horizontal, Spacing.screen)
            }
        }
    }

    // MARK: - Pre-peak toggle (MRT only)

    private func prePeakSection(_ vm: FaresViewModel) -> some View {
        @Bindable var vm = vm
        return VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Pre-peak")
            Toggle(isOn: $vm.isPrePeak) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tap in before 7:45 am (weekdays)")
                        .font(.appBodyMedium)
                        .foregroundStyle(Color.appText)
                    Text("Lower fare on MRT/LRT, excluding public holidays.")
                        .font(.appCaption)
                        .foregroundStyle(Color.appText2)
                }
            }
            .tint(Color.appSuccess)
            .padding(.vertical, 10)
            .padding(.horizontal, Spacing.cardInner)
            .background(Color.appSurface2)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .padding(.horizontal, Spacing.screen)
            .sensoryFeedback(.selection, trigger: vm.isPrePeak)
        }
    }

    // MARK: - Result tile

    private var fareResult: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Estimated fare")
                .font(.appCaption)
                .foregroundStyle(Color.appInfo)
                .opacity(0.85)
            HStack(alignment: .lastTextBaseline) {
                Text(viewModel.fareString)
                    .font(.appHero)
                    .tracking(-1)
                    .foregroundStyle(Color.appInfoStrong)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: viewModel.fareCents)
                Spacer()
                Text(viewModel.bandLabel)
                    .font(.appCaption)
                    .foregroundStyle(Color.appInfo)
                    .opacity(0.85)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appInfoBg)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .padding(.horizontal, Spacing.screen)
    }

    // MARK: - Breakdown

    private var breakdown: some View {
        VStack(spacing: 0) {
            row(key: "Mode", value: viewModel.mode.label)
            divider
            row(key: "Distance band", value: viewModel.bandLabel)
            divider
            row(key: "Card type", value: viewModel.category.label)
            divider
            row(key: "Payment", value: viewModel.payment.label)
            if viewModel.appliesPrePeak {
                divider
                row(key: "Standard fare", value: FaresViewModel.formatCents(viewModel.standardFareCents))
                divider
                row(
                    key: "Pre-peak discount",
                    value: "−\(viewModel.prePeakSavingsString)",
                    valueColor: Color.appSuccess
                )
            }
            divider
            row(key: "Total", value: viewModel.fareString, bold: true)
        }
        .padding(Spacing.cardInner)
        .background(Color.appSurface)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .padding(.horizontal, Spacing.screen)
    }

    private var divider: some View {
        Divider().background(Color.appBorder).padding(.vertical, 6)
    }

    private func row(key: String, value: String, bold: Bool = false, valueColor: Color? = nil) -> some View {
        HStack {
            Text(key)
                .font(bold ? .appLabelStrong : .appLabel)
                .foregroundStyle(bold ? Color.appText : Color.appText2)
            Spacer()
            Text(value)
                .font(bold ? .appLabelStrong : .appLabelMedium)
                .foregroundStyle(valueColor ?? (bold ? Color.appText : Color.appText))
                .contentTransition(.numericText())
        }
        .padding(.vertical, 6)
    }

    // MARK: - Pre-peak savings card (only when toggle on + saving > 0)

    private var prePeakSavingsCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.appSuccess)
            Group {
                Text("You save ")
                    .font(.appLabel)
                    .foregroundStyle(Color.appSuccessStrong)
                +
                Text(viewModel.prePeakSavingsString)
                    .font(.appLabelStrong)
                    .foregroundStyle(Color.appSuccessStrong)
                +
                Text(" with the early-bird MRT discount.")
                    .font(.appLabel)
                    .foregroundStyle(Color.appSuccessStrong)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color.appSuccessBg)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .padding(.horizontal, Spacing.screen)
    }

    // MARK: - LTA link & footnote

    private var ltaLink: some View {
        Link(destination: ltaFareCalculatorURL) {
            HStack {
                Image(systemName: "safari")
                    .font(.system(size: 14, weight: .semibold))
                Text("Verify on LTA's official calculator")
                    .font(.appLabelStrong)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, Spacing.cardInner)
            .frame(maxWidth: .infinity)
            .foregroundStyle(Color.appInfo)
            .background(Color.appSurface)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(Color.appInfo.opacity(0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .padding(.horizontal, Spacing.screen)
    }

    private var sourceFootnote: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 10, weight: .medium))
            Text("Source: PTC fare tables on data.gov.sg")
                .font(.appMicro)
        }
        .foregroundStyle(Color.appText3)
        .padding(.horizontal, Spacing.screen)
        .padding(.top, 2)
    }

    // MARK: - Pieces

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.appCaptionStrong)
            .foregroundStyle(Color.appText3)
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.horizontal, Spacing.screen)
    }

    private func chipButton(
        label: String,
        isActive: Bool,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.appLabelMedium)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(isActive ? Color.appText : Color.appSurface)
                .foregroundStyle(disabled ? Color.appText3 : (isActive ? Color.appSurface : Color.appText))
                .overlay(
                    Capsule().stroke(isActive ? Color.clear : Color.appBorderStrong, lineWidth: 0.5)
                )
                .clipShape(Capsule())
                .opacity(disabled ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}
