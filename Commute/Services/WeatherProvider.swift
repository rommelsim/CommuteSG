import Foundation
import CoreLocation
import WeatherKit

/// Maps Apple WeatherKit data → the hero card's small weather chip.
///
/// Requires the **WeatherKit** capability enabled on the app target AND on
/// the App ID in your Apple Developer account. Without it, `WeatherService`
/// fails at runtime; we catch the error silently and the hero falls back to
/// the placeholder weather. To enable:
///   1. Xcode → target → Signing & Capabilities → "+" → WeatherKit
///   2. developer.apple.com → Identifiers → app ID → enable WeatherKit
///   3. Wait ~30 min for the entitlement to propagate
@MainActor
final class WeatherProvider {
    static let shared = WeatherProvider()

    private let service = WeatherService()
    private var cache: (location: CLLocation, weather: HeroContext.Weather, at: Date)?
    private let cacheTTL: TimeInterval = 15 * 60  // 15 min — weather changes slowly

    func current(at location: CLLocation) async -> HeroContext.Weather? {
        if let cache,
           cache.at.timeIntervalSinceNow > -cacheTTL,
           cache.location.distance(from: location) < 5_000 {
            return cache.weather
        }
        do {
            let result = try await service.weather(for: location)
            let temp = Int(result.currentWeather.temperature.converted(to: .celsius).value.rounded())
            let cond = result.currentWeather.condition
            let weather = HeroContext.Weather(
                symbol: Self.sfSymbol(for: cond),
                text: "\(temp)°C · \(Self.label(for: cond))"
            )
            cache = (location, weather, Date())
            return weather
        } catch {
            // Capability not enabled, throttled, or offline — caller falls
            // back to placeholder. Don't log loudly; this is expected on
            // first run before the capability is enabled.
            return nil
        }
    }

    private static func sfSymbol(for condition: WeatherCondition) -> String {
        switch condition {
        case .clear, .mostlyClear, .hot:                return "sun.max.fill"
        case .partlyCloudy:                             return "cloud.sun.fill"
        case .cloudy, .mostlyCloudy:                    return "cloud.fill"
        case .drizzle, .rain, .freezingRain, .sunShowers:
                                                        return "cloud.rain.fill"
        case .heavyRain:                                return "cloud.heavyrain.fill"
        case .thunderstorms, .strongStorms, .scatteredThunderstorms,
             .isolatedThunderstorms:                    return "cloud.bolt.rain.fill"
        case .snow, .heavySnow, .flurries, .blowingSnow,
             .blizzard, .freezingDrizzle, .sleet, .wintryMix,
             .sunFlurries, .frigid, .hail:              return "cloud.snow.fill"
        case .haze, .smoky, .foggy, .breezy, .windy, .blowingDust,
             .tropicalStorm, .hurricane:                return "cloud.fog.fill"
        @unknown default:                               return "sun.max.fill"
        }
    }

    private static func label(for condition: WeatherCondition) -> String {
        switch condition {
        case .clear, .mostlyClear:                      return "Clear"
        case .partlyCloudy:                             return "Partly cloudy"
        case .cloudy, .mostlyCloudy:                    return "Cloudy"
        case .drizzle:                                  return "Drizzle"
        case .rain, .sunShowers:                        return "Rain"
        case .heavyRain:                                return "Heavy rain"
        case .thunderstorms, .strongStorms,
             .scatteredThunderstorms,
             .isolatedThunderstorms:                    return "Thunderstorms"
        case .haze:                                     return "Hazy"
        case .smoky:                                    return "Smoky"
        case .foggy:                                    return "Foggy"
        case .windy, .breezy:                           return "Windy"
        case .hot:                                      return "Hot"
        default:                                        return "—"
        }
    }
}
