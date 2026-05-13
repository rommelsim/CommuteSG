import SwiftUI

/// Hosts `PlanView` for the inline-morph presentation off Home. Position is
/// driven by a single `offset(y:)` rather than `.transition`, which avoids the
/// jump that happens when a `.move` transition unmounts a view that was
/// already translated by a live drag. Result: open / close / drag all share
/// one animation track.
struct PlannerMorphContainer: View {
    @Binding var isOpen: Bool
    @State private var dragOffset: CGFloat = 0
    @State private var containerHeight: CGFloat = 1000

    private let closeCurve: Animation = .timingCurve(0.32, 0.72, 0, 1, duration: 0.35)

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                handleArea
                PlanView()
            }
            .background(Color.cfPageBackground.ignoresSafeArea())
            .offset(y: appliedOffset)
            .opacity(opacityForOffset)
            .onAppear { containerHeight = geo.size.height }
            .onChange(of: geo.size.height) { _, h in containerHeight = h }
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    /// Final y-translation: hidden = full container height off-screen, open =
    /// follow live drag (clamped to non-negative so the planner can't be
    /// dragged upward past its anchor).
    private var appliedOffset: CGFloat {
        if isOpen { return max(0, dragOffset) }
        return containerHeight
    }

    /// Fades the planner toward transparent as the user drags it down — caps
    /// at 0.4 so it never disappears entirely before the dismiss threshold.
    private var opacityForOffset: Double {
        guard isOpen else { return 0 }
        let progress = min(Double(dragOffset) / 300.0, 1.0)
        return 1 - progress * 0.4
    }

    private var handleArea: some View {
        VStack(spacing: 6) {
            Capsule()
                .fill(Color.cfHairlineStrong)
                .frame(width: 36, height: 5)
                .padding(.top, 10)
            Text("swipe to close")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.cfTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 6)
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Close planner")
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Track downward drag only. No animation wrapping — the
                // offset follows the finger 1:1 for a tactile feel.
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                let shouldClose = value.translation.height > 80
                    || value.predictedEndTranslation.height > 200
                if shouldClose {
                    // Single animation track: flip isOpen *and* let dragOffset
                    // snap back to 0 so the next open starts clean. Both
                    // happen inside the same curve so there's no fight
                    // between a transition and a residual translation.
                    withAnimation(closeCurve) {
                        isOpen = false
                        dragOffset = 0
                    }
                } else {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                        dragOffset = 0
                    }
                }
            }
    }
}
