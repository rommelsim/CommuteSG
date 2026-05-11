import SwiftUI

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.appCaptionMedium)
            .tracking(0.6)
            .foregroundStyle(Color.appText2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.screen)
            .padding(.bottom, 8)
    }
}

struct SectionHeader: View {
    let title: String
    var meta: String? = nil
    var isCollapsed: Bool = false
    var onToggleCollapse: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.appSection)
                .foregroundStyle(Color.appText)
            Spacer()
            if let meta {
                Text(meta)
                    .font(.appCaption)
                    .foregroundStyle(Color.appText2)
            }
            if let onToggleCollapse {
                Button(action: onToggleCollapse) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.appText2)
                        .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isCollapsed ? "Expand \(title)" : "Collapse \(title)")
            }
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.bottom, 10)
    }
}
