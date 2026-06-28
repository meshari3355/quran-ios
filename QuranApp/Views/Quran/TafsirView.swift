import SwiftUI

struct TafsirEntry: Identifiable {
    let id: Int           // global ayah number (unique key)
    let numberInSurah: Int
    let surahName: String
    let text: String
}

struct TafsirView: View {
    let pageNumber: Int
    let pageAyahs: [AyahData]   // only the ayahs visible on the current page

    @State private var entries: [TafsirEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @Environment(\.dismiss) private var dismiss

    // Unique surahs represented on this page (ordered)
    private var surahsOnPage: [(number: Int, name: String)] {
        var seen = Set<Int>()
        var result: [(Int, String)] = []
        for ayah in pageAyahs {
            if !seen.contains(ayah.surah.number) {
                seen.insert(ayah.surah.number)
                result.append((ayah.surah.number, ayah.surah.name))
            }
        }
        return result
    }

    private var headerSubtitle: String {
        surahsOnPage.map { $0.name }.joined(separator: " • ")
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {

                // ── Header ──────────────────────────────────────
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Theme.gold)
                    }
                    Spacer()
                    VStack(spacing: 3) {
                        Text("تفسير الصفحة \(arabicNumber(pageNumber))")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Theme.goldLight)
                        if !headerSubtitle.isEmpty {
                            Text(headerSubtitle)
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    // balance spacer
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.clear)
                }
                .padding(16)
                .background(Theme.card)

                Divider().background(Theme.border)

                // ── Content ─────────────────────────────────────
                if isLoading {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView().tint(Theme.gold).scaleEffect(1.2)
                        Text("جاري تحميل التفسير...")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                } else if let err = errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 32))
                            .foregroundColor(Theme.textSecondary)
                        Text(err)
                            .font(.system(size: 15))
                            .foregroundColor(Theme.textSecondary)
                        Button(action: { Task { await loadTafsir() } }) {
                            Text("إعادة المحاولة")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.background)
                                .padding(.horizontal, 20).padding(.vertical, 8)
                                .background(Theme.gold).cornerRadius(8)
                        }
                    }
                    Spacer()
                } else if entries.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 32))
                            .foregroundColor(Theme.textSecondary)
                        Text("التفسير غير متاح حالياً")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(entries) { entry in
                                TafsirEntryCard(entry: entry,
                                                showSurahName: surahsOnPage.count > 1)
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
        .task { await loadTafsir() }
    }

    // MARK: - Load

    private func loadTafsir() async {
        isLoading = true
        errorMessage = nil

        guard !pageAyahs.isEmpty else {
            await MainActor.run { isLoading = false }
            return
        }

        // Group page ayahs by surah number
        let surahGroups = Dictionary(grouping: pageAyahs) { $0.surah.number }
        var allEntries: [TafsirEntry] = []

        for (surahNum, surahAyahsOnPage) in surahGroups.sorted(by: { $0.key < $1.key }) {
            guard let url = URL(string: "https://api.alquran.cloud/v1/surah/\(surahNum)/ar.muyassar") else { continue }

            // Which ayah numbers (within surah) appear on this page
            let pageNums  = Set(surahAyahsOnPage.map { $0.numberInSurah })
            let surahName = surahAyahsOnPage.first?.surah.name ?? ""

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let json  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let d     = json["data"] as? [String: Any],
                      let ayahs = d["ayahs"]  as? [[String: Any]] else { continue }

                for ayah in ayahs {
                    guard let text        = ayah["text"]          as? String,
                          let num         = ayah["number"]        as? Int,
                          let numInSurah  = ayah["numberInSurah"] as? Int,
                          pageNums.contains(numInSurah) else { continue }

                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { continue }
                    allEntries.append(TafsirEntry(id: num, numberInSurah: numInSurah,
                                                  surahName: surahName, text: trimmed))
                }
            } catch { }
        }

        await MainActor.run {
            self.entries     = allEntries.sorted { $0.id < $1.id }
            self.isLoading   = false
        }
    }

    private func arabicNumber(_ n: Int) -> String {
        let d = ["٠","١","٢","٣","٤","٥","٦","٧","٨","٩"]
        return String(n).compactMap { d[Int(String($0)) ?? 0] }.joined()
    }
}

// MARK: - Entry Card

struct TafsirEntryCard: View {
    let entry: TafsirEntry
    let showSurahName: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {

            // Badge: surah name (optional) + ayah number
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    if showSurahName {
                        Text(entry.surahName)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                        Text("•").font(.system(size: 10)).foregroundColor(Theme.textSecondary)
                    }
                    Text("الآية \(arabicNumber(entry.numberInSurah))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.gold)
                }
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Theme.gold.opacity(0.13)).cornerRadius(8)
            }

            Divider().background(Theme.border)

            Text(entry.text)
                .font(.system(size: 16))
                .foregroundColor(Theme.text)
                .lineSpacing(7)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(14)
        .background(Theme.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    private func arabicNumber(_ n: Int) -> String {
        let d = ["٠","١","٢","٣","٤","٥","٦","٧","٨","٩"]
        return String(n).compactMap { d[Int(String($0)) ?? 0] }.joined()
    }
}
