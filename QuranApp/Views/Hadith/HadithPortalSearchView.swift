import SwiftUI

// MARK: - HadithPortalSearchView
// Live search across hadith collections.

struct HadithPortalSearchView: View {

    @State var query: String
    @State private var results:   [PortalHadith] = []
    @State private var isLoading: Bool = false
    @State private var searched   = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {

                // Inline search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.textSecondary)
                        .font(.system(size: 14))
                    TextField("ابحث في الأحاديث...", text: $query)
                        .font(.system(size: 15))
                        .foregroundColor(Theme.text)
                        .environment(\.layoutDirection, .rightToLeft)
                        .onSubmit { Task { await search() } }
                    if isLoading {
                        ProgressView().progressViewStyle(.circular).scaleEffect(0.7)
                    } else if !query.isEmpty {
                        Button(action: {
                            query = ""
                            results = []
                            searched = false
                        }) {
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
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider().background(Theme.border)

                // Results
                if searched && results.isEmpty && !isLoading {
                    emptyState
                } else {
                    resultsList
                }
            }
        }
        .navigationTitle("البحث في الأحاديث")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !query.isEmpty { await search() }
        }
    }

    // MARK: - Results List

    private var resultsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                ForEach(results) { hadith in
                    let book = PortalCategory.book(id: hadith.bookId)
                        ?? PortalBook(id: hadith.bookId, nameAr: hadith.bookName ?? "حديث", categoryId: "sihah")
                    NavigationLink(destination: HadithPortalDetailView(hadith: hadith, book: book)) {
                        searchResultCard(hadith: hadith)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
        }
    }

    private func searchResultCard(hadith: PortalHadith) -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack {
                Spacer()
                Text(hadith.bookName ?? PortalCategory.book(id: hadith.bookId)?.nameAr ?? "حديث")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.gold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.gold.opacity(0.12))
                    .cornerRadius(6)
            }

            // Highlight query in text
            Text(hadith.text.prefix(250) + (hadith.text.count > 250 ? "..." : ""))
                .font(.system(size: 14))
                .foregroundColor(Theme.text)
                .multilineTextAlignment(.trailing)
                .lineSpacing(5)
                .environment(\.layoutDirection, .rightToLeft)
        }
        .padding(14)
        .background(Theme.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 44))
                .foregroundColor(Theme.textSecondary.opacity(0.5))
            Text("لا توجد نتائج لـ \"\(query)\"")
                .font(.system(size: 15))
                .foregroundColor(Theme.textSecondary)
            Text("جرّب كلمات مختلفة أو تحقق من الإملاء")
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary.opacity(0.7))
            Spacer()
        }
    }

    // MARK: - Search

    private func search() async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isLoading = true
        results   = []
        searched  = true
        do {
            results   = try await HadithPortalService.shared.search(query: query)
        } catch {}
        isLoading = false
    }
}
