import Foundation

// MARK: - HadithPortalOfflineManager
//
// Downloads and caches all chapters + hadiths from hadithportal.com for any book.
// Cache structure:
//   Documents/hadith_portal/{bookId}/chapters.json
//   Documents/hadith_portal/{bookId}/{chapterId}.json
//
// The manager also surfaces a combined "download all" that iterates every chapter.

@MainActor
final class HadithPortalOfflineManager: ObservableObject {

    static let shared = HadithPortalOfflineManager()
    private init() { Task { await loadStatesAsync() } }

    // MARK: - Per-book download state

    struct BookDownloadState {
        var isDownloading:    Bool   = false
        var totalChapters:    Int    = 0
        var doneChapters:     Int    = 0
        var progress:         Double = 0
        var isAvailable:      Bool   = false   // chapters.json exists
        var chaptersOnly:     Bool   = false   // chapters downloaded but not all hadiths
        var currentChapter:   String = ""
    }

    @Published var states: [Int: BookDownloadState] = [:]

    // Active cancellation flags (nonisolated access)
    private var cancelFlags: [Int: Bool] = [:]

    // MARK: - Paths

    private func portalDir() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("hadith_portal", isDirectory: true)
    }

    private func bookDir(bookId: Int) -> URL {
        portalDir().appendingPathComponent("\(bookId)", isDirectory: true)
    }

    private func chaptersFile(bookId: Int) -> URL {
        bookDir(bookId: bookId).appendingPathComponent("chapters.json")
    }

    private func hadithsFile(bookId: Int, chapterId: Int) -> URL {
        bookDir(bookId: bookId).appendingPathComponent("\(chapterId).json")
    }

    private func babsFile(bookId: Int, chapterId: Int) -> URL {
        bookDir(bookId: bookId).appendingPathComponent("babs_\(chapterId).json")
    }

    // MARK: - Load persisted state on startup

    /// Scans cached files off the main thread to avoid blocking the UI on launch.
    private func loadStatesAsync() async {
        let books = PortalCategory.allBooks
        // Capture URL builders as closures-safe values
        let portalBase = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("hadith_portal", isDirectory: true)

        let computed = await Task.detached(priority: .utility) {
            let fm = FileManager.default
            var result: [Int: BookDownloadState] = [:]
            for book in books {
                let bookDir   = portalBase.appendingPathComponent("\(book.id)", isDirectory: true)
                let chapFile  = bookDir.appendingPathComponent("chapters.json")
                var s         = BookDownloadState()

                if fm.fileExists(atPath: chapFile.path),
                   let data     = try? Data(contentsOf: chapFile),
                   let list     = try? JSONDecoder().decode(PortalChapterList.self, from: data) {
                    let chapters = list.chapters
                    let hadithFiles = (try? fm.contentsOfDirectory(atPath: bookDir.path))?
                        .filter { $0.hasSuffix(".json") && $0 != "chapters.json" }.count ?? 0
                    s.isAvailable   = true
                    s.totalChapters = chapters.count
                    s.doneChapters  = hadithFiles
                    s.chaptersOnly  = hadithFiles < chapters.count
                    s.progress      = chapters.count > 0
                        ? Double(hadithFiles) / Double(chapters.count) : 0
                }
                result[book.id] = s
            }
            return result
        }.value
        // Back on MainActor — publish the result
        self.states = computed
    }

    // MARK: - Public API

    func isAvailable(bookId: Int) -> Bool       { states[bookId]?.isAvailable ?? false }
    func isDownloading(bookId: Int) -> Bool     { states[bookId]?.isDownloading ?? false }
    func progress(bookId: Int) -> Double        { states[bookId]?.progress ?? 0 }
    func doneChapters(bookId: Int) -> Int       { states[bookId]?.doneChapters ?? 0 }
    func totalChapters(bookId: Int) -> Int      { states[bookId]?.totalChapters ?? 0 }
    func currentChapter(bookId: Int) -> String  { states[bookId]?.currentChapter ?? "" }

    // MARK: - Read cached data

    func loadChapters(bookId: Int) -> [PortalChapter]? {
        guard let data = try? Data(contentsOf: chaptersFile(bookId: bookId)),
              let list = try? JSONDecoder().decode(PortalChapterList.self, from: data)
        else { return nil }
        return list.chapters
    }

    func loadHadiths(bookId: Int, chapterId: Int) -> [PortalHadith]? {
        guard let data = try? Data(contentsOf: hadithsFile(bookId: bookId, chapterId: chapterId)),
              let list = try? JSONDecoder().decode(PortalHadithList.self, from: data)
        else { return nil }
        return list.hadiths
    }

    func saveHadithsBrowseCache(_ hadiths: [PortalHadith], bookId: Int, chapterId: Int) {
        guard !hadiths.isEmpty else { return }
        let dir = bookDir(bookId: bookId)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let list = PortalHadithList(
            bookId: bookId,
            chapterId: chapterId,
            hadiths: hadiths,
            fetchedAt: Date()
        )
        if let data = try? JSONEncoder().encode(list) {
            try? data.write(to: hadithsFile(bookId: bookId, chapterId: chapterId), options: .atomic)
        }
    }

    // MARK: - Babs browse cache (babs = sub-chapters, cached per chapter)

    func loadBabs(bookId: Int, chapterId: Int) -> [PortalChapter]? {
        guard let data = try? Data(contentsOf: babsFile(bookId: bookId, chapterId: chapterId)),
              let list = try? JSONDecoder().decode(PortalChapterList.self, from: data),
              !list.chapters.isEmpty
        else { return nil }
        return list.chapters
    }

    func saveBabsBrowseCache(_ babs: [PortalChapter], bookId: Int, chapterId: Int) {
        guard !babs.isEmpty else { return }
        let dir = bookDir(bookId: bookId)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let list = PortalChapterList(bookId: bookId, chapters: babs, fetchedAt: Date())
        if let data = try? JSONEncoder().encode(list) {
            try? data.write(to: babsFile(bookId: bookId, chapterId: chapterId), options: .atomic)
        }
    }

    /// Lightweight cache of just the chapter list (called after first browse, before full download).
    /// Makes repeat visits to a book page instant without requiring a full offline download.
    func saveChaptersBrowseCache(_ chapters: [PortalChapter], bookId: Int) {
        guard !chapters.isEmpty else { return }
        let dir = bookDir(bookId: bookId)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let list = PortalChapterList(bookId: bookId, chapters: chapters, fetchedAt: Date())
        if let data = try? JSONEncoder().encode(list) {
            try? data.write(to: chaptersFile(bookId: bookId), options: .atomic)
        }
        if states[bookId] == nil { states[bookId] = BookDownloadState() }
        states[bookId]?.isAvailable   = true
        states[bookId]?.chaptersOnly  = true
        states[bookId]?.totalChapters = chapters.count
    }

    // MARK: - Download book (chapters + all hadiths)

    func downloadBook(bookId: Int) async {
        guard !isDownloading(bookId: bookId) else { return }

        // Ensure directory
        let dir = bookDir(bookId: bookId)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        cancelFlags[bookId] = false

        var s = states[bookId] ?? BookDownloadState()
        s.isDownloading  = true
        s.progress       = 0
        s.doneChapters   = 0
        s.currentChapter = "جارٍ تحميل قائمة الأبواب..."
        states[bookId]   = s

        do {
            // 1. Fetch chapter list
            let chapters = try await HadithPortalService.shared.fetchChapters(bookId: bookId)
            guard !chapters.isEmpty else {
                states[bookId]?.isDownloading = false
                return
            }

            // 2. Cache chapter list
            let chapList = PortalChapterList(bookId: bookId, chapters: chapters, fetchedAt: Date())
            if let data = try? JSONEncoder().encode(chapList) {
                try? data.write(to: chaptersFile(bookId: bookId), options: .atomic)
            }

            states[bookId]?.isAvailable   = true
            states[bookId]?.totalChapters = chapters.count

            // 3. Download each chapter's hadiths
            for (idx, chapter) in chapters.enumerated() {
                if cancelFlags[bookId] == true { break }

                states[bookId]?.currentChapter = chapter.nameAr
                states[bookId]?.doneChapters   = idx

                // Skip if already cached
                let destFile = hadithsFile(bookId: bookId, chapterId: chapter.id)
                if FileManager.default.fileExists(atPath: destFile.path) {
                    states[bookId]?.progress = Double(idx + 1) / Double(chapters.count)
                    continue
                }

                if let hadiths = try? await HadithPortalService.shared.fetchHadiths(chapter: chapter) {
                    let list = PortalHadithList(
                        bookId:    bookId,
                        chapterId: chapter.id,
                        hadiths:   hadiths,
                        fetchedAt: Date()
                    )
                    if let data = try? JSONEncoder().encode(list) {
                        try? data.write(to: destFile, options: .atomic)
                    }
                }

                states[bookId]?.progress = Double(idx + 1) / Double(chapters.count)
                // Tiny delay to avoid rate-limiting
                try? await Task.sleep(nanoseconds: 300_000_000)
            }

            states[bookId]?.doneChapters   = chapters.count
            states[bookId]?.chaptersOnly   = false
            states[bookId]?.progress       = 1.0

        } catch {
            // Keep whatever was cached
        }

        states[bookId]?.isDownloading  = false
        states[bookId]?.currentChapter = ""
        cancelFlags[bookId]            = false
    }

    // MARK: - Cancel

    func cancelDownload(bookId: Int) {
        cancelFlags[bookId]              = true
        states[bookId]?.isDownloading    = false
        states[bookId]?.currentChapter   = ""
    }

    // MARK: - Delete

    func deleteBook(bookId: Int) {
        cancelDownload(bookId: bookId)
        try? FileManager.default.removeItem(at: bookDir(bookId: bookId))
        states[bookId] = BookDownloadState()
    }

    // MARK: - Download all books in a category

    func downloadCategory(_ category: PortalCategory) async {
        for book in category.books {
            await downloadBook(bookId: book.id)
        }
    }
}
