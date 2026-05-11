import SwiftUI

// MARK: - Animated splash view shown during cold launch while data loads.
//
// Usage:
//   SplashView {
//       // your async data load (LTA DataMall calls)
//       try? await Task.sleep(for: .seconds(2)) // placeholder
//   } onComplete: {
//       // called when the load finishes; switch to your main view here
//   }
//
// Drop this in as your app's first view. Replace the blue cold-launch
// screen by setting your iOS LaunchScreen to plain white (matches the
// icon background) so there's no color flash before this view appears.

struct SplashView: View {
    /// Async work to perform while the splash is on-screen
    /// (e.g. fetching MRT + bus arrivals from LTA DataMall).
    let load: () async -> Void

    /// Called once the load completes and the fade-out finishes.
    let onComplete: () -> Void

    @State private var dotProgress: CGFloat = 0
    @State private var statusIndex: Int = 0
    @State private var isVisible: Bool = true

    private let statusMessages = [
        "Fetching MRT arrivals…",
        "Loading bus stops…",
        "Almost there…"
    ]

    private let routeWidth: CGFloat = 180
    private let routeHeight: CGFloat = 40

    var body: some View {
        ZStack {
            // Solid white — matches the app icon background, no blue flash.
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 14) {
                // Wordmark
                Text("commute")
                    .font(.system(size: 42, weight: .bold, design: .default))
                    .tracking(-2)
                    .foregroundStyle(.black)

                // Animated route + traveling dot
                routeAnimation
                    .frame(width: routeWidth, height: routeHeight)

                // Status label, rotates as data loads
                Text(statusMessages[statusIndex])
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.top, 14)
                    .id(statusIndex)                              // forces transition
                    .transition(.opacity.animation(.easeInOut(duration: 0.25)))
            }
        }
        // Splash is a brand surface — always white background, always dark
        // text — so we pin the colour scheme to light. Otherwise semantic
        // colours like `.secondary` on the status label resolve to light grey
        // in dark mode and disappear against the white background.
        .colorScheme(.light)
        .opacity(isVisible ? 1 : 0)
        .task {
            let start = ContinuousClock.now
            // Guarantees the user sees at least one full there-and-back of the
            // travelling dot even when the data load returns instantly (warm
            // cache). Equal to one full round trip of the dot animation so the
            // dot always returns to its starting station before fade-out.
            let minimumVisible: Duration = .seconds(3.0)

            // 1. Start the route animation (loops until view disappears).
            //    1.5s per direction → 3.0s full round trip.
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                dotProgress = 1
            }

            // 2. Cycle status text. Paced to ~half the dot round-trip so all
            //    three messages get a chance to show across the minimum window.
            let statusTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(1500))
                    if Task.isCancelled { break }
                    withAnimation {
                        statusIndex = (statusIndex + 1) % statusMessages.count
                    }
                }
            }

            // 3. Run the actual data load.
            await load()
            statusTask.cancel()

            // 4. Hold the splash up to the minimum visible window so the dot
            //    animation completes its first round trip before fade-out.
            let elapsed = ContinuousClock.now - start
            if elapsed < minimumVisible {
                try? await Task.sleep(for: minimumVisible - elapsed)
            }

            // 5. Fade out, then hand off to the main app.
            withAnimation(.easeInOut(duration: 0.35)) { isVisible = false }
            try? await Task.sleep(for: .milliseconds(350))
            onComplete()
        }
    }

    // MARK: - Route animation

    private var routeAnimation: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let y = geo.size.height / 2
            let startX: CGFloat = 10
            let endX: CGFloat = w - 10

            ZStack {
                // Track
                Path { p in
                    p.move(to: CGPoint(x: startX, y: y))
                    p.addLine(to: CGPoint(x: endX, y: y))
                }
                .stroke(Color(white: 0.91), style: StrokeStyle(lineWidth: 2, lineCap: .round))

                // Station dots
                ForEach([startX, w / 2, endX], id: \.self) { x in
                    Circle()
                        .fill(Color(white: 0.8))
                        .frame(width: 6, height: 6)
                        .position(x: x, y: y)
                }

                // Pulse trail
                Circle()
                    .fill(Color(red: 1, green: 0.23, blue: 0.19).opacity(0.3))
                    .frame(width: 22, height: 22)
                    .position(
                        x: startX + (endX - startX) * dotProgress,
                        y: y
                    )
                    .scaleEffect(0.6 + dotProgress * 0.6)

                // Active traveling dot
                Circle()
                    .fill(Color(red: 1, green: 0.23, blue: 0.19))   // #FF3B30
                    .frame(width: 12, height: 12)
                    .position(
                        x: startX + (endX - startX) * dotProgress,
                        y: y
                    )
            }
        }
    }
}

#Preview {
    SplashView(
        load: { try? await Task.sleep(for: .seconds(3)) },
        onComplete: { print("Splash finished") }
    )
}
