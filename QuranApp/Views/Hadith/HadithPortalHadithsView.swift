import SwiftUI

// MARK: - HadithPortalHadithsView
// Shows hadiths within a chapter. Fetches from:
//   1. Offline cache (Documents/hadith_portal/{bookId}/{chapterId}.json)
//   2. quran.meshari.tech API

struct HadithPortalHadithsView: View {

    let chapter: PortalChapter
    let book:    PortalBook

    @ObservedObject private var offline = HadithPortalOfflineManager.shared

    @State private var hadiths:      [PortalHadith] = []
    @State private var isLoading:    Bool = true
    @State private var errorMessage: String? = nil

    // ربط كل كتاب بـ collection_id على السيرفر
    // يدعم الآن 14 collections
    private var serverCollectionId: String? {
        switch book.id {
        // ── الكتب الستة ──
        case 33: return "bukhari"         // صحيح البخاري
        case 31: return "muslim"          // صحيح مسلم
        case 26: return "abudawud"        // سنن أبي داود
        case 38: return "tirmidhi"        // جامع الترمذي
        case 25: return "nasai"           // سنن النسائي
        case 27: return "ibnmajah"        // سنن ابن ماجه
        // ── Collections إضافية ──
        case 30: return "malik"           // موطأ الإمام مالك
        case 32: return "darimi"          // سنن الدارمي
        case 1:  return "ahmad"           // مسند الإمام أحمد
        case 76: return "nawawi40"        // الأربعون النووية
        // ── sunnah.com ──
        case 756: return "riyadussalihin" // رياض الصالحين
        case 55:  return "adab"           // الأدب المفرد
        case 131: return "shamail"        // الشمائل المحمدية
        case 200: return "bulugh"         // بلوغ المرام
        default: return nil
        }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if isLoading {
                loadingView
            } else if let err = errorMessage {
                errorView(message: err)
            } else if hadiths.isEmpty {
                emptyView
            } else {
                hadithList
            }
        }
        .navigationTitle(chapter.nameAr.isEmpty ? book.nameAr : chapter.nameAr)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadHadiths() }
    }

    // MARK: - Hadith List

    private var hadithList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(hadiths) { hadith in
                    NavigationLink(destination: HadithPortalDetailView(hadith: hadith, book: book)) {
                        hadithCard(hadith)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func hadithCard(_ hadith: PortalHadith) -> some View {
        VStack(alignment: .trailing, spacing: 10) {
            // Header: number + source
            HStack {
                Spacer()
                HStack(spacing: 8) {
                    Text(book.nameAr)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                    Text("·")
                        .foregroundColor(Theme.border)
                    Text(hadith.number)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.gold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.gold.opacity(0.12))
                        .cornerRadius(6)
                }
            }

            // Hadith text (first 200 chars)
            Text(hadith.text.prefix(220) + (hadith.text.count > 220 ? "..." : ""))
                .font(.system(size: 15))
                .foregroundColor(Theme.text)
                .multilineTextAlignment(.trailing)
                .lineSpacing(5)
                .environment(\.layoutDirection, .rightToLeft)

            // Read more
            HStack {
                Spacer()
                Text("قراءة كاملاً")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.gold)
                Image(systemName: "chevron.left")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.gold)
            }
        }
        .padding(14)
        .background(Theme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Loading / Error / Empty

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView().progressViewStyle(.circular).tint(Theme.gold).scaleEffect(1.2)
            Text("جارٍ تحميل الأحاديث...")
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 40))
                .foregroundColor(Theme.textSecondary)
            Text("تعذّر الاتصال")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.text)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button(action: { Task { await loadHadiths() } }) {
                Text("إعادة المحاولة")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.background)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Theme.gold)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(30)
    }

    private var emptyView: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundColor(Theme.textSecondary)
            Text("لا توجد أحاديث في هذا الباب")
                .font(.system(size: 15))
                .foregroundColor(Theme.textSecondary)
        }
    }

    // MARK: - Data loading

    private func loadHadiths() async {
        isLoading    = true
        errorMessage = nil

        // 1. Offline cache (fastest)
        if let cached = offline.loadHadiths(bookId: book.id, chapterId: chapter.id), !cached.isEmpty {
            hadiths   = cached
            isLoading = false
            return
        }

        if !chapter.urlParams.hasPrefix("server:") {
            do {
                let fetched = try await HadithPortalService.shared.fetchHadiths(chapter: chapter)
                hadiths = fetched
                offline.saveHadithsBrowseCache(fetched, bookId: book.id, chapterId: chapter.id)
                isLoading = false
            } catch {
                errorMessage = "تعذّر تحميل أحاديث الباب. تحقق من اتصال الإنترنت ثم أعد المحاولة."
                isLoading = false
            }
            return
        }

        if await loadServerRangeIfNeeded() {
            return
        }

        // 2. Server API (quran.meshari.tech) — الأولوية للسيرفر
        if let collectionId = serverCollectionId {

            // 2a. Locally cached collection
            let localCache = HadithOfflineManager.shared.cachedHadiths(collectionId: collectionId)
            if !localCache.isEmpty {
                hadiths = localCache.enumerated().map { idx, h in
                    PortalHadith(
                        id: idx + 1,
                        bookId: book.id,
                        chapterId: chapter.id,
                        number: h.hadith_number.map { "\($0)" } ?? "\(idx + 1)",
                        text: h.fullTextAr,
                        bookName: book.nameAr
                    )
                }
                isLoading = false
                return
            }

            // 2b. Live fetch from server list endpoint
            do {
                let page = try await HadithServerService.shared.fetchList(
                    collection: collectionId,
                    page: 1,
                    pageSize: 100
                )
                if !page.data.isEmpty {
                    hadiths = page.data.enumerated().map { idx, h in
                        PortalHadith(
                            id: idx + 1,
                            bookId: book.id,
                            chapterId: chapter.id,
                            number: h.hadith_number.map { "\($0)" } ?? "\(idx + 1)",
                            text: h.fullTextAr,
                            bookName: book.nameAr
                        )
                    }
                    isLoading = false
                    return
                }
            } catch {
                errorMessage = "تعذّر تحميل الأحاديث. تأكد من الاتصال بالإنترنت."
                isLoading    = false
            }
        } else {
            errorMessage = "تعذّر تحميل الأحاديث."
            isLoading    = false
        }
    }

    private func loadServerRangeIfNeeded() async -> Bool {
        let parts = chapter.urlParams.split(separator: ":").map(String.init)
        guard parts.count == 4,
              let start = Int(parts[2]),
              let end = Int(parts[3]) else { return false }

        let collectionId = parts[1]
        let numbers = Array(start...end)
        let capturedBookId = book.id
        let capturedChapterId = chapter.id
        let capturedBookName = book.nameAr
        var result: [(Int, PortalHadith)] = []

        await withTaskGroup(of: (Int, PortalHadith?).self) { group in
            for num in numbers {
                group.addTask {
                    guard let h = try? await HadithServerService.shared.fetchHadith(
                        collection: collectionId,
                        number: num
                    ), !h.fullTextAr.isEmpty else { return (num, nil) }
                    return (num, PortalHadith(
                        id: num,
                        bookId: capturedBookId,
                        chapterId: capturedChapterId,
                        number: "\(h.hadith_number ?? num)",
                        text: h.fullTextAr,
                        bookName: capturedBookName
                    ))
                }
            }
            for await (num, hadith) in group {
                if let hadith { result.append((num, hadith)) }
            }
        }

        hadiths = result.sorted { $0.0 < $1.0 }.map(\.1)
        offline.saveHadithsBrowseCache(hadiths, bookId: book.id, chapterId: chapter.id)
        isLoading = false
        return true
    }
}
