import Foundation
import CoreLocation
import WeatherKit

/// Fetches the hero card's small weather chip via Apple **WeatherKit**.
///
/// **Setup required** (one-time):
///   1. Xcode → Commute target → Signing & Capabilities → "+" → WeatherKit
///   2. (Apple Developer portal) Identifiers → your App ID → enable WeatherKit
///   3. Wait ~30 min for the entitlement to propagate, then re-run the app
///
/// If the capability isn't enabled, `WeatherService.weather(for:)` throws
/// at runtime and we silently fall back to `nil` — the hero shows its
/// placeholder "—" weather chip rather than crashing.
///
/// WeatherKit gives us:
///   • 1 km grid resolution (vs wttr.in's nearest-station)
///   • Sub-hourly updates (vs hourly)
///   • Apple-curated `WeatherCondition` enum that maps cleanly to SF Symbols
///
/// 15 min cache + 5 km location-radius reuse so we don't hammer the API
/// when the user reopens the app or moves a few blocks.
@MainActor
final class WeatherProvider {
    static let shared = WeatherProvider()

    private let service = WeatherService()
    private var cache: (location: CLLocation, weather: HeroContext.Weather, at: Date)?
    private let cacheTTL: TimeInterval = 15 * 60

    func current(at location: CLLocation) async -> HeroContext.Weather? {
        if let cache,
           cache.at.timeIntervalSinceNow > -cacheTTL,
           cache.location.distance(from: location) < 5_000 {
            return cache.weather
        }

        do {
            let result = try await service.weather(for: location)
            let current = result.currentWeather
            let temp = Int(current.temperature.converted(to: .celsius).value.rounded())
            let weather = HeroContext.Weather(
                symbol: Self.sfSymbol(for: current.condition),
                text: "\(temp)°C · \(Self.label(for: current.condition))"
            )
            cache = (location, weather, Date())
            return weather
        } catch {
            // Capability not enabled, throttled, offline — caller falls back
            // to the placeholder chip. Don't log loudly; this can fire on
            // first launch before the entitlement has propagated.
            return nil
        }
    }

    // MARK: - Condition → display

    private static func sfSymbol(for condition: WeatherCondition) -> String {
        switch condition {
        case .clear, .mostlyClear, .hot:
            return "sun.max.fill"
        case .partlyCloudy:
            return "cloud.sun.fill"
        case .cloudy, .mostlyCloudy:
            return "cloud.fill"
        case .drizzle, .rain, .freezingRain, .sunShowers:
            return "cloud.rain.fill"
        case .heavyRain:
            return "cloud.heavyrain.fill"
        case .thunderstorms, .strongStorms,
             .scatteredThunderstorms, .isolatedThunderstorms:
            return "cloud.bolt.rain.fill"
        case .snow, .heavySnow, .flurries, .blowingSnow,
             .blizzard, .freezingDrizzle, .sleet, .wintryMix,
             .sunFlurries, .frigid, .hail:
            return "cloud.snow.fill"
        case .haze, .smoky, .foggy:
            return "cloud.fog.fill"
        case .breezy, .windy, .blowingDust:
            return "wind"
        case .tropicalStorm, .hurricane:
            return "tropicalstorm"
        @unknown default:
            return "sun.max.fill"
        }
    }

    /// Short, friendly label suited to the hero chip (12pt). WeatherKit's
    /// own `.description` strings can be verbose ("Mostly Cloudy with
    /// Showers") so we re-shape into single words / pairs.
    private static func label(for condition: WeatherCondition) -> String {
        switch condition {
        case .clear, .mostlyClear:                          return "Clear"
        case .partlyCloudy:                                 return "Partly cloudy"
        case .cloudy, .mostlyCloudy:                        return "Cloudy"
        case .drizzle:                                      return "Drizzle"
        case .rain, .sunShowers:                            return "Rain"
        case .heavyRain:                                    return "Heavy rain"
        case .freezingRain, .freezingDrizzle:               return "Freezing rain"
        case .thunderstorms, .strongStorms,
             .scatteredThunderstorms, .isolatedThunderstorms:
                                                            return "Thunderstorms"
        case .snow, .heavySnow:                             return "Snow"
        case .flurries, .sunFlurries, .blowingSnow:         return "Flurries"
        case .blizzard:                                     return "Blizzard"
        case .sleet, .wintryMix, .hail:                     return "Sleet"
        case .frigid:                                       return "Frigid"
        case .haze:                                         return "Hazy"
        case .smoky:                                        return "Smoky"
        case .foggy:                                        return "Foggy"
        case .windy, .breezy:                               return "Windy"
        case .blowingDust:                                  return "Dusty"
        case .hot:                                          return "Hot"
        case .tropicalStorm:                                return "Tropical storm"
        case .hurricane:                                    return "Hurricane"
        @unknown default:                                   return "—"
        }
    }
}
