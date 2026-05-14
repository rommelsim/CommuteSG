import SwiftUI
import Observation

enum AppColorScheme: Int, CaseIterable {
    case system = 0, light = 1, dark = 2

    var preferred: ColorScheme? {
        switch self {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }
}

enum AppLanguage: String, CaseIterable {
    case system = "system"
    case english = "en"
    case chinese = "zh-Hans"

    /// The ISO code passed to `Bundle(path:)` to load the matching `.lproj`.
    /// `system` returns `nil` so we restore Bundle.main's default behavior.
    var bundleCode: String? {
        switch self {
        case .system:  nil
        case .english: "en"
        case .chinese: "zh-Hans"
        }
    }

    /// Native-script display label so each option reads in its own language —
    /// users can recognize "中文" even when the rest of the UI is in English.
    var displayName: String {
        switch self {
        case .system:  "System"
        case .english: "English"
        case .chinese: "中文"
        }
    }

    /// Locale to apply via SwiftUI's environment — drives number/date
    /// formatters and a few text-rendering decisions. The string-table
    /// lookup itself is handled by `LanguageOverride`.
    var locale: Locale {
        switch self {
        case .system:  .current
        case .english: Locale(identifier: "en_SG")
        case .chinese: Locale(identifier: "zh_Hans_SG")
        }
    }
}

@Observable
final class AppState {
    private static let onboardingKey   = "commute.onboardingComplete"
    private static let colorSchemeKey  = "commute.colorScheme"
    private static let savedPlacesKey  = "commute.savedPlaces"
    private static let favoriteStops   = "commute.favoriteBusStops"
    private static let favoriteLines   = "commute.favoriteLines"
    private static let notificationsKey = "commute.notifications"
    private static let userNameKey      = "commute.userName"
    private static let nearbyOrderKey   = "commute.nearbyOrder"
    private static let collapsedKey     = "commute.collapsedSections"
    private static let languageKey      = "commute.language"

    /// Set when a `commute://` deep link arrives (e.g. tap on a Live
    /// Activity). HomeView observes this and pushes the matching screen,
    /// then clears it back to nil so re-entries don't re-fire.
    var pendingDeepLink: DeepLink?

    enum DeepLink: Hashable {
        /// Open the bus-stop detail screen for this stop code.
        case busStop(stopCode: String)
    }

