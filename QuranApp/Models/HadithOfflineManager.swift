import Foundation

// MARK: - HadithOfflineManager
//
// Downloads complete hadith collections from quran.meshari.tech and caches to disk.
// Cache path: Documents/hadith_offline/{collectionId}.json

@MainActor
final class HadithOfflineManager: ObservableObject {

    static let shared = HadithOfflineManager()
    private init() { Task { await loadStatesAsync() } }

    // MARK: - Collection definitions

    struct HadithCollection: Identifiable {
        let id: String          // server collection id
        let nameAr: String
        let icon: String
        let color: String       // used in SwiftUI as identifier
        let estimatedCount: Int
    }

    nonisolated static let allCollections: [HadithCollection] = [
        HadithCollection(id: "bukhari",  nameAr: "صحيح البخاري",   icon: "scroll.fill",          color: "purple", estimatedCount: 7563),
        HadithCollection(id: "muslim",   nameAr: "صحيح مسلم",      icon: "book.closed.fill",      color: "green",  estimatedCount: 7453),
        HadithCollection(id: "abudawud", nameAr: "سنن أبي داود",   icon: "books.vertical.fill",   color: "brown",  estimatedCount: 5274),
        HadithCollection(id: "tirmidhi", nameAr: "جامع الترمذي",   icon: "book.fill",             color: "teal",   estimatedCount: 3956),
        HadithCollection(id: "nasai",    nameAr: "سنن النسائي",    icon: "doc.text.fill",         color: "indigo", estimatedCount: 5761),
        HadithCollection(id: "ibnmajah", nameAr: "سنن ابن ماجه",  icon: "text.book.closed.fill",  color: "orange", estimatedCount: 4341),
    ]

    // MARK: - State per collection

    struct CollectionState {
        var isDownloading:  Bool   = false
        var progress:       Double = 0
        var downloadedCount: Int   = 0
        var totalCount:     Int    = 0
        var isAvailable:    Bool   = false
    }

    @Published var states: [String: CollectionState] = [:]

    // MARK: - Helpers

    var allComplete: Bool {
        Self.allCollections.allSatisfy { states[$0.id]?.isAvailable ?? false }
    }

    func isAvailable(_ id: String) -> Bool     { states[id]?.isAvailable ?? false }
    func isDownloading(_ id: String) -> Bool   { states[id]?.isDownloading ?? false }
    func progress(_ id: String) -> Double       { states[id]?.progress ?? 0 }
    func downloadedCount(_ id: String) -> Int   { states[id]?.downloadedCount ?? 0 }
    func totalCount(_ id: String) -> Int        { states[id]?.totalCount ?? 0 }

    // MARK: - Cache file

    private func cacheFile(for id: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("hadith_offline/\(id).json")
    }

    /// Loads cached collection states off the main thread to avoid blocking the UI on launch.
    private func loadStatesAsync() async {
        let computed = await Task.detached(priority: .utility) {
            var result: [String: CollectionState] = [:]
            for col in HadithOfflineManager.allCollections {
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let url  = docs.appendingPathComponent("hadith_offline/\(col.id).json")
                var s    = CollectionState()
                if FileManager.default.fileExists(atPath: url.path),
                   let data = try? Data(contentsOf: url),
                   let arr  = try? JSONDecoder().decode([ServerHadith].self, from: data) {
                    s.isAvailable     = true
                    s.downloadedCount = arr.count
                    s.totalCount      = arr.count
                    s.progress        = 1.0
                }
                result[col.id] = s
            }
            return result
        }.value
        // Back on MainActor — publish the result
        self.states = computed
    }

    // MARK: - Download

    func download(collectionId: String) async {
        guard !isDownloading(collectionId) else { return }

        // Ensure directory
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("hadith_offline", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var s = states[collectionId] ?? CollectionState()
        s.isDownloading  = true
        s.progress       = 0
        s.downloadedCount = 0
        s.totalCount     = 0
        states[collectionId] = s

        do {
            // 1. Get first page to learn total
            let firstPage = try await HadithServerService.shared.fetchList(
                collection: collectionId, page: 1, pageSize: 100)
            let total      = firstPage.total ?? 5000
            let totalPages = firstPage.pages ?? Int(ceil(Double(total) / 100.0))

            states[collectionId]?.totalCount = total

            var all: [ServerHadith] = firstPage.data
            states[collectionId]?.downloadedCount = all.count
            states[collectionId]?.progress = totalPages > 1 ? Double(1) / Double(totalPages) : 1.0

            // 2. Fetch remaining pages (3 at a time)
            var page = 2
            while page <= totalPages {
                // Check if cancelled
                guard isDownloading(collectionId) else { return }

                let batchEnd = min(page + 2, totalPages)
                await withTaskGroup(of: [ServerHadith].self) { group in
                    for p in page...batchEnd {
                        group.addTask {
                            (try? await HadithServerService.shared.fetchList(
                                collection: collectionId, page: p, pageSize: 100))?.data ?? []
                        }
                    }
                    for await results in group {
                        all.append(contentsOf: results)
                    }
                }
                states[collectionId]?.downloadedCount = all.count
                states[collectionId]?.progress = Double(batchEnd) / Double(totalPages)
                page = batchEnd + 1
            }

            // 3. Save to disk
            let data = try JSONEncoder().encode(all)
            try data.write(to: cacheFile(for: collectionId), options: .atomic)

            states[collectionId]?.isAvailable     = true
            states[collectionId]?.downloadedCount = all.count
            states[collectionId]?.totalCount      = all.count
            states[collectionId]?.progress        = 1.0

        } catch {
            // partial — keep what we have
        }

        states[collectionId]?.isDownloading = false
    }

    // MARK: - Clear

    func clearCache(collectionId: String) {
        try? FileManager.default.removeItem(at: cacheFile(for: collectionId))
        states[collectionId] = CollectionState()
    }

    // MARK: - Read cached hadiths

    func cachedHadiths(collectionId: String) -> [ServerHadith] {
        guard let data = try? Data(contentsOf: cacheFile(for: collectionId)),
              let arr  = try? JSONDecoder().decode([ServerHadith].self, from: data) else { return [] }
        return arr
    }
}
