import SwiftUI

// MARK: - Models

struct FatwaItem: Identifiable, Codable {
    let id: Int
    let title: String
    let category: String
    var preview: String?
    var question: String?
    var answer: String?
    var source: String?

    var sourceURL: String {
        "https://binbaz.org.sa/fatwas/\(id)"
    }

    enum CodingKeys: String, CodingKey {
        case id, title, category, preview, question, answer, source
    }
}

struct FatwaListResponse: Codable {
    let success: Bool
    let page: Int?
    let perPage: Int?
    let total: Int?
    let totalPages: Int?
    let data: [FatwaItem]

    enum CodingKeys: String, CodingKey {
        case success, page
        case perPage = "per_page"
        case total
        case totalPages = "total_pages"
        case data
    }
}

struct FatwaSingleResponse: Codable {
    let success: Bool
    let data: FatwaItem?
}

// MARK: - Category Model

struct FatwaCategory: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: Color
}

let fatwaCategories: [FatwaCategory] = [
    FatwaCategory(id: "", name: "الكل", icon: "list.bullet", color: .blue),
    FatwaCategory(id: "عبادة", name: "عبادة", icon: "moon.stars.fill", color: .indigo),
    FatwaCategory(id: "عقيدة", name: "عقيدة", icon: "star.fill", color: .orange),
    FatwaCategory(id: "فقه", name: "فقه", icon: "scale.3d", color: .green),
    FatwaCategory(id: "معاملات", name: "معاملات", icon: "dollarsign.circle.fill", color: .teal),
    FatwaCategory(id: "أسرة", name: "أسرة", icon: "house.fill", color: .pink),
    FatwaCategory(id: "أخلاق", name: "أخلاق", icon: "heart.fill", color: .red),
    FatwaCategory(id: "عام", name: "عام", icon: "circle.grid.3x3.fill", color: .gray),
]

// MARK: - Bookmark Manager

class FatwaBookmarkManager: ObservableObject {
    static let shared = FatwaBookmarkManager()
    private let key = "saved_fatwas_ids"
    @Published var savedIDs: Set<Int> = []

    init() { load() }

    private func load() {
        let arr = UserDefaults.standard.array(forKey: key) as? [Int] ?? []
        savedIDs = Set(arr)
    }

    func toggle(id: Int) {
        if savedIDs.contains(id) { savedIDs.remove(id) }
        else { savedIDs.insert(id) }
        UserDefaults.standard.set(Array(savedIDs), forKey: key)
    }

    func isSaved(_ id: Int) -> Bool { savedIDs.contains(id) }
}

// MARK: - Fatwa Service

@MainActor
class FatwaService: ObservableObject {
    static let shared = FatwaService()

    private let base = "https://quran.meshari.tech/api/fatwa.php"

    func fetchList(page: Int = 1, category: String = "", perPage: Int = 20) async throws -> FatwaListResponse {
        var url = "\(base)?action=list&page=\(page)&per_page=\(perPage)"
        if !category.isEmpty, let enc = category.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            url += "&category=\(enc)"
        }
        return try await fetch(FatwaListResponse.self, from: url)
    }

    func fetchDetail(id: Int) async throws -> FatwaItem {
        let url = "\(base)?action=get&id=\(id)"
        let resp = try await fetch(FatwaSingleResponse.self, from: url)
        guard let item = resp.data else { throw URLError(.cannotParseResponse) }
        return item
    }

    func search(query: String, page: Int = 1) async throws -> FatwaListResponse {
        guard let enc = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw URLError(.badURL)
        }
        let url = "\(base)?action=search&q=\(enc)&page=\(page)"
        return try await fetch(FatwaListResponse.self, from: url)
    }

    func fetchRandom() async throws -> FatwaItem {
        let url = "\(base)?action=random"
        let resp = try await fetch(FatwaSingleResponse.self, from: url)
        guard let item = resp.data else { throw URLError(.cannotParseResponse) }
        return item
    }

    private func fetch<T: Decodable>(_ type: T.Type, from urlStr: String) async throws -> T {
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(type, from: data)
    }
}

// MARK: - Main List View

