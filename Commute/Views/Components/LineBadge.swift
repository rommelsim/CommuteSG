import SwiftUI

struct LineBadge: View {
    let line: MRTLine
    var code: String? = nil
    var emphasized: Bool = false

    var body: some View {
        Text(code ?? line.code)
            .font(.system(size: 11, weight: .medium))
            .tracking(0.3)
            .foregroundStyle(line.foreground)
            .padding(.horizontal, emphasized ? 8 : 7)
            .padding(.vertical, emphasized ? 4 : 3)
            .background(line.background, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
    }
}
