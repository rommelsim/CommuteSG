import SwiftUI

/// Sheet for picking a fare-calculator endpoint (point A or B). Reuses the
/// global `SearchViewModel` for live search across MRT stations + bus stops,
/// then maps the tapped result into a coordinate-bearing `FareEndpoint`.
struct FareEndpointPicker: View {
    enum Field: Identifiable, Hashable {
        case from, to

        var id: String {
            switch self {
            case .from: "from"
            case .to:   "to"
            }
        }

        var title: String {
            switch self {
            case .from: "Pick starting point"
            case .to:   "Pick destination"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var search = SearchViewModel()

    let field: Field
    let onPick: (FareEndpoint) -> Void

    var body: some View {
        @Bindable var search = search

        NavigationStack {
            VStack(spacing: 0) {
                searchField
                    .padding(.horizontal, Spacing.screen)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                Divider().background(Color.cfHairline)
                content
            }
            .background(Color.appSurface)
            .navigationTitle(field.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.appInfo)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isFocused = true }
        }
    }

    @ViewBuilder
    private var content: some View {
        let trimmed = search.query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            emptyHint
        } else if search.busStopResults.isEmpty && search.mrtResults.isEmpty && !search.isSearching {
            ContentUnavailableView.search(text: trimmed)
        } else {
            results
        }
    }

    private var emptyHint: some View {
        VStack(spacing: 8) {
            Spacer().frame(height: 28)
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.cfTextTertiary)
            Text("Search for an MRT station or bus stop")
                .font(.appBody)
                .foregroundStyle(Color.cfTextSecondary)
            Text("e.g. \"Jurong East\", \"Marina Bay\", or a 5-digit stop code.")
                .font(.appCaption)
                .foregroundStyle(Color.cfTextTertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.screen)
    }

    private var results: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s20) {
                if !search.mrtResults.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        sectionHeader("MRT stations")
                        VStack(spacing: 0) {
                            ForEach(search.mrtResults) { station in
                                Button {
                                    if let ep = FareEndpoint.make(from: station) { pick(ep) }
                                } label: {
                                    mrtRow(station: station)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                if !search.busStopResults.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        sectionHeader("Bus stops")
                        VStack(spacing: 0) {
                            ForEach(search.busStopResults) { stop in
                                Button {
                                    if let ep = FareEndpoint.make(from: stop) { pick(ep) }
                                } label: {
                                    busStopRow(stop: stop)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.appCaptionStrong)
            .foregroundStyle(Color.cfTextTertiary)
            .textCase(.uppercase)
            .tracking(0.4)
            .padding(.horizontal, Spacing.screen)
    }

    private var searchField: some View {
        @Bindable var search = search
        return HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.cfTextSecondary)
            TextField("Station, stop, road, or 5-digit code", text: $search.query)
                .focused($isFocused)
                .submitLabel(.search)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(true)
                .font(.appBody)
            if search.isSearching {
                ProgressView().scaleEffect(0.7)
            } else if !search.query.isEmpty {
                Button { search.query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.cfTextTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color.appSurface2)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private func mrtRow(station: MRTStation) -> some View {
        HStack(spacing: 12) {
            LineBadge(line: station.line, code: station.id, emphasized: false)
            VStack(alignment: .leading, spacing: 2) {
                Text(station.name)
                    .font(.appBodyMedium)
                    .foregroundStyle(Color.cfTextPrimary)
                Text(station.line.fullName)
                    .font(.appCaption)
                    .foregroundStyle(Color.cfTextSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.cfTextTertiary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, Spacing.screen)
        .contentShape(Rectangle())
    }

    private func busStopRow(stop: BusStop) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bus.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.cfTextSecondary)
                .frame(width: 32, height: 32)
                .background(Color.appSurface2)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(stop.name)
                    .font(.appBodyMedium)
                    .foregroundStyle(Color.cfTextPrimary)
                Text("\(stop.id) · \(stop.road)")
                    .font(.appCaption)
                    .foregroundStyle(Color.cfTextSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.cfTextTertiary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, Spacing.screen)
        .contentShape(Rectangle())
    }

    private func pick(_ endpoint: FareEndpoint) {
        onPick(endpoint)
        // Subtle confirmation that the fare has just been recomputed for
        // the new endpoint pair — paired with the toast/haptic at the
        // call sites the user already gets.
        SoundEffect.playSuccess()
        dismiss()
    }
}
