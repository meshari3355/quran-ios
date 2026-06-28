import Foundation

// MARK: - Tafsir IDs
//
// qurancdn.com (same backend as quran.com, CDN endpoint — no API key required):
//   169 = ابن كثير  |  91 = السعدي  |  74 = الجلالين
//
// alquran.cloud (completely free fallback):
//   ar.jalalayn   = تفسير الجلالين
//   ar.muyassar   = التفسير الميسر (King Fahd Complex — simplified tafsir)

enum TafsirBook: Int, CaseIterable, Identifiable {
    case ibnKathir  = 169
    case saadi      = 91
    case jalalyn    = 74

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .ibnKathir: return "تفسير ابن كثير"
        case .saadi:     return "تفسير السعدي"
        case .jalalyn:   return "تفسير الجلالين"
        }
    }

    var author: String {
        switch self {
        case .ibnKathir: return "إسماعيل بن عمر ابن كثير (774هـ)"
        case .saadi:     return "عبد الرحمن بن ناصر السعدي (1376هـ)"
        case .jalalyn:   return "جلال الدين المحلي والسيوطي"
        }
    }

    var description: String {
        switch self {
        case .ibnKathir:
            return "من أشهر كتب التفسير بالمأثور — يعتمد على القرآن والسنة وأقوال الصحابة والتابعين"
        case .saadi:
            return "تيسير الكريم الرحمن — تفسير ميسّر جامع مركّز يناسب عموم القراء"
        case .jalalyn:
            return "من أشهر المختصرات في التفسير — وجيز ومختصر ومعتمد في المدارس الشرعية"
        }
    }

    var icon: String {
        switch self {
        case .ibnKathir: return "book.closed.fill"
        case .saadi:     return "doc.text.fill"
        case .jalalyn:   return "book.fill"
        }
    }

    /// Edition ID for alquran.cloud (nil = not available there)
    var alquranCloudEdition: String? {
        switch self {
        case .ibnKathir: return nil           // not on alquran.cloud
        case .saadi:     return "ar.muyassar" // التفسير الميسر
        case .jalalyn:   return "ar.jalalayn"
        }
    }

    /// Tafsir ID on our own server (quran.meshari.tech).
    /// Priority source: fast, no third-party dependency, always available.
    var ownServerTafsirId: String? {
        switch self {
        case .ibnKathir: return "ibn-kathir"  // تفسير ابن كثير ✅
        case .saadi:     return "muyassar"    // التفسير الميسر ✅
        case .jalalyn:   return "jalalayn"    // تفسير الجلالين ✅
        }
    }
}

// MARK: - App-domain model

struct TafsirAyah: Identifiable {
    let id: Int          // ayah number in surah
    let verseKey: String // e.g. "2:255"
    let text: String     // tafsir text (HTML stripped)
}

// MARK: - Disk cache

struct TafsirSurahCache: Codable {
    let surahId:  Int
    let tafsirId: Int
    let ayahs:    [TafsirAyahCache]
    let fetchedAt: Date
}

struct TafsirAyahCache: Codable {
    let id:       Int
    let verseKey: String
    let text:     String
}

// MARK: - TafsirService

@MainActor
class TafsirService: ObservableObject {

    static let shared = TafsirService()

    private var memCache: [Int: [Int: [TafsirAyah]]] = [:]