    var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Self.onboardingKey) }
    }

    var colorScheme: AppColorScheme {
        didSet { UserDefaults.standard.set(colorScheme.rawValue, forKey: Self.colorSchemeKey) }
    }

    var savedPlaces: [SavedPlace] {
        didSet { Self.encode(savedPlaces, to: Self.savedPlacesKey) }
    }

    var favoriteBusStopCodes: Set<String> {
        didSet { Self.encode(Array(favoriteBusStopCodes), to: Self.favoriteStops) }
    }

    var favoriteLineCodes: Set<String> {
        didSet { Self.encode(Array(favoriteLineCodes), to: Self.favoriteLines) }
    }

    var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: Self.notificationsKey)
            // Ask the OS for permission the first time the user opts in.
            // The service short-circuits if already granted/denied.
            if notificationsEnabled && !oldValue {
                Task { await NotificationService.shared.requestAuthorization() }
            }
        }
    }

    var userName: String {
        didSet { UserDefaults.standard.set(userName, forKey: Self.userNameKey) }
    }

    /// Transient: when set, the Plan tab will pick it up as the destination then clear it.
    var pendingPlanDestination: String?

    var nearbyOrder: [NearbyBlock] {
        didSet { Self.encode(nearbyOrder, to: Self.nearbyOrderKey) }
    }

    var collapsedSections: Set<NearbyBlock> {
        didSet { Self.encode(Array(collapsedSections), to: Self.collapsedKey) }
    }

    var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey)
            LanguageOverride.apply(languageCode: language.bundleCode)
        }
    }

    init() {
        let defaults = UserDefaults.standard
        self.hasCompletedOnboarding = defaults.bool(forKey: Self.onboardingKey)
        // Dark-mode override was removed from the UI — the app now follows
        // the OS appearance unconditionally. Reset any value persisted by
        // older builds so users who had Light/Dark forced get unstuck.
        self.colorScheme = .system
        defaults.set(AppColorScheme.system.rawValue, forKey: Self.colorSchemeKey)
        self.savedPlaces = Self.decode(Self.savedPlacesKey) ?? AppState.defaultPlaces
        let stops: [String] = Self.decode(Self.favoriteStops) ?? []
        self.favoriteBusStopCodes = Set(stops)
        let lines: [String] = Self.decode(Self.favoriteLines) ?? []
        self.favoriteLineCodes = Set(lines)
        self.notificationsEnabled = defaults.object(forKey: Self.notificationsKey) as? Bool ?? true
        self.userName = defaults.string(forKey: Self.userNameKey) ?? ""
        let savedOrder: [NearbyBlock] = Self.decode(Self.nearbyOrderKey) ?? NearbyBlock.allCases
        var seen = Set<NearbyBlock>()
        let unique = savedOrder.filter { seen.insert($0).inserted }
        let missing = NearbyBlock.allCases.filter { !seen.contains($0) }
        self.nearbyOrder = unique + missing
        let collapsed: [NearbyBlock] = Self.decode(Self.collapsedKey) ?? []
        self.collapsedSections = Set(collapsed)
        let storedLanguage = defaults.string(forKey: Self.languageKey) ?? AppLanguage.system.rawValue
        self.language = AppLanguage(rawValue: storedLanguage) ?? .system
        LanguageOverride.apply(languageCode: language.bundleCode)
    }

    func toggleCollapsed(_ block: NearbyBlock) {
        if collapsedSections.contains(block) {
            collapsedSections.remove(block)
        } else {
            collapsedSections.insert(block)
        }
    }

    func setSavedPlaceAddress(_ kind: SavedPlace.Kind, address: String) {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = kind == .home ? "Home" : (kind == .work ? "Work" : "Place")
        let previous = savedPlaces.first(where: { $0.kind == kind })?.address ?? ""

        if let idx = savedPlaces.firstIndex(where: { $0.kind == kind }) {
            savedPlaces[idx].address = trimmed
        } else {
            savedPlaces.append(SavedPlace(kind: kind, label: label, address: trimmed))
        }

        // Three cases for the toast:
        //   - new/changed value → "saved" success
        //   - cleared an existing value → "removed" info
        //   - empty save when nothing was set → no toast (nothing happened)
        if !trimmed.isEmpty {
            SoundEffect.playSuccess()
            Task { @MainActor in
                ToastCenter.shared.show(.success("\(label) address saved"))
            }
        } else if !previous.isEmpty {
            Task { @MainActor in
                ToastCenter.shared.show(.info("\(label) address removed"))
            }
        }
    }

    func toggleFavoriteBusStop(_ code: String) {
        let added: Bool
        if favoriteBusStopCodes.contains(code) {
            favoriteBusStopCodes.remove(code)
            added = false
        } else {
            favoriteBusStopCodes.insert(code)
            added = true
        }
        // Stops get the fuller 3-note major-chord arpeggio (C-E-G) — distinct
        // from the 2-note bus tone so you can tell by ear what you pinned.
        SoundEffect.playStopPinToggle()
        Task { @MainActor in
            ToastCenter.shared.show(added
                ? .success("Stop saved", symbol: "star.fill")
                : .info("Stop removed", symbol: "star"))
        }
    }

    func toggleFavoriteLine(_ code: String) {
        let added: Bool
        if favoriteLineCodes.contains(code) {
            favoriteLineCodes.remove(code)
            added = false
        } else {
            favoriteLineCodes.insert(code)
            added = true
        }
        // Buses get the lighter 2-note rising-major-third arpeggio (C-E).
        SoundEffect.playBusPinToggle()
        Task { @MainActor in
            ToastCenter.shared.show(added
                ? .success("Bus \(code) saved", symbol: "star.fill")
                : .info("Bus \(code) removed", symbol: "star"))
        }
    }

    func cycleLanguage() {
        let all = AppLanguage.allCases
        let idx = all.firstIndex(of: language) ?? 0
        language = all[(idx + 1) % all.count]
    }

    /// Wipe everything tied to this user: saved places, favourites, name,
    /// preferences, widget snapshots, pending notifications, and any
    /// in-flight Live Activity. After this returns, RootView will react to
    /// `hasCompletedOnboarding = false` and present the onboarding flow
    /// again from a clean slate.
    func resetAllData() async {
        await LiveActivityManager.shared.endActiveActivity()
        await NotificationService.shared.resetAll()
        SharedSnapshot.clearAll()

        // Wipe the persisted keys first so any background read in flight
        // sees an empty store, then re-assign in-memory values to defaults
        // (the didSet hooks re-write those defaults back to UserDefaults).
        let defaults = UserDefaults.standard
        for key in [Self.onboardingKey, Self.colorSchemeKey, Self.savedPlacesKey,
                    Self.favoriteStops, Self.favoriteLines, Self.notificationsKey,
                    Self.userNameKey, Self.nearbyOrderKey, Self.collapsedKey,
                    Self.languageKey] {
            defaults.removeObject(forKey: key)
        }

        savedPlaces = AppState.defaultPlaces
        favoriteBusStopCodes = []
        favoriteLineCodes = []
        notificationsEnabled = true
        userName = ""
        nearbyOrder = NearbyBlock.allCases
        collapsedSections = []
        language = .system
        colorScheme = .system
        hasCompletedOnboarding = false
    }

    private static let defaultPlaces: [SavedPlace] = [
        .init(kind: .home, label: "Home", address: ""),
        .init(kind: .work, label: "Work", address: "")
    ]

    private static func encode<T: Encodable>(_ value: T, to key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func decode<T: Decodable>(_ key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
