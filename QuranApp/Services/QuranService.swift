import Foundation

// MARK: - Response models

struct ServerSura: Codable, Identifiable {
    let id: Int
    let name_ar: String
    let name_en: String
    let name_transliteration: String?
    let verses_count: Int
    let revelation_type: String?
    let pages_start: Int?
    let juz_start: Int?
}

struct ServerVerse: Codable, Identifiable {
    let id: Int
    let sura_id: Int
    let verse_number: Int
    let text_uthmani: String
    let text_simple: String?
    let juz: Int?
    let hizb: Int?
    let page: Int?
    let manzil: Int?
    let sajda: Int?
    // Joined fields (from page/sura queries)
    let sura_name_ar: String?
    let sura_name_en: String?
    let revelation_type: String?
    let verses_count: Int?
    // Translation (when ?translation= is included)
    var translations: [ServerTranslation]?
}

struct ServerTranslation: Codable {
    let translator_id: String?
    let language: String?
    let text: String
}

struct ServerSearchVerse: Codable, Identifiable {
    let id: Int
    let sura_id: Int
    let verse_number: Int
    let text_uthmani: String
    let sura_name_ar: String?
    let sura_name_en: String?
}

// MARK: - QuranService

/// Central service for fetching Quran content from quran.meshari.tech.
/// All methods are async and throw on network failure.
/// Falls back gracefully — callers can chain with alquran.cloud if needed.
final class QuranService {

    static let shared = QuranService()
    private init() {}

    private let base = "https://quran.meshari.tech/api/quran.php"

    // MARK: - Suras

    /// Returns all 114 suras ordered by ID.
    func fetchSuras() async throws -> [ServerSura] {
        let url = try buildURL(params: ["action": "suras"])
        let data = try await get(url)
        return try decode([ServerSura].self, from: data, key: "data")
    }

    // MARK: - Verses by page

    /// Returns all ayahs on a given mushaf page (1–604).
    func fetchPage(_ page: Int) async throws -> [ServerVerse] {
        let url = try buildURL(params: ["action": "page", "page": "\(page)"])
        let data = try await get(url)
        return try decode([ServerVerse].self, from: data, key: "data")
    }

    /// Returns all ayahs on a given mushaf page with translation.
    func fetchPage(_ page: Int, translation: String) async throws -> [ServerVerse] {
        let url = try buildURL(params: [
            "action": "page", "page": "\(page)", "translation": translation
        ])
        let data = try await get(url)
        return try decode([ServerVerse].self, from: data, key: "data")
    }

    // MARK: - Verses by sura

    /// Returns all verses in a given sura (1–114).
    func fetchSura(_ suraId: Int) async throws -> [ServerVerse] {
        let url = try buildURL(params: ["action": "sura", "sura": "\(suraId)"])
        let data = try await get(url)
        return try decode([ServerVerse].self, from: data, key: "data")
    }

    /// Returns all verses in a sura with the given translation.
    func fetchSura(_ suraId: Int, translation: String) async throws -> [ServerVerse] {
        let url = try buildURL(params: [
            "action": "sura", "sura": "\(suraId)", "translation": translation
        ])
        let data = try await get(url)
        return try decode([ServerVerse].self, from: data, key: "data")
    }

    // MARK: - Single verse

    /// Returns a single verse, optionally with translation.
    func fetchVerse(sura: Int, verse: Int, translation: String? = nil) async throws -> ServerVerse {
        var params: [String: String] = [
            "action": "verse", "sura": "\(sura)", "verse": "\(verse)"
        ]
        if let t = translation { params["translation"] = t }
        let url = try buildURL(params: params)
        let data = try await get(url)
        return try decode(ServerVerse.self, from: data, key: "data")
    }

    // MARK: - Verses by Juz

    func fetchJuz(_ juz: Int) async throws -> [ServerVerse] {
        let url = try buildURL(params: ["action": "juz", "juz": "\(juz)"])
        let data = try await get(url)
        return try decode([ServerVerse].self, from: data, key: "data")
    }

