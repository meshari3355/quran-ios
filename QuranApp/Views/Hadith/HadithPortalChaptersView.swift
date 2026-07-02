import SwiftUI

// MARK: - HadithPortalChaptersView
// Shows the chapter list for a book.
// Fetches from network if not cached, or uses cached JSON.

struct HadithPortalChaptersView: View {

    let book: PortalBook
    @ObservedObject private var offline = HadithPortalOfflineManager.shared

    @State private var chapters:     [PortalChapter] = []
    @State private var isLoading:    Bool = true
    @State private var errorMessage: String? = nil
    @State private var isDownloading = false

    private var category: PortalCategory? {
        PortalCategory.category(id: book.categoryId)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if isLoading {
                loadingView
            } else if let err = errorMessage {
                errorView(message: err)
            } else {
                chapterList
            }
        }
        .navigationTitle(book.nameAr)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                downloadButton
            }
        }
        .task { await loadChapters() }
    }

    // MARK: - Chapter List

    private var chapterList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // Download progress banner
                if offline.isDownloading(bookId: book.id) {
                    downloadBanner
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                }

                // Chapter cells
                VStack(spacing: 1) {
                    ForEach(Array(chapters.enumerated()), id: \.element.id) { idx, chapter in
                        NavigationLink(destination: HadithPortalBabsView(chapter: chapter, book: book)) {
                            chapterCell(chapter: chapter, index: idx)
                        }
                        .buttonStyle(.plain)

                        if idx < chapters.count - 1 {
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

    private func chapterCell(chapter: PortalChapter, index: Int) -> some View {
        let isCached = offline.loadHadiths(bookId: book.id, chapterId: chapter.id) != nil
        let color    = category?.color ?? Theme.gold

        return HStack(spacing: 12) {
            // Chapter index badge
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Text("\(index + 1)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(color)
            }

            Text(chapter.nameAr)
                .font(.system(size: 14))
                .foregroundColor(Theme.text)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)

            Spacer()

            if isCached {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.gold.opacity(0.6))
            }

            Image(systemName: "chevron.left")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Download Banner

    private var downloadBanner: some View {
        HStack(spacing: 10) {
            ProgressView(value: offline.progress(bookId: book.id))
                .progressViewStyle(.linear)
                .tint(Theme.gold)
                .frame(maxWidth: .infinity)

            Text("\(offline.doneChapters(bookId: book.id))/\(offline.totalChapters(bookId: book.id))")
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
                .monospacedDigit()
        }
        .padding(12)
        .background(Theme.card)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.gold.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Download Button (toolbar)

    private var downloadButton: some View {
        Group {
            if offline.isDownloading(bookId: book.id) {
                Button(action: { offline.cancelDownload(bookId: book.id) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.circle")
                        Text("إيقاف")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.red)
                }
            } else if offline.isAvailable(bookId: book.id) {
                Menu {
                    Button(role: .destructive, action: { offline.deleteBook(bookId: book.id) }) {
                        Label("حذف المحتوى المحفوظ", systemImage: "trash")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("محفوظ")
                            .font(.system(size: 13))
                            .foregroundColor(.green)
                    }
                }
            } else {
                Button(action: startDownload) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                        Text("تحميل")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(Theme.gold)
                }
            }
        }
    }

    // MARK: - Loading / Error

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Theme.gold)
                .scaleEffect(1.3)
            Text("جارٍ تحميل أبواب الكتاب...")
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)
            Text("جارٍ الاتصال، يرجى الانتظار...")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(Theme.gold.opacity(0.7))

            Text("تعذّر تحميل أبواب الكتاب")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Theme.text)

            Text(message)
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Button {
                Task { await loadChapters() }
            } label: {
                Label("إعادة المحاولة", systemImage: "arrow.clockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.background)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(Theme.gold)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Server collection mapping (quran.meshari.tech)

    /// Maps portal book IDs to fast quran.meshari.tech collections.
    private var serverInfo: HadithServerBookInfo? {
        HadithServerBookCatalog.info(forPortalBookId: book.id)
    }

    /// Builds virtual page-chapters (no network needed).
    /// Each covers consecutive server rows, including repeated routes for the same hadith number.
    private func buildServerChapters(info: HadithServerBookInfo) -> [PortalChapter] {
        let pageSize = HadithServerBookCatalog.pageSize
        let total = info.totalRecords
        let pages    = (total + pageSize - 1) / pageSize
        return (1...max(1, pages)).map { page in
            let start = (page - 1) * pageSize + 1
            let end   = min(start + pageSize - 1, total)
            return PortalChapter(
                id:        HadithServerBookCatalog.virtualChapterId(bookId: book.id, page: page),
                bookId:    book.id,
                nameAr:    pages == 1 ? "كامل الكتاب" : "المجموعة \(page) — السجلات \(start) – \(end)",
                urlParams: HadithServerPageRequest(
                    collectionId: info.collectionId,
                    page: page,
                    pageSize: pageSize
                ).urlParams
            )
        }
    }

    // MARK: - Data loading

    private func loadChapters() async {
        isLoading    = true
        errorMessage = nil

        // Server-backed books: fast path, no external dependency
        if let info = serverInfo {
            chapters  = buildServerChapters(info: info)
            isLoading = false
            return
        }

        if let cached = offline.loadChapters(bookId: book.id), !cached.isEmpty {
            chapters  = cached
            isLoading = false
            return
        }

        do {
            let fetched = try await HadithPortalService.shared.fetchChapters(bookId: book.id)
            if fetched.isEmpty {
                errorMessage = "لم يتم العثور على أبواب لهذا الكتاب حالياً."
            } else {
                chapters = fetched
                offline.saveChaptersBrowseCache(fetched, bookId: book.id)
            }
        } catch {
            errorMessage = "تعذّر الاتصال بمصدر الحديث. تحقق من اتصال الإنترنت ثم أعد المحاولة."
        }
        isLoading = false
    }

    private func startDownload() {
        Task { await offline.downloadBook(bookId: book.id) }
    }
}
