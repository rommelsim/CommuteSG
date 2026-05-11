import SwiftUI

/// Freshness pill per redesign spec §5.
///
/// State machine:
///   < 1 min   → "Live" (pulsing green dot)
///   1–5 min   → "Live · 2m" (steady green dot)
///   > 5 min   → "Updated 32m" + refresh icon, amber tint, tappable when
///               `onRefresh` is supplied
///
/// `granularity` decides whether sub-minute updates count seconds. Home
/// screen uses `.coarse` (just "Live"); detail sheets that actively poll
/// use `.fine` to show "Live · 12s" so the user can see polling working.
struct LiveBadge: View {
    enum Mode { case live, demo }
    enum Granularity { case coarse, fine }

    let mode: Mode
    var lastUpdated: Date? = nil
    var granularity: Granularity = .coarse
    var onRefresh: (() -> Void)? = nil

    @State private var ringScale: CGFloat = 1.0
    @State private var ringOpacity: Double = 0.0
    @State private var nowTick = Date()
    @State private var tapCount = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var elapsed: Int {
        guard mode == .live, let lastUpdated else { return 0 }
        return max(0, Int(nowTick.timeIntervalSince(lastUpdated)))
    }

    private var isStale: Bool { elapsed >= 300 }
    private var isPulsing: Bool { mode == .live && elapsed < 60 }

    var body: some View {
        Group {
            if let onRefresh {
                Button {
                    tapCount &+= 1
                    onRefresh()
                } label: { content }
                    .buttonStyle(.plain)
                    .accessibilityLabel(accessibilityLabel)
                    .accessibilityHint("Tap to refresh")
                    .sensoryFeedback(.impact(weight: .light), trigger: tapCount)
            } else {
                content
                    .accessibilityLabel(accessibilityLabel)
            }
        }
        .onReceive(timer) { nowTick = $0 }
        .onChange(of: isPulsing, initial: true) { _, pulsing in
            if pulsing {
                ringScale = 1.0
                ringOpacity = 0.7
                withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                    ringScale = 3.0
                    ringOpacity = 0.0
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    ringOpacity = 0.0
                    ringScale = 1.0
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        HStack(spacing: 6) {
            indicator
            Text(label)
                .font(.appMicroStrong)
                .contentTransition(.numericText())
                .animation(.snappy, value: label)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .foregroundStyle(foreground)
        .glassCapsule()
    }

    @ViewBuilder
    private var indicator: some View {
        switch mode {
        case .live:
            if isStale {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold))
            } else {
                ZStack {
                    Circle()
                        .stroke(Color.appSuccessStrong, lineWidth: 1.2)
                        .frame(width: 6, height: 6)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)
                    Circle()
                        .fill(Color.appSuccessStrong)
                        .frame(width: 6, height: 6)
                }
                .frame(width: 6, height: 6)
            }
        case .demo:
            ProgressView()
                .controlSize(.mini)
                .tint(Color.appText2)
        }
    }

    private var label: String {
        switch mode {
        case .demo: return "Connecting…"
        case .live:
            guard lastUpdated != nil else { return "Live" }
            switch elapsed {
            case 0..<60:
                if granularity == .fine, elapsed > 0 {
                    return "Live · \(elapsed)s"
                }
                return "Live"
            case 60..<300:
                return "Live · \(elapsed / 60)m"
            default:
                return "Updated \(elapsed / 60)m"
            }
        }
    }

    private var foreground: Color {
        switch mode {
        case .live: isStale ? Color.appWarning : Color.appSuccessStrong
        case .demo: Color.appText2
        }
    }

    private var accessibilityLabel: String {
        switch mode {
        case .demo: return "Loading data"
        case .live:
            if isStale {
                let mins = elapsed / 60
                return "Data \(mins) minute\(mins == 1 ? "" : "s") old"
            }
            return "Live data"
        }
    }
}
