import SwiftUI

@main
struct CommuteApp: App {
    @State private var appState = AppState()
    /// Lives for the lifetime of the process (App is created once per cold
    /// launch). The splash plays on every cold launch, but stays dismissed
    /// across backgrounding / re-foregrounding.
    @State private var hasShownSplash = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if hasShownSplash {
                    RootView()
                        .environment(appState)
                        .transition(.opacity)
                } else {
                    SplashView(
                        load: { await coldStartPrefetch() },
                        onComplete: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                hasShownSplash = true
                            }
                        }
                    )
                    .transition(.opacity)
                }
            }
        }
    }

    /// Cold-launch prefetch — warms the bus-stops dataset so
    /// `HomeViewModel.load()` finds a hot cache the first time it asks.
    /// Errors are swallowed; Home will retry on appear if this misses.
    private func coldStartPrefetch() async {
        do {
            for try await _ in BusStopsRepository.shared.loadAllStops() { }
        } catch {
            // Intentional no-op — Home re-runs the same call on appear.
        }
    }
}
