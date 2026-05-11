import SwiftUI

struct DetailHeader<Center: View, Trailing: View>: View {
    @Environment(\.dismiss) private var dismiss

    @ViewBuilder let center: () -> Center
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.appText)
                    .frame(width: 36, height: 36)
            }
            .glassCircleButton()
            .accessibilityLabel("Back")

            center()
                .frame(maxWidth: .infinity, alignment: .leading)

            trailing()
        }
        .padding(.horizontal, Spacing.screen)
        // 28pt of top padding clears the system drag-indicator handle on
        // sheet presentations *and* gives the title room to breathe inside
        // the 28pt rounded sheet corner. Smaller values (16pt) crammed the
        // title against the top edge when the indicator wasn't visible.
        .padding(.top, 28)
        .padding(.bottom, 14)
        // No own background: the parent surface (sheet glass or detail
        // view's appSurface) shows through. Stacking another material on
        // top would double the opacity at the top of the card.
    }
}

extension DetailHeader where Trailing == EmptyView {
    init(@ViewBuilder center: @escaping () -> Center) {
        self.init(center: center, trailing: { EmptyView() })
    }
}

struct DetailHeaderTitle: View {
    let title: String
    let meta: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.appSubTitle)
                .foregroundStyle(Color.appText)
            if let meta {
                Text(meta)
                    .font(.appCaption)
                    .foregroundStyle(Color.appText2)
            }
        }
    }
}

/// Circular glass icon button — used for back, favourite/star, locate, etc.
/// in detail headers throughout the app. Per redesign spec §1, these use the
/// native iOS 26 glass button style.
struct IconCircleButton: View {
    let symbol: String
    var foreground: Color = Color.appText
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: 36, height: 36)
        }
        .glassCircleButton()
    }
}

private extension View {
    /// Wrap a button in the iOS 26 `.glass` button style with a circular
    /// border shape. Falls back to a `CardButtonStyle` press animation +
    /// material circle on iOS 17–25 so the button still floats above content.
    @ViewBuilder
    func glassCircleButton() -> some View {
        if #available(iOS 26.0, *) {
            self
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
        } else {
            self
                .buttonStyle(LegacyGlassCircleButtonStyle())
        }
    }
}

private struct LegacyGlassCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(.regularMaterial, in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 0.5))
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}
