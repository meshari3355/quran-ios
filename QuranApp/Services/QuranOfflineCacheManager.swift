import Foundation
import Combine

// MARK: - QuranOfflineCacheManager
//
// Downloads all 604 Quran pages from alquran.cloud and stores them as JSON
// in the app's Documents directory so the reader works 100% offline
// after the first complete download.
//
// Cache path: Documents/quran_cache/page_001.json … page_604.json

final class QuranOfflineCacheManager: ObservableObject {

    static let shared = QuranOfflineCacheManager()

    // ── Published state (drive progress UI) ─────────────────────────
    @Published var downloadedPages: Int = 0
    @Published var isDownloading:   Bool = false

    let totalPages = 604

    /// 0.0 – 1.0
    var progress: Double { Double(downloadedPages) / Double(totalPages) }
    var isComplete: Bool { downloadedPages >= totalPages }

    // ── Internal ─────────────────────────────────────────────────────
    let cacheDir: URL   // internal so QuranPageCache can also save there

    private let concurrentSlots = 8          // parallel downloads
    private var activeCount     = 0
    private var nextPage        = 1
    private var completionCount = 0

    // MARK: - Init

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDir = docs.appendingPathComponent("quran_cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir,
                                                  withIntermediateDirectories: true)
        let counted = (1...604).filter { self.hasPage($0) }.count
        downloadedPages = counted
    }

    // MARK: - Disk access

    func hasPage(_ page: Int) -> Bool {
        FileManager.default.fileExists(atPath: filePath(page).path)
    }

    /// Returns raw JSON Data for a page if cached, nil otherwise.
    func cachedData(for page: Int) -> Data? {
        try? Data(contentsOf: filePath(page))
    }

    /// Save raw JSON data returned from network (also used by QuranPageCache).
    func savePage(_ page: Int, data: Data) {
        try? data.write(to: filePath(page))
        DispatchQueue.main.async {
            if self.downloadedPages < page { self.downloadedPages = page }
            // More accurate: count total
        }
    }

    private func filePath(_ page: Int) -> URL {
        cacheDir.appendingPathComponent(String(format: "page_%03d.json", page))
    }

    // MARK: - Full background download

    /// Call once on app launch; does nothing if already complete.
    func startFullDownloadIfNeeded() {
        guard !isComplete, !isDownloading else { return }
        DispatchQueue.main.async { self.isDownloading = true }
        nextPage        = 1
        completionCount = downloadedPages   // already done pages
        activeCount     = 0
        spawnSlots()
    }

    private func spawnSlots() {
        while activeCount < concurrentSlots, nextPage <= totalPages {
            let page = nextPage
            nextPage += 1
            if hasPage(page) {
                // Already on disk — count it and move on
                DispatchQueue.main.async { self.downloadedPages = max(self.downloadedPages, page) }
                completionCount += 1
                checkDone()
                continue
            }
            activeCount += 1
            downloadPage(page)
        }
    }

    private func downloadPage(_ page: Int) {
        guard let url = URL(string:
            "https://api.alquran.cloud/v1/page/\(page)/ar.uthmani") else {
            finish(page: page, success: false); return
        }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self else { return }
            if let data = data {
                try? data.write(to: self.filePath(page))
            }
            self.finish(page: page, success: data != nil)
        }.resume()
    }

    private func finish(page: Int, success: Bool) {
        DispatchQueue.main.async {
            self.activeCount     -= 1
            self.completionCount += 1
            self.downloadedPages  = self.completionCount
            self.spawnSlots()
            self.checkDone()
        }
    }

    private func checkDone() {
        if completionCount >= totalPages {
            isDownloading   = false
            downloadedPages = totalPages
        }
    }

    /// Cancel an in-progress download.
    func cancel() {
        DispatchQueue.main.async {
            self.isDownloading   = false
            self.nextPage        = self.downloadedPages + 1
            self.activeCount     = 0
            self.completionCount = 0
        }
    }
}