    private let cacheDir: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir  = docs.appendingPathComponent("tafsir_cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    // MARK: Public

    func load(surah: Int, book: TafsirBook) async throws -> [TafsirAyah] {
        if let cached = memCache[book.id]?[surah] { return cached }
        if let disk = loadFromDisk(surah: surah, book: book) {
            memCache[book.id, default: [:]][surah] = disk
            return disk
        }
        let ayahs = try await fetchBestSource(surah: surah, book: book)
        saveToDisk(ayahs: ayahs, surah: surah, book: book)
        memCache[book.id, default: [:]][surah] = ayahs
        return ayahs
    }

    func isCached(surah: Int, book: TafsirBook) -> Bool {
        if memCache[book.id]?[surah] != nil { return true }
        return FileManager.default.fileExists(atPath: cacheURL(surah: surah, book: book).path)
    }

    // MARK: - Multi-source strategy

    private func fetchBestSource(surah: Int, book: TafsirBook) async throws -> [TafsirAyah] {

        // 0. ✅ Own server (quran.meshari.tech) — highest priority, no third-party dependency
        //    Currently has التفسير الميسر (muyassar) for all 6236 verses.
        //    Saadi book maps to "muyassar" on our server (same simplified Arabic).
        if let ownTafsirId = book.ownServerTafsirId,
           let result = try? await fetchFromOwnServer(surah: surah, tafsirId: ownTafsirId),
           !result.isEmpty {
            return result
        }

        // 1. qurancdn.com — same DB as quran.com, CDN endpoint, no key required
        if let result = try? await fetchFromQuranCDN(surah: surah, book: book), !result.isEmpty {
            return result
        }

        // 2. quran.com v4 — alternate CDN subdomain
        if let result = try? await fetchFromQuranCDNAlt(surah: surah, book: book), !result.isEmpty {
            return result
        }

        // 3. quran.com v4 — direct API (may need key, try anyway)
        if let result = try? await fetchFromQuranCom(surah: surah, book: book), !result.isEmpty {
            return result
        }

        // 4. alquran.cloud — completely free, limited editions
        if let edition = book.alquranCloudEdition,
           let result = try? await fetchFromAlquranCloud(surah: surah, edition: edition),
           !result.isEmpty {
            return result
        }

        // 5. Al-Quran Encyclopedia (quranenc.com) — additional fallback, covers more books
        if let result = try? await fetchFromQuranEnc(surah: surah, book: book), !result.isEmpty {
            return result
        }

        // All sources failed
        throw NSError(
            domain: "TafsirService",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "تعذّر تحميل التفسير من جميع المصادر. تحقق من الاتصال بالإنترنت."]
        )
    }

    // MARK: - Source 0: quran.meshari.tech (own server — primary)

    private func fetchFromOwnServer(surah: Int, tafsirId: String) async throws -> [TafsirAyah] {
        let urlStr = "https://quran.meshari.tech/api/tafsir.php?action=sura&sura=\(surah)&tafsir=\(tafsirId)"
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }

        var req = URLRequest(url: url, timeoutInterval: 20)
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        guard let json  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ok    = json["success"] as? Bool, ok,
              let rows  = json["data"] as? [[String: Any]]
        else { throw URLError(.cannotParseResponse) }

        let suraObj = json["sura"] as? [String: Any]
        let suraId  = (suraObj?["id"] as? Int) ?? surah