struct FatwaListView: View {
    @StateObject private var service       = FatwaService.shared
    @StateObject private var bookmarks     = FatwaBookmarkManager.shared
    @StateObject private var offlineMgr    = FatwaOfflineManager.shared

    @State private var fatwas: [FatwaItem] = []
    @State private var seenTitles: Set<String> = []   // dedup guard
    @State private var isLoading = false
    @State private var page = 1
    @State private var totalPages = 1
    @State private var total = 0
    @State private var selectedCategory = ""
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchResults: [FatwaItem] = []
    @State private var errorMsg: String?
    @State private var randomFatwa: FatwaItem?
    @State private var showOfflineSheet = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Category pills
                categoryBar

                if isLoading && fatwas.isEmpty {
                    loadingView
                } else if let err = errorMsg, fatwas.isEmpty {
                    errorView(err)
                } else {
                    listContent
                }
            }
        }
        .navigationTitle("فتاوى ابن باز")
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarItems }
        .searchable(text: $searchText, prompt: "ابحث في الفتاوى...")
        .onSubmit(of: .search) { runSearch() }
        .onChange(of: searchText) { txt in
            if txt.isEmpty { isSearching = false; searchResults = [] }
        }
        .onAppear { if fatwas.isEmpty { Task { await loadPage() } } }
        .sheet(item: $randomFatwa) { fatwa in
            NavigationView { FatwaDetailView(fatwaId: fatwa.id, preloaded: fatwa) }
        }
        .sheet(isPresented: $showOfflineSheet) { offlineSheet }
    }

    // MARK: - Sub-views

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(fatwaCategories) { cat in
                    Button {
                        selectedCategory = cat.id
                        fatwas = []
                        seenTitles = []
                        page = 1
                        Task { await loadPage() }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 11))
                            Text(cat.name)
                                .font(.system(size: 13))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(selectedCategory == cat.id ? Theme.gold : Theme.card)
                        .foregroundColor(selectedCategory == cat.id ? Theme.background : Theme.text)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(selectedCategory == cat.id ? Theme.gold : Theme.border, lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private var listContent: some View {
        let items = isSearching ? searchResults : fatwas
        return ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 1) {
                if !isSearching {
                    headerBanner
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                }

                VStack(spacing: 1) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, fatwa in
                        NavigationLink(destination: FatwaDetailView(fatwaId: fatwa.id, preloaded: fatwa)) {
                            FatwaRowView(fatwa: fatwa)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            // Auto-load more when last 5 items become visible
                            if !isSearching && idx >= items.count - 5 && page < totalPages && !isLoading {
                                Task { await loadMore() }
                            }
                        }

                        if idx < items.count - 1 {
                            Divider().background(Theme.border).padding(.leading, 52)
                        }
                    }
                }
                .background(Theme.card)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.top, 4)

                if isLoading {
                    HStack { Spacer(); ProgressView().tint(Theme.gold); Spacer() }
                        .padding(.vertical, 16)
                }

                Spacer(minLength: 40)
            }
        }
        .refreshable { await refreshList() }
    }

    private var headerBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.gold.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "book.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Theme.gold)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("فتاوى الإمام ابن باز رحمه الله")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.text)
                Text("\(fatwas.count) فتوى")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Theme.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.gold.opacity(0.25), lineWidth: 1))
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Theme.gold)
                .scaleEffect(1.3)
            Text("جارٍ التحميل...")
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 40))
                .foregroundColor(Theme.textSecondary)
            Text("تعذّر الاتصال بالخادم")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.text)
            Text(msg)
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button(action: { Task { await loadPage() } }) {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 14) {
                // Offline download button
                Button { showOfflineSheet = true } label: {
                    Image(systemName: offlineMgr.isAvailableOffline ? "arrow.down.circle.fill" : "arrow.down.circle")
                        .foregroundColor(offlineMgr.isAvailableOffline ? .green : Theme.gold)
                }

                // Random fatwa
                Button {
                    Task {
                        do { randomFatwa = try await service.fetchRandom() } catch {}
                    }
                } label: {
                    Image(systemName: "shuffle")
                        .foregroundColor(Theme.gold)
                }
            }
        }
    }

    // MARK: - Offline Sheet
    private var offlineSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                OfflineDownloadButton(
                    title: "فتاوى ابن باز — كاملاً",
                    icon: "questionmark.circle.fill",
                    color: .purple,
                    isOffline: offlineMgr.isAvailableOffline,
                    isDownloading: offlineMgr.isDownloading,
                    progress: offlineMgr.progress,
                    cachedCount: offlineMgr.isDownloading ? offlineMgr.downloadedCount : (offlineMgr.isAvailableOffline ? offlineMgr.cachedCount : nil),
                    totalCount: offlineMgr.isDownloading ? (offlineMgr.totalCount > 0 ? offlineMgr.totalCount : 2565) : nil,
                    onDownload: { Task { await offlineMgr.downloadAll() } },
                    onClear: { offlineMgr.clearCache() }
                )
                .padding(.horizontal, 16)

                Text("بعد التحميل تستطيع تصفح جميع الفتاوى والبحث فيها بدون إنترنت")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("الاستخدام دون إنترنت")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("إغلاق") { showOfflineSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Data Loading

    // MARK: - Dedup helper
    /// Returns only items whose title hasn't been seen yet, and registers them.
    private func dedup(_ items: [FatwaItem]) -> [FatwaItem] {
        var out: [FatwaItem] = []
        for item in items {
            if !seenTitles.contains(item.title) {
                seenTitles.insert(item.title)
                out.append(item)
            }
        }
        return out
    }

    private func loadPage() async {
        guard !isLoading else { return }
        isLoading = true
        errorMsg = nil
        do {
            // Fetch with larger page size so we see more unique fatwas per request
            let resp = try await service.fetchList(page: 1, category: selectedCategory, perPage: 50)
            let unique = dedup(resp.data)
            fatwas = unique
            page = 1
            totalPages = resp.totalPages ?? 1
            // Show true unique count (we'll discover it as we page through)
            total = resp.total ?? 0
        } catch {
            // Fallback to offline cache if available
            let cached = offlineMgr.cachedFatwas
            if !cached.isEmpty {
                let filtered = selectedCategory.isEmpty ? cached : cached.filter { $0.category == selectedCategory }
                fatwas = filtered
                total = filtered.count
                totalPages = 1    // All loaded at once from cache
                errorMsg = nil
            } else {
                errorMsg = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func loadMore() async {
        guard !isLoading, page < totalPages else { return }
        isLoading = true
        do {
            let nextPage = page + 1
            let resp = try await service.fetchList(page: nextPage, category: selectedCategory, perPage: 50)
            let unique = dedup(resp.data)
            fatwas.append(contentsOf: unique)
            page = nextPage
            totalPages = resp.totalPages ?? totalPages
        } catch {}
        isLoading = false
    }

    private func refreshList() async {
        fatwas = []
        seenTitles = []
        page = 1
        await loadPage()
    }

    private func runSearch() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        Task {
            do {
                let resp = try await service.search(query: searchText)
                searchResults = resp.data
            } catch {
                searchResults = []
            }
        }
    }
}

// MARK: - Row View

struct FatwaRowView: View {
    let fatwa: FatwaItem
    @ObservedObject private var bookmarks = FatwaBookmarkManager.shared

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Category icon badge
            ZStack {
                Circle()
                    .fill(categoryColor(fatwa.category).opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: categoryIcon(fatwa.category))
                    .font(.system(size: 15))
                    .foregroundColor(categoryColor(fatwa.category))
            }

            VStack(alignment: .trailing, spacing: 5) {
                Text(fatwa.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                if let preview = fatwa.preview, !preview.isEmpty {
                    Text(preview)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                HStack(spacing: 8) {
                    if bookmarks.isSaved(fatwa.id) {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.gold)
                    }

                    Spacer()

                    Text(fatwa.category)
                        .font(.system(size: 11))
                        .foregroundColor(categoryColor(fatwa.category))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(categoryColor(fatwa.category).opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            Image(systemName: "chevron.left")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .padding(.top, 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func categoryColor(_ cat: String) -> Color {
        switch cat {
        case "عبادة":    return .indigo
        case "عقيدة":    return .orange
        case "فقه":      return .green
        case "معاملات":  return .teal
        case "أسرة":     return .pink
        case "أخلاق":    return .red
        default:         return .blue
        }
    }

    private func categoryIcon(_ cat: String) -> String {
        switch cat {
        case "عبادة":    return "moon.stars.fill"
        case "عقيدة":    return "star.fill"
        case "فقه":      return "scale.3d"
        case "معاملات":  return "dollarsign.circle.fill"
        case "أسرة":     return "house.fill"
        case "أخلاق":    return "heart.fill"
        default:         return "circle.fill"
        }
    }
}

// MARK: - Detail View

struct FatwaDetailView: View {
    let fatwaId: Int
    var preloaded: FatwaItem?

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var bookmarks = FatwaBookmarkManager.shared
    @State private var fatwa: FatwaItem?
    @State private var isLoading = false
    @State private var fontSize: CGFloat = 18

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            Group {
                if isLoading || fatwa == nil {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(Theme.gold)
                            .scaleEffect(1.3)
                        Text("جارٍ التحميل...")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let f = fatwa {
                    detailContent(f)
                }
            }
        }
        .navigationTitle("فتوى ابن باز")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarItems }
        .onAppear { loadIfNeeded() }
    }

    // MARK: - Main content

    private func detailContent(_ f: FatwaItem) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {

                // ── Header card ──────────────────────────────────────
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Theme.gold.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "person.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Theme.gold)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("سماحة الشيخ")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textSecondary)
                            Text("ابن باز رحمه الله")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Theme.goldLight)
                        }
                        Spacer()
                        Text(f.category)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Theme.gold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Theme.gold.opacity(0.12))
                            .cornerRadius(20)
                    }

                    Divider().background(Theme.border)

                    Text(f.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Theme.text)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(.trailing)
                        .lineSpacing(4)
                }
                .padding(14)
                .background(Theme.card)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.gold.opacity(0.25), lineWidth: 1))

                // ── Question ─────────────────────────────────────────
                if let q = f.question, !q.isEmpty {
                    fatwaSection(label: "السؤال", icon: "questionmark.circle.fill",
                                 iconColor: .blue, text: q)
                }

                // ── Answer ───────────────────────────────────────────
                if let ans = f.answer, !ans.isEmpty {
                    fatwaSection(label: "الجواب", icon: "checkmark.seal.fill",
                                 iconColor: .green, text: ans)
                }

                // ── Source ───────────────────────────────────────────
                if let source = f.source, !source.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                        Text("المصدر: \(source)")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }

                Spacer(minLength: 40)
            }
            .padding(16)
            .environment(\.layoutDirection, .rightToLeft)
        }
    }

    private func fatwaSection(label: String, icon: String, iconColor: Color, text: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(iconColor.opacity(0.14))
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(iconColor)
                }
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider().background(Theme.border).padding(.horizontal, 14)

            Text(text)
                .font(.system(size: fontSize))
                .foregroundColor(Theme.text)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .multilineTextAlignment(.trailing)
                .lineSpacing(8)
                .padding(14)
        }
        .background(Theme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Menu {
                Button { fontSize = 15 } label: { Label("صغير",  systemImage: "textformat.size.smaller") }
                Button { fontSize = 18 } label: { Label("متوسط", systemImage: "textformat") }
                Button { fontSize = 22 } label: { Label("كبير",  systemImage: "textformat.size.larger") }
            } label: {
                Image(systemName: "textformat.size").foregroundColor(Theme.gold)
            }

            Button { bookmarks.toggle(id: fatwaId) } label: {
                Image(systemName: bookmarks.isSaved(fatwaId) ? "bookmark.fill" : "bookmark")
                    .foregroundColor(Theme.gold)
            }

            if let f = fatwa {
                ShareLink(item: "\(f.title)\n\n\(f.answer ?? "")\n\nالمصدر: \(f.sourceURL)") {
                    Image(systemName: "square.and.arrow.up").foregroundColor(Theme.gold)
                }
            }
        }
    }

    // MARK: - Load

    private func loadIfNeeded() {
        if let pre = preloaded, pre.answer != nil { fatwa = pre; return }
        isLoading = true
        Task {
            do { fatwa = try await FatwaService.shared.fetchDetail(id: fatwaId) }
            catch { if let pre = preloaded { fatwa = pre } }
            isLoading = false
        }
    }
}
