import Foundation
import Combine

// MARK: - AudioOfflineCacheManager
//
// Downloads all 6236 Quran ayah audio files for the default reciter
// (Maher Al-Muaiqly 128kbps) from everyayah.com and stores them locally.
//
// Cache path: Documents/audio_cache/{folder}/{surah:3d}{ayah:3d}.mp3
// e.g.:       Documents/audio_cache/Maher_Al_Muaiqly_128kbps/001001.mp3

final class AudioOfflineCacheManager: ObservableObject {

    static let shared = AudioOfflineCacheManager()

    // ── Published state ──────────────────────────────────────────
    @Published var downloadedFiles: Int  = 0
    @Published var isDownloading:   Bool = false

    /// The reciter folder being cached (matches Reciter.cdnId)
    let defaultFolder = "Maher_Al_Muaiqly_128kbps"

    let totalFiles = 6236   // total ayahs in the Quran

    var progress: Double { Double(downloadedFiles) / Double(totalFiles) }
    var isComplete: Bool  { downloadedFiles >= totalFiles }

    // ── Surah ayah counts (Hafs recitation, 114 surahs) ─────────
    static let surahAyahCounts: [Int] = [
        7,  286, 200, 176, 120, 165, 206, 75,  129, 109,  // 1-10
        123, 111, 43,  52,  99,  128, 111, 110, 98,  135, // 11-20
        112, 78,  118, 64,  77,  227, 93,  88,  69,  60,  // 21-30
        34,  30,  73,  54,  45,  83,  182, 88,  75,  85,  // 31-40
        54,  53,  89,  59,  37,  35,  38,  29,  18,  45,  // 41-50
        60,  49,  62,  55,  78,  96,  29,  22,  24,  13,  // 51-60
        14,  11,  11,  18,  12,  12,  30,  52,  52,  44,  // 61-70
        28,  28,  20,  56,  40,  31,  50,  40,  46,  42,  // 71-80
        29,  19,  36,  25,  22,  17,  19,  26,  30,  20,  // 81-90
        15,  21,  11,  8,   8,   19,  5,   8,   8,   11,  // 91-100
        11,  8,   3,   9,   5,   4,   7,   3,   6,   3,   // 101-110
        5,   4,   5,   6,   5,   3,   4,   5,   3,   5,   // 111-120 (only 114 used)
        3,   3,   3,   3                                   // 111-114
    ]

    // ── Internal ─────────────────────────────────────────────────
    private let cacheRoot: URL
    private let concurrentSlots = 8
    private var activeCount     = 0
    private var queue:    [(surah: Int, ayah: Int)] = []
    private var queueIdx  = 0
    private var completed = 0

    // MARK: - Init

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheRoot = docs.appendingPathComponent("audio_cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheRoot, withIntermediateDirectories: true)

        // Count existing files for default folder
        let folderURL = cacheRoot.appendingPathComponent(defaultFolder)
        let count = (try? FileManager.default.contentsOfDirectory(atPath: folderURL.path))?.count ?? 0
        downloadedFiles = min(count, totalFiles)
    }

    // MARK: - Disk

    /// Local file URL if cached, nil otherwise.
    func cachedURL(surah: Int, ayah: Int, folder: String) -> URL? {
        let url = fileURL(surah: surah, ayah: ayah, folder: folder)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func hasFile(surah: Int, ayah: Int, folder: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(surah: surah, ayah: ayah, folder: folder).path)
    }

    private func fileURL(surah: Int, ayah: Int, folder: String) -> URL {
        let name = String(format: "%03d%03d.mp3", surah, ayah)
        return cacheRoot.appendingPathComponent(folder).appendingPathComponent(name)
    }

    // MARK: - Full download

    /// Start downloading all ayahs for the default reciter. Safe to call multiple times.
    func startFullDownloadIfNeeded() {
        guard !isComplete, !isDownloading else { return }

        // Build download queue (skip already downloaded)
        var pending: [(surah: Int, ayah: Int)] = []
        for (idx, count) in Self.surahAyahCounts.prefix(114).enumerated() {
            let surah = idx + 1
            for ayah in 1...count {
                if !hasFile(surah: surah, ayah: ayah, folder: defaultFolder) {
                    pending.append((surah, ayah))
                }
            }
        }

        guard !pending.isEmpty else {
            DispatchQueue.main.async { self.downloadedFiles = self.totalFiles }
            return
        }

        // Ensure folder exists
        let folderURL = cacheRoot.appendingPathComponent(defaultFolder)
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        DispatchQueue.main.async { self.isDownloading = true }
        queue     = pending
        queueIdx  = 0
        completed = downloadedFiles  // already on disk
        activeCount = 0
        spawnSlots()
    }

    private func spawnSlots() {
        while activeCount < concurrentSlots, queueIdx < queue.count {
            let item = queue[queueIdx]; queueIdx += 1
            activeCount += 1
            downloadFile(surah: item.surah, ayah: item.ayah)
        }
    }

    private func downloadFile(surah: Int, ayah: Int) {
        let fileName = String(format: "%03d%03d.mp3", surah, ayah)
        let urlStr   = "https://everyayah.com/data/\(defaultFolder)/\(fileName)"
        guard let url = URL(string: urlStr) else { finish(success: false); return }

        let dest = cacheRoot.appendingPathComponent(defaultFolder).appendingPathComponent(fileName)

        URLSession.shared.dataTask(with: url) { [weak self] data, response, _ in
            guard let self else { return }
            if let data, !data.isEmpty {
                try? data.write(to: dest)
            }
            self.finish(success: data != nil && !(data?.isEmpty ?? true))
        }.resume()
    }

    private func finish(success: Bool) {
        DispatchQueue.main.async {
            self.activeCount -= 1
            self.completed   += 1
            self.downloadedFiles = self.completed
            self.spawnSlots()
            if self.completed >= self.totalFiles {
                self.isDownloading   = false
                self.downloadedFiles = self.totalFiles
            }
        }
    }

    // MARK: - Cancel

    func cancel() {
        DispatchQueue.main.async {
            self.isDownloading = false
            self.queue = []
            self.queueIdx = 0
        }
    }
}
