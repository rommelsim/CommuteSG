import SwiftUI

struct PlaceEditorSheet: View {
    let kind: SavedPlace.Kind
    var onSave: ((String) -> Void)? = nil

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""
    @FocusState private var isFocused: Bool

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
                .onSubmit(save)
                .textInputAutocapitalization(.words)
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Save", action: save)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appInfo)
            }
        }
        .padding(20)
        .background(Color.appSurface)
        .onAppear {
            draft = appState.savedPlaces.first(where: { $0.kind == kind })?.address ?? ""
            isFocused = true
        }
    }

    private var title: String {
        switch kind {
        case .home:   "Home"
        case .work:   "Work"
        case .custom: "Place"
        }
    }

    private func save() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        appState.setSavedPlaceAddress(kind, address: trimmed)
        onSave?(trimmed)
        dismiss()
    }
}
