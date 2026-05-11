import SwiftUI
import Observation

enum AppColorScheme: Int, CaseIterable {
    case system = 0, light = 1, dark = 2

    var label: String {
        switch self {
        case .system: "Auto"
        case .light:  "Light"
        case .dark:   "Dark"
        }
    }

    var preferred: ColorScheme? {
        switch self {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }

    var next: AppColorScheme {
        switch self {
        case .system: .light
        case .light:  .dark
        case .dark:   .system
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
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: Self.notificationsKey) }
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

    init() {
        let defaults = UserDefaults.standard
        self.hasCompletedOnboarding = defaults.bool(forKey: Self.onboardingKey)
        self.colorScheme = AppColorScheme(rawValue: defaults.integer(forKey: Self.colorSchemeKey)) ?? .system
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
        if let idx = savedPlaces.firstIndex(where: { $0.kind == kind }) {
            savedPlaces[idx].address = trimmed
        } else {
            savedPlaces.append(SavedPlace(kind: kind, label: label, address: trimmed))
        }
        SoundEffect.playSuccess()
        Task { @MainActor in
            ToastCenter.shared.show(.success("\(label) address saved"))
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
        // Only sound on save (the rewarding action), not on un-save.
        if added { SoundEffect.playSuccess() }
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
        if added { SoundEffect.playSuccess() }
        Task { @MainActor in
            ToastCenter.shared.show(added
                ? .success("Bus \(code) saved", symbol: "star.fill")
                : .info("Bus \(code) removed", symbol: "star"))
        }
    }

    func cycleColorScheme() {
        colorScheme = colorScheme.next
    }

    func resetOnboarding() {
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
