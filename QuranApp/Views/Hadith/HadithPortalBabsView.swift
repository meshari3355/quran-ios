import SwiftUI

// MARK: - HadithPortalBabsView
// Shows either:
//   A) A list of babs (أبواب) if the chapter has sub-chapters → navigates to HadithPortalHadithsView
//   B) The hadiths directly (inline) if the chapter has no sub-babs
//
// Uses a SINGLE network request via fetchChapterContent — avoids the previous
// double-request pattern that caused two consecutive timeouts.

struct HadithPortalBabsView: View {

    let chapter: PortalChapter
    let book:    PortalBook

    @ObservedObject private var offline = HadithPortalOfflineManager.shared

    @State private var babs:         [PortalChapter] = []
    @State private var hadiths:      [PortalHadith]  = []
    @State private var isLoading:    Bool = true
    @State private var errorMessage: String? = nil

    private var color: Color {
        PortalCategory.category(id: book.categoryId)?.color ?? Theme.gold
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if isLoading {
                loadingView
            } else if let err = errorMessage {
                errorView(message: err)
            } else if !babs.isEmpty {
                babList
            } else if !hadiths.isEmpty {
                hadithList
            } else {
                emptyView
            }
        }
        .navigationTitle(chapter.nameAr.isEmpty ? book.nameAr : chapter.nameAr)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadContent() }
    }

    // MARK: - Bab List

    private var babList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                VStack(spacing: 1) {
                    ForEach(Array(babs.enumerated()), id: \.element.id) { idx, bab in
                        NavigationLink(destination: HadithPortalHadithsView(chapter: bab, book: book)) {
                            babCell(bab: bab, index: idx)
                        }
                        .buttonStyle(.plain)

                        if idx < babs.count - 1 {
                            Divider().background(Theme.border).padding(.leading, 52)
                        }
                    }
                }
                .background(Theme.card)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.top, 10)

                Spacer(minLength: 40)
            }
        }
    }

    private func babCell(bab: PortalChapter, index: Int) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Text("\(index + 1)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(color)
            }

            Text(bab.nameAr)
                .font(.system(size: 14))
                .foregroundColor(Theme.text)
                .multilineTextAlignment(.trailing)
                .lineLimit(3)

            Spacer()

            Image(systemName: "chevron.left")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Inline Hadith List (no sub-babs case)

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
                        .foregroundColor(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(color.opacity(0.12))
                        .cornerRadius(6)
                }
            }

            Text(hadith.text.prefix(220) + (hadith.text.count > 220 ? "..." : ""))
                .font(.system(size: 15))
                .foregroundColor(Theme.text)
                .multilineTextAlignment(.trailing)
                .lineSpacing(5)
                .environment(\.layoutDirection, .rightToLeft)

            HStack {
                Spacer()
                Text("قراءة كاملاً")
                    .font(.system(size: 12))
                    .foregroundColor(color)
                Image(systemName: "chevron.left")
                    .font(.system(size: 10))
                    .foregroundColor(color)
            }
        }
        .padding(14)
        .background(Theme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Empty

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

    // MARK: - Loading / Error

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Theme.gold)
                .scaleEffect(1.3)
            Text("جارٍ تحميل الأبواب...")
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)
            Text("قد يستغرق الاتصال لحظات...")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary.opacity(0.6))
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 40))
                .foregroundColor(Theme.textSecondary)
            Text("تعذّر الاتصال بالخادم")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.text)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button(action: { Task { await loadContent() } }) {
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

    // MARK: - Data Loading

    private func loadContent() async {
        isLoading    = true
        errorMessage = nil
        babs         = []
        hadiths      = []

        // All chapters use the server — urlParams encoded as "server:{collectionId}:{start}:{end}"
        if chapter.urlParams.hasPrefix("server:") {
            await loadFromServer()
            return
        }

        await loadFromHadithPortal()
    }

    private func loadFromHadithPortal() async {
        if let cachedBabs = offline.loadBabs(bookId: book.id, chapterId: chapter.id), !cachedBabs.isEmpty {
            babs = cachedBabs
            isLoading = false
            return
        }

        if let cachedHadiths = offline.loadHadiths(bookId: book.id, chapterId: chapter.id), !cachedHadiths.isEmpty {
            hadiths = cachedHadiths
            isLoading = false
            return
        }

        do {
            let content = try await HadithPortalService.shared.fetchChapterContent(
                chapterUrlParams: chapter.urlParams,
                bookId: book.id,
                chapter: chapter
            )

            if !content.babs.isEmpty {
                babs = content.babs
                offline.saveBabsBrowseCache(content.babs, bookId: book.id, chapterId: chapter.id)
            } else if !content.hadiths.isEmpty {
                hadiths = content.hadiths
                offline.saveHadithsBrowseCache(content.hadiths, bookId: book.id, chapterId: chapter.id)
            }
            isLoading = false
        } catch {
            errorMessage = "تعذّر تحميل بيانات الباب. تحقق من اتصال الإنترنت ثم أعد المحاولة."
            isLoading = false
        }
    }

    /// Fetches hadiths from quran.meshari.tech using the "server:" URL scheme.
    /// All hadith requests fire concurrently for maximum speed.
    private func loadFromServer() async {
        // Parse "server:{collectionId}:{start}:{end}"
        let parts = chapter.urlParams.split(separator: ":").map(String.init)
        guard parts.count == 4,
              let start = Int(parts[2]),
              let end   = Int(parts[3]) else {
            errorMessage = "خطأ في بيانات الفصل"
            isLoading    = false
            return
        }
        let collectionId = parts[1]
        let numbers      = Array(start...end)

        // Capture plain value types before entering @Sendable task closures
        let capturedBookId    = book.id
        let capturedChapterId = chapter.id
        let capturedBookName  = book.nameAr

        var result: [(Int, PortalHadith)] = []

        // Fire ALL requests concurrently — collect as they complete
        await withTaskGroup(of: (Int, PortalHadith?).self) { group in
            for num in numbers {
                group.addTask {
                    guard let h = try? await HadithServerService.shared.fetchHadith(
                        collection: collectionId, number: num
                    ), !h.fullTextAr.isEmpty else { return (num, nil) }
                    let portal = PortalHadith(
                        id:        num,
                        bookId:    capturedBookId,
                        chapterId: capturedChapterId,
                        number:    "\(h.hadith_number ?? num)",
                        text:      h.fullTextAr,
                        bookName:  capturedBookName
                    )
                    return (num, portal)
                }
            }
            for await (num, portal) in group {
                if let p = portal { result.append((num, p)) }
            }
        }

        hadiths   = result.sorted { $0.0 < $1.0 }.map(\.1)
        isLoading = false
    }
}
