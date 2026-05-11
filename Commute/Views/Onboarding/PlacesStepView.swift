import SwiftUI

struct PlacesStepView: View {
    @Environment(AppState.self) private var appState
    @State private var alertsOn: Bool = true
    @State private var name: String = ""
    @State private var homeAddress: String = ""
    @State private var workAddress: String = ""
    @FocusState private var focusedField: Field?

    enum Field: Hashable { case name, home, work }

    let onFinish: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Text("Set up your profile")
                        .font(.appTitleMedium)
                    Text("So we can greet you and find your way home.")
                        .font(.appBody)
                        .foregroundStyle(Color.appText2)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 14) {
                    nameField
                    placeField(
                        kind: .home,
                        label: "Home",
                        placeholder: "Address or station name",
                        text: $homeAddress,
                        field: .home
                    )
                    placeField(
                        kind: .work,
                        label: "Work",
                        placeholder: "Address or station name",
                        text: $workAddress,
                        field: .work
                    )
                    alertToggleRow
                }

                Button(action: finish) {
                    Text("Start using Commute")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(background: Color.appInfo, foreground: .white))
                .padding(.top, 24)
                .padding(.bottom, 16)
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            alertsOn = appState.notificationsEnabled
            name = appState.userName
            homeAddress = appState.savedPlaces.first(where: { $0.kind == .home })?.address ?? ""
            workAddress = appState.savedPlaces.first(where: { $0.kind == .work })?.address ?? ""
        }
        .onChange(of: alertsOn) { _, newValue in
            appState.notificationsEnabled = newValue
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your name")
                .font(.appLabelStrong)
                .foregroundStyle(Color.appText)
            TextField("e.g. Aisyah", text: $name)
                .focused($focusedField, equals: .name)
                .submitLabel(.next)
                .onSubmit { focusedField = .home }
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(true)
                .padding(12)
                .background(Color.appSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .stroke(focusedField == .name ? Color.appInfo : Color.appBorder, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
    }

    private func placeField(
        kind: SavedPlace.Kind,
        label: String,
        placeholder: String,
        text: Binding<String>,
        field: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(kind == .home ? Color.appInfo : Color.appPurple)
                Text(label)
                    .font(.appLabelStrong)
                    .foregroundStyle(Color.appText)
            }
            TextField(placeholder, text: text, axis: .vertical)
                .lineLimit(1...3)
                .focused($focusedField, equals: field)
                .submitLabel(field == .home ? .next : .done)
                .onSubmit {
                    if field == .home { focusedField = .work }
                    else { focusedField = nil }
                }
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(Color.appSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .stroke(focusedField == field ? Color.appInfo : Color.appBorder, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
    }

    private var alertToggleRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.appText2)
                .frame(width: 22)
            Text("Alert me about disruptions")
                .font(.appBodyMedium)
                .foregroundStyle(Color.appText)
            Spacer()
            Toggle("", isOn: $alertsOn)
                .labelsHidden()
                .tint(Color.appInfo)
                .sensoryFeedback(.selection, trigger: alertsOn)
        }
        .padding(14)
        .background(Color.appSurface)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .padding(.top, 6)
    }

    private func finish() {
        appState.userName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        appState.setSavedPlaceAddress(.home, address: homeAddress)
        appState.setSavedPlaceAddress(.work, address: workAddress)
        onFinish()
    }
}
