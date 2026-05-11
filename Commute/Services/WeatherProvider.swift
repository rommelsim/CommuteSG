import Foundation
import CoreLocation

/// Fetches the hero card's small weather chip from **wttr.in** — a free,
/// no-auth weather API. We previously used WeatherKit but it requires the
/// "WeatherKit" capability on the App ID, which has to be enabled in the
/// developer portal AND propagated through Xcode automatic signing; many
/// developer accounts can't enable it reliably. wttr.in needs none of that.
///
/// Returns nil silently on any failure (network, malformed JSON, etc) —
/// the hero falls back to its `—` placeholder weather chip.
@MainActor
final class WeatherProvider {
    static let shared = WeatherProvider()

    private var cache: (location: CLLocation, weather: HeroContext.Weather, at: Date)?
    private let cacheTTL: TimeInterval = 15 * 60   // 15 min

    func current(at location: CLLocation) async -> HeroContext.Weather? {
        if let cache,
           cache.at.timeIntervalSinceNow > -cacheTTL,
           cache.location.distance(from: location) < 5_000 {
            return cache.weather
        }

        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        guard let url = URL(string: "https://wttr.in/\(lat),\(lon)?format=j1") else { return nil }

        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 6
            // wttr.in sometimes refuses default URLSession user agents — set
            // a generic curl-style UA which it expects for plain-text mode.
            req.setValue("curl/8.0", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: req)
            let result = try JSONDecoder().decode(WTTRResponse.self, from: data)
            guard let current = result.current_condition.first,
                  let temp = Int(current.temp_C) else { return nil }
            let desc = current.weatherDesc.first?.value.trimmingCharacters(in: .whitespaces) ?? "—"
            let weather = HeroContext.Weather(
                symbol: Self.sfSymbol(forWeatherCode: current.weatherCode),
                text: "\(temp)°C · \(desc)"
            )
            cache = (location, weather, Date())
            return weather
        } catch {
            return nil
        }
    }

    /// Map wttr.in's weather code (WWO API) → SF Symbol. Codes are documented
    /// at https://www.worldweatheronline.com/developer/api/docs/weather-icons.aspx
    private static func sfSymbol(forWeatherCode code: String) -> String {
        switch code {
        case "113":                                  return "sun.max.fill"            // Clear / Sunny
        case "116":                                  return "cloud.sun.fill"          // Partly cloudy
        case "119", "122":                           return "cloud.fill"              // Cloudy / Overcast
        case "143", "248", "260":                    return "cloud.fog.fill"          // Mist / Fog
        case "176", "263", "266", "281", "284",
             "293", "296", "299", "302", "305",
             "308", "311", "314", "353", "356", "359":
                                                     return "cloud.rain.fill"         // Rain
        case "200", "386", "389", "392", "395":      return "cloud.bolt.rain.fill"    // Thunder
        case "227", "230", "320", "323", "326",
             "329", "332", "335", "338", "350",
             "362", "365", "368", "371", "374", "377":
                                                     return "cloud.snow.fill"         // Snow / sleet
        default:                                     return "sun.max.fill"
        }
    }
}

// MARK: - wttr.in JSON shape (only the fields we use)

private struct WTTRResponse: Decodable {
    let current_condition: [Current]
    struct Current: Decodable {
        let temp_C: String
        let weatherCode: String
        let weatherDesc: [Desc]
    }
    struct Desc: Decodable {
        let value: String
    }
}
