import Foundation

// MARK: - Response models
// Server response structure (from prayer_times.php):
// { "success": true, "data": { "date": "...", "hijri": {...}, "prayers": { "fajr": {"time":"04:31",...}, ... } } }

struct ServerPrayerResponse: Codable {
    let success: Bool
    let data: ServerPrayerData?
}

struct ServerPrayerData: Codable {
    let date: String?
    let hijri: ServerHijriDate?
    let coordinates: ServerPrayerCoords?
    let timezone: Int?
    let method: Int?
    let prayers: ServerPrayerEntries?
}

struct ServerHijriDate: Codable {
    let year: Int?
    let month: Int?
    let day: Int?
    let month_name_ar: String?
    let formatted: String?
}

struct ServerPrayerCoords: Codable {
    let lat: Double?
    let lng: Double?
}

struct ServerPrayerEntries: Codable {
    let fajr:    ServerPrayerEntry?
    let sunrise: ServerPrayerEntry?
    let dhuhr:   ServerPrayerEntry?
    let asr:     ServerPrayerEntry?
    let maghrib: ServerPrayerEntry?
    let isha:    ServerPrayerEntry?
    let midnight: ServerPrayerEntry?
    let last_third: ServerPrayerEntry?
}

struct ServerPrayerEntry: Codable {
    let name_ar: String?
    let name_en: String?
    let time: String?
}

// Convenience flattened model for UI use
struct ServerPrayerTimes {
    let date: String?
    let hijri: ServerHijriDate?
    let fajr: String?
    let sunrise: String?
    let dhuhr: String?
    let asr: String?
    let maghrib: String?
    let isha: String?
    let midnight: String?
    let last_third: String?
    let method: Int?

    init(from response: ServerPrayerResponse) {
        let d = response.data
        date      = d?.date
        hijri     = d?.hijri
        fajr      = d?.prayers?.fajr?.time
        sunrise   = d?.prayers?.sunrise?.time
        dhuhr     = d?.prayers?.dhuhr?.time
        asr       = d?.prayers?.asr?.time
        maghrib   = d?.prayers?.maghrib?.time
        isha      = d?.prayers?.isha?.time
        midnight  = d?.prayers?.midnight?.time
        last_third = d?.prayers?.last_third?.time
        method    = d?.method
    }
}

struct ServerPrayerLocation: Codable {
    let lat: Double?
    let lng: Double?
    let timezone: String?
}

struct ServerPrayerMethod: Codable, Identifiable {
    let id: Int
    let name_ar: String
    let name_en: String
    let fajr_angle: Double?
    let isha_angle: Double?
    let isha_interval: Int?
    let asr_method: String?
    let is_default: Int

    var isDefault: Bool { is_default == 1 }
}

// MARK: - PrayerService

/// Fetches prayer times from quran.meshari.tech using self-contained
/// astronomical calculation — no third-party dependency.
final class PrayerService {

    static let shared = PrayerService()
    private init() {}

    private let base = "https://quran.meshari.tech/api/prayer_times.php"

    // In-memory cache for methods (rarely changes)
    private var cachedMethods: [ServerPrayerMethod]?

    // MARK: - Prayer times

    /// Fetch prayer times for a given latitude, longitude and date.
    /// - Parameters:
    ///   - lat: Latitude
    ///   - lng: Longitude
    ///   - date: Date in "yyyy-MM-dd" format. Defaults to today.
    ///   - method: Prayer method ID (1–12). 10 = Umm Al-Qura (Saudi Arabia default)
    ///   - asr: Asr calculation method: "standard" (Shafi/Maliki/Hanbali) or "hanafi"
    func fetchTimes(
        lat: Double,
        lng: Double,
        date: String? = nil,
        method: Int = 10,
        asr: String = "standard"
    ) async throws -> ServerPrayerTimes {

        let dateStr: String
        if let d = date {
            dateStr = d
        } else {
            let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
            dateStr = fmt.string(from: Date())
        }

        guard var comps = URLComponents(string: base) else { throw PrayerServiceError.badURL }
        comps.queryItems = [
            URLQueryItem(name: "lat",    value: String(lat)),
            URLQueryItem(name: "lng",    value: String(lng)),
            URLQueryItem(name: "date",   value: dateStr),
            URLQueryItem(name: "method", value: String(method)),
            URLQueryItem(name: "asr",    value: asr),
        ]
        guard let url = comps.url else { throw PrayerServiceError.badURL }
        let data     = try await get(url)
        let response = try JSONDecoder().decode(ServerPrayerResponse.self, from: data)
        return ServerPrayerTimes(from: response)
    }

    /// Fetch prayer times for the next N days (for weekly planning or notifications).
    func fetchWeek(lat: Double, lng: Double, method: Int = 10) async throws -> [ServerPrayerTimes] {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let cal = Calendar.current
        return try await withThrowingTaskGroup(of: ServerPrayerTimes.self) { group in
            for i in 0..<7 {
                let date = cal.date(byAdding: .day, value: i, to: Date()) ?? Date()
                let str  = fmt.string(from: date)
                group.addTask { [self] in
                    try await fetchTimes(lat: lat, lng: lng, date: str, method: method)
                }
            }
            var results: [ServerPrayerTimes] = []
            for try await r in group { results.append(r) }
            return results.sorted { ($0.date ?? "") < ($1.date ?? "") }
        }
    }

    // MARK: - Prayer methods

    /// Returns all available prayer calculation methods.
    func fetchMethods() async throws -> [ServerPrayerMethod] {
        if let cached = cachedMethods { return cached }
        guard var comps = URLComponents(string: base) else { throw PrayerServiceError.badURL }
        comps.queryItems = [URLQueryItem(name: "action", value: "methods")]
        guard let url = comps.url else { throw PrayerServiceError.badURL }
        let data = try await get(url)
        guard let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ok      = json["success"] as? Bool, ok,
              let raw     = json["data"],
              let inner   = try? JSONSerialization.data(withJSONObject: raw)
        else { throw PrayerServiceError.parseFailed }
        let methods = try JSONDecoder().decode([ServerPrayerMethod].self, from: inner)
        cachedMethods = methods
        return methods
    }

    // MARK: - Private helpers

    private func get(_ url: URL) async throws -> Data {
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw PrayerServiceError.badResponse
        }
        return data
    }

    enum PrayerServiceError: Error {
        case badURL, badResponse, parseFailed
    }
}
