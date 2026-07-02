import SwiftUI

// MARK: - HadithPortalView
// Main landing page for the native Hadith Portal.
// Shows stats, quick-access to the main collections, and category browser.

struct HadithPortalView: View {

    @ObservedObject private var offline = HadithPortalOfflineManager.shared
    @State private var searchText  = ""
    @State private var showSearch  = false

    // Server stats (loaded lazily)
    @State private var totalHadiths   = "..."
    @State private var availableBooks = "..."

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // ── Search bar ────────────────────────────────────
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    // ── Hero stats ────────────────────────────────────
                    statsRow
                        .padding(.horizontal, 16)

                    // ── الكتب الستة (quick access) ────────────────────
                    mainSixSection

                    // ── كتب إضافية ────────────────────────────────────
                    extraBooksSection

                    // ── Category browser ──────────────────────────────
                    categorySection

                    Spacer(minLength: 40)
                }
            }

        }
        .navigationTitle("بوابة الحديث النبوي")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showSearch) {
            HadithPortalSearchView(query: searchText)
        }
        .task { await loadServerStats() }
    }

    // MARK: - Fetch real stats from server
    private func loadServerStats() async {
        guard let url = URL(string: "https://quran.meshari.tech/api/hadith.php?action=collections") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let collections = json["data"] as? [[String: Any]] {
                let available   = collections.filter { ($0["is_available"] as? Int) == 1 }
                let hadithCount = available.reduce(0) { $0 + (($1["total_hadiths"] as? Int) ?? 0) }
                let bookCount   = available.reduce(0) { $0 + (($1["total_books"]   as? Int) ?? 0) }
                await MainActor.run {
                    totalHadiths   = Self.formatNumber(hadithCount)
                    availableBooks = "\(bookCount)"
                }
            }
        } catch { /* keep defaults */ }
    }

    private static func formatNumber(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.textSecondary)
                .font(.system(size: 15))

            TextField("ابحث في الأحاديث...", text: $searchText)
                .font(.system(size: 15))
                .foregroundColor(Theme.text)
                .environment(\.layoutDirection, .rightToLeft)
                .onSubmit {
                    if !searchText.isEmpty { showSearch = true }
                }

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.textSecondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 10) {
            statPill(number: totalHadiths, label: "حديث", icon: "quote.bubble.fill",   color: Theme.gold)
            statPill(number: availableBooks, label: "باب", icon: "books.vertical.fill", color: .indigo)
            statPill(number: "10",  label: "مجموعة", icon: "rectangle.grid.2x2.fill",  color: .teal)
            statPill(number: "11",  label: "قسم",    icon: "text.magnifyingglass",      color: .orange)
        }
    }

    private func statPill(number: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(number)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Theme.text)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Main Six Section

    private var mainSixSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "الكتب الستة", icon: "star.fill", color: Theme.gold)

            VStack(spacing: 1) {
                ForEach(Array(mainSixBooks.enumerated()), id: \.offset) { idx, book in
                    NavigationLink(destination: HadithPortalChaptersView(book: book)) {
                        bookRow(book: book, showDownloadState: true)
                    }
                    .buttonStyle(.plain)

                    if idx < mainSixBooks.count - 1 {
                        Divider().background(Theme.border).padding(.leading, 60)
                    }
                }
            }
            .background(Theme.card)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
        }
        .padding(.horizontal, 16)
    }

    private var mainSixBooks: [PortalBook] {
        let ids = [33, 31, 26, 38, 25, 27]
        return ids.compactMap { PortalCategory.book(id: $0) }
    }

    // MARK: - Extra Books Section

    private var extraBooksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "كتب أخرى", icon: "book.closed.fill", color: .teal)

            VStack(spacing: 1) {
                ForEach(Array(extraBooks.enumerated()), id: \.offset) { idx, book in
                    NavigationLink(destination: HadithPortalChaptersView(book: book)) {
                        bookRow(book: book, showDownloadState: false)
                    }
                    .buttonStyle(.plain)

                    if idx < extraBooks.count - 1 {
                        Divider().background(Theme.border).padding(.leading, 60)
                    }
                }
            }
            .background(Theme.card)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
        }
        .padding(.horizontal, 16)
    }

    private var extraBooks: [PortalBook] {
        let ids = [30, 32, 1, 76, 756, 55, 131, 200]
        return ids.compactMap { PortalCategory.book(id: $0) }
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "جميع الكتب", icon: "books.vertical.fill", color: .indigo)

            VStack(spacing: 10) {
                ForEach(PortalCategory.allCategories) { category in
                    NavigationLink(destination: HadithPortalBooksView(category: category)) {
                        categoryRow(category)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func categoryRow(_ category: PortalCategory) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(category.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: category.icon)
                    .font(.system(size: 17))
                    .foregroundColor(category.color)
            }

            VStack(alignment: .trailing, spacing: 2) {
                Text(category.nameAr)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Theme.text)
                Text("\(category.books.count) كتاب")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.left")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Book Row (reusable)

    func bookRow(book: PortalBook, showDownloadState: Bool = false) -> some View {
        let cat = PortalCategory.category(id: book.categoryId)
        let color = cat?.color ?? Theme.gold
        let icon  = cat?.icon  ?? "book.fill"
        let state = offline.states[book.id]

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.14))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(color)
            }

            Text(book.nameAr)
                .font(.system(size: 15))
                .foregroundColor(Theme.text)

            Spacer()

            if showDownloadState, let s = state, s.isAvailable {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.gold.opacity(0.7))
            }

            Image(systemName: "chevron.left")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}
