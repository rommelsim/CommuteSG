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
                        load: { report in await coldStartPrefetch(report: report) },
                        onComplete: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                hasShownSplash = true
                            }
                        }
                    )
                    .transition(.opacity)
                }
            }
            .task { await NotificationService.shared.bootstrap() }
        }
    }

    /// Cold-launch prefetch — warms the bus-stops dataset so
    /// `HomeViewModel.load()` finds a hot cache the first time it asks.
    /// Splash status text stays friendly and non-technical: the user
    /// doesn't need to know about LTA, DataMall, caches, or row counts.
    /// The traveling-dot animation in `SplashView` is the real progress
    /// indicator; the status label is just a gentle reassurance, so it
    /// only swaps once (mid-load → late-load) rather than chattering.
    private func coldStartPrefetch(
        report: @escaping @MainActor (String) -> Void
    ) async {
        await report("Loading nearby transit…")
        do {
            for try await _ in BusStopsRepository.shared.loadAllStops() { }
        } catch {
            // Silent — Home will retry on appear, and the splash shouldn't
            // surface backend faults to the user.
        }
        await report("Almost there…")
    }
}
