import SwiftUI

/// A loading-state placeholder rectangle with an animated shimmer sweep
/// across it. Use it to build skeleton cards that match the final layout
/// instead of showing a blank `ProgressView` + "Loading…" text. Apple's
/// `.redacted(reason: .placeholder)` greys out real content nicely; layering
/// `.shimmering()` on top adds the moving highlight that signals "loading,
/// not broken".
public extension View {
    func shimmering() -> some View {
        modifier(Shimmer())
    }
}

private struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -0.6

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.35),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: phase * geo.size.width * 1.6)
                    .blendMode(.overlay)
                }
                .mask(content)
            }
            .onAppear {
                withAnimation(
                    .linear(duration: 1.4).repeatForever(autoreverses: false)
                ) {
                    phase = 1.0
                }
            }
    }
}

/// Reusable solid-rounded-rect placeholder bar. Use with explicit `width` and
/// `height` to mimic text/card shapes (e.g. `SkeletonBar(width: 120, height: 14)`).
struct SkeletonBar: View {
    var width: CGFloat? = nil
    var height: CGFloat = 12
    var cornerRadius: CGFloat = 6

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.appBorderStrong.opacity(0.35))
            .frame(width: width, height: height)
    }
}

/// One card-shaped skeleton matching the layout of `NearbyBusStopCard`.
struct NearbyBusStopSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle()
                    .fill(Color.appBorderStrong.opacity(0.35))
                    .frame(width: 14, height: 14)
                SkeletonBar(width: 90, height: 12)
                Spacer()
                SkeletonBar(width: 32, height: 9)
            }
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .fill(Color.appBorderStrong.opacity(0.18))
                        .frame(height: 50)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .shimmering()
    }
}

/// Skeleton matching `NearbyMRTCard` layout — line badge + station name +
/// status pill.
struct NearbyMRTSkeleton: View {
    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.appBorderStrong.opacity(0.35))
                .frame(width: 36, height: 18)
            SkeletonBar(width: 110, height: 12)
            Spacer()
            SkeletonBar(width: 70, height: 10)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .shimmering()
    }
}

/// Skeleton row for the MRT line-status grid in `AlertsView`.
struct LineStatusSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { idx in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.appBorderStrong.opacity(0.35))
                        .frame(width: 36, height: 18)
                    SkeletonBar(width: 130, height: 12)
                    Spacer()
                    SkeletonBar(width: 50, height: 14, cornerRadius: 7)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                if idx != 4 {
                    Divider()
                        .background(Color.appBorder)
                        .padding(.leading, 60)
                }
            }
        }
        .background(Color.appSurface2)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 0.5)
        )
        .shimmering()
    }
}

/// Skeleton for the ETA rows in `ShortcutPreviewSheet`.
struct ShortcutETASkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { idx in
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.appBorderStrong.opacity(0.3))
                        .frame(width: 22, height: 22)
                    SkeletonBar(width: 60, height: 12)
                    Spacer()
                    SkeletonBar(width: 50, height: 12)
                }
                .padding(14)
                if idx != 2 {
                    Divider().background(Color.appBorder)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.appSurface)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .shimmering()
    }
}
