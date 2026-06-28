import SwiftUI

// MARK: - HadithPortalBooksView
// Shows all books within a portal category.

struct HadithPortalBooksView: View {

    let category: PortalCategory
    @ObservedObject private var offline = HadithPortalOfflineManager.shared
    @State private var downloadingAll = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {

                    // ── Download all button ───────────────────────────────
                    downloadAllButton
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    // ── Book list ─────────────────────────────────────────
                    VStack(spacing: 1) {
                        ForEach(Array(category.books.enumerated()), id: \.element.id) { idx, book in
                            NavigationLink(destination: HadithPortalChaptersView(book: book)) {
                                bookCell(book: book)
                            }
                            .buttonStyle(.plain)

                            if idx < category.books.count - 1 {
                                Divider().background(Theme.border).padding(.leading, 60)
                            }
                        }
                    }
                    .background(Theme.card)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
                    .padding(.horizontal, 16)

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle(category.nameAr)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Download All Button

    private var downloadAllButton: some View {
        let downloadedCount = category.books.filter { offline.isAvailable(bookId: $0.id) }.count
        let allDone = downloadedCount == category.books.count

        return Button(action: {
            guard !downloadingAll, !allDone else { return }
            downloadingAll = true
            Task {
                await offline.downloadCategory(category)
                downloadingAll = false
            }
        }) {
            HStack(spacing: 10) {
                if downloadingAll {
                    ProgressView().progressViewStyle(.circular).tint(Theme.background).scaleEffect(0.8)
                } else {
                    Image(systemName: allDone ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                        .font(.system(size: 16))
                }
                Text(allDone
                    ? "تم تحميل جميع كتب القسم"
                    : "تحميل جميع كتب \(category.nameAr) (\(downloadedCount)/\(category.books.count))"
                )
                .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(allDone ? .green : Theme.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(allDone ? Theme.card : (downloadingAll ? Theme.gold.opacity(0.7) : Theme.gold))
            .cornerRadius(12)
            .overlay(allDone ? RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.5), lineWidth: 1) : nil)
        }
        .buttonStyle(.plain)
        .disabled(downloadingAll || allDone)
    }

    // MARK: - Book Cell

    private func bookCell(book: PortalBook) -> some View {
        let state = offline.states[book.id]
        let isDownloading = offline.isDownloading(bookId: book.id)
        let isAvailable   = offline.isAvailable(bookId: book.id)
        let progress      = offline.progress(bookId: book.id)

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(category.color.opacity(0.14))
                    .frame(width: 36, height: 36)
                Image(systemName: category.icon)
                    .font(.system(size: 15))
                    .foregroundColor(category.color)
            }

            VStack(alignment: .trailing, spacing: 3) {
                Text(book.nameAr)
                    .font(.system(size: 15))
                    .foregroundColor(Theme.text)
                    .multilineTextAlignment(.trailing)

                if isDownloading {
                    HStack(spacing: 6) {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .tint(Theme.gold)
                            .frame(width: 80)
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textSecondary)
                    }
                } else if isAvailable {
                    let chapters = state?.totalChapters ?? 0
                    let done     = state?.doneChapters  ?? 0
                    if done > 0 {
                        Text("متاح بدون إنترنت · \(done) باب")
                            .font(.system(size: 11))
                            .foregroundColor(.green.opacity(0.8))
                    } else if chapters > 0 {
                        Text("الأبواب محفوظة · \(chapters) باب")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.gold.opacity(0.8))
                    } else {
                        Text("جارٍ التحقق من المحتوى...")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }

            Spacer()

            // Download badge
            if isDownloading {
                ProgressView().progressViewStyle(.circular).scaleEffect(0.7)
            } else if isAvailable {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green.opacity(0.7))
                    .font(.system(size: 16))
            }

            Image(systemName: "chevron.left")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}
