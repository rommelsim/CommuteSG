import SwiftUI

/// Reusable empty-state pattern: SF-Symbol illustration in a soft tinted
/// circle, title, optional subtitle, optional CTA. Use this anywhere you'd
/// otherwise have a `Text("No items yet.")` floating alone — it makes the
/// empty state read as intentional rather than missing.
struct EmptyStateView: View {
    enum Style {
        case neutral, success, warning, info

        var tint: Color {
            switch self {
            case .neutral: Color.appText3
            case .success: Color.appSuccess
            case .warning: Color.appWarning
            case .info:    Color.appInfo
            }
        }

        var bg: Color {
            switch self {
            case .neutral: Color.appSurface2
            case .success: Color.appSuccessBg
            case .warning: Color.appWarningBg
            case .info:    Color.appInfoBg
            }
        }
    }

    let symbol: String
    let title: String
    var subtitle: String? = nil
    var style: Style = .neutral
    var ctaTitle: String? = nil
    var ctaAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(style.bg)
                    .frame(width: 64, height: 64)
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(style.tint)
            }
            VStack(spacing: 4) {
                Text(title)
                    .font(.appBodyMedium)
                    .foregroundStyle(Color.appText)
                    .multilineTextAlignment(.center)
                if let subtitle {
                    Text(subtitle)
                        .font(.appCaption)
                        .foregroundStyle(Color.appText2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            if let ctaTitle, let ctaAction {
                Button(ctaTitle, action: ctaAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .tint(style.tint)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }
}
