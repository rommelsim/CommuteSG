import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        // `.preferredColorScheme(nil)` is documented as "follow system" but in
        // practice can leave a stale preference on the WindowGroup so the app
        // doesn't react when the user toggles Settings → Display & Brightness.
        // We only apply the modifier when the user has explicitly chosen Light
        // or Dark; on `.system` we don't apply it at all so the app naturally
        // inherits the OS appearance and re-renders on system changes.
        if let scheme = appState.colorScheme.preferred {
            content.preferredColorScheme(scheme)
        } else {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        Group {
            if appState.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingFlowView()
            }
        }
        .animation(.snappy, value: appState.hasCompletedOnboarding)
        .toastOverlay()
        // Bundle.main's localized-string cache survives view rebuilds, but
        // SwiftUI's Text cache is keyed by view identity — bumping `.id` on
        // language change forces every Text to re-resolve through the
        // (now-swizzled) bundle so the UI redraws in the new language
        // without an app restart.
        .id(appState.language)
        .environment(\.locale, appState.language.locale)
    }
}
