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
    }
}
