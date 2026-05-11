import SwiftUI

struct OnboardingFlowView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var step: Int = 1

    var body: some View {
        VStack(spacing: 0) {
            ProgressDots(total: 3, current: step)
                .padding(.top, 16)

            Group {
                switch step {
                case 1: WelcomeStepView(onNext: { step = 2 })
                case 2: LocationStepView(onNext: { step = 3 })
                default: PlacesStepView(onFinish: finish)
                }
            }
            .transition(.opacity)
            .animation(.snappy, value: step)
        }
        .padding(.horizontal, 24)
        .background(Color.appSurface)
        .interactiveDismissDisabled(false)
    }

    private func finish() {
        appState.hasCompletedOnboarding = true
        dismiss()
    }
}

struct ProgressDots: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(color(for: i))
                    .frame(width: 28, height: 4)
            }
        }
    }

    private func color(for i: Int) -> Color {
        let zeroIdx = current - 1
        if i == zeroIdx { return Color.appInfo }
        if i < zeroIdx { return Color.appText.opacity(0.3) }
        return Color.appBorderStrong
    }
}
