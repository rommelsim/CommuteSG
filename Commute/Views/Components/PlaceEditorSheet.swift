import SwiftUI
import MapKit

struct PlaceEditorSheet: View {
    let kind: SavedPlace.Kind
    var onSave: ((String) -> Void)? = nil

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""
    @State private var completer = AddressSearchCompleter()
    @State private var detent: PresentationDetent = .height(320)
    @FocusState private var isFocused: Bool

    private var trimmed: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var hasContent: Bool { !trimmed.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: kind.symbol)
                    .foregroundStyle(kind == .home ? Color.appInfo : Color.appPurple)
                Text(title)
                    .font(.appSubTitle)
            }
            Text("Address or station name")
                .font(.appCaption)
                .foregroundStyle(Color.appText2)
            TextField("e.g. Blk 416 Bedok North Rd", text: $draft, axis: .vertical)
                .font(.appBody)
                .lineLimit(2...3)
                .padding(12)
                .background(Color.appSurface2)
                .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                .submitLabel(.done)
                .focused($isFocused)
                .onSubmit { if hasContent { save() } }
                .textInputAutocapitalization(.words)

            if !completer.results.isEmpty {
                suggestionsList
            }

            Spacer(minLength: 0)

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Save", action: save)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appInfo)
                    .disabled(!hasContent)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.appSurface)
        .presentationDetents([.height(320), .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .onAppear {
            draft = appState.savedPlaces.first(where: { $0.kind == kind })?.address ?? ""
            isFocused = true
        }
        .onChange(of: draft) { _, newValue in
            completer.update(query: newValue)
            // First keystroke that produces content → grow the sheet so the
            // suggestion list has room to breathe.
            if !newValue.isEmpty && detent != .large {
                withAnimation(.snappy) { detent = .large }
            }
        }
        .onChange(of: isFocused) { _, focused in
            if focused && !draft.isEmpty && detent != .large {
                withAnimation(.snappy) { detent = .large }
            }
        }
    }

    // MARK: - Suggestions

    private var suggestionsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(completer.results.enumerated()), id: \.offset) { idx, result in
                    Button { apply(result) } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.appText3)
                                .frame(width: 18)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .font(.appBodyMedium)
                                    .foregroundStyle(Color.appText)
                                    .lineLimit(1)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.appCaption)
                                        .foregroundStyle(Color.appText2)
                                        .lineLimit(2)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if idx < completer.results.count - 1 {
                        Divider().background(Color.appBorder).padding(.leading, 42)
                    }
                }
            }
            .background(Color.appSurface2)
            .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
        }
        .scrollIndicators(.hidden)
    }

    private func apply(_ result: MKLocalSearchCompletion) {
        // Combine title + subtitle into one address string. The title alone
        // is often a building/POI name; the subtitle gives the road/area.
        if result.subtitle.isEmpty {
            draft = result.title
        } else {
            draft = "\(result.title), \(result.subtitle)"
        }
        completer.clear()
        isFocused = false
    }

    private var title: String {
        switch kind {
        case .home:   "Home"
        case .work:   "Work"
        case .custom: "Place"
        }
    }

    private func save() {
        guard hasContent else { return }
        appState.setSavedPlaceAddress(kind, address: trimmed)
        onSave?(trimmed)
        dismiss()
    }
}
