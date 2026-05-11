import Foundation

enum Secrets {
    static let ltaAPIKey = value(for: "LTA_API_KEY")

    // Add accessors for future keys here, e.g.:
    // static let googleAdsAppId = value(for: "GOOGLE_ADS_APP_ID")

    private static func value(for key: String) -> String {
        guard
            let raw = Bundle.main.infoDictionary?[key] as? String,
            !raw.isEmpty,
            raw != "$(\(key))"
        else {
            assertionFailure("Missing \(key) in Info.plist — check Secrets.xcconfig and that it is set as the project's base configuration.")
            return ""
        }
        return raw
    }
}
