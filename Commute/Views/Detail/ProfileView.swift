import SwiftUI
import UIKit

/// Bug reports are sent to this address.
private let bugReportRecipient = "commute688@gmail.com"

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @State private var showingOnboarding = false
    @State private var showingNameEditor = false
    @State private var editingPlace: SavedPlace.Kind?
    @State private var showingMailUnavailable = false
    @State private var showingFavourites = false

    var body: some View {
        VStack(spacing: 0) {
            DetailHeader(
                center: {
                    Text("Profile")
                        .font(.appSubTitle)
                        .foregroundStyle(Color.cfTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .center)
                },
                trailing: {
                    Color.clear.frame(width: 36, height: 36)
                }
            )
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    userCard
                    SectionLabel(text: "Saved places")
                    savedPlacesGroup
                    SectionLabel(text: "Preferences")
                    preferencesGroup
                    SectionLabel(text: "About")
                    aboutGroup
                }
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(Color.appSurface)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showingOnboarding) {
            OnboardingFlowView()
        }
        .sheet(isPresented: $showingNameEditor) {
            NameEditorSheet()
                .environment(appState)
                .presentationDetents([.height(220)])
        }
        .sheet(item: $editingPlace) { kind in
            PlaceEditorSheet(kind: kind)
                .environment(appState)
                .presentationDetents([.height(260)])
        }
        .sheet(isPresented: $showingFavourites) {
            FavouritesSheet()
                .environment(appState)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var userCard: some View {
        Button { showingNameEditor = true } label: {
            HStack(spacing: 12) {
                Text(avatarInitial)
                    .font(.appSubTitle)
                    .foregroundStyle(Color.appInfo)
                    .frame(width: 48, height: 48)
                    .background(Color.appInfoBg)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.appSection)
                        .foregroundStyle(Color.cfTextPrimary)
                    Text("Tap to edit")
                        .font(.appCaption)
                        .foregroundStyle(Color.cfTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.cfTextTertiary)
            }
            // `.frame(maxWidth: .infinity)` BEFORE the background — without
            // it the HStack collapses to its intrinsic content size and the
            // background only paints under that narrow span, leaving the
            // card visually unfilled across the available width.
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.appSurface2)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .padding(.horizontal, Spacing.screen)
        }
        .buttonStyle(.plain)
    }

    private var displayName: String {
        let trimmed = appState.userName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Set your name" : trimmed
    }

    private var avatarInitial: String {
        let trimmed = appState.userName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "•" : String(trimmed.prefix(1)).uppercased()
    }

    private var savedPlacesGroup: some View {
        ListGroup {
            Button { editingPlace = .home } label: {
                ListRow(
                    symbol: "house.fill", symbolTint: Color.appInfo,
                    label: "Home",
                    value: addressValue(for: .home),
                    chevron: true
                )
            }
            .buttonStyle(.plain)

            Button { editingPlace = .work } label: {
                ListRow(
                    symbol: "briefcase.fill", symbolTint: Color.appPurple,
                    label: "Work",
                    value: addressValue(for: .work),
                    chevron: true
                )
            }
            .buttonStyle(.plain)

            Button { showingFavourites = true } label: {
                ListRow(
                    symbol: "star.fill", symbolTint: Color.appAmber,
                    label: "Favourite stops & lines",
                    value: "\(appState.favoriteBusStopCodes.count + appState.favoriteLineCodes.count)",
                    chevron: true
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.screen)
    }

    private func addressValue(for kind: SavedPlace.Kind) -> String {
        let raw = appState.savedPlaces.first(where: { $0.kind == kind })?.address ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Not set" : trimmed
    }

    private var preferencesGroup: some View {
        ListGroup {
            Button {
                appState.cycleColorScheme()
            } label: {
                ListRow(symbol: "moon.fill", symbolTint: Color.cfTextSecondary, label: "Dark mode", value: appState.colorScheme.label)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: appState.colorScheme)

            ListRow(symbol: "bell.fill", symbolTint: Color.cfTextSecondary, label: "Notifications") {
                ToggleSwitch(isOn: Binding(get: { appState.notificationsEnabled }, set: { appState.notificationsEnabled = $0 }))
            }

            Button {
                appState.cycleLanguage()
            } label: {
                ListRow(
                    symbol: "globe",
                    symbolTint: Color.cfTextSecondary,
                    label: "Language",
                    value: appState.language.displayName
                )
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: appState.language)
        }
        .padding(.horizontal, Spacing.screen)
    }

    private var aboutGroup: some View {
        ListGroup {
            Button {
                showingOnboarding = true
            } label: {
                ListRow(symbol: "sparkles", symbolTint: Color.cfTextSecondary, label: "Replay onboarding", chevron: true)
            }
            .buttonStyle(.plain)

            Button {
                openBugReport()
            } label: {
                ListRow(symbol: "ladybug.fill", symbolTint: Color.appDanger, label: "Report a bug", chevron: true)
            }
            .buttonStyle(.plain)
            .alert("Email not set up", isPresented: $showingMailUnavailable) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Add a mail account in Settings, or email \(bugReportRecipient) from another device.")
            }

            ListRow(
                symbol: "info.circle.fill",
                symbolTint: Color.cfTextSecondary,
                label: "App version",
                value: Self.appVersionLabel
            )
        }
        .padding(.horizontal, Spacing.screen)
    }

    /// Read the live marketing version + build number from `Info.plist`.
    /// `CFBundleShortVersionString` is what Xcode's General → Version field
    /// writes (e.g. "1.0.2"); `CFBundleVersion` is the Build field (e.g. "1").
    /// Combined for display so testers can see exactly which build they're on.
    private static var appVersionLabel: String {
        let info = Bundle.main.infoDictionary
        let v = (info?["CFBundleShortVersionString"] as? String) ?? "—"
        let b = (info?["CFBundleVersion"] as? String) ?? "—"
        return "\(v) (\(b))"
    }

    /// Compose a `mailto:` URL with diagnostic info pre-filled so the user
    /// only has to describe what went wrong. Falls back to an alert if the
    /// device has no mail client configured.
    private func openBugReport() {
        let info = Bundle.main.infoDictionary
        let appVersion = info?["CFBundleShortVersionString"] as? String ?? "?"
        let buildNumber = info?["CFBundleVersion"] as? String ?? "?"
        let device = UIDevice.current
        let modelName = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]
            ?? UIDevice.current.model

        let subject = "Commute Bug Report"
        let body = """
        Hi,

        I ran into an issue in Commute.

        What happened:


        Steps to reproduce:
        1.
        2.
        3.

        — Diagnostics (please leave intact) —
        App: Commute \(appVersion) (build \(buildNumber))
        iOS: \(device.systemVersion)
        Device: \(modelName)
        """

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = bugReportRecipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]

        guard let url = components.url else { return }
        openURL(url) { accepted in
            if !accepted { showingMailUnavailable = true }
        }
    }
}

