import SwiftUI

struct CrowdIndicator: View {
    let level: CrowdLevel
    var showLabel: Bool = true

    var body: some View {
        HStack(spacing: 5) {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(i < filledBars ? activeColor : Color.appBorderStrong)
                        .frame(width: 5, height: 12)
                }
            }
            if showLabel {
                Text(level.label)
                    .font(.appCaptionStrong)
                    .foregroundStyle(activeColor)
                    .padding(.leading, 4)
            }
        }
    }

    private var filledBars: Int {
        switch level {
        case .seats:    1
        case .standing: 2
        case .limited:  3
        case .unknown:  0
        }
    }

    private var activeColor: Color {
        switch level {
        case .seats:    Color.appSuccess
        case .standing: Color.appWarning
        case .limited:  Color.appDanger
        case .unknown:  Color.appText3
        }
    }
}

struct CrowdBars: View {
    let level: StationCrowdLevel

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(i < level.filledBars ? activeColor : Color.appBorderStrong)
                    .frame(width: 5, height: 14)
            }
        }
    }

    private var activeColor: Color {
        switch level {
        case .low:      Color.appSuccess
        case .moderate: Color.appWarning
        case .high:     Color.appDanger
        case .unknown:  Color.appText3
        }
    }
}
