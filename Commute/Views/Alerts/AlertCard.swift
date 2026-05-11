import SwiftUI

struct AlertCard: View {
    let item: TransitAlert

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)
                Text(item.tag.uppercased())
                    .font(.appMicroStrong)
                    .tracking(0.5)
                    .foregroundStyle(accent)
                Spacer()
                Text(item.timeLabel)
                    .font(.appMicro)
                    .foregroundStyle(strongColor)
            }
            if !item.title.isEmpty {
                Text(item.title)
                    .font(.appSection)
                    .foregroundStyle(strongColor)
            }
            if let body = item.body {
                Text(body)
                    .font(.appLabel)
                    .foregroundStyle(strongColor)
                    .lineSpacing(2)
            }
        }
        .padding(Spacing.cardInner)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private var symbol: String {
        switch item.severity {
        case .danger:  "exclamationmark.triangle.fill"
        case .warning: "clock.fill"
        case .info:    "info.circle.fill"
        case .success: "checkmark.circle.fill"
        }
    }

    private var accent: Color {
        switch item.severity {
        case .danger:  Color.appDanger
        case .warning: Color.appWarning
        case .info:    Color.appInfo
        case .success: Color.appSuccess
        }
    }

    private var strongColor: Color {
        switch item.severity {
        case .danger:  Color.appDangerStrong
        case .warning: Color.appWarningStrong
        case .info:    Color.appInfoStrong
        case .success: Color.appSuccessStrong
        }
    }

    private var background: Color {
        switch item.severity {
        case .danger:  Color.appDangerBg
        case .warning: Color.appWarningBg
        case .info:    Color.appInfoBg
        case .success: Color.appSuccessBg
        }
    }
}
