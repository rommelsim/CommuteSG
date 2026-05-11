import SwiftUI

struct CardButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.99
    var hapticWeight: SensoryFeedback = .impact(weight: .light)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
            .sensoryFeedback(hapticWeight, trigger: configuration.isPressed) { old, new in
                new && !old
            }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var background: Color = .appText
    var foreground: Color = .appSurface

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(background)
            .foregroundStyle(foreground)
            .font(.appHeading)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .medium), trigger: configuration.isPressed) { old, new in
                new && !old
            }
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(Color.appText2)
            .font(.appLabel)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

struct PermissionButtonStyle: ButtonStyle {
    var ghost: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.appSurface)
            .foregroundStyle(ghost ? Color.appText2 : Color.appInfo)
            .font(ghost ? .appLabel : .appLabelMedium)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                    .stroke(Color.appBorder, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { old, new in
                new && !old
            }
    }
}
