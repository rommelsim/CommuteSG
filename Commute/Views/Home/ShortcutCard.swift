import SwiftUI

struct ShortcutCard: View {
    enum Kind { case home, work

        var symbol: String {
            switch self {
            case .home: "house.fill"
            case .work: "briefcase.fill"
            }
        }

        var label: String {
            switch self {
            case .home: "Home"
            case .work: "Work"
            }
        }

        var tint: Color {
            switch self {
            case .home: Color.appInfo
            case .work: Color.appPurple
            }
        }

        var foreground: Color {
            switch self {
            case .home: Color.appInfo
            case .work: Color.appPurpleStrong
            }
        }
    }

    let kind: Kind
    let etaLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .padding(.bottom, 14)
                Text(kind.label)
                    .font(.system(size: 14, weight: .medium))
                    .padding(.bottom, Spacing.s4 / 2)  // 2pt
                Text(etaLabel)
                    .font(.system(size: 12, weight: .regular))
                    .opacity(0.85)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(Spacing.s16)
            .foregroundStyle(kind.foreground)
            // Lighter tint (0.18) lets the glass material read through clearly
            // — matches the imminent-arrival chip's intensity in the spec.
            .tintedGlassCard(
                cornerRadius: Radius.shortcutCard,
                tint: kind.tint.opacity(0.18)
            )
        }
        .buttonStyle(CardButtonStyle(pressedScale: 0.97))
    }
}
