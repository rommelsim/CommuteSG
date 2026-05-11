import SwiftUI

struct LoadingCard: View {
    let symbol: String
    let title: String
    let detail: String?

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
                .tint(Color.appInfo)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.appCardTitle)
                    .foregroundStyle(Color.appText)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.appMicro)
                        .foregroundStyle(Color.appText3)
                }
            }
            Spacer()
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(Color.appText3)
        }
        .padding(Spacing.cardInner)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

struct ErrorCard: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.appWarningStrong)
                Text("Couldn't load nearby stops")
                    .font(.appCardTitle)
                    .foregroundStyle(Color.appText)
            }
            Text(message)
                .font(.appMicro)
                .foregroundStyle(Color.appText2)
                .fixedSize(horizontal: false, vertical: true)
            Button("Try again", action: onRetry)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(Color.appInfo)
        }
        .padding(Spacing.cardInner)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appWarningBg)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}
