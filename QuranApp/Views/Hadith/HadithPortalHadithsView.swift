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
        let serverRequest = HadithServerPageRequest.parse(chapter.urlParams)

        // 1. Offline cache (fastest)
        if serverRequest == nil,
           let cached = offline.loadHadiths(bookId: book.id, chapterId: chapter.id), !cached.isEmpty {
            hadiths   = cached
            isLoading = false
            return
        }

        if serverRequest == nil {
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

        if await loadServerPageIfNeeded() {
            return
        }

        errorMessage = "تعذّر تحميل الأحاديث."
        isLoading = false
    }

    private func loadServerPageIfNeeded() async -> Bool {
        guard let request = HadithServerPageRequest.parse(chapter.urlParams) else { return false }

        do {
            let page = try await HadithServerService.shared.fetchList(
                collection: request.collectionId,
                page: request.page,
                pageSize: request.pageSize
            )

            let fetched = page.data.compactMap { h -> PortalHadith? in
                let text = h.fullTextAr.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }
                return PortalHadith(
                    id: h.id,
                    bookId: book.id,
                    chapterId: chapter.id,
                    number: "\(h.hadith_number ?? h.id)",
                    text: text,
                    bookName: book.nameAr
                )
            }

            hadiths = fetched
            offline.saveHadithsBrowseCache(fetched, bookId: book.id, chapterId: chapter.id)
            isLoading = false
            return true
        } catch {
            errorMessage = "تعذّر تحميل الأحاديث. تأكد من الاتصال بالإنترنت."
            isLoading = false
            return true
        }
    }
}
