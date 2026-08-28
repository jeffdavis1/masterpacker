import Foundation
import CoreLocation

/// A single day's forecast summary.
struct DayForecast: Identifiable {
    var id: Date { date }
    let date: Date
    let weatherCode: Int
    let highTemperature: Double
    let lowTemperature: Double

    var symbolName: String { WeatherCode.symbolName(for: weatherCode) }
    var label: String { WeatherCode.label(for: weatherCode) }
}

/// Maps Open-Meteo's WMO weather codes to SF Symbols and short labels.
/// https://open-meteo.com/en/docs — "WMO Weather interpretation codes"
enum WeatherCode {
    static func symbolName(for code: Int) -> String {
        switch code {
        case 0: "sun.max.fill"
        case 1, 2: "cloud.sun.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51, 53, 55, 56, 57: "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67: "cloud.rain.fill"
        case 71, 73, 75, 77, 85, 86: "cloud.snow.fill"
        case 80, 81, 82: "cloud.heavyrain.fill"
        case 95, 96, 99: "cloud.bolt.rain.fill"
        default: "questionmark.circle"
        }
    }

    static func label(for code: Int) -> String {
        switch code {
        case 0: "Clear"
        case 1, 2: "Partly Cloudy"
        case 3: "Cloudy"
        case 45, 48: "Fog"
        case 51, 53, 55, 56, 57: "Drizzle"
        case 61, 63, 65, 66, 67: "Rain"
        case 71, 73, 75, 77, 85, 86: "Snow"
        case 80, 81, 82: "Rain Showers"
        case 95, 96, 99: "Thunderstorms"
        default: "Weather"
        }
    }
}

/// Fetches and caches destination weather forecasts using Open-Meteo (free,
/// no API key/account needed) and CLGeocoder to resolve a trip's
/// destination text to coordinates.
///
/// Deliberately not persisted to SwiftData — forecasts are short-lived and
/// destination-derived, not something that needs to sync across devices —
/// so this stays a simple in-memory cache rather than adding to the
/// CloudKit-synced schema.
actor WeatherService {
    static let shared = WeatherService()

    private var geocodeCache: [String: CLLocationCoordinate2D] = [:]
    private var forecastCache: [String: (forecasts: [DayForecast], fetchedAt: Date)] = [:]

    /// How long a cached forecast is trusted before this actor will hit
    /// the network again for the same destination/date-range. Balances not
    /// hammering Open-Meteo against actually noticing when conditions
    /// change — NotificationManager's weather-change watcher depends on
    /// this cache eventually going stale, or it would compare the same
    /// cached forecast to itself forever within one app session.
    private static let cacheTTL: TimeInterval = 3 * 60 * 60

    /// Up to `days` forecast entries starting from the trip's start date
    /// (or today, whichever is later). Returns an empty array if the
    /// destination can't be geocoded, the trip is too far in the future
    /// for a forecast to exist yet, or the request fails (e.g. offline) —
    /// callers should treat an empty result as "nothing to show" rather
    /// than an error.
    func forecast(destination: String, startDate: Date, days: Int) async -> [DayForecast] {
        guard let coordinate = await coordinate(for: destination) else { return [] }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let rangeStart = max(calendar.startOfDay(for: startDate), today)
        guard let rangeEnd = calendar.date(byAdding: .day, value: days - 1, to: rangeStart) else { return [] }

        let cacheKey = "\(coordinate.latitude.rounded4),\(coordinate.longitude.rounded4)|\(dateKey(rangeStart))|\(dateKey(rangeEnd))"
        if let cached = forecastCache[cacheKey], Date.now.timeIntervalSince(cached.fetchedAt) < Self.cacheTTL {
            return cached.forecasts
        }

        guard let url = forecastURL(coordinate: coordinate, start: rangeStart, end: rangeEnd) else { return [] }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            let result = response.daily.toDayForecasts()
            forecastCache[cacheKey] = (result, .now)
            return result
        } catch {
            // Prefer a stale cached forecast over nothing (e.g. briefly
            // offline) — only fall back to empty if we've never fetched
            // this destination/range at all.
            return forecastCache[cacheKey]?.forecasts ?? []
        }
    }

    /// Resolves a destination string to coordinates, using the same cache
    /// as `forecast(destination:startDate:days:)`. Exposed publicly for the
    /// trip map view — `Trip.destination` is just a validated place-name
    /// string, never stored coordinates, so plotting a pin needs this too.
    func coordinate(for destination: String) async -> CLLocationCoordinate2D? {
        let trimmed = destination.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if let cached = geocodeCache[trimmed] { return cached }

        do {
            let placemarks = try await CLGeocoder().geocodeAddressString(trimmed)
            guard let coordinate = placemarks.first?.location?.coordinate else { return nil }
            geocodeCache[trimmed] = coordinate
            return coordinate
        } catch {
            return nil
        }
    }

    private func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }

    private func forecastURL(coordinate: CLLocationCoordinate2D, start: Date, end: Date) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "daily", value: "weathercode,temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
            URLQueryItem(name: "start_date", value: dateKey(start)),
            URLQueryItem(name: "end_date", value: dateKey(end)),
        ]
        return components?.url
    }
}

private extension Double {
    /// Rounds coordinates to ~1km precision for cache-key purposes only —
    /// not used for the actual API request.
    var rounded4: Double { (self * 10_000).rounded() / 10_000 }
}

private struct OpenMeteoResponse: Decodable {
    let daily: DailyBlock

    struct DailyBlock: Decodable {
        let time: [String]
        let weatherCode: [Int]
        let temperatureMax: [Double]
        let temperatureMin: [Double]

        enum CodingKeys: String, CodingKey {
            case time
            case weatherCode = "weathercode"
            case temperatureMax = "temperature_2m_max"
            case temperatureMin = "temperature_2m_min"
        }

        func toDayForecasts() -> [DayForecast] {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "UTC")

            var result: [DayForecast] = []
            for index in time.indices {
                guard let date = formatter.date(from: time[index]),
                      index < weatherCode.count,
                      index < temperatureMax.count,
                      index < temperatureMin.count
                else { continue }

                result.append(DayForecast(
                    date: date,
                    weatherCode: weatherCode[index],
                    highTemperature: temperatureMax[index],
                    lowTemperature: temperatureMin[index]
                ))
            }
            return result
        }
    }
}
