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

// MARK: - Server-backed portal books

struct HadithServerBookInfo: Hashable {
    let portalBookId: Int
    let collectionId: String
    let totalRecords: Int
}

struct HadithServerPageRequest: Hashable {
    let collectionId: String
    let page: Int
    let pageSize: Int

    init(collectionId: String, page: Int, pageSize: Int = HadithServerBookCatalog.pageSize) {
        self.collectionId = collectionId
        self.page = max(1, page)
        self.pageSize = min(max(1, pageSize), HadithServerBookCatalog.pageSize)
    }

    var urlParams: String {
        "serverPage:\(collectionId):\(page):\(pageSize)"
    }

    static func parse(_ params: String) -> HadithServerPageRequest? {
        let parts = params.split(separator: ":").map(String.init)

        if parts.count >= 4, parts[0] == "serverPage",
           let page = Int(parts[2]),
           let pageSize = Int(parts[3]) {
            return HadithServerPageRequest(collectionId: parts[1], page: page, pageSize: pageSize)
        }

        // Backward compatibility with cached chapters created as
        // "server:{collectionId}:{start}:{end}". Those values were row ranges,
        // not hadith numbers, so translate them back to API pages.
        if parts.count == 4, parts[0] == "server",
           let start = Int(parts[2]),
           let end = Int(parts[3]) {
            let rangeSize = max(1, end - start + 1)
            let page = ((max(1, start) - 1) / HadithServerBookCatalog.pageSize) + 1
            return HadithServerPageRequest(collectionId: parts[1], page: page, pageSize: rangeSize)
        }

        return nil
    }
}

enum HadithServerBookCatalog {
    static let pageSize = 100

    static let books: [HadithServerBookInfo] = [
        HadithServerBookInfo(portalBookId: 33,  collectionId: "bukhari",         totalRecords: 21178),
        HadithServerBookInfo(portalBookId: 31,  collectionId: "muslim",          totalRecords: 13763),
        HadithServerBookInfo(portalBookId: 26,  collectionId: "abudawud",        totalRecords: 5274),
        HadithServerBookInfo(portalBookId: 38,  collectionId: "tirmidhi",        totalRecords: 3998),
        HadithServerBookInfo(portalBookId: 25,  collectionId: "nasai",           totalRecords: 5765),
        HadithServerBookInfo(portalBookId: 27,  collectionId: "ibnmajah",        totalRecords: 4343),
        HadithServerBookInfo(portalBookId: 30,  collectionId: "malik",           totalRecords: 1829),
        HadithServerBookInfo(portalBookId: 32,  collectionId: "darimi",          totalRecords: 2949),
        HadithServerBookInfo(portalBookId: 1,   collectionId: "ahmad",           totalRecords: 4305),
        HadithServerBookInfo(portalBookId: 76,  collectionId: "nawawi40",        totalRecords: 42),
        HadithServerBookInfo(portalBookId: 756, collectionId: "riyadussalihin",  totalRecords: 1217),
        HadithServerBookInfo(portalBookId: 55,  collectionId: "adab",            totalRecords: 1185),
        HadithServerBookInfo(portalBookId: 131, collectionId: "shamail",         totalRecords: 345),
        HadithServerBookInfo(portalBookId: 200, collectionId: "bulugh",          totalRecords: 378)
    ]

    static func info(forPortalBookId id: Int) -> HadithServerBookInfo? {
        books.first { $0.portalBookId == id }
    }

    static func info(forCollectionId id: String) -> HadithServerBookInfo? {
        books.first { $0.collectionId == id }
    }

    static func virtualChapterId(bookId: Int, page: Int) -> Int {
        10_000_000 + bookId * 1_000 + page
    }
}

// MARK: - HadithServerService

/// Fetches hadith content from quran.meshari.tech.
/// Supports server-backed collections, paginated listing, and full-text search.
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
        case "riyadussalihin": return "رياض الصالحين"
        case "adab":     return "الأدب المفرد"
        case "shamail":  return "الشمائل المحمدية"
        case "bulugh":   return "بلوغ المرام"
        default:         return collection_id
        }
    }
}
