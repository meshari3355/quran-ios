import Foundation

// MARK: - HadithPortalService
//
// Fetches and parses pages from hadithportal.com.
// Returns native Swift models (PortalChapter, PortalHadith).
// All parsing is done with NSRegularExpression — no third-party HTML parser needed.

final class HadithPortalService {

    static let shared = HadithPortalService()

    private let baseURL = "https://hadithportal.com/index.php"
    private let session: URLSession

    // MARK: - In-memory cache (session-level, avoids re-fetching same pages)
    private var chaptersCache: [Int: [PortalChapter]] = [:]
    private var contentCache:  [String: (babs: [PortalChapter], hadiths: [PortalHadith])] = [:]

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 20   // hadithportal.com can be slow — give it time
        config.timeoutIntervalForResource = 45
        config.requestCachePolicy         = .returnCacheDataElseLoad
        config.urlCache                   = URLCache(
            memoryCapacity: 20 * 1024 * 1024,    // 20 MB RAM cache for HTML
            diskCapacity:   80 * 1024 * 1024,    // 80 MB disk cache
            diskPath:       "hadith_portal_html"
        )
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
            "Accept-Language": "ar,en;q=0.9",
            "Accept": "text/html,application/xhtml+xml",
            "Referer": "https://hadithportal.com/"
        ]
        session = URLSession(configuration: config)
    }

    // MARK: - Fetch Chapters for a Book

    func fetchChapters(bookId: Int) async throws -> [PortalChapter] {
        // Return in-memory cached result immediately
        if let cached = chaptersCache[bookId], !cached.isEmpty { return cached }

        let urlStr  = "\(baseURL)?show=book&book_id=\(bookId)"
        let html    = try await fetchHTML(urlStr)
        let result  = parseChapters(from: html, bookId: bookId)
        if !result.isEmpty { chaptersCache[bookId] = result }
        return result
    }

    // MARK: - Fetch Babs (sub-chapters) for a Chapter

    func fetchBabs(chapterUrlParams: String, bookId: Int) async throws -> [PortalChapter] {
        let urlStr = "\(baseURL)?\(chapterUrlParams)"
        let html   = try await fetchHTML(urlStr)
        return parseBabs(from: html, bookId: bookId)
    }

    // MARK: - Fetch Chapter Content (babs OR hadiths — one request)
    //
    // Fetches the chapter page ONCE and returns:
    //   • babs:    list of sub-chapters if the page is a bab-index page
    //   • hadiths: all hadiths (all pages) if the page shows hadiths directly
    // Eliminates the previous double-request: BabsView fetched to check for babs, then
    // HadithsView fetched the SAME URL again for hadiths. Now it's one trip.

    func fetchChapterContent(
        chapterUrlParams: String,
        bookId: Int,
        chapter: PortalChapter
    ) async throws -> (babs: [PortalChapter], hadiths: [PortalHadith]) {

        // Return in-memory cached result if already fetched this session
        if let cached = contentCache[chapterUrlParams] { return cached }

        let firstURL  = "\(baseURL)?\(chapterUrlParams)"
        let firstHTML = try await fetchHTML(firstURL)

        // Page is a bab-index — return babs immediately
        let babs = parseBabs(from: firstHTML, bookId: bookId)
        if !babs.isEmpty {
            let result = (babs: babs, hadiths: [PortalHadith]())
            contentCache[chapterUrlParams] = result
            return result
        }

        // No babs → parse hadiths + follow pagination
        var hadiths: [PortalHadith] = parseHadiths(from: firstHTML, chapter: chapter, offset: 0)
        var currentHTML   = firstHTML
        var currentParams = chapterUrlParams
        var visitedURLs   = Set<String>([firstURL])

        while let nextParams = findNextPageParams(in: currentHTML, currentParams: currentParams) {
            let nextURL = "\(baseURL)?\(nextParams)"
            guard !visitedURLs.contains(nextURL) else { break }
            visitedURLs.insert(nextURL)
            currentHTML = try await fetchHTML(nextURL)
            hadiths.append(contentsOf: parseHadiths(from: currentHTML, chapter: chapter, offset: hadiths.count))
            currentParams = nextParams
        }

        let result = (babs: [PortalChapter](), hadiths: hadiths)
        if !hadiths.isEmpty { contentCache[chapterUrlParams] = result }
        return result
    }

    // MARK: - Fetch Hadiths for a Chapter (all pages)

    func fetchHadiths(chapter: PortalChapter) async throws -> [PortalHadith] {
        if let cached = contentCache[chapter.urlParams] { return cached.hadiths }
        let hadiths = try await fetchAllPages(baseParams: chapter.urlParams, chapter: chapter)
        if !hadiths.isEmpty {
            contentCache[chapter.urlParams] = (babs: [], hadiths: hadiths)
        }
        return hadiths
    }

    // Overload: fetch by raw chapter-ID and bookId (used by offline manager)
    func fetchHadiths(chapterId: Int, bookId: Int, urlParams: String) async throws -> [PortalHadith] {
        let chapter = PortalChapter(id: chapterId, bookId: bookId, nameAr: "", urlParams: urlParams)
        return try await fetchAllPages(baseParams: urlParams, chapter: chapter)
    }

    // MARK: - Paginated fetch (follows next-page links until none)

    private func fetchAllPages(baseParams: String, chapter: PortalChapter) async throws -> [PortalHadith] {
        var allHadiths: [PortalHadith] = []
        var currentParams = baseParams
        var visitedURLs   = Set<String>()

        while true {
            let urlStr = "\(baseURL)?\(currentParams)"
            guard !visitedURLs.contains(urlStr) else { break }
            visitedURLs.insert(urlStr)

            let html = try await fetchHTML(urlStr)
            let pageHadiths = parseHadiths(from: html, chapter: chapter, offset: allHadiths.count)
            allHadiths.append(contentsOf: pageHadiths)

            // Look for a "next page" link in the HTML
            guard let nextParams = findNextPageParams(in: html, currentParams: currentParams) else { break }
            currentParams = nextParams
        }

        return allHadiths
    }

    // MARK: - Find next page URL params from HTML

    private func findNextPageParams(in html: String, currentParams: String) -> String? {
        let ns = html as NSString

        // Pattern 1: Arabic next-page labels — التالي / التالية / الصفحة التالية
        // Pattern 2: >> or › symbol  inside <a> with index.php link
        // Pattern 3: page= or start= parameter increment
        let patterns = [
            // <a href="index.php?...">التالي</a>  or  التالية
            #"href="index\.php\?([^"]*)"[^>]*>(?:[^<]*(?:التالي|التالية|&gt;&gt;|›|»)[^<]*)</a>"#,
            #"href='index\.php\?([^']*)'[^>]*>(?:[^<]*(?:التالي|التالية|&gt;&gt;|›|»)[^<]*)</a>"#,
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { continue }
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
            for match in matches {
                guard match.numberOfRanges > 1 else { continue }
                let rawParams = ns.substring(with: match.range(at: 1))
                    .replacingOccurrences(of: "&amp;", with: "&")
                // Must contain show= and differ from current
                guard rawParams.contains("show="),
                      rawParams != currentParams else { continue }
                return rawParams
            }
        }

        // Pattern 3: look for page= parameter in any chapter link that has a higher page number
        if let currentPage = extractPageNumber(from: currentParams) {
            let nextPage = currentPage + 1
            let nextPattern = #"href="index\.php\?([^"]*page=\#(nextPage)[^"]*)"[^>]*>"#
            if let regex = try? NSRegularExpression(pattern: nextPattern),
               let match  = regex.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)),
               match.numberOfRanges > 1 {
                let raw = ns.substring(with: match.range(at: 1))
                    .replacingOccurrences(of: "&amp;", with: "&")
                if raw != currentParams { return raw }
            }
        }

        return nil
    }

    private func extractPageNumber(from params: String) -> Int? {
        let pattern = #"(?:^|&)page=(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match  = regex.firstMatch(in: params, range: NSRange(params.startIndex..., in: params)),
              match.numberOfRanges > 1,
              let range  = Range(match.range(at: 1), in: params) else { return nil }
        return Int(params[range])
    }

    // MARK: - Search

    func search(query: String) async throws -> [PortalHadith] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }
        let urlStr = "\(baseURL)?show=result&type=&word=\(encoded)"
        let html   = try await fetchHTML(urlStr)
        return parseSearchResults(from: html)
    }

    // MARK: - Private: Fetch HTML

    private func fetchHTML(_ urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
            forHTTPHeaderField: "User-Agent"
        )
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        // Try UTF-8 first, then windows-1256 (common Arabic encoding)
        if let s = String(data: data, encoding: .utf8) { return s }
        // Windows-1256 Arabic = CF encoding value 1268
        let win1256 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(1268))
        if let s = String(data: data, encoding: win1256) { return s }
        return String(data: data, encoding: .isoLatin1) ?? ""
    }

    // MARK: - Parse Bab List (sub-chapters within a chapter)
    //
    // Chapter page at ?show=chapter&chapter_id=X lists babs in <a> tags.
    // Pattern: href="index.php?show=bab&bab_id=X&chapter_id=X&book=X..."
    // Parameters can be in any order; &amp; or & both handled.

    private func parseBabs(from html: String, bookId: Int) -> [PortalChapter] {
        var babs: [PortalChapter] = []
        var seen = Set<Int>()
        let ns = html as NSString

        // Flexible: require bab_id=N anywhere in the href
        let patterns = [
            // double quotes
            #"href="index\.php\?([^"]*\bbab_id=(\d+)\b[^"]*)">([^<]+)</a>"#,
            // single quotes
            #"href='index\.php\?([^']*\bbab_id=(\d+)\b[^']*)'>([^<]+)</a>"#,
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { continue }
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
            for match in matches {
                guard match.numberOfRanges >= 4 else { continue }
                let rawParams = ns.substring(with: match.range(at: 1))
                    .replacingOccurrences(of: "&amp;", with: "&")
                // Only accept actual bab links
                guard rawParams.contains("show=bab") else { continue }
                let babIdStr  = ns.substring(with: match.range(at: 2))
                let rawName   = ns.substring(with: match.range(at: 3))
                guard let babId = Int(babIdStr), !seen.contains(babId) else { continue }
                let name = stripHTML(rawName).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { continue }
                seen.insert(babId)
                babs.append(PortalChapter(
                    id:        babId,
                    bookId:    bookId,
                    nameAr:    name,
                    urlParams: rawParams
                ))
            }
            if !babs.isEmpty { break }
        }
        return babs
    }

    // MARK: - Parse Chapter List
    //
    // The book page at ?show=book&book_id={id} lists chapters in <a> tags.
    // Pattern: href="index.php?show=chapter&chapter_id=2&book=33&..."
    // Parameters can be in any order; &amp; or & both handled.

    private func parseChapters(from html: String, bookId: Int) -> [PortalChapter] {
        var chapters: [PortalChapter] = []
        var seen = Set<Int>()

        // Flexible: just require chapter_id=N and show=chapter anywhere in the href (any param order)
        let patterns = [
            // double quotes
            #"href="index\.php\?([^"]*\bchapter_id=(\d+)\b[^"]*)">([^<]+)</a>"#,
            // single quotes
            #"href='index\.php\?([^']*\bchapter_id=(\d+)\b[^']*)'>([^<]+)</a>"#,
        ]

        let ns = html as NSString
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { continue }
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
            for match in matches {
                guard match.numberOfRanges >= 4 else { continue }
                let rawParams = ns.substring(with: match.range(at: 1))
                    .replacingOccurrences(of: "&amp;", with: "&")
                // Only accept links that are for chapters (show=chapter) or babs
                guard rawParams.contains("show=chapter") else { continue }
                let chapIdStr = ns.substring(with: match.range(at: 2))
                let rawName   = ns.substring(with: match.range(at: 3))
                guard let chapId = Int(chapIdStr), !seen.contains(chapId) else { continue }
                let name = stripHTML(rawName).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { continue }
                seen.insert(chapId)
                chapters.append(PortalChapter(
                    id: chapId,
                    bookId: bookId,
                    nameAr: name,
                    urlParams: rawParams
                ))
            }
            if !chapters.isEmpty { break }
        }
        return chapters
    }

    // MARK: - Parse Hadiths
    //
    // Chapter pages (?show=chapter or ?show=bab) contain hadith blocks.
    // Each hadith is in a numbered div or table row with Arabic text.

    private func parseHadiths(from html: String, chapter: PortalChapter, offset: Int = 0) -> [PortalHadith] {
        var hadiths: [PortalHadith] = []

        hadiths = extractHadithBlocks(from: html, chapter: chapter, offset: offset)

        if hadiths.isEmpty {
            hadiths = extractFallbackHadiths(from: html, chapter: chapter, offset: offset)
        }

        return hadiths
    }

    /// Primary extraction: look for hadith containers (div/li/article with id="tab_hadith_N" etc.)
    private func extractHadithBlocks(from html: String, chapter: PortalChapter, offset: Int = 0) -> [PortalHadith] {
        var hadiths: [PortalHadith] = []
        let ns = html as NSString

        // Match the FULL opening tag of each hadith container so content starts AFTER ">".
        // This avoids capturing raw attribute text (id="..." class="...") as part of hadith text.
        let blockPatterns = [
            // <div id="tab_hadith_N" ...> or <div id="hadith_N" ...>  (double quotes)
            #"<(?:div|li|article|section|tr)[^>]*\bid="(?:tab_hadith|hadith)_?(\d+)[^"]*"[^>]*>"#,
            // Single-quote variant
            #"<(?:div|li|article|section|tr)[^>]*\bid='(?:tab_hadith|hadith)_?(\d+)[^']*'[^>]*>"#,
            // data-hadith-id="N"
            #"<(?:div|li|article|section|tr)[^>]*\bdata-hadith-id="(\d+)"[^>]*>"#,
        ]

        for pattern in blockPatterns {
            guard let blockRegex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { continue }
            let matches = blockRegex.matches(in: html, range: NSRange(location: 0, length: ns.length))
            guard !matches.isEmpty else { continue }

            for (i, match) in matches.enumerated() {
                guard match.numberOfRanges > 1, match.range(at: 1).location != NSNotFound else { continue }
                let numStr = ns.substring(with: match.range(at: 1))

                // Content starts AFTER the closing ">" of this opening tag — no attribute leakage
                let contentStart = NSMaxRange(match.range)
                // Content ends where the NEXT hadith block's opening tag begins
                let contentEnd   = i + 1 < matches.count ? matches[i + 1].range.location : ns.length
                guard contentStart < contentEnd else { continue }

                let block = ns.substring(with: NSRange(location: contentStart, length: contentEnd - contentStart))
                var text  = stripHTML(block).trimmingCharacters(in: .whitespacesAndNewlines)
                text = cleanHadithText(text)

                guard text.count > 30, containsArabic(text) else { continue }
                hadiths.append(PortalHadith(
                    id:        offset + hadiths.count + 1,
                    bookId:    chapter.bookId,
                    chapterId: chapter.id,
                    number:    numStr,
                    text:      text,
                    bookName:  nil
                ))
            }

            if !hadiths.isEmpty { return hadiths }
        }

        // Pattern 2: <td class="hadith"> or <div class="hadith">
        let cellPattern = #"<(?:td|div)[^>]*class="[^"]*hadith[^"]*"[^>]*>([\s\S]*?)</(?:td|div)>"#
        if let cellRegex = try? NSRegularExpression(pattern: cellPattern) {
            let matches = cellRegex.matches(in: html, range: NSRange(location: 0, length: ns.length))
            for match in matches {
                guard match.numberOfRanges > 1 else { continue }
                let inner = ns.substring(with: match.range(at: 1))
                var text  = stripHTML(inner).trimmingCharacters(in: .whitespacesAndNewlines)
                text = cleanHadithText(text)
                guard text.count > 40, containsArabic(text) else { continue }
                hadiths.append(PortalHadith(
                    id:        offset + hadiths.count + 1,
                    bookId:    chapter.bookId,
                    chapterId: chapter.id,
                    number:    "\(offset + hadiths.count + 1)",
                    text:      text,
                    bookName:  nil
                ))
            }
        }

        return hadiths
    }

    /// Fallback: extract substantial Arabic text paragraphs when structured parsing fails
    private func extractFallbackHadiths(from html: String, chapter: PortalChapter, offset: Int = 0) -> [PortalHadith] {
        var hadiths: [PortalHadith] = []
        let ns = html as NSString

        // Try RTL-marked paragraphs first
        let paraPatterns = [
            #"<(?:p|td|div)[^>]*dir=["']rtl["'][^>]*>([\s\S]*?)</(?:p|td|div)>"#,
            #"<(?:p|td)[^>]*class=["'][^"']*arabic[^"']*["'][^>]*>([\s\S]*?)</(?:p|td)>"#,
        ]

        for pattern in paraPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { continue }
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
            for match in matches {
                guard match.numberOfRanges > 1 else { continue }
                let inner = ns.substring(with: match.range(at: 1))
                var text  = stripHTML(inner).trimmingCharacters(in: .whitespacesAndNewlines)
                text = cleanHadithText(text)
                guard text.count > 60, containsArabic(text) else { continue }
                hadiths.append(PortalHadith(
                    id:        offset + hadiths.count + 1,
                    bookId:    chapter.bookId,
                    chapterId: chapter.id,
                    number:    "\(offset + hadiths.count + 1)",
                    text:      text,
                    bookName:  nil
                ))
            }
            if !hadiths.isEmpty { break }
        }

        return hadiths
    }

    // MARK: - Parse Search Results

    private func parseSearchResults(from html: String) -> [PortalHadith] {
        var results: [PortalHadith] = []
        let ns = html as NSString

        // Search results are typically in divs with class "search_result" or similar
        // Pattern: extract text blocks between result separators
        let pattern = #"<div[^>]*class="[^"]*result[^"]*"[^>]*>([\s\S]*?)</div>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))

        for match in matches {
            guard match.numberOfRanges > 1 else { continue }
            let inner = ns.substring(with: match.range(at: 1))
            let text  = stripHTML(inner).trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.count > 30, containsArabic(text) else { continue }

            // Try to extract book reference from nearby text
            results.append(PortalHadith(
                id:        results.count + 1,
                bookId:    0,
                chapterId: 0,
                number:    "\(results.count + 1)",
                text:      text,
                bookName:  nil
            ))
        }

        return results
    }

    // MARK: - HTML Utility

    /// Strip all HTML tags from a string, removing media/script blocks entirely
    func stripHTML(_ html: String) -> String {
        var result = html
        // Remove script, style, audio, video blocks entirely (including their content)
        for tag in ["script", "style", "audio", "video", "figure", "noscript"] {
            let pattern = "<\(tag)[^>]*>[\\s\\S]*?</\(tag)>"
            if let r = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                result = r.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: " "
                )
            }
        }
        // Replace <br>, </p>, </div>, </li> with newline
        for tag in ["<br>", "<br/>", "<br />", "</p>", "</div>", "</li>", "</tr>", "</td>"] {
            result = result.replacingOccurrences(of: tag, with: "\n", options: .caseInsensitive)
        }
        // Remove all remaining tags
        if let tagRegex = try? NSRegularExpression(pattern: "<[^>]+>") {
            result = tagRegex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }
        // Decode HTML entities
        result = result
            .replacingOccurrences(of: "&amp;",  with: "&")
            .replacingOccurrences(of: "&lt;",   with: "<")
            .replacingOccurrences(of: "&gt;",   with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;",  with: "'")
        // Collapse multiple whitespace/newlines
        if let wsRegex = try? NSRegularExpression(pattern: "[ \t]+") {
            result = wsRegex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: " "
            )
        }
        if let nlRegex = try? NSRegularExpression(pattern: "\n{3,}") {
            result = nlRegex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "\n\n"
            )
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Remove known browser artifacts and unwanted phrases from hadith text
    private func cleanHadithText(_ text: String) -> String {
        var result = text
        let unwanted = [
            "Sorry, your browser does not support HTML5 audio.",
            "هذه القراءة حاسوبية، وما زالت قيد الضبط والتطوير",
            "هذه القراءة حاسوبية",
            "الرجاء تحديث المتصفح",
        ]
        for phrase in unwanted {
            result = result.replacingOccurrences(of: phrase, with: "")
        }
        // Collapse any extra blank lines left after removals
        if let nlRegex = try? NSRegularExpression(pattern: "\n{3,}") {
            result = nlRegex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "\n\n"
            )
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func containsArabic(_ text: String) -> Bool {
        text.unicodeScalars.contains { $0.value >= 0x0600 && $0.value <= 0x06FF }
    }
}
