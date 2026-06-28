import Foundation
import Combine

// MARK: - ReciterOfflineCacheManager
//
// Downloads all 6236 Quran ayah audio files for ANY reciter from everyayah.com.
// Cache path: Documents/audio_cache/{cdnId}/{surah:3d}{ayah:3d}.mp3
// Compatible with AudioOfflineCacheManager path structure.

@MainActor
final class ReciterOfflineCacheManager: ObservableObject {

    static let shared = ReciterOfflineCacheManager()

    // MARK: - Published state per reciter (keyed by cdnId)

    @Published var downloadedFiles: [String: Int]  = [:]
    @Published var isDownloading:   [String: Bool] = [:]

    let totalFiles = 6236

    // MARK: - Active download queues (nonisolated for background work)

    private var queues:      [String: [(surah: Int, ayah: Int)]] = [:]
    private var queueIdxs:   [String: Int] = [:]
    private var completed:   [String: Int] = [:]
    private var activeCounts:[String: Int] = [:]
    private let concurrentSlots = 6
    private let cacheRoot: URL

    // MARK: - Init

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheRoot = docs.appendingPathComponent("audio_cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheRoot, withIntermediateDirectories: true)
        // Pre-scan existing downloads for each reciter
        scanExisting()
    }

    private func scanExisting() {
        guard let folders = try? FileManager.default.contentsOfDirectory(atPath: cacheRoot.path) else { return }
        for folder in folders {
            let count = (try? FileManager.default.contentsOfDirectory(
                atPath: cacheRoot.appendingPathComponent(folder).path))?.count ?? 0
            downloadedFiles[folder] = min(count, totalFiles)
        }
    }

    // MARK: - Public API

    func isComplete(cdnId: String) -> Bool {
        (downloadedFiles[cdnId] ?? 0) >= totalFiles
    }

    func isActivelyDownloading(cdnId: String) -> Bool {
        isDownloading[cdnId] ?? false
    }

    func progress(cdnId: String) -> Double {
        Double(downloadedFiles[cdnId] ?? 0) / Double(totalFiles)
    }

    func downloaded(cdnId: String) -> Int {
        downloadedFiles[cdnId] ?? 0
    }

    // MARK: - Start download

    func startDownload(cdnId: String) {
        guard !isComplete(cdnId: cdnId), !(isDownloading[cdnId] ?? false) else { return }

        // Build pending list
        var pending: [(surah: Int, ayah: Int)] = []
        for (idx, count) in AudioOfflineCacheManager.surahAyahCounts.prefix(114).enumerated() {
            let surah = idx + 1
            for ayah in 1...count {
                if !hasFile(surah: surah, ayah: ayah, cdnId: cdnId) {
                    pending.append((surah, ayah))
                }
            }
        }

        guard !pending.isEmpty else {
            downloadedFiles[cdnId] = totalFiles
            return
        }

        // Ensure folder exists
        let folderURL = cacheRoot.appendingPathComponent(cdnId)
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        isDownloading[cdnId]  = true
        queues[cdnId]         = pending
        queueIdxs[cdnId]      = 0
        completed[cdnId]      = downloadedFiles[cdnId] ?? 0
        activeCounts[cdnId]   = 0
        spawnSlots(cdnId: cdnId)
    }

    // MARK: - Cancel

    func cancel(cdnId: String) {
        isDownloading[cdnId] = false
        queues[cdnId]        = []
        queueIdxs[cdnId]     = 0
    }

    // MARK: - Delete

    func delete(cdnId: String) {
        cancel(cdnId: cdnId)
        try? FileManager.default.removeItem(at: cacheRoot.appendingPathComponent(cdnId))
        downloadedFiles[cdnId] = 0
    }

    // MARK: - Private

    private func hasFile(surah: Int, ayah: Int, cdnId: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(surah: surah, ayah: ayah, cdnId: cdnId).path)
    }

    private func fileURL(surah: Int, ayah: Int, cdnId: String) -> URL {
        let name = String(format: "%03d%03d.mp3", surah, ayah)
        return cacheRoot.appendingPathComponent(cdnId).appendingPathComponent(name)
    }

    private func spawnSlots(cdnId: String) {
        while (activeCounts[cdnId] ?? 0) < concurrentSlots,
              let idx  = queueIdxs[cdnId],
              let queue = queues[cdnId],
              idx < queue.count {
            let item = queue[idx]
            queueIdxs[cdnId] = idx + 1
            activeCounts[cdnId] = (activeCounts[cdnId] ?? 0) + 1
            downloadFileBackground(surah: item.surah, ayah: item.ayah, cdnId: cdnId)
        }
    }

    private func downloadFileBackground(surah: Int, ayah: Int, cdnId: String) {
        let fileName = String(format: "%03d%03d.mp3", surah, ayah)
        let urlStr   = "https://everyayah.com/data/\(cdnId)/\(fileName)"
        guard let url = URL(string: urlStr) else {
            Task { @MainActor in self.finishOne(cdnId: cdnId, success: false) }
            return
        }
        let dest = fileURL(surah: surah, ayah: ayah, cdnId: cdnId)
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            if let data, !data.isEmpty { try? data.write(to: dest) }
            Task { @MainActor [weak self] in
                self?.finishOne(cdnId: cdnId, success: data != nil && !(data?.isEmpty ?? true))
            }
        }.resume()
    }

    private func finishOne(cdnId: String, success: Bool) {
        guard isDownloading[cdnId] == true else { return }
        activeCounts[cdnId] = max(0, (activeCounts[cdnId] ?? 1) - 1)
        completed[cdnId]    = (completed[cdnId] ?? 0) + 1
        downloadedFiles[cdnId] = completed[cdnId] ?? 0

        let total   = queues[cdnId]?.count ?? 0
        let done    = completed[cdnId] ?? 0
        let initial = (downloadedFiles[cdnId] ?? 0) - done

        if done >= total {
            isDownloading[cdnId]   = false
            downloadedFiles[cdnId] = min((initial + done), totalFiles)
        } else {
            spawnSlots(cdnId: cdnId)
        }
    }
}