extension SavedPlace.Kind: Identifiable {
    public var id: String { rawValue }
}

private struct NameEditorSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your name")
                .font(.appSubTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("Enter your name", text: $draft)
                .font(.appBody)
                .padding(12)
                .background(Color.appSurface2)
                .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                .submitLabel(.done)
                .focused($isFocused)
                .onSubmit(save)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(true)
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Save", action: save)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appInfo)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        // `.frame(maxWidth: .infinity, maxHeight: .infinity)` BEFORE the
        // background so the surface paints across the full sheet area —
        // without this the VStack collapses to its intrinsic content size
        // and the unfilled bottom strip shows through to the dimmed
        // backdrop. Same fix pattern as PlaceEditorSheet.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.appSurface)
        .onAppear {
            draft = appState.userName
            isFocused = true
        }
    }

    private func save() {
        appState.userName = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        dismiss()
    }
}

// MARK: - List building blocks

private struct ListGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Color.appSurface)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.cfHairline, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

private struct ListRow<Trailing: View>: View {
    let symbol: String
    let symbolTint: Color
    let label: String
    let value: String?
    let chevron: Bool
    @ViewBuilder let trailing: Trailing

    init(
        symbol: String,
        symbolTint: Color,
        label: String,
        value: String? = nil,
        chevron: Bool = false,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.symbol = symbol
        self.symbolTint = symbolTint
        self.label = label
        self.value = value
        self.chevron = chevron
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(symbolTint)
                .frame(width: 22)
            // Wrap incoming String through LocalizedStringKey so callers can
            // pass plain literals like "Dark mode" and still get the Chinese
            // translation. For already-localized strings (e.g. dynamic enum
            // labels via String(localized:)), the lookup falls through and
            // the value renders verbatim — harmless.
            Text(LocalizedStringKey(label))
                .font(.appBodyMedium)
                .foregroundStyle(Color.cfTextPrimary)
            Spacer()
            if let value {
                Text(LocalizedStringKey(value))
                    .font(.appCaption)
                    .foregroundStyle(Color.cfTextSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            trailing
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.cfTextTertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color.appSurface)
        .overlay(
            Rectangle()
                .fill(Color.cfHairline)
                .frame(height: 0.5),
            alignment: .top
        )
    }
}

private struct ToggleSwitch: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle("", isOn: $isOn)
            .labelsHidden()
            .tint(Color.appInfo)
            .sensoryFeedback(.selection, trigger: isOn)
    }
}
