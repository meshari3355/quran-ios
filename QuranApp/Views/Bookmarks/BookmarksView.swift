import SwiftUI

struct BookmarkEntry: Identifiable {
    let id: Int        // surah id
    let surah: Surah
    let bookmarkedPage: Int    // explicitly saved bookmark
    let lastReadPage: Int      // auto-saved last read
}

struct BookmarksView: View {
    @State private var entries: [BookmarkEntry] = []
    @State private var showingLastRead = true    // toggle: bookmarks vs last-read

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 0) {

                    // Header
                    HStack {
                        Spacer()
                        Text("المحفوظات")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Theme.goldLight)
                        Spacer()
                    }
                    .padding(.vertical, 16)

                    // Segment control
                    HStack(spacing: 0) {
                        SegmentButton(
                            title: "الإشارات المرجعية",
                            icon: "bookmark.fill",
                            selected: !showingLastRead,
                            action: { showingLastRead = false }
                        )
                        SegmentButton(
                            title: "آخر قراءة",
                            icon: "clock.fill",
                            selected: showingLastRead,
                            action: { showingLastRead = true }
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                    let displayed = showingLastRead
                        ? entries.filter { $0.lastReadPage > 0 }
                        : entries.filter { $0.bookmarkedPage > 0 }

                    if displayed.isEmpty {
                        Spacer()
                        VStack(spacing: 14) {
                            Image(systemName: showingLastRead ? "clock" : "bookmark.slash")
                                .font(.system(size: 40))
                                .foregroundColor(Theme.textSecondary)
                            Text(showingLastRead ? "لم تقرأ أي سورة بعد" : "لم تضف أي إشارة مرجعية بعد")
                                .font(.system(size: 16))
                                .foregroundColor(Theme.textSecondary)
                            if !showingLastRead {
                                Text("افتح أي سورة واضغط على أيقونة الإشارة المرجعية")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.textSecondary.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(displayed) { entry in
                                    let page = showingLastRead ? entry.lastReadPage : entry.bookmarkedPage
                                    let surahForNav = Surah(
                                        id: entry.surah.id,
                                        name: entry.surah.name,
                                        nameEn: entry.surah.nameEn,
                                        verses: entry.surah.verses,
                                        page: page,
                                        type: entry.surah.type
                                    )
                                    NavigationLink(destination: QuranReaderView(surah: surahForNav)) {
                                        BookmarkCard(
                                            entry: entry,
                                            page: page,
                                            isLastRead: showingLastRead
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .onAppear { loadEntries() }
        }
    }

    private func loadEntries() {
        var result: [BookmarkEntry] = []
        for surah in allSurahs {
            let bookmarked = UserDefaults.standard.integer(forKey: "bookmark_\(surah.id)")
            let lastRead = UserDefaults.standard.integer(forKey: "lastPage_\(surah.id)")
            if bookmarked > 0 || lastRead > 0 {
                result.append(BookmarkEntry(
                    id: surah.id,
                    surah: surah,
                    bookmarkedPage: bookmarked,
                    lastReadPage: lastRead
                ))
            }
        }
        // Sort by most recently accessed (highest lastRead page as proxy, or surah id)
        entries = result.sorted { $0.lastReadPage > $1.lastReadPage }
    }
}

// MARK: - Segment button

struct SegmentButton: View {
    let title: String
    let icon: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(title)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
            }
            .foregroundColor(selected ? Theme.background : Theme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(selected ? Theme.gold : Theme.card)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? Theme.gold : Theme.border, lineWidth: 1)
            )
        }
        .padding(.horizontal, 3)
    }
}

// MARK: - Bookmark card

struct BookmarkCard: View {
    let entry: BookmarkEntry
    let page: Int
    let isLastRead: Bool

    var body: some View {
        HStack(spacing: 14) {
            // Surah number badge
            ZStack {
                Image(systemName: "seal.fill")
                    .font(.system(size: 38))
                    .foregroundColor(Theme.gold.opacity(0.13))
                Text("\(entry.surah.id)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.gold)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .trailing, spacing: 5) {
                Text(entry.surah.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.text)

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: isLastRead ? "clock.fill" : "bookmark.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.gold)
                        Text("صفحة \(page)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.gold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.gold.opacity(0.13))
                    .cornerRadius(6)

                    Text(entry.surah.type)
                        .font(.system(size: 11))
                        .foregroundColor(entry.surah.type == "مكية" ? .orange : Color.blue.opacity(0.9))
                }
            }

            Spacer()

            Image(systemName: "book.fill")
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary.opacity(0.5))
        }
        .padding(14)
        .background(Theme.card)
        .cornerRadius(13)
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.border, lineWidth: 1))
    }
}
