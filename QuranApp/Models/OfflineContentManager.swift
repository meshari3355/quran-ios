import Foundation
import SwiftUI

// MARK: - FatwaOfflineManager
// Downloads all 2565 Ibn Baz fatwas and caches to disk for offline use.

@MainActor
final class FatwaOfflineManager: ObservableObject {
    static let shared = FatwaOfflineManager()

    @Published var isDownloading = false
    @Published var progress: Double = 0        // 0.0 – 1.0
    @Published var downloadedCount = 0
    @Published var totalCount = 0

    private let cacheFile: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("fatwas_offline.json")
    }()

    // Returns cached fatwas if available
    var cachedFatwas: [FatwaItem] {
        guard let data = try? Data(contentsOf: cacheFile),
              let fatwas = try? JSONDecoder().decode([FatwaItem].self, from: data) else {
            return []
        }
        return fatwas
    }

    var isAvailableOffline: Bool {
        FileManager.default.fileExists(atPath: cacheFile.path)
    }

    var cachedCount: Int {
        cachedFatwas.count
    }

    func clearCache() {
        try? FileManager.default.removeItem(at: cacheFile)
    }

    func downloadAll() async {
        guard !isDownloading else { return }
        isDownloading = true
        progress = 0
        downloadedCount = 0

        do {
            // 1. Get total count first
            let firstPage = try await FatwaService.shared.fetchList(page: 1, perPage: 50)
            totalCount = firstPage.total ?? 2565
            let totalPages = firstPage.totalPages ?? Int(ceil(Double(totalCount) / 50.0))

            var all: [FatwaItem] = []
            var seenTitles: Set<String> = []

            // Dedup helper
            func addUnique(_ items: [FatwaItem]) {
                for item in items {
                    if !seenTitles.contains(item.title) {
                        seenTitles.insert(item.title)
                        all.append(item)
                    }
                }
            }

            addUnique(firstPage.data)
            downloadedCount = all.count
            progress = Double(1) / Double(totalPages)

            // 2. Fetch remaining pages sequentially, deduplicating on-the-fly
            for page in 2...totalPages {
                if let resp = try? await FatwaService.shared.fetchList(page: page, perPage: 50) {
                    addUnique(resp.data)
                    downloadedCount = all.count
                    progress = Double(page) / Double(totalPages)
                }
                // Tiny delay to avoid rate-limiting
                try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms
            }

            // 3. Save only unique fatwas to disk
            let data = try JSONEncoder().encode(all)
            try data.write(to: cacheFile, options: .atomic)
            downloadedCount = all.count
            progress = 1.0

        } catch {
            // Partial save if possible
        }

        isDownloading = false
    }
}

// MARK: - TafsirOfflineManager
// Downloads a complete tafsir book and caches to disk.

struct TafsirVerseCache: Codable {
    let surah: Int
    let ayah: Int
    let text: String
}

@MainActor
final class TafsirOfflineManager: ObservableObject {
    static let shared = TafsirOfflineManager()

    @Published var downloadingBooks: Set<String> = []
    @Published var bookProgress: [String: Double] = [:]

    private func cacheFile(for tafsirId: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("tafsir_\(tafsirId)_offline.json")
    }

    func isAvailableOffline(tafsirId: String) -> Bool {
        FileManager.default.fileExists(atPath: cacheFile(for: tafsirId).path)
    }

    func cachedVerses(tafsirId: String) -> [TafsirVerseCache] {
        guard let data = try? Data(contentsOf: cacheFile(for: tafsirId)),
              let verses = try? JSONDecoder().decode([TafsirVerseCache].self, from: data) else {
            return []
        }
        return verses
    }

    func cachedVerse(tafsirId: String, surah: Int, ayah: Int) -> String? {
        cachedVerses(tafsirId: tafsirId).first(where: { $0.surah == surah && $0.ayah == ayah })?.text
    }

    func clearCache(tafsirId: String) {
        try? FileManager.default.removeItem(at: cacheFile(for: tafsirId))
    }

    func download(tafsirId: String) async {
        guard !downloadingBooks.contains(tafsirId) else { return }
        downloadingBooks.insert(tafsirId)
        bookProgress[tafsirId] = 0

        let base = "https://quran.meshari.tech/api/tafsir.php"
        var all: [TafsirVerseCache] = []
        let totalSurahs = 114

        // Download sura by sura
        for surah in 1...totalSurahs {
            let urlStr = "\(base)?action=sura&sura=\(surah)&tafsir=\(tafsirId)"
            guard let url = URL(string: urlStr) else { continue }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let json = try? JSONDecoder().decode(TafsirSuraResponse.self, from: data),
                   json.success {
                    for v in json.data {
                        all.append(TafsirVerseCache(surah: surah,
                                                     ayah: v.verse_number,
                                                     text: v.text))
                    }
                }
            } catch {}

            bookProgress[tafsirId] = Double(surah) / Double(totalSurahs)
        }

        // Save to disk
        if let data = try? JSONEncoder().encode(all) {
            try? data.write(to: cacheFile(for: tafsirId), options: .atomic)
        }

        downloadingBooks.remove(tafsirId)
        bookProgress[tafsirId] = 1.0
    }
}

// Helper response model for tafsir sura
private struct TafsirSuraResponse: Codable {
    let success: Bool
    let data: [TafsirSuraVerse]
}
private struct TafsirSuraVerse: Codable {
    let verse_number: Int
    let text: String
}

// MARK: - OfflineDownloadButton (reusable UI component)

struct OfflineDownloadButton: View {
    let title: String
    let icon: String
    let color: Color
    let isOffline: Bool
    let isDownloading: Bool
    let progress: Double        // 0.0-1.0
    let cachedCount: Int?
    let totalCount: Int?
    let onDownload: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: statusIcon)
                        .font(.system(size: 17))
                        .foregroundColor(statusColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.text)
                    Text(statusLabel)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                if isDownloading {
                    ProgressView()
                        .scaleEffect(0.85)
                } else if isOffline {
                    Button(role: .destructive) {
                        onClear()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: onDownload) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 15))
                            Text("تحميل")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(color)
                        .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)

            if isDownloading {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Theme.border)
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color)
                            .frame(width: geo.size.width * CGFloat(min(progress, 1.0)), height: 4)
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
        }
        .background(Theme.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    private var statusIcon: String {
        if isDownloading { return icon }
        if isOffline     { return "checkmark.circle.fill" }
        return icon
    }

    private var statusColor: Color {
        if isOffline { return .green }
        return color
    }

    private var statusLabel: String {
        if isDownloading {
            let pct = Int(progress * 100)
            if let c = cachedCount, let t = totalCount {
                return "جارٍ التحميل... \(c)/\(t) (\(pct)%)"
            }
            return "جارٍ التحميل... \(pct)%"
        }
        if isOffline {
            if let c = cachedCount { return "متاح دون إنترنت — \(c) عنصر" }
            return "متاح دون إنترنت"
        }
        return "اضغط للتحميل وتفعيل الاستخدام دون إنترنت"
    }
}