        return rows.compactMap { row -> TafsirAyah? in
            guard let num  = row["verse_number"] as? Int,
                  let text = row["text"]         as? String
            else { return nil }
            return TafsirAyah(id: num, verseKey: "\(suraId):\(num)", text: text)
        }
    }

    // MARK: - Source 1: qurancdn.com (primary CDN)

    private func fetchFromQuranCDN(surah: Int, book: TafsirBook) async throws -> [TafsirAyah] {
        let urlStr = "https://api.qurancdn.com/api/qdc/tafsirs/\(book.id)/by_surah/\(surah)"
        return try await fetchQuranComFormat(urlStr: urlStr, surahId: surah)
    }

    // MARK: - Source 2: qurancdn alternate subdomain

    private func fetchFromQuranCDNAlt(surah: Int, book: TafsirBook) async throws -> [TafsirAyah] {
        let urlStr = "https://cdn.qurancdn.com/api/qdc/tafsirs/\(book.id)/by_surah/\(surah)"
        return try await fetchQuranComFormat(urlStr: urlStr, surahId: surah)
    }

    // MARK: - Source 3: api.quran.com v4

    private func fetchFromQuranCom(surah: Int, book: TafsirBook) async throws -> [TafsirAyah] {
        let urlStr = "https://api.quran.com/api/v4/tafsirs/\(book.id)/by_surah/\(surah)"
        return try await fetchQuranComFormat(urlStr: urlStr, surahId: surah)
    }

    // MARK: - Source 5: quranenc.com (additional fallback)

    private func fetchFromQuranEnc(surah: Int, book: TafsirBook) async throws -> [TafsirAyah] {
        // quranenc.com uses different IDs; map only supported books
        let quranEncId: String?
        switch book {
        case .ibnKathir: quranEncId = "arabic_ibn_katheer"
        case .saadi:     quranEncId = "arabic_saadi"
        case .jalalyn:   quranEncId = "arabic_jalalayn"
        }
        guard let encId = quranEncId else { throw URLError(.unsupportedURL) }

        let urlStr = "https://quranenc.com/api/v1/translation/sura/\(encId)/\(surah)"
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }

        var req = URLRequest(url: url, timeoutInterval: 20)
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        // Response: { "result": [ { "aya": 1, "translation": "...", "footnotes": "..." } ] }
        guard let json   = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [[String: Any]]
        else { throw URLError(.cannotParseResponse) }

        return result.compactMap { item -> TafsirAyah? in
            guard let num  = item["aya"] as? Int,
                  let text = item["translation"] as? String
            else { return nil }
            return TafsirAyah(id: num, verseKey: "\(surah):\(num)", text: stripHTML(text))
        }
    }

    /// Shared parser for quran.com / qurancdn.com (same JSON format)
    /// NOTE: qurancdn.com returns the outer key as "tafseer" (double-e)
    ///       while quran.com v4 may return "tafsir" — we try both.
    private func fetchQuranComFormat(urlStr: String, surahId: Int) async throws -> [TafsirAyah] {
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }

        var req = URLRequest(url: url, timeoutInterval: 20)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("https://quran.com", forHTTPHeaderField: "Origin")
        req.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        // Try both "tafseer" (qurancdn.com) and "tafsir" (quran.com v4) outer keys
        let tafsirObj = (json["tafseer"] as? [String: Any]) ?? (json["tafsir"] as? [String: Any])
        guard let tafsir = tafsirObj,
              let verses = tafsir["verses"] as? [[String: Any]]
        else { throw URLError(.cannotParseResponse) }

        return verses.compactMap { verse -> TafsirAyah? in
            guard let key  = verse["verse_key"] as? String,
                  let html = verse["text"]      as? String
            else { return nil }
            let num = Int(key.split(separator: ":").last ?? "0") ?? 0
            return TafsirAyah(id: num, verseKey: key, text: stripHTML(html))
        }
    }

    // MARK: - Source 3: alquran.cloud (free, no key)

    private func fetchFromAlquranCloud(surah: Int, edition: String) async throws -> [TafsirAyah] {
        let urlStr = "https://api.alquran.cloud/v1/surah/\(surah)/\(edition)"
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }

        var req = URLRequest(url: url, timeoutInterval: 20)
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        // Response: { "data": { "ayahs": [ { "numberInSurah": 1, "text": "..." } ] } }
        guard let json  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let outer = json["data"] as? [String: Any],
              let ayahs = outer["ayahs"] as? [[String: Any]],
              let surahNum = outer["number"] as? Int
        else { throw URLError(.cannotParseResponse) }

        return ayahs.compactMap { ayah -> TafsirAyah? in
            guard let num  = ayah["numberInSurah"] as? Int,
                  let html = ayah["text"] as? String
            else { return nil }
            let key = "\(surahNum):\(num)"
            return TafsirAyah(id: num, verseKey: key, text: stripHTML(html))
        }
    }

    // MARK: - Disk

    private func cacheURL(surah: Int, book: TafsirBook) -> URL {
        cacheDir.appendingPathComponent("tafsir_\(book.id)_surah_\(surah).json")
    }

    private func loadFromDisk(surah: Int, book: TafsirBook) -> [TafsirAyah]? {
        let url = cacheURL(surah: surah, book: book)
        guard let data  = try? Data(contentsOf: url),
              let cache = try? JSONDecoder().decode(TafsirSurahCache.self, from: data)
        else { return nil }
        return cache.ayahs.map { TafsirAyah(id: $0.id, verseKey: $0.verseKey, text: $0.text) }
    }

    private func saveToDisk(ayahs: [TafsirAyah], surah: Int, book: TafsirBook) {
        let record = TafsirSurahCache(
            surahId:   surah,
            tafsirId:  book.id,
            ayahs:     ayahs.map { TafsirAyahCache(id: $0.id, verseKey: $0.verseKey, text: $0.text) },
            fetchedAt: Date()
        )
        if let data = try? JSONEncoder().encode(record) {
            try? data.write(to: cacheURL(surah: surah, book: book))
        }
    }

    // MARK: - HTML stripping

    private func stripHTML(_ html: String) -> String {
        var s = html

        // Remove <sup> footnote markers (with content)
        if let r = try? NSRegularExpression(pattern: "<sup[^>]*>.*?</sup>",
                                             options: [.dotMatchesLineSeparators]) {
            s = r.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
        }
        // Strip all remaining HTML tags
        if let r = try? NSRegularExpression(pattern: "<[^>]+>") {
            s = r.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
        }
        // Decode common HTML entities
        let entities: [String: String] = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">",
            "&quot;": "\"", "&#39;": "'", "&nbsp;": " ",
            "&laquo;": "«", "&raquo;": "»", "&#8203;": ""
        ]
        for (entity, char) in entities { s = s.replacingOccurrences(of: entity, with: char) }

        // Clean up whitespace
        return s.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n")
    }
}
