import SwiftUI

/// iOS 26 Liquid Glass surface modifiers used across the app: cards, capsules,
/// and circular buttons. Falls back to `.regularMaterial` + a 0.5px white
/// hairline stroke on iOS 17–25 per redesign spec §1, so older OSes still
/// get a recognisably "glass" finish.
extension View {
    /// Standard rectangular glass surface with rounded corners.
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassRectModifier(cornerRadius: cornerRadius, tint: nil))
    }

    /// Tinted glass — used where a card carries an accent colour (Home/Work
    /// shortcuts, imminent arrival chip, "Best" plan card, etc.). Tint is
    /// blended by the system on iOS 26; layered as a translucent overlay on
    /// the Material fallback.
    func tintedGlassCard(cornerRadius: CGFloat = 16, tint: Color) -> some View {
        modifier(GlassRectModifier(cornerRadius: cornerRadius, tint: tint))
    }

    /// Capsule glass — filter pills, freshness pill.
    func glassCapsule() -> some View {
        modifier(GlassCapsuleModifier(tint: nil))
    }

    /// Tinted capsule — selected filter pills.
    func tintedGlassCapsule(tint: Color) -> some View {
        modifier(GlassCapsuleModifier(tint: tint))
    }

    /// Circular glass — icon buttons (back, star, locate).
    func glassCircle() -> some View {
        modifier(GlassCircleModifier())
    }

    /// Pick the right glass treatment for an arrival chip based on its
    /// `ArrivalStatus`. Normal status = clear glass; everything else inherits
    /// the status tint (green / amber / red).
    @ViewBuilder
    func arrivalChipBackground(status: ArrivalStatus, cornerRadius: CGFloat) -> some View {
        if let tint = status.tint {
            tintedGlassCard(cornerRadius: cornerRadius, tint: tint)
        } else {
            glassCard(cornerRadius: cornerRadius)
        }
    }
}

private struct GlassRectModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            if let tint {
                content.glassEffect(.regular.tint(tint), in: .rect(cornerRadius: cornerRadius))
            } else {
                content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            content
                .background {
                    ZStack {
                        shape.fill(.regularMaterial)
                        if let tint { shape.fill(tint) }
                    }
                }
                .overlay(shape.stroke(.white.opacity(0.7), lineWidth: 0.5))
        }
    }
}

private struct GlassCapsuleModifier: ViewModifier {
    let tint: Color?

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                content.glassEffect(.regular.tint(tint), in: .capsule)
            } else {
                content.glassEffect(.regular, in: .capsule)
            }
        } else {
            content
                .background {
                    ZStack {
                        Capsule().fill(.regularMaterial)
                        if let tint { Capsule().fill(tint) }
                    }
                }
                .overlay(Capsule().stroke(.white.opacity(0.7), lineWidth: 0.5))
        }
    }
}

private struct GlassCircleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .circle)
        } else {
            content
                .background(.regularMaterial, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 0.5))
        }
    }
}
