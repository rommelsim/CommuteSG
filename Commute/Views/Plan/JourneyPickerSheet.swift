import SwiftUI

struct JourneyPickerSheet: View {
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
            case .from: "Set starting point"
            case .to:   "Set destination"
            }
        }

        var placeholder: String {
            switch self {
            case .from: "Search station, road, or stop code"
            case .to:   "Search station, road, or stop code"
            }
        }
    }

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var search = SearchViewModel()

    let field: Field
    let initialText: String
    let onPick: (String) -> Void

    var body: some View {
        @Bindable var search = search

        NavigationStack {
            VStack(spacing: 0) {
                searchField
                    .padding(.horizontal, Spacing.screen)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                Divider().background(Color.appBorder)
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
            if initialText != "Current location" {
                search.query = initialText
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isFocused = true }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        let trimmed = search.query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            shortcutsList
        } else if search.busStopResults.isEmpty && search.mrtResults.isEmpty && !search.isSearching {
            noResultsView(for: trimmed)
        } else {
            resultsList(query: trimmed)
        }
    }

    // MARK: - Empty state (shortcuts)

    private var shortcutsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s20) {
                if field == .from {
                    quickRow(
                        symbol: "location.fill",
                        tint: Color.appInfo,
                        title: "Current location",
                        subtitle: "Use device GPS"
                    ) {
                        pick("Current location")
                    }
                }

                let saved = appState.savedPlaces.filter {
                    !$0.address.trimmingCharacters(in: .whitespaces).isEmpty
                }
                if !saved.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        sectionHeader("Saved places")
                        VStack(spacing: 8) {
                            ForEach(saved) { place in
                                quickRow(
                                    symbol: place.kind.symbol,
                                    tint: place.kind == .work ? Color.appPurple : Color.appInfo,
                                    title: place.label,
                                    subtitle: place.address
                                ) {
                                    pick(place.address)
                                }
                            }
                        }
                    }
                }

                Text("Type a station name, road, or 5-digit stop code to search.")
                    .font(.appCaption)
                    .foregroundStyle(Color.appText3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.screen)
                    .padding(.top, 4)
            }
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Results

    private func resultsList(query: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s20) {
                if !search.mrtResults.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        sectionHeader("MRT stations")
                        VStack(spacing: 0) {
                            ForEach(search.mrtResults) { station in
                                Button {
                                    pick("\(station.name) MRT")
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
                                    pick(stop.name)
                                } label: {
                                    busStopRow(stop: stop)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Button {
                    pick(query)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "text.cursor")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.appText2)
                            .frame(width: 32, height: 32)
                            .background(Color.appSurface2)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Use “\(query)”")
                                .font(.appBodyMedium)
                                .foregroundStyle(Color.appText)
                            Text("Set as a free-text address")
                                .font(.appCaption)
                                .foregroundStyle(Color.appText2)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.appText3)
                    }
                    .padding(.horizontal, Spacing.screen)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private func noResultsView(for query: String) -> some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 30)
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.appText3)
            Text("No matches for “\(query)”")
                .font(.appBody)
                .foregroundStyle(Color.appText2)
            Button {
                pick(query)
            } label: {
                Text("Use “\(query)” anyway")
                    .font(.appLabelMedium)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 14)
                    .background(Color.appInfoBg)
                    .foregroundStyle(Color.appInfo)
                    .clipShape(Capsule())
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.screen)
    }

    // MARK: - Result rows

    private func mrtRow(station: MRTStation) -> some View {
        HStack(spacing: 12) {
            LineBadge(line: station.line, code: station.id, emphasized: false)
            VStack(alignment: .leading, spacing: 2) {
                Text(station.name)
                    .font(.appBodyMedium)
                    .foregroundStyle(Color.appText)
                Text(station.line.fullName)
                    .font(.appCaption)
                    .foregroundStyle(Color.appText2)
            }
            Spacer()
            if let m = station.distanceMeters {
                Text(distanceLabel(m))
                    .font(.appMicro)
                    .foregroundStyle(Color.appText3)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.appText3)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, Spacing.screen)
        .contentShape(Rectangle())
    }

    private func busStopRow(stop: BusStop) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bus.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.appText2)
                .frame(width: 32, height: 32)
                .background(Color.appSurface2)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(stop.name)
                    .font(.appBodyMedium)
                    .foregroundStyle(Color.appText)
                Text("\(stop.id) · \(stop.road)")
                    .font(.appCaption)
                    .foregroundStyle(Color.appText2)
                    .lineLimit(1)
            }
            Spacer()
            if let m = stop.distanceMeters {
                Text(distanceLabel(m))
                    .font(.appMicro)
                    .foregroundStyle(Color.appText3)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.appText3)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, Spacing.screen)
        .contentShape(Rectangle())
    }

    // MARK: - Pieces

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.appCaptionStrong)
            .foregroundStyle(Color.appText3)
            .textCase(.uppercase)
            .tracking(0.4)
            .padding(.horizontal, Spacing.screen)
    }

    private var searchField: some View {
        @Bindable var search = search
        return HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.appText2)
            TextField(field.placeholder, text: $search.query)
                .focused($isFocused)
                .submitLabel(.search)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(true)
                .font(.appBody)
                .onSubmit {
                    let trimmed = search.query.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty { pick(trimmed) }
                }
            if search.isSearching {
                ProgressView()
                    .scaleEffect(0.7)
            } else if !search.query.isEmpty {
                Button { search.query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.appText3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color.appSurface2)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private func quickRow(
        symbol: String,
        tint: Color,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.appBodyMedium)
                        .foregroundStyle(Color.appText)
                    Text(subtitle)
                        .font(.appCaption)
                        .foregroundStyle(Color.appText2)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.appText3)
            }
            .padding(.horizontal, Spacing.screen)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func pick(_ value: String) {
        onPick(value)
        dismiss()
    }

    private func distanceLabel(_ meters: Int) -> String {
        meters < 1000 ? "\(meters)m" : String(format: "%.1fkm", Double(meters) / 1000)
    }
}
