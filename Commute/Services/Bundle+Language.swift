import Foundation

/// Runtime language override. Lets the user switch the app's language from
/// the Profile screen without restarting — when `setLanguage(_:)` is called,
/// the matching `*.lproj/Localizable.strings` resources become the source for
/// every `NSLocalizedString` / `Text("…")` lookup. Combined with a `.id()`
/// change on the root view, the UI redraws in the new language immediately.
///
/// Pass `nil` (the System option) to restore Bundle.main's default behavior,
/// which is to follow the iOS-level language preference.
enum LanguageOverride {
    nonisolated(unsafe) fileprivate static var overrideBundle: Bundle?

    static func apply(languageCode: String?) {
        ensureSwizzled()
        guard let code = languageCode,
              let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            overrideBundle = nil
            return
        }
        overrideBundle = bundle
    }

    private static let swizzleOnce: Void = {
        object_setClass(Bundle.main, LanguageBundle.self)
    }()

    private static func ensureSwizzled() {
        _ = swizzleOnce
    }
}

private final class LanguageBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let bundle = LanguageOverride.overrideBundle {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}
