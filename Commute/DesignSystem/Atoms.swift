import SwiftUI

// MARK: - Service chip
// A pill displaying a bus service number. Fixed width per size so single-
// digit "7" and three-digit "282" align across rows. Tabular nums + tight
// tracking. Always neutral (light grey or white-on-dark) — saturated colors
// are reserved for MRT line pills only.
enum ServiceChipSize { case xs, sm, md, lg }

struct ServiceChip: View {
    let service: String
    var size: ServiceChipSize = .sm
    var onDark: Bool = false

    private var dims: (w: CGFloat, h: CGFloat, font: CGFloat) {
        switch size {
        case .xs: (34, 19, 10.5)
        case .sm: (44, 24, 12)
        case .md: (50, 28, 13)
        case .lg: (64, 36, 17)
        }
    }

    var body: some View {
        Text(service)
            .font(.system(size: dims.font, weight: .bold))
            .monospacedDigit()
            .tracking(-0.01 * dims.font)
            .foregroundStyle(onDark ? Color.cfChipOnDarkText : Color.cfChipText)
            .frame(width: dims.w, height: dims.h)
            .background {
                Capsule(style: .continuous)
                    .fill(onDark ? Color.cfChipOnDarkFill : Color.cfChipFill)
            }
            .overlay {
                if !onDark {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.cfChipBorder, lineWidth: 0.5)
                }
            }
    }
}

// MARK: - NOW tag
// The only fully-dark element in the UI. Pulsing white dot + "NOW" label.
struct NowTag: View {
    @State private var pulseOn = false

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.white)
                .frame(width: 4, height: 4)
                .opacity(pulseOn ? 0.5 : 1.0)
            Text("NOW")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Color.cfNowFill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseOn = true
            }
        }
    }
}

// MARK: - ETA view
// Bold number + "min" label. Shows NowTag when urgent.
enum ETASize { case sm, md, lg }

struct ETAView: View {
    let urgent: Bool
    let value: String
    var size: ETASize = .sm

    private var nums: CGFloat {
        switch size { case .lg: 32; case .md: 22; case .sm: 16 }
    }
    private var label: CGFloat {
        switch size { case .lg: 13; case .md: 11; case .sm: 10 }
    }

    var body: some View {
        if urgent {
            NowTag()
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(size: nums, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.cfTextPrimary)
                Text("min")
                    .font(.system(size: label, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.45))
            }
        }
    }
}

// MARK: - Crowd people indicator
// Three person silhouettes; first N filled per level. Shown in lists only
// when level is `.high`; always shown in detail panels.
struct CrowdPeople: View {
    enum Level { case low, med, high }
    let level: Level
    var size: CGFloat = 12

    private var filled: Int {
        switch level { case .low: 1; case .med: 2; case .high: 3 }
    }

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: "person.fill")
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(i < filled ? Color.cfCrowdFilled : Color.cfCrowdEmpty)
            }
        }
    }
}

// MARK: - Bus stop icon
// A custom sign-post + sign glyph. SF Symbols has no equivalent. Drawn from
// the SVG in commute-flow.tsx (24x24 viewBox).
struct BusStopIcon: View {
    var size: CGFloat = 16
    var color: Color = .primary
    var strokeWidth: CGFloat = 2

    var body: some View {
        let s = size / 24.0
        ZStack {
            // Sign rectangle (rounded)
            RoundedRectangle(cornerRadius: 2 * s, style: .continuous)
                .strokeBorder(color, lineWidth: strokeWidth)
                .frame(width: 12 * s, height: 11 * s)
                .position(x: 12 * s, y: 8.5 * s)

            // Post (line down from middle of sign)
            Path { p in
                p.move(to: CGPoint(x: 12 * s, y: 14 * s))
                p.addLine(to: CGPoint(x: 12 * s, y: 22 * s))
            }
            .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))

            // Horizontal line inside sign (slightly thinner)
            Path { p in
                p.move(to: CGPoint(x: 9 * s, y: 9 * s))
                p.addLine(to: CGPoint(x: 15 * s, y: 9 * s))
            }
            .stroke(color, style: StrokeStyle(lineWidth: strokeWidth * 0.9, lineCap: .round))

            // Two dots ("eyes")
            Circle()
                .fill(color)
                .frame(width: 1.4 * s, height: 1.4 * s)
                .position(x: 9 * s, y: 11.5 * s)
            Circle()
                .fill(color)
                .frame(width: 1.4 * s, height: 1.4 * s)
                .position(x: 15 * s, y: 11.5 * s)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Glass surface modifier
// Translucent white card with hairline border. No shadow.
struct GlassSurface: ViewModifier {
    var cornerRadius: CGFloat = 16
    var fill: Color = .cfGlassFill

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.cfHairline, lineWidth: 0.5)
            }
    }
}

extension View {
    func glassSurface(cornerRadius: CGFloat = 16, fill: Color = .cfGlassFill) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius, fill: fill))
    }
}

// MARK: - Pulsing live dot (used inside Live indicator + hero label)
struct LiveDot: View {
    var color: Color = .cfLiveDot
    var size: CGFloat = 6

    @State private var on = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .opacity(on ? 0.5 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    on = true
                }
            }
    }
}
