import Foundation

// MARK: - Response models

struct ServerReciter: Codable, Identifiable {
    let id: Int
    let slug: String
    let name_ar: String
    let name_en: String
    let style_ar: String?
    let style_en: String?
    let base_url: String?
    let file_format: String?
    let filename_pattern: String?
    let sura_pattern: String?
    let is_featured: Int
    let sort_order: Int

    var isFeatured: Bool { is_featured == 1 }

    /// Builds the audio URL for a full sura. Returns nil if pattern unavailable.
    func suraURL(sura: Int) -> URL? {
        guard let base = base_url, let pattern = sura_pattern else { return nil }
        let padded3 = String(format: "%03d", sura)
        let padded  = String(sura)
        let filename = pattern
            .replacingOccurrences(of: "{sura:3}", with: padded3)
            .replacingOccurrences(of: "{sura}",   with: padded)
        return URL(string: base + filename)
    }

    /// Builds the audio URL for a single verse. Returns nil if pattern unavailable.
    func verseURL(sura: Int, verse: Int) -> URL? {
        guard let base = base_url, let pattern = filename_pattern else { return nil }
        let padSura  = String(format: "%03d", sura)
        let padVerse = String(format: "%03d", verse)
        let filename = pattern
            .replacingOccurrences(of: "{sura:3}",  with: padSura)
            .replacingOccurrences(of: "{verse:3}", with: padVerse)
            .replacingOccurrences(of: "{sura}",    with: String(sura))
            .replacingOccurrences(of: "{verse}",   with: String(verse))
        return URL(string: base + filename)
    }
}

struct ServerPlaylistItem: Codable {
    let verse: Int
    let url: String
}

struct ServerSuraAudio: Codable {
    let reciter: Int
    let sura: Int
    let sura_url: String?
    let playlist: [ServerPlaylistItem]?
}

// MARK: - AudioService

/// Fetches reciter metadata and audio URLs from quran.meshari.tech.
/// Audio files themselves are streamed from each reciter's CDN (e.g. everyayah.com).
final class AudioService {

    static let shared = AudioService()
    private init() {}

    private let base = "https://quran.meshari.tech/api/audio.php"

    // In-memory cache for reciters (rarely changes)
    private var cachedReciters: [ServerReciter]?

    // MARK: - Reciters

    /// Returns all 20 reciters ordered by sort_order.
    func fetchReciters() async throws -> [ServerReciter] {
        if let cached = cachedReciters { return cached }
        let url = try buildURL(params: ["action": "reciters"])
        let data = try await get(url)
        let reciters = try decode([ServerReciter].self, from: data, key: "data")
        cachedReciters = reciters
        return reciters
    }

    /// Returns only featured reciters.
    func fetchFeaturedReciters() async throws -> [ServerReciter] {
        let url = try buildURL(params: ["action": "featured"])
        let data = try await get(url)
        return try decode([ServerReciter].self, from: data, key: "data")
    }

    // MARK: - Audio URLs

    /// Returns the audio URL for a full sura by a given reciter.
    func fetchSuraURL(reciterId: Int, sura: Int) async throws -> URL? {
        let url = try buildURL(params: [
            "action": "sura", "reciter": "\(reciterId)", "sura": "\(sura)"
        ])
        let data = try await get(url)
        guard let json   = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ok     = json["success"] as? Bool, ok,
              let urlStr = json["sura_url"] as? String
        else { return nil }
        return URL(string: urlStr)
    }

    /// Returns the audio URL for a single verse by a given reciter.
    func fetchVerseURL(reciterId: Int, sura: Int, verse: Int) async throws -> URL? {
        let url = try buildURL(params: [
            "action": "verse", "reciter": "\(reciterId)",
            "sura": "\(sura)", "verse": "\(verse)"
        ])
        let data = try await get(url)
        guard let json   = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ok     = json["success"] as? Bool, ok,
              let urlStr = json["url"] as? String
        else { return nil }
        return URL(string: urlStr)
    }

    /// Returns a full playlist (all verses) for a sura by a given reciter.
    func fetchPlaylist(reciterId: Int, sura: Int) async throws -> ServerSuraAudio {
        let url = try buildURL(params: [
            "action": "playlist", "reciter": "\(reciterId)", "sura": "\(sura)"
        ])
        let data = try await get(url)
        guard let json   = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ok     = json["success"] as? Bool, ok,
              let inner  = try? JSONSerialization.data(withJSONObject: json)
        else { throw AudioServiceError.parseFailed }
        return try JSONDecoder().decode(ServerSuraAudio.self, from: inner)
    }

    // MARK: - Convenience: offline-friendly URL generation

    /// Generates a verse URL directly from reciter metadata — no network call needed.
    /// Returns nil if the reciter has no URL pattern stored.
    func offlineVerseURL(reciter: ServerReciter, sura: Int, verse: Int) -> URL? {
        reciter.verseURL(sura: sura, verse: verse)
    }

    // MARK: - Private helpers

    private func buildURL(params: [String: String]) throws -> URL {
        guard var comps = URLComponents(string: base) else { throw AudioServiceError.badURL }
        comps.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = comps.url else { throw AudioServiceError.badURL }
        return url
    }

    private func get(_ url: URL) async throws -> Data {
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AudioServiceError.badResponse
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data, key: String) throws -> T {
        guard let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = json["success"] as? Bool, success,
              let raw     = json[key],
              let inner   = try? JSONSerialization.data(withJSONObject: raw)
        else { throw AudioServiceError.parseFailed }
        return try JSONDecoder().decode(T.self, from: inner)
    }

    enum AudioServiceError: Error {
        case badURL, badResponse, parseFailed
    }
}
