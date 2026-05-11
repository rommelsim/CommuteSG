import SwiftUI

/// Horizontal scroll of filter pills. Per redesign spec §1: unselected = clear
/// glass capsule, selected = tinted glass capsule with brand green.
struct FilterPills<T: Hashable>: View {
    let options: [T]
    let label: (T) -> String
    @Binding var selection: T

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { opt in
                    Pill(text: label(opt), isActive: opt == selection) {
                        selection = opt
                    }
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.bottom, 4)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

private struct Pill: View {
    let text: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.appLabelMedium)
                .padding(.vertical, 7)
                .padding(.horizontal, 14)
                .foregroundStyle(foreground)
                .pillBackground(isActive: isActive)
        }
        .buttonStyle(PillButtonStyle())
    }

    private var foreground: Color { isActive ? Color.appSuccessStrong : Color.appText }
}

private extension View {
    @ViewBuilder
    func pillBackground(isActive: Bool) -> some View {
        if isActive {
            tintedGlassCapsule(tint: Color.appSuccess.opacity(0.30))
        } else {
            glassCapsule()
        }
    }
}

private struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}
