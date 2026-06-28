import Foundation

// MARK: - Response models

struct ServerHadithCollection: Codable, Identifiable {
    let id: String
    let name_ar: String
    let name_en: String
    let author_ar: String?
    let total_hadiths: Int?
    let is_available: Int
    let sort_order: Int?

    var isAvailable: Bool { is_available == 1 }
}

struct ServerHadithBook: Codable, Identifiable {
    let id: Int
    let collection_id: String
    let book_number: Int
    let name_ar: String
    let name_en: String?
    let hadiths_count: Int?
}

struct ServerHadith: Codable, Identifiable {
    let id: Int
    let collection_id: String
    let book_id: Int?
    let hadith_number: Int?
    let narrator_ar: String?
    let narrator_en: String?
    let text_ar: String
    let text_en: String?
    let grade_ar: String?
    let grade_en: String?
    let reference: String?
}

struct ServerHadithPage: Codable {
    let success: Bool
    let collection: String?
    let page: Int?
    let total: Int?
    let pages: Int?
    let has_more: Bool?
    let data: [ServerHadith]
}

// MARK: - HadithServerService

/// Fetches hadith content from quran.meshari.tech.
/// Supports 6 collections (54,321+ hadiths), paginated listing, and full-text search.
final class HadithServerService: ObservableObject {

    static let shared = HadithServerService()
    private init() {}

    private let base = "https://quran.meshari.tech/api/hadith.php"

    // Collections cache (read-only after first fetch — safe to access from any context)
    private var cachedCollections: [ServerHadithCollection]?
    // NOTE: per-hadith cache removed — it caused a data race when 100 concurrent TaskGroup
    // tasks wrote to the same dict. Persistent caching is handled by HadithOfflineManager.

    // MARK: - Collections

    func fetchCollections() async throws -> [ServerHadithCollection] {
        if let cached = cachedCollections { return cached }
        let url = try buildURL(params: ["action": "collections"])
        let data = try await get(url)
        let collections = try decode([ServerHadithCollection].self, from: data, key: "data")
        cachedCollections = collections
        return collections
    }

    // MARK: - Books

    func fetchBooks(collection: String) async throws -> [ServerHadithBook] {
        let url = try buildURL(params: ["action": "books", "collection": collection])
        let data = try await get(url)
        return try decode([ServerHadithBook].self, from: data, key: "data")
    }

    // MARK: - Hadith list (paginated)

    /// Fetches a paginated list of hadiths from a collection.
    /// - Parameters:
    ///   - collection: Collection ID (e.g. "bukhari", "muslim")
    ///   - book: Optional book number within the collection
    ///   - page: 1-based page number
    ///   - pageSize: Items per page (max 100)
    func fetchList(
        collection: String,
        book: Int? = nil,
        page: Int = 1,
        pageSize: Int = 50
    ) async throws -> ServerHadithPage {
        var params: [String: String] = [
            "action":     "list",
            "collection": collection,
            "page":       "\(page)",
            "limit":      "\(min(pageSize, 100))"
        ]
        if let b = book { params["book"] = "\(b)" }
        let url = try buildURL(params: params)
        let data = try await get(url)
        return try JSONDecoder().decode(ServerHadithPage.self, from: data)
    }

    // MARK: - Single hadith

    func fetchHadith(collection: String, number: Int) async throws -> ServerHadith {
        let url  = try buildURL(params: ["action": "get", "collection": collection, "number": "\(number)"])
        let data = try await get(url)
        return try decode(ServerHadith.self, from: data, key: "data")
    }

    // MARK: - Search

    /// Full-text search across all hadith collections (Arabic).
    func search(query: String, collection: String? = nil, limit: Int = 20) async throws -> [ServerHadith] {
        guard let enc = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw HadithServiceError.badURL
        }
        var params: [String: String] = [
            "action": "search", "q": enc, "limit": "\(min(limit, 50))"
        ]
        if let c = collection { params["collection"] = c }
        let url = try buildURL(params: params)
        let data = try await get(url)
        return try decode([ServerHadith].self, from: data, key: "data")
    }

    // MARK: - Random hadith

    func fetchRandom(collection: String? = nil) async throws -> ServerHadith {
        var params: [String: String] = ["action": "random"]
        if let c = collection { params["collection"] = c }
        let url = try buildURL(params: params)
        let data = try await get(url)
        return try decode(ServerHadith.self, from: data, key: "data")
    }

    // MARK: - Private helpers

    private func buildURL(params: [String: String]) throws -> URL {
        guard var comps = URLComponents(string: base) else { throw HadithServiceError.badURL }
        comps.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = comps.url else { throw HadithServiceError.badURL }
        return url
    }

    private func get(_ url: URL) async throws -> Data {
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw HadithServiceError.badResponse
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data, key: String) throws -> T {
        guard let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = json["success"] as? Bool, success,
              let raw     = json[key],
              let inner   = try? JSONSerialization.data(withJSONObject: raw)
        else { throw HadithServiceError.parseFailed }
        return try JSONDecoder().decode(T.self, from: inner)
    }

    enum HadithServiceError: Error {
        case badURL, badResponse, parseFailed
    }
}

// MARK: - ServerHadith helpers

extension ServerHadith {
    /// Arabic text with narrator prefix if available
    var fullTextAr: String {
        if let narrator = narrator_ar, !narrator.isEmpty {
            return "عن \(narrator): \(text_ar)"
        }
        return text_ar
    }

    /// Display-friendly collection name (Arabic)
    var collectionNameAr: String {
        switch collection_id {
        case "bukhari":  return "صحيح البخاري"
        case "muslim":   return "صحيح مسلم"
        case "abudawud": return "سنن أبي داود"
        case "tirmidhi": return "جامع الترمذي"
        case "nasai":    return "سنن النسائي"
        case "ibnmajah": return "سنن ابن ماجه"
        case "malik":    return "موطأ مالك"
        case "darimi":   return "سنن الدارمي"
        case "ahmad":    return "مسند الإمام أحمد"
        case "nawawi40": return "الأربعون النووية"
        default:         return collection_id
        }
    }
}
