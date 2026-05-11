import SwiftUI

struct WelcomeStepView: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                heroIcon
                    .padding(.bottom, 12)
                Text("Welcome to Commute")
                    .font(.appTitleMedium)
                    .multilineTextAlignment(.center)
                Text("Real-time buses, MRT, fares\n& disruptions — all in one place.")
                    .font(.appBody)
                    .foregroundStyle(Color.appText2)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 0) {
                feature(symbol: "clock.fill", text: "Live arrival times")
                feature(symbol: "point.topleft.down.curvedto.point.bottomright.up", text: "Smart journey planner")
                feature(symbol: "function", text: "Bus & MRT fare calculator")
                feature(symbol: "bell.fill", text: "Service disruption alerts")
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 24)

            Spacer()

            Button("Get started", action: onNext)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.bottom, 16)
        }
    }

    private var heroIcon: some View {
        Image(systemName: "bus.fill")
            .font(.system(size: 40, weight: .semibold))
            .foregroundStyle(Color.appInfo)
            .frame(width: 80, height: 80)
            .background(Color.appInfoBg)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func feature(symbol: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.appInfo)
                .frame(width: 24)
            Text(text)
                .font(.appBody)
                .foregroundStyle(Color.appText2)
        }
        .padding(.vertical, 10)
    }
}
