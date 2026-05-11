import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingFlowView()
            }
        }
        .preferredColorScheme(appState.colorScheme.preferred)
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