    // MARK: - Search

    /// Full-text Quran search (Arabic). Returns up to 50 matching verses.
    func search(query: String, limit: Int = 30) async throws -> [ServerSearchVerse] {
        guard let enc = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw QuranServiceError.badURL
        }
        do {
            let url = try buildURL(params: [
                "action": "search", "q": enc, "limit": "\(min(limit, 50))"
            ])
            let data = try await get(url)
            return try decode([ServerSearchVerse].self, from: data, key: "data")
        } catch {
            return try await fallbackSearch(query: query, limit: limit)
        }
    }

    // MARK: - Random verse

    func fetchRandomVerse() async throws -> ServerVerse {
        let url = try buildURL(params: ["action": "random"])
        let data = try await get(url)
        return try decodeSingle(ServerVerse.self, from: data, key: "data")
    }

    // MARK: - Private helpers

    private func buildURL(params: [String: String]) throws -> URL {
        guard var comps = URLComponents(string: base) else { throw QuranServiceError.badURL }
        comps.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = comps.url else { throw QuranServiceError.badURL }
        return url
    }

    private func get(_ url: URL) async throws -> Data {
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw QuranServiceError.badResponse
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data, key: String) throws -> T {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = json["success"] as? Bool, success,
              let raw = json[key],
              let innerData = try? JSONSerialization.data(withJSONObject: raw)
        else { throw QuranServiceError.parseFailed }
        return try JSONDecoder().decode(T.self, from: innerData)
    }

    private func decodeSingle<T: Decodable>(_ type: T.Type, from data: Data, key: String) throws -> T {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = json["success"] as? Bool, success,
              let raw = json[key]
        else { throw QuranServiceError.parseFailed }

        if let array = raw as? [Any], let first = array.first {
            let firstData = try JSONSerialization.data(withJSONObject: first)
            return try JSONDecoder().decode(T.self, from: firstData)
        }

        let innerData = try JSONSerialization.data(withJSONObject: raw)
        return try JSONDecoder().decode(T.self, from: innerData)
    }

    private func fallbackSearch(query: String, limit: Int) async throws -> [ServerSearchVerse] {
        let wanted = normalizedArabic(query)
        guard !wanted.isEmpty else { return [] }

        var results: [ServerSearchVerse] = []
        for sura in 1...114 {
            let verses = try await fetchSura(sura)
            for verse in verses where normalizedArabic(verse.text_uthmani).contains(wanted) {
                results.append(ServerSearchVerse(
                    id: verse.id,
                    sura_id: verse.sura_id,
                    verse_number: verse.verse_number,
                    text_uthmani: verse.text_uthmani,
                    sura_name_ar: verse.sura_name_ar,
                    sura_name_en: verse.sura_name_en
                ))
                if results.count >= min(limit, 50) { return results }
            }
        }
        return results
    }

    private func normalizedArabic(_ text: String) -> String {
        let replaced = text
            .replacingOccurrences(of: "أ", with: "ا")
            .replacingOccurrences(of: "إ", with: "ا")
            .replacingOccurrences(of: "آ", with: "ا")
            .replacingOccurrences(of: "ٱ", with: "ا")
            .replacingOccurrences(of: "ى", with: "ي")
            .replacingOccurrences(of: "ؤ", with: "و")
            .replacingOccurrences(of: "ئ", with: "ي")
            .replacingOccurrences(of: "ـ", with: "")

        let scalars = replaced.unicodeScalars.filter { scalar in
            let value = scalar.value
            return !(0x064B...0x065F).contains(value)
                && value != 0x0670
                && !(0x06D6...0x06ED).contains(value)
        }
        return String(String.UnicodeScalarView(scalars))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum QuranServiceError: Error {
        case badURL, badResponse, parseFailed
    }
}
