import SwiftUI
import CoreLocation
import UIKit

struct LocationStepView: View {
    let onNext: () -> Void
    private let location = LocationService.shared
    @State private var isRequesting = false

    private var status: CLAuthorizationStatus { location.authorizationStatus }

    private var buttonTitle: String {
        switch status {
        case .denied, .restricted: "Open Settings"
        case .authorizedWhenInUse, .authorizedAlways: "Continue"
        default: "Allow location access"
        }
    }

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

            infoCard

            Spacer()

            Button(buttonTitle) {
                guard !isRequesting else { return }
                switch status {
                case .notDetermined:
                    isRequesting = true
                    location.requestAuthorization()
                case .denied, .restricted:
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                default:
                    onNext()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.bottom, 16)
            .onChange(of: status) { _, newValue in
                if isRequesting, newValue != .notDetermined {
                    isRequesting = false
                    onNext()
                } else if newValue == .authorizedWhenInUse || newValue == .authorizedAlways {
                    onNext()
                }
            }
        }
    }

    private var infoCard: some View {
        VStack(spacing: 6) {
            Text("Why we need your location")
                .font(.appLabelStrong)
                .multilineTextAlignment(.center)
            Text("We use your location to show nearby bus stops and MRT stations. iOS will ask for your permission on the next screen.")
                .font(.appMicro)
                .foregroundStyle(Color.appText2)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.appSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
