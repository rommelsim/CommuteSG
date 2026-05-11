import SwiftUI

struct LocationStepView: View {
    let onNext: () -> Void
    private let location = LocationService.shared

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(Color.appSuccess)
                    .frame(width: 80, height: 80)
                    .background(Color.appSuccessBg)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .padding(.bottom, 12)
                Text("Find what's nearby")
                    .font(.appTitleMedium)
                    .multilineTextAlignment(.center)
                Text("Allow location access to see\nstops & stations around you.")
                    .font(.appBody)
                    .foregroundStyle(Color.appText2)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)

            permissionCard

            Spacer()

            Button("Skip for now", action: onNext)
                .buttonStyle(GhostButtonStyle())
                .padding(.bottom, 16)
        }
    }

    private var permissionCard: some View {
        VStack(spacing: 6) {
            Text("Allow \"Commute\" to use your location?")
                .font(.appLabelStrong)
                .multilineTextAlignment(.center)
            Text("We use your location to show nearby bus stops and MRT stations.")
                .font(.appMicro)
                .foregroundStyle(Color.appText2)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            Button("Allow once") {
                location.requestAuthorization()
                onNext()
            }
            .buttonStyle(PermissionButtonStyle())
            Button("While using app") {
                location.requestAuthorization()
                onNext()
            }
            .buttonStyle(PermissionButtonStyle())
            Button("Don't allow", action: onNext)
                .buttonStyle(PermissionButtonStyle(ghost: true))
        }
        .padding(16)
        .background(Color.appSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
