import SwiftUI
import UIKit
import AVFoundation

// MARK: - Reciter
// audioFolder maps to everyayah.com per-ayah audio:
// https://everyayah.com/data/{audioFolder}/{surah:3d}{ayah:3d}.mp3

struct Reciter: Identifiable, Hashable {
    let id: String
    let name: String
    let server: String       // full-surah mp3quran.net server (kept for reference)
    let cdnId: String        // everyayah.com folder name
}

let allReciters: [Reciter] = [
    Reciter(id: "102", name: "ماهر المعيقلي",      server: "https://server12.mp3quran.net/maher/",                  cdnId: "MaherAlMuaiqly128kbps"),
    Reciter(id: "123", name: "مشاري العفاسي",      server: "https://server8.mp3quran.net/afs/",                     cdnId: "Alafasy_128kbps"),
    Reciter(id: "68",  name: "محمد جبريل",         server: "https://server8.mp3quran.net/jbrl/",                    cdnId: "Muhammad_Jibreel_128kbps"),
    Reciter(id: "118", name: "عبدالباسط عبدالصمد", server: "https://server7.mp3quran.net/basit/",                   cdnId: "Abdul_Basit_Mujawwad_128kbps"),
    Reciter(id: "111", name: "عبدالرحمن السديس",   server: "https://server11.mp3quran.net/sds/",                    cdnId: "Abdurrahmaan_As-Sudais_192kbps"),
    Reciter(id: "104", name: "سعود الشريم",        server: "https://server7.mp3quran.net/shur/",                    cdnId: "Saood_ash-Shuraym_128kbps"),
    Reciter(id: "9",   name: "ناصر القطامي",       server: "https://server6.mp3quran.net/qtm/",                     cdnId: "Nasser_Alqatami_128kbps"),
    Reciter(id: "76",  name: "سعد الغامدي",        server: "https://server7.mp3quran.net/s_gmd/",                   cdnId: "Ghamadi_40kbps"),
    Reciter(id: "40",  name: "عبدالله الجهني",     server: "https://server12.mp3quran.net/jhn/",                    cdnId: "Abdullaah_3awwaad_Al-Juhaynee_128kbps"),
    Reciter(id: "67",  name: "محمد أيوب",          server: "https://server10.mp3quran.net/ayyub/",                  cdnId: "Muhammad_Ayyoub_128kbps"),
    Reciter(id: "17",  name: "أحمد العجمي",        server: "https://server10.mp3quran.net/ahmed_ibn_ali_al_ajamy/", cdnId: "ahmed_ibn_ali_al_ajamy_128kbps"),
    Reciter(id: "19",  name: "علي الحذيفي",        server: "https://server7.mp3quran.net/huthfi/",                  cdnId: "Hudhaify_128kbps"),
    Reciter(id: "55",  name: "فارس عباد",          server: "https://server9.mp3quran.net/aabad/",                   cdnId: "Fares_Abbad_64kbps"),
    Reciter(id: "21",  name: "أبو بكر الشاطري",    server: "https://server11.mp3quran.net/shatri/",                 cdnId: "Abu_Bakr_Ash-Shaatree_128kbps"),
    Reciter(id: "88",  name: "ياسر الدوسري",       server: "https://server11.mp3quran.net/yasser/",                 cdnId: "Yasser_Ad-Dussary_128kbps"),
    Reciter(id: "35",  name: "خالد القحطاني",      server: "https://server11.mp3quran.net/jlil/",                   cdnId: "Khaalid_Abdullaah_al-Qahtaanee_192kbps"),
]

// MARK: - Page-by-Page Audio Player
//
// Plays each ayah individually using everyayah.com CDN.
// Tracks the active ayah number so the UI can highlight it.

class PageAudioPlayer: ObservableObject {
    @Published var isPlaying    = false
    @Published var isLoading    = false
    @Published var currentAyahNumber: Int? = nil
    @Published private(set) var currentIndex: Int = -1
    @Published var currentTime: Double = 0      // ثواني منقضية من الآية الحالية
    @Published var duration:    Double = 0      // مدة الآية الكاملة
    @Published var isSeeking:   Bool   = false  // true أثناء سحب الشريط

    // ── Playback mode settings ──────────────────────────────
    @Published var repeatPage:    Bool = false  // إعادة تشغيل الصفحة
    @Published var autoNextPage:  Bool = false  // الانتقال التلقائي للصفحة التالية
    @Published var pageCompleted: Bool = false  // fires true when page ends & autoNextPage on

    private(set) var queue:        [AyahData] = []
    private var     cdnId:         String     = "ar.alafasy"
    private(set)  var activeCdnId: String     = "ar.alafasy"
    private var     player:        AVPlayer?
    private var     endObserver:   Any?
    private var     statusObs:     NSKeyValueObservation?
    private var     timeObserver:  Any?

    var totalCount: Int   { queue.count }
    var canPrevious: Bool { currentIndex > 0 }
    var canNext:     Bool { currentIndex < queue.count - 1 }
    var progress:    Double { duration > 0 ? min(currentTime / duration, 1) : 0 }

    var currentAyahInfo: AyahData? {
        guard currentIndex >= 0, currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }

    func play(ayahs: [AyahData], cdnId: String, from index: Int = 0) {
        cleanup()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        queue         = ayahs
        self.cdnId    = cdnId
        self.activeCdnId = cdnId
        currentIndex  = max(0, min(index, ayahs.count - 1))
        playAt(currentIndex)
    }

    func togglePlay() {
        if isPlaying { player?.pause(); isPlaying = false }
        else         { player?.play();  isPlaying = true  }
    }

    func next() {
        if canNext {
            currentIndex += 1; playAt(currentIndex)
        } else {
            if repeatPage {
                // Loop: restart from first ayah of this page
                playAt(0)
            } else {
                stop()
                if autoNextPage {
                    DispatchQueue.main.async { self.pageCompleted = true }
                }
            }
        }
    }

    func previous() {
        guard canPrevious else { return }
        currentIndex -= 1
        playAt(currentIndex)
    }

    /// Seek to fraction 0–1 of current ayah
    func seek(to fraction: Double) {
        guard duration > 0, let p = player else { return }
        let t = CMTime(seconds: max(0, min(fraction * duration, duration)), preferredTimescale: 600)
        p.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            DispatchQueue.main.async { self?.isSeeking = false }
        }
    }

    /// Skip forward (+) or backward (-) by seconds
    func skip(by seconds: Double) {
        guard duration > 0 else { return }
        seek(to: max(0, min(progress + seconds / duration, 1)))
    }

    func stop() {
        cleanup()
        isPlaying = false; isLoading = false
        currentAyahNumber = nil; currentIndex = -1
        queue = []; currentTime = 0; duration = 0
    }

    // MARK: - Private

    private func playAt(_ idx: Int) {
        guard idx >= 0, idx < queue.count else { stop(); return }
        cleanup()

        let ayah = queue[idx]
        currentAyahNumber = ayah.number
        currentTime = 0; duration = 0
        isLoading = true; isPlaying = true

        // 1️⃣ Local cache first (offline), 2️⃣ fallback to streaming
        let surahN = ayah.surah.number
        let ayahN  = ayah.numberInSurah
        let audioManager = AudioOfflineCacheManager.shared
        let playURL: URL
        if let local = audioManager.cachedURL(surah: surahN, ayah: ayahN, folder: cdnId) {
            playURL = local
        } else {
            let s = String(format: "%03d", surahN)
            let a = String(format: "%03d", ayahN)
            guard let remote = URL(string: "https://everyayah.com/data/\(cdnId)/\(s)\(a).mp3") else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.next() }
                return
            }
            playURL = remote
        }

        let item = AVPlayerItem(url: playURL)
        let avPlayer = AVPlayer(playerItem: item)
        player = avPlayer

        statusObs = item.observe(\.status, options: .new) { [weak self] it, _ in
            DispatchQueue.main.async {
                switch it.status {
                case .readyToPlay:
                    self?.isLoading = false
                    Task { [weak self] in
                        if let d = try? await it.asset.load(.duration), d.isNumeric && d.seconds > 0 {
                            await MainActor.run { self?.duration = d.seconds }
                        }
                    }
                case .failed: self?.next()
                default: break
                }
            }
        }

        // تحديث الوقت كل 0.1 ثانية
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self, !self.isSeeking else { return }
            self.currentTime = time.seconds
            if self.duration <= 0,
               let d = avPlayer.currentItem?.duration, d.isNumeric, d.seconds > 0 {
                self.duration = d.seconds
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in self?.isLoading = false; self?.next() }

        avPlayer.play()
    }

    private func cleanup() {
        if let obs = timeObserver, let p = player { p.removeTimeObserver(obs) }
        timeObserver = nil
        endObserver.map { NotificationCenter.default.removeObserver($0) }
        endObserver = nil
        statusObs?.invalidate(); statusObs = nil
        player?.pause(); player = nil
    }

    deinit { cleanup() }
}

// MARK: - Page Interaction State

class QuranPageInteractionState: ObservableObject {
    @Published var tappedAyah: AyahData?      = nil   // tap → seek audio to this ayah
    @Published var longPressedAyah: AyahData? = nil   // long-press → verse analysis sheet
}

// MARK: - Page API Models

// MARK: - alquran.cloud response models (legacy fallback)

struct QuranPageResponse: Codable {
    let code: Int
    let data: QuranPageData
}

struct QuranPageData: Codable {
    let ayahs: [AyahData]
    let number: Int
}

struct AyahData: Codable, Identifiable, Equatable {
    var id: Int { number }
    let number: Int
    let text: String
    let numberInSurah: Int
    let surah: SurahInfo
    let juz: Int?
}

struct SurahInfo: Codable, Equatable {
    let number: Int
    let name: String
    let englishName: String
    let revelationType: String
}

// MARK: - Own server (quran.meshari.tech) response models

private struct OwnServerPageResponse: Codable {
    let success: Bool
    let data: [OwnServerAyah]
}

private struct OwnServerAyah: Codable {
    let id: Int
    let sura_id: Int
    let verse_number: Int
    let text_uthmani: String
    let juz: Int?
    let sura_name_ar: String?
    let sura_name_en: String?
    let revelation_type: String?

    /// Convert to the shared AyahData model used throughout the app
    func toAyahData() -> AyahData {
        AyahData(
            number:        id,
            text:          text_uthmani,
            numberInSurah: verse_number,
            surah: SurahInfo(
                number:          sura_id,
                name:            sura_name_ar ?? "",
                englishName:     sura_name_en ?? "",
                revelationType:  revelation_type ?? ""
            ),
            juz: juz
        )
    }
}

// MARK: - Page Cache
// Checks on-disk cache (QuranOfflineCacheManager) before hitting the network.
// This allows 100% offline reading after the initial full download.

class QuranPageCache: ObservableObject {
    @Published var pages: [Int: [AyahData]] = [:]
    private var loading: Set<Int> = []
    private let disk = QuranOfflineCacheManager.shared

    func ayahs(for page: Int) -> [AyahData]? { pages[page] }

    func load(_ page: Int) {
        guard (1...604).contains(page), pages[page] == nil, !loading.contains(page) else { return }
        loading.insert(page)

        // 1️⃣ Disk cache — instant, no network required
        if let data = disk.cachedData(for: page) {
            // Try our server cache format first, then legacy alquran.cloud format
            if let decoded = try? JSONDecoder().decode(OwnServerPageResponse.self, from: data),
               decoded.success, !decoded.data.isEmpty {
                let ayahs = decoded.data.map { $0.toAyahData() }
                DispatchQueue.main.async { self.loading.remove(page); self.pages[page] = ayahs }
                return
            }
            if let decoded = try? JSONDecoder().decode(QuranPageResponse.self, from: data) {
                DispatchQueue.main.async {
                    self.loading.remove(page)
                    self.pages[page] = decoded.data.ayahs
                }
                return
            }
        }

        // 2️⃣ Own server — primary network source (no third-party dependency)
        if let ownUrl = URL(string: "https://quran.meshari.tech/api/quran.php?action=page&page=\(page)") {
            URLSession.shared.dataTask(with: ownUrl) { [weak self] data, response, error in
                if let data = data, error == nil,
                   let decoded = try? JSONDecoder().decode(OwnServerPageResponse.self, from: data),
                   decoded.success, !decoded.data.isEmpty {
                    let ayahs = decoded.data.map { $0.toAyahData() }
                    DispatchQueue.main.async {
                        self?.loading.remove(page)
                        self?.pages[page] = ayahs
                    }
                    // Cache the response for offline use
                    self?.disk.savePage(page, data: data)
                    return
                }
                // 3️⃣ Fallback: alquran.cloud
                guard let fallbackUrl = URL(string: "https://api.alquran.cloud/v1/page/\(page)/ar.uthmani") else {
                    DispatchQueue.main.async { self?.loading.remove(page) }
                    return
                }
                URLSession.shared.dataTask(with: fallbackUrl) { [weak self] data, _, error in
                    DispatchQueue.main.async {
                        self?.loading.remove(page)
                        guard let data = data, error == nil,
                              let decoded = try? JSONDecoder().decode(QuranPageResponse.self, from: data)
                        else { return }
                        self?.disk.savePage(page, data: data)
                        self?.pages[page] = decoded.data.ayahs
                    }
                }.resume()
            }.resume()
            return
        }

        // If URL construction failed
        loading.remove(page)
    }

    func preload(around center: Int) {
        for p in max(1, center - 2)...min(604, center + 2) { load(p) }
    }
}

// MARK: - Translation Cache
// Fetches per-page translation from alquran.cloud and caches in memory.
// Keyed by "page|translationId" so different languages stay separate.

class TranslationCache: ObservableObject {
    static let shared = TranslationCache()
    @Published private(set) var pages: [String: [Int: String]] = [:]
    private var loading: Set<String> = []

    func translations(page: Int, key: String) -> [Int: String]? {
        pages["\(page)|\(key)"]
    }

    func load(page: Int, key: String) {
        let k = "\(page)|\(key)"
        guard pages[k] == nil, !loading.contains(k) else { return }
        loading.insert(k)
        guard let url = URL(string: "https://api.alquran.cloud/v1/page/\(page)/\(key)") else {
            loading.remove(k); return
        }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            DispatchQueue.main.async {
                self?.loading.remove(k)
                guard let data = data,
                      let decoded = try? JSONDecoder().decode(QuranPageResponse.self, from: data)
                else { return }
                var dict: [Int: String] = [:]
                for ayah in decoded.data.ayahs { dict[ayah.number] = ayah.text }
                self?.pages[k] = dict
            }
        }.resume()
    }
}

// MARK: - Single Page View
//
// Reads @AppStorage fontSize directly so any font-size change auto-propagates
// into the UIHostingController without needing to go through UIPageViewController.

struct QuranSinglePageView: View {
    let page: Int
    @ObservedObject var cache: QuranPageCache
    @ObservedObject var audioPlayer: PageAudioPlayer
    @ObservedObject var interactionState: QuranPageInteractionState
    @AppStorage("quranFontSize")     private var fontSize: Double = 22
    @AppStorage("showTranslation")   private var showTranslation  = false
    @AppStorage("translationKey")    private var translationKey   = "en.sahih"
    @ObservedObject private var translationCache = TranslationCache.shared

    var body: some View {
        ZStack {
            Theme.background
            if let ayahs = cache.ayahs(for: page) {
                ScrollView {
                    QuranPageContent(
                        ayahs: ayahs,
                        fontSize: fontSize,
                        activeAyahNumber: audioPlayer.currentAyahNumber,
                        showTranslation: showTranslation,
                        translationMap: translationCache.translations(page: page, key: translationKey),
                        onAyahTapped: { ayah in
                            if let idx = ayahs.firstIndex(where: { $0.number == ayah.number }) {
                                interactionState.tappedAyah = ayah
                                let cdnId = audioPlayer.activeCdnId.isEmpty
                                    ? "ar.alafasy" : audioPlayer.activeCdnId
                                audioPlayer.play(ayahs: ayahs, cdnId: cdnId, from: idx)
                            }
                        },
                        onAyahLongPressed: { ayah in
                            interactionState.longPressedAyah = ayah
                        }
                    )
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
            } else {
                VStack(spacing: 14) {
                    ProgressView().tint(Theme.gold).scaleEffect(1.3)
                    Text("جاري تحميل الصفحة \(page)...")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .onAppear {
            cache.load(page)
            if showTranslation { translationCache.load(page: page, key: translationKey) }
        }
        .onChange(of: showTranslation) { on in
            if on { translationCache.load(page: page, key: translationKey) }
        }
        .onChange(of: translationKey) { key in
            if showTranslation { translationCache.load(page: page, key: key) }
        }
    }
}

// MARK: - Book Pager (UIPageViewController pageCurl)

struct QuranBookPager: UIViewControllerRepresentable {
    @Binding var currentPage: Int
    @ObservedObject var cache: QuranPageCache
    @ObservedObject var audioPlayer: PageAudioPlayer
    @ObservedObject var interactionState: QuranPageInteractionState
    var onPageChange: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pvc = UIPageViewController(
            transitionStyle: .pageCurl,
            navigationOrientation: .horizontal,
            options: [UIPageViewController.OptionsKey.spineLocation:
                        UIPageViewController.SpineLocation.max.rawValue]
        )
        pvc.dataSource = context.coordinator
        pvc.delegate   = context.coordinator
        pvc.view.backgroundColor = .clear
        for v in pvc.view.subviews { v.backgroundColor = .clear }

        let initial = context.coordinator.makeHosting(for: currentPage)
        pvc.setViewControllers([initial], direction: .forward, animated: false)
        context.coordinator.shown = currentPage
        cache.preload(around: currentPage)
        return pvc
    }

    func updateUIViewController(_ pvc: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        let coord = context.coordinator
        guard coord.shown != currentPage else { return }
        let dir: UIPageViewController.NavigationDirection =
            currentPage > coord.shown ? .forward : .reverse
        pvc.setViewControllers([coord.makeHosting(for: currentPage)],
                               direction: dir, animated: true)
        coord.shown = currentPage
        cache.preload(around: currentPage)
    }

    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: QuranBookPager
        var shown:  Int

        init(_ p: QuranBookPager) { parent = p; shown = p.currentPage }

        func makeHosting(for page: Int) -> UIHostingController<QuranSinglePageView> {
            let view = QuranSinglePageView(page: page,
                                          cache: parent.cache,
                                          audioPlayer: parent.audioPlayer,
                                          interactionState: parent.interactionState)
            let hc = UIHostingController(rootView: view)
            hc.view.tag             = page
            hc.view.backgroundColor = .clear
            return hc
        }

        func pageViewController(_ pvc: UIPageViewController,
                                viewControllerBefore vc: UIViewController) -> UIViewController? {
            let p = vc.view.tag; guard p > 1   else { return nil }
            parent.cache.load(p - 1); return makeHosting(for: p - 1)
        }
        func pageViewController(_ pvc: UIPageViewController,
                                viewControllerAfter vc: UIViewController) -> UIViewController? {
            let p = vc.view.tag; guard p < 604 else { return nil }
            parent.cache.load(p + 1); return makeHosting(for: p + 1)
        }
        func pageViewController(_ pvc: UIPageViewController,
                                didFinishAnimating _: Bool,
                                previousViewControllers _: [UIViewController],
                                transitionCompleted completed: Bool) {
            guard completed, let vc = pvc.viewControllers?.first else { return }
            let newPage = vc.view.tag
            shown = newPage
            parent.onPageChange(newPage)
            parent.cache.preload(around: newPage)
        }
    }
}

// MARK: - Main Reader View

struct QuranReaderView: View {
    let surah: Surah

    @State private var currentPage: Int
    @State private var showReciterPicker      = false
    @State private var showTafsir             = false
    @State private var showAudioControls      = false
    @State private var showTranslationPicker  = false
    @State private var selectedReciter        = allReciters[0]
    @StateObject private var audioPlayer      = PageAudioPlayer()
    @StateObject private var pageCache        = QuranPageCache()
    @StateObject private var interactionState = QuranPageInteractionState()
    @ObservedObject private var offlineCache  = QuranOfflineCacheManager.shared
    @State private var analysisAyah: AyahData? = nil
    @State private var bookmarkedPage          = 0
    @State private var showBookmarkDone        = false
    @AppStorage("quranFontSize")    private var fontSize: Double = 22
    @AppStorage("showTranslation")  private var showTranslation  = false
    @AppStorage("translationKey")   private var translationKey   = "en.sahih"
    @Environment(\.dismiss) private var dismiss

    private let minFont: Double = 16
    private let maxFont: Double = 34

    private var bookmarkKey: String { "bookmark_\(surah.id)" }
    private var lastPageKey: String  { "lastPage_\(surah.id)" }
    private var currentSurahName: String {
        pageCache.pages[currentPage]?.first?.surah.name ?? surah.name
    }
    private var pageAyahs: [AyahData] { pageCache.pages[currentPage] ?? [] }

    init(surah: Surah) {
        self.surah = surah
        let saved = UserDefaults.standard.integer(forKey: "lastPage_\(surah.id)")
        _currentPage    = State(initialValue: saved > 0 ? saved : surah.page)
        _bookmarkedPage = State(initialValue: UserDefaults.standard.integer(forKey: "bookmark_\(surah.id)"))
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {

                // ── Header ────────────────────────────────────────────────
                HStack(spacing: 12) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Theme.gold)
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text(currentSurahName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Theme.goldLight)
                        Text("صفحة \(currentPage) من 604")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        // Font size A- / A+
                        HStack(spacing: 0) {
                            Button(action: { if fontSize > minFont { fontSize -= 1 } }) {
                                Text("أ-")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(fontSize > minFont ? Theme.gold : Theme.gold.opacity(0.3))
                                    .frame(width: 28, height: 28)
                            }
                            Button(action: { if fontSize < maxFont { fontSize += 1 } }) {
                                Text("أ+")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(fontSize < maxFont ? Theme.gold : Theme.gold.opacity(0.3))
                                    .frame(width: 28, height: 28)
                            }
                        }
                        .background(Theme.card).cornerRadius(8)

                        Button(action: toggleBookmark) {
                            Image(systemName: bookmarkedPage == currentPage ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 18))
                                .foregroundColor(bookmarkedPage == currentPage ? Theme.gold : Theme.gold.opacity(0.5))
                        }
                        if bookmarkedPage > 0 && bookmarkedPage != currentPage {
                            Button(action: { jumpToPage(bookmarkedPage) }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.uturn.backward").font(.system(size: 11))
                                    Text("ص \(bookmarkedPage)").font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundColor(Theme.background)
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .background(Theme.gold).cornerRadius(8)
                            }
                        }
                        // Translation toggle (tap = on/off, long-press = pick language)
                        Button(action: { showTranslation.toggle() }) {
                            Text("EN")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(showTranslation ? Theme.background : Theme.gold)
                                .frame(width: 32, height: 28)
                                .background(showTranslation ? Theme.gold : Theme.card)
                                .cornerRadius(8)
                        }
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                                showTranslationPicker = true
                            }
                        )

                        Button(action: { showTafsir.toggle() }) {
                            Image(systemName: "text.book.closed").font(.system(size: 18))
                                .foregroundColor(Theme.gold)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Theme.card)

                // ── Offline download progress bar ─────────────────────────
                if offlineCache.isDownloading {
                    VStack(spacing: 2) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Theme.gold.opacity(0.15))
                                Rectangle()
                                    .fill(Theme.gold.opacity(0.8))
                                    .frame(width: geo.size.width * CGFloat(offlineCache.progress))
                                    .animation(.linear(duration: 0.3), value: offlineCache.progress)
                            }
                        }
                        .frame(height: 3)
                        Text("تحميل القرآن للاستخدام بدون إنترنت • \(offlineCache.downloadedPages)/\(offlineCache.totalPages)")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.bottom, 3)
                    }
                    .background(Theme.card)
                }

                // ── Page Curl ─────────────────────────────────────────────
                QuranBookPager(
                    currentPage: $currentPage,
                    cache: pageCache,
                    audioPlayer: audioPlayer,
                    interactionState: interactionState,
                    onPageChange: { newPage in
                        currentPage = newPage
                        UserDefaults.standard.set(newPage, forKey: lastPageKey)
                        // Keep home_lastSurahId in sync so HomeView always shows
                        // the correct surah when returning from reading
                        UserDefaults.standard.set(surah.id, forKey: "home_lastSurahId")
                        // Record for reading stats (fixes zeros in stats screen)
                        ReadingStatsService.shared.recordPageRead()
                        // Stop audio when turning page (user can restart on new page)
                        audioPlayer.stop()
                    }
                )

                // ── Bottom Bar ────────────────────────────────────────────
                VStack(spacing: 0) {
                    Divider().background(Theme.border)
                    HStack(alignment: .center, spacing: 12) {

                        // Reciter picker
                        Button(action: { showReciterPicker.toggle() }) {
                            HStack(spacing: 5) {
                                Image(systemName: "person.wave.2").font(.system(size: 12))
                                Text(selectedReciter.name)
                                    .font(.system(size: 12, weight: .medium)).lineLimit(1)
                                Image(systemName: "chevron.up").font(.system(size: 9))
                            }
                            .foregroundColor(Theme.gold)
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .background(Theme.card).cornerRadius(8)
                        }

                        Spacer()

                        // Page navigation
                        HStack(spacing: 10) {
                            Button(action: { changePage(by: +1) }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(currentPage < 604 ? Theme.gold : Theme.gold.opacity(0.3))
                                    .frame(width: 36, height: 36)
                                    .background(Theme.card).cornerRadius(8)
                            }.disabled(currentPage >= 604)

                            Text("\(currentPage)/604")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Theme.text).frame(minWidth: 58)

                            Button(action: { changePage(by: -1) }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(currentPage > 1 ? Theme.gold : Theme.gold.opacity(0.3))
                                    .frame(width: 36, height: 36)
                                    .background(Theme.card).cornerRadius(8)
                            }.disabled(currentPage <= 1)
                        }

                        // Play button + Controls button stacked
                        VStack(spacing: 4) {
                            Button(action: {
                                if pageAyahs.isEmpty { return }
                                if audioPlayer.currentAyahNumber != nil {
                                    audioPlayer.togglePlay()
                                } else {
                                    audioPlayer.play(ayahs: pageAyahs, cdnId: selectedReciter.cdnId)
                                }
                            }) {
                                ZStack {
                                    if audioPlayer.isLoading {
                                        ProgressView().tint(Theme.background).scaleEffect(0.8)
                                    } else {
                                        Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(Theme.background)
                                            .offset(x: audioPlayer.isPlaying ? 0 : 2)
                                    }
                                }
                                .frame(width: 44, height: 44)
                                .background(Theme.gold)
                                .clipShape(Circle())
                            }

                            // Controls sheet trigger
                            Button(action: { showAudioControls.toggle() }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.system(size: 10))
                                    Text("تحكم")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundColor(showAudioControls ? Theme.gold : Theme.gold.opacity(0.55))
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 6)
                    .background(Theme.background)
                }
            }
        }
        .navigationBarHidden(true)
        .overlay(alignment: .top) {
            if showBookmarkDone {
                HStack(spacing: 8) {
                    Image(systemName: "bookmark.fill").foregroundColor(Theme.gold)
                    Text("تم حفظ الإشارة في صفحة \(bookmarkedPage)")
                        .font(.system(size: 13, weight: .medium)).foregroundColor(Theme.text)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Theme.card).cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.gold.opacity(0.4), lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                .padding(.top, 70)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(), value: showBookmarkDone)
            }
        }
        .onChange(of: showBookmarkDone) { shown in
            if shown { DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { showBookmarkDone = false } } }
        }
        .onAppear {
            pageCache.preload(around: currentPage)
            UserDefaults.standard.set(currentPage, forKey: lastPageKey)
            UserDefaults.standard.set(surah.id, forKey: "home_lastSurahId")
            bookmarkedPage = UserDefaults.standard.integer(forKey: bookmarkKey)
            NotificationManager.shared.recordQuranRead()
        }
        .sheet(isPresented: $showTranslationPicker) {
            TranslationPickerSheet(selectedKey: $translationKey, isShowing: $showTranslation)
        }
        .sheet(isPresented: $showReciterPicker) {
            ReciterPickerSheet(selectedReciter: $selectedReciter,
                               audioPlayer: audioPlayer, surahId: surah.id)
        }
        .sheet(isPresented: $showTafsir) {
            TafsirView(pageNumber: currentPage, pageAyahs: pageAyahs)
        }
        .sheet(isPresented: $showAudioControls) {
            AudioControlsSheet(player: audioPlayer, pageAyahs: pageAyahs, reciter: selectedReciter)
        }
        .sheet(item: $analysisAyah) { ayah in
            VerseAnalysisSheet(ayah: ayah)
                .onDisappear { interactionState.longPressedAyah = nil }
        }
        .onChange(of: interactionState.longPressedAyah) { ayah in
            if let ayah = ayah { analysisAyah = ayah }
        }
        .onDisappear { audioPlayer.stop() }
        // Auto-advance to next page when page's ayahs finish
        .onChange(of: audioPlayer.pageCompleted) { completed in
            guard completed else { return }
            audioPlayer.pageCompleted = false
            changePage(by: +1)
        }
    }

    private func changePage(by delta: Int) {
        let next = currentPage + delta
        guard next >= 1 && next <= 604 else { return }
        jumpToPage(next)
    }

    private func jumpToPage(_ page: Int) {
        currentPage = page
        UserDefaults.standard.set(page, forKey: lastPageKey)
    }

    private func toggleBookmark() {
        if bookmarkedPage == currentPage {
            bookmarkedPage = 0
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
        } else {
            bookmarkedPage = currentPage
            UserDefaults.standard.set(currentPage, forKey: bookmarkKey)
            showBookmarkDone = true
        }
    }
}

// MARK: - Audio Controls Sheet

struct AudioControlsSheet: View {
    @ObservedObject var player: PageAudioPlayer
    let pageAyahs: [AyahData]
    let reciter: Reciter

    // Local slider value while dragging
    @State private var sliderValue: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 14)

            // ── Ayah info ─────────────────────────────────────────────
            VStack(spacing: 4) {
                if let info = player.currentAyahInfo {
                    Text(info.surah.name)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                    Text("الآية \(num(info.numberInSurah))")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Theme.goldLight)
                    Text("\(num(player.currentIndex + 1)) / \(num(player.totalCount)) آية")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                } else {
                    Image(systemName: "waveform")
                        .font(.system(size: 24))
                        .foregroundColor(Theme.gold.opacity(0.4))
                        .padding(.top, 6)
                    Text("اضغط تشغيل لبدء قراءة الصفحة")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .padding(.top, 16).padding(.bottom, 14)

            // ── Seek bar ──────────────────────────────────────────────
            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { player.isSeeking ? sliderValue : player.progress },
                        set: { newVal in
                            sliderValue = newVal
                            player.isSeeking = true
                        }
                    ),
                    in: 0...1
                ) { editing in
                    if !editing {
                        player.seek(to: sliderValue)
                    }
                }
                .accentColor(Theme.gold)
                .disabled(player.duration <= 0)

                HStack {
                    Text(formatTime(player.isSeeking ? sliderValue * player.duration : player.currentTime))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text(formatTime(player.duration))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            // ── Controls ──────────────────────────────────────────────
            HStack(spacing: 0) {

                // Previous ayah
                Button(action: { player.previous() }) {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 22))
                        .foregroundColor(player.canPrevious ? Theme.gold : Theme.gold.opacity(0.2))
                        .frame(width: 52, height: 52)
                }
                .disabled(!player.canPrevious)

                // Rewind 15s
                Button(action: { player.skip(by: -15) }) {
                    VStack(spacing: 1) {
                        Image(systemName: "gobackward.15")
                            .font(.system(size: 24))
                    }
                    .foregroundColor(player.duration > 0 ? Theme.gold : Theme.gold.opacity(0.2))
                    .frame(width: 52, height: 52)
                }
                .disabled(player.duration <= 0)

                // Play / Pause
                Button(action: {
                    if player.currentAyahNumber == nil {
                        player.play(ayahs: pageAyahs, cdnId: reciter.cdnId)
                    } else {
                        player.togglePlay()
                    }
                }) {
                    ZStack {
                        Circle().fill(Theme.gold).frame(width: 64, height: 64)
                        if player.isLoading {
                            ProgressView().tint(Theme.background).scaleEffect(1.0)
                        } else {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Theme.background)
                                .offset(x: player.isPlaying ? 0 : 2)
                        }
                    }
                }
                .frame(width: 64)
                .padding(.horizontal, 16)

                // Forward 15s
                Button(action: { player.skip(by: 15) }) {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 24))
                        .foregroundColor(player.duration > 0 ? Theme.gold : Theme.gold.opacity(0.2))
                        .frame(width: 52, height: 52)
                }
                .disabled(player.duration <= 0)

                // Next ayah
                Button(action: { player.next() }) {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 22))
                        .foregroundColor(player.canNext ? Theme.gold : Theme.gold.opacity(0.2))
                        .frame(width: 52, height: 52)
                }
                .disabled(!player.canNext)
            }
            .padding(.bottom, 12)

            // ── Playback mode toggles ──────────────────────────────
            VStack(spacing: 0) {
                // Repeat page
                Button {
                    player.repeatPage.toggle()
                    if player.repeatPage { player.autoNextPage = false }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(player.repeatPage ? Theme.gold.opacity(0.18) : Theme.card)
                                .frame(width: 34, height: 34)
                            Image(systemName: "repeat")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(player.repeatPage ? Theme.gold : Theme.textSecondary)
                        }
                        Text("إعادة تشغيل الصفحة")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(player.repeatPage ? Theme.text : Theme.textSecondary)
                        Spacer()
                        Image(systemName: player.repeatPage ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundColor(player.repeatPage ? Theme.gold : Theme.textSecondary)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().background(Theme.border).padding(.leading, 68)

                // Auto-next page
                Button {
                    player.autoNextPage.toggle()
                    if player.autoNextPage { player.repeatPage = false }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(player.autoNextPage ? Theme.gold.opacity(0.18) : Theme.card)
                                .frame(width: 34, height: 34)
                            Image(systemName: "forward.end.alt.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(player.autoNextPage ? Theme.gold : Theme.textSecondary)
                        }
                        Text("الانتقال التلقائي للصفحة التالية")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(player.autoNextPage ? Theme.text : Theme.textSecondary)
                        Spacer()
                        Image(systemName: player.autoNextPage ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundColor(player.autoNextPage ? Theme.gold : Theme.textSecondary)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .background(Theme.card)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.hidden)
    }

    private func num(_ n: Int) -> String {
        let d = ["٠","١","٢","٣","٤","٥","٦","٧","٨","٩"]
        return String(n).compactMap { d[Int(String($0)) ?? 0] }.joined()
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let s = Int(seconds)
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }
}

// MARK: - Page Content

struct QuranPageContent: View {
    let ayahs: [AyahData]
    let fontSize: Double
    let activeAyahNumber: Int?
    var showTranslation: Bool                    = false
    var translationMap: [Int: String]?           = nil   // [absoluteAyahNumber: text]
    var onAyahTapped: ((AyahData) -> Void)?      = nil
    var onAyahLongPressed: ((AyahData) -> Void)? = nil

    private var groupedBySurah: [(SurahInfo, [AyahData])] {
        var result: [(SurahInfo, [AyahData])] = []
        var cur: (SurahInfo, [AyahData])? = nil
        for ayah in ayahs {
            if cur == nil || cur?.0.number != ayah.surah.number {
                if let c = cur { result.append(c) }
                cur = (ayah.surah, [ayah])
            } else { cur?.1.append(ayah) }
        }
        if let c = cur { result.append(c) }
        return result
    }

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            ForEach(groupedBySurah, id: \.0.number) { surahInfo, surahAyahs in
                if surahAyahs.first?.numberInSurah == 1 {
                    SurahHeaderCard(surahInfo: surahInfo).frame(maxWidth: .infinity)
                }
                let stripBasmala = surahAyahs.first?.numberInSurah == 1
                    && surahInfo.number != 1 && surahInfo.number != 9
                QuranTextBlock(
                    ayahs: surahAyahs,
                    stripBasmala: stripBasmala,
                    fontSize: fontSize,
                    activeAyahNumber: activeAyahNumber,
                    onAyahTapped: onAyahTapped,
                    onAyahLongPressed: onAyahLongPressed
                )
                .frame(maxWidth: .infinity)

                if showTranslation {
                    TranslationBlock(
                        ayahs: surahAyahs,
                        translations: translationMap ?? [:]
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Translation Block

private struct TranslationBlock: View {
    let ayahs: [AyahData]
    let translations: [Int: String]   // [absoluteAyahNumber: text]

    var body: some View {
        VStack(spacing: 0) {
            // Header divider
            HStack(spacing: 6) {
                Rectangle().fill(Color(red: 0.86, green: 0.71, blue: 0.35).opacity(0.35)).frame(height: 1)
                Image(systemName: "globe").font(.system(size: 9)).foregroundColor(Color(red: 0.86, green: 0.71, blue: 0.35).opacity(0.6))
                Rectangle().fill(Color(red: 0.86, green: 0.71, blue: 0.35).opacity(0.35)).frame(height: 1)
            }
            .padding(.bottom, 8)

            if translations.isEmpty {
                HStack {
                    ProgressView().scaleEffect(0.7).tint(Theme.textSecondary)
                    Text("جاري تحميل الترجمة…")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(ayahs) { ayah in
                        if let text = translations[ayah.number] {
                            HStack(alignment: .top, spacing: 8) {
                                // Ayah number badge
                                Text("\(ayah.numberInSurah)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(red: 0.86, green: 0.71, blue: 0.35))
                                    .frame(minWidth: 22, minHeight: 22)
                                    .background(
                                        Circle().fill(Color(red: 0.86, green: 0.71, blue: 0.35).opacity(0.12))
                                    )
                                    .padding(.top, 1)
                                Text(text)
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.text.opacity(0.8))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            if ayah.number != ayahs.last?.number {
                                Divider().background(Theme.border.opacity(0.5))
                            }
                        }
                    }
                }
                .padding(12)
                .background(Theme.card.opacity(0.6))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(red: 0.86, green: 0.71, blue: 0.35).opacity(0.2), lineWidth: 1)
                )
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Surah Header Card

struct SurahHeaderCard: View {
    let surahInfo: SurahInfo

    var body: some View {
        VStack(spacing: 10) {
            dividerLine
            Text(surahInfo.name)
                .font(.custom("Amiri", size: 28)).foregroundColor(Theme.goldLight)
            Text(surahInfo.revelationType == "Meccan" ? "مكية" : "مدنية")
                .font(.system(size: 12)).foregroundColor(Theme.gold)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(Theme.gold.opacity(0.15)).cornerRadius(10)
            if surahInfo.number != 9 && surahInfo.number != 1 {
                Text("بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ")
                    .font(.custom("Amiri", size: 22)).foregroundColor(Theme.gold)
                    .multilineTextAlignment(.center).padding(.vertical, 4)
            }
            dividerLine
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14).padding(.horizontal, 16)
        .background(Theme.card).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.gold.opacity(0.25), lineWidth: 1))
    }

    private var dividerLine: some View {
        HStack {
            Rectangle().fill(Theme.gold.opacity(0.3)).frame(height: 1)
            Image(systemName: "star.fill").font(.system(size: 8)).foregroundColor(Theme.gold.opacity(0.7))
            Rectangle().fill(Theme.gold.opacity(0.3)).frame(height: 1)
        }
    }
}

// MARK: - Quran Text Block
//
// UITextView + NSAttributedString for proper Arabic ligatures.
// Highlights the currently-playing ayah with a gold tint background.
// Responds to font-size changes immediately via @AppStorage.

struct QuranTextBlock: UIViewRepresentable {
    let ayahs: [AyahData]
    let stripBasmala: Bool
    let fontSize: Double
    let activeAyahNumber: Int?
    var onAyahTapped: ((AyahData) -> Void)?       = nil
    var onAyahLongPressed: ((AyahData) -> Void)?  = nil

    // MARK: Coordinator
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject {
        var parent: QuranTextBlock
        var ranges: [Int: NSRange] = [:]   // ayah.number → NSRange

        init(_ p: QuranTextBlock) { parent = p }

        func ayah(at charIndex: Int) -> AyahData? {
            for (num, range) in ranges {
                if charIndex >= range.location && charIndex < NSMaxRange(range) {
                    return parent.ayahs.first { $0.number == num }
                }
            }
            return nil
        }

        private func charIndex(in tv: UITextView, at point: CGPoint) -> Int? {
            let inset = tv.textContainerInset
            let adjusted = CGPoint(x: point.x - inset.left, y: point.y - inset.top)
            let lm = tv.layoutManager
            let tc = tv.textContainer
            var fraction: CGFloat = 0
            let glyph = lm.glyphIndex(for: adjusted, in: tc, fractionOfDistanceThroughGlyph: &fraction)
            guard glyph < lm.numberOfGlyphs else { return nil }
            return lm.characterIndexForGlyph(at: glyph)
        }

        @objc func handleTap(_ gr: UITapGestureRecognizer) {
            guard gr.state == .ended, let tv = gr.view as? UITextView else { return }
            if let idx = charIndex(in: tv, at: gr.location(in: tv)), let ayah = ayah(at: idx) {
                DispatchQueue.main.async { self.parent.onAyahTapped?(ayah) }
            }
        }

        @objc func handleLongPress(_ gr: UILongPressGestureRecognizer) {
            guard gr.state == .began, let tv = gr.view as? UITextView else { return }
            if let idx = charIndex(in: tv, at: gr.location(in: tv)), let ayah = ayah(at: idx) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                DispatchQueue.main.async { self.parent.onAyahLongPressed?(ayah) }
            }
        }
    }

    private func arabicNumber(_ n: Int) -> String {
        let map: [Character: Character] = [
            "0":"٠","1":"١","2":"٢","3":"٣","4":"٤",
            "5":"٥","6":"٦","7":"٧","8":"٨","9":"٩"
        ]
        return String(String(n).map { map[$0] ?? $0 })
    }

    private static let basmalaPrefixes = [
        "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ",
        "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
        "بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ",
        "بسم الله الرحمن الرحيم"
    ]

    private func cleanText(_ text: String, isFirst: Bool) -> String {
        guard stripBasmala && isFirst else { return text }
        for p in Self.basmalaPrefixes {
            if text.hasPrefix(p) {
                return String(text.dropFirst(p.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return text
    }

    // Builds the attributed string AND returns a range map (globalAyahNumber → NSRange)
    private func buildAttributedString(darkMode: Bool) -> (NSMutableAttributedString, [Int: NSRange]) {
        let qSize     = CGFloat(fontSize)
        let nSize     = CGFloat(fontSize * 0.74)
        let quranFont = UIFont(name: "Amiri", size: qSize) ?? UIFont.systemFont(ofSize: qSize)
        let numFont   = UIFont(name: "Amiri", size: nSize) ?? UIFont.systemFont(ofSize: nSize)

        let textColor = darkMode
            ? UIColor(red: 0.95, green: 0.92, blue: 0.85, alpha: 1)
            : UIColor(red: 0.15, green: 0.10, blue: 0.05, alpha: 1)
        let goldColor = UIColor(red: 0.85, green: 0.70, blue: 0.35, alpha: 1)

        let result = NSMutableAttributedString()
        var ranges: [Int: NSRange] = [:]
        var pos = 0

        for (idx, ayah) in ayahs.enumerated() {
            let text    = cleanText(ayah.text, isFirst: idx == 0) + " "
            let numText = "\u{06DD}" + arabicNumber(ayah.numberInSurah) + " "

            let textLen = (text    as NSString).length
            let numLen  = (numText as NSString).length
            ranges[ayah.number] = NSRange(location: pos, length: textLen + numLen)
            pos += textLen + numLen

            result.append(NSAttributedString(string: text,
                attributes: [.font: quranFont, .foregroundColor: textColor]))
            result.append(NSAttributedString(string: numText,
                attributes: [.font: numFont,   .foregroundColor: goldColor]))
        }

        let para = NSMutableParagraphStyle()
        para.alignment            = .natural
        para.lineSpacing          = 8
        para.paragraphSpacing     = 2
        para.baseWritingDirection = .rightToLeft
        result.addAttribute(.paragraphStyle, value: para,
                            range: NSRange(location: 0, length: result.length))

        return (result, ranges)
    }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable             = false
        tv.isScrollEnabled        = false
        tv.backgroundColor        = .clear
        tv.textContainerInset     = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        tv.textContainer.lineFragmentPadding = 0
        tv.layer.cornerRadius     = 14
        tv.layer.borderWidth      = 1

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap))
        tap.cancelsTouchesInView = false
        tv.addGestureRecognizer(tap)

        let lp = UILongPressGestureRecognizer(target: context.coordinator,
                                              action: #selector(Coordinator.handleLongPress))
        lp.minimumPressDuration = 0.5
        tv.addGestureRecognizer(lp)

        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        context.coordinator.parent = self
        let dark = tv.traitCollection.userInterfaceStyle == .dark
        let (attrStr, ranges) = buildAttributedString(darkMode: dark)
        context.coordinator.ranges = ranges

        // Apply gold highlight on the active ayah
        if let active = activeAyahNumber, let range = ranges[active] {
            let highlight = UIColor(red: 0.85, green: 0.70, blue: 0.35, alpha: 0.22)
            attrStr.addAttribute(.backgroundColor, value: highlight, range: range)
        }

        tv.attributedText = attrStr

        if dark {
            tv.backgroundColor   = UIColor(red: 0.08, green: 0.08, blue: 0.16, alpha: 1)
            tv.layer.borderColor = UIColor(white: 1, alpha: 0.08).cgColor
        } else {
            tv.backgroundColor   = UIColor(red: 0.98, green: 0.97, blue: 0.94, alpha: 1)
            tv.layer.borderColor = UIColor(red: 0.7,  green: 0.6,  blue: 0.4,  alpha: 0.3).cgColor
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        uiView.frame = CGRect(x: 0, y: 0, width: width, height: 0)
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(fitted.height, 60))
    }
}

// MARK: - Reciter Picker Sheet

struct ReciterPickerSheet: View {
    @Binding var selectedReciter: Reciter
    @ObservedObject var audioPlayer: PageAudioPlayer
    let surahId: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text("اختر القارئ")
                        .font(.system(size: 20, weight: .bold)).foregroundColor(Theme.goldLight)
                    Spacer()
                    Button("إغلاق") { dismiss() }.foregroundColor(Theme.gold)
                }.padding(16)
                Divider().background(Theme.border)
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(allReciters) { reciter in
                            Button(action: {
                                selectedReciter = reciter
                                // If currently playing, restart with new reciter
                                if audioPlayer.isPlaying || audioPlayer.currentAyahNumber != nil {
                                    audioPlayer.stop()
                                }
                                // cdnId sync happens automatically via selectedReciter
                                dismiss()
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: selectedReciter.id == reciter.id
                                          ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20)).foregroundColor(Theme.gold)
                                    Text(reciter.name)
                                        .font(.system(size: 16,
                                            weight: selectedReciter.id == reciter.id ? .bold : .regular))
                                        .foregroundColor(Theme.text)
                                    Spacer()
                                }
                                .padding(.horizontal, 16).padding(.vertical, 12)
                                .background(selectedReciter.id == reciter.id ? Theme.card : Color.clear)
                                .cornerRadius(10).contentShape(Rectangle())
                            }
                        }
                    }.padding(8)
                }
            }
        }
    }
}

// MARK: - Verse Analysis Sheet
// Shown on long-press of any ayah. Fetches tafsir, translation, and word meanings live.

struct VerseAnalysisSheet: View {
    let ayah: AyahData
    @Environment(\.dismiss) private var dismiss

    enum AnalysisTab: String, CaseIterable {
        case tafsir      = "تفسير"
        case translation = "ترجمة"
        case words       = "معاني الكلمات"
        case morphology  = "الصرف والنحو"
        case similar     = "المتشابهات"
        case info        = "معلومات"
    }

    @State private var selectedTab: AnalysisTab = .tafsir
    @State private var tafsirText       = ""
    @State private var translationText  = ""
    @State private var wordMeanings: [WordMeaning] = []
    @State private var similarVerses: [SimilarVerse] = []
    @State private var isLoadingTafsir       = true
    @State private var isLoadingTranslation  = true
    @State private var isLoadingWords        = true
    @State private var isLoadingSimilar      = true
    @State private var tafsirEdition = "ar.muyassar"

    struct WordMeaning: Identifiable {
        let id = UUID()
        let word: String           // Arabic
        let transliteration: String
        let root: String
        let pos: String            // part of speech (English tag)
        let english: String        // meaning
    }

    struct SimilarVerse: Identifiable {
        let id: String             // "surah:verse"
        let arabicText: String
        let surahName: String
        let verseNum: Int
    }

    private let tafsirEditions: [(id: String, name: String)] = [
        ("ar.muyassar",  "التفسير الميسر"),
        ("ar.jalalayn",  "تفسير الجلالين"),
        ("ar.maududi",   "في ظلال القرآن"),
        ("en.sahih",     "Saheeh International"),
        ("en.pickthall", "Pickthall"),
        ("ur.jalandhry", "اردو – جالندھری"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 0) {

                    // ── Ayah text header ─────────────────────────────
                    VStack(spacing: 6) {
                        Text(ayah.surah.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                        Text(ayah.text)
                            .font(.custom("Amiri", size: 20))
                            .foregroundColor(Theme.goldLight)
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .padding(.horizontal, 16)
                        Text("الآية \(arabicNum(ayah.numberInSurah))")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.gold)
                    }
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(Theme.card)

                    // ── Tab bar ──────────────────────────────────────
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(AnalysisTab.allCases, id: \.self) { tab in
                                Button(action: { selectedTab = tab }) {
                                    Text(tab.rawValue)
                                        .font(.system(size: 13, weight: selectedTab == tab ? .bold : .regular))
                                        .foregroundColor(selectedTab == tab ? Theme.background : Theme.text)
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(selectedTab == tab ? Theme.gold : Theme.card)
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                    }
                    .background(Theme.background)

                    Divider().background(Theme.border)

                    // ── Content ──────────────────────────────────────
                    ScrollView {
                        Group {
                            switch selectedTab {
                            case .tafsir:      tafsirTab
                            case .translation: translationTab
                            case .words:       wordsTab
                            case .morphology:  morphologyTab
                            case .similar:     similarTab
                            case .info:        infoTab
                            }
                        }
                        .padding(16)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("تحليل الآية")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إغلاق") { dismiss() }
                        .foregroundColor(Theme.gold)
                }
            }
        }
        .onAppear {
            fetchTafsir()
            fetchTranslation()
            fetchWordMeanings()
            fetchSimilarVerses()
        }
        .onChange(of: tafsirEdition) { _ in
            isLoadingTafsir = true
            tafsirText = ""
            fetchTafsir()
        }
    }

    // MARK: - Tafsir Tab

    private var tafsirTab: some View {
        VStack(alignment: .trailing, spacing: 16) {
            // Edition picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tafsirEditions, id: \.id) { ed in
                        Button(action: { tafsirEdition = ed.id }) {
                            Text(ed.name)
                                .font(.system(size: 12, weight: tafsirEdition == ed.id ? .bold : .regular))
                                .foregroundColor(tafsirEdition == ed.id ? Theme.background : Theme.gold)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(tafsirEdition == ed.id
                                            ? Theme.gold : Theme.gold.opacity(0.12))
                                .cornerRadius(16)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }

            if isLoadingTafsir {
                loadingView("جاري تحميل التفسير...")
            } else if tafsirText.isEmpty {
                emptyView("لم يتوفر التفسير لهذه الآية")
            } else {
                Text(tafsirText)
                    .font(.system(size: 16))
                    .foregroundColor(Theme.text)
                    .multilineTextAlignment(.trailing)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(14)
                    .background(Theme.card)
                    .cornerRadius(12)
            }
        }
    }

    // MARK: - Translation Tab

    private var translationTab: some View {
        VStack(alignment: .trailing, spacing: 12) {
            if isLoadingTranslation {
                loadingView("جاري تحميل الترجمة...")
            } else if translationText.isEmpty {
                emptyView("لم تتوفر الترجمة")
            } else {
                VStack(alignment: .trailing, spacing: 8) {
                    Text("الترجمة الإنجليزية")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                    Text(translationText)
                        .font(.system(size: 15))
                        .foregroundColor(Theme.text)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
                .background(Theme.card)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Word Meanings Tab

    private var wordsTab: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if isLoadingWords {
                loadingView("جاري تحليل الكلمات...")
            } else if wordMeanings.isEmpty {
                emptyView("لم تتوفر معاني الكلمات")
            } else {
                ForEach(wordMeanings) { w in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            if !w.pos.isEmpty {
                                Text(arabicPOS(w.pos))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(posColor(w.pos))
                                    .cornerRadius(4)
                            }
                            Text(w.english)
                                .font(.system(size: 13))
                                .foregroundColor(Theme.text)
                            if !w.transliteration.isEmpty {
                                Text(w.transliteration)
                                    .font(.system(size: 11, design: .serif))
                                    .foregroundColor(Theme.textSecondary)
                                    .italic()
                            }
                        }
                        Spacer()
                        Text(w.word)
                            .font(.custom("Amiri", size: 24))
                            .foregroundColor(Theme.goldLight)
                    }
                    .padding(12)
                    .background(Theme.card)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                }
            }
        }
    }

    // MARK: - Morphology Tab

    private var morphologyTab: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if isLoadingWords {
                loadingView("جاري تحليل الصرف والنحو...")
            } else if wordMeanings.isEmpty {
                emptyView("لم تتوفر بيانات الصرف والنحو")
            } else {
                // Header
                Text("تحليل مفردات الآية")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                ForEach(Array(wordMeanings.enumerated()), id: \.element.id) { idx, w in
                    VStack(alignment: .trailing, spacing: 8) {
                        // Arabic word + number
                        HStack {
                            Text(arabicPOS(w.pos))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(posColor(w.pos))
                                .cornerRadius(12)
                            Spacer()
                            HStack(spacing: 8) {
                                Text("الكلمة \(arabicNum(idx + 1))")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textSecondary)
                                Text(w.word)
                                    .font(.custom("Amiri", size: 26))
                                    .foregroundColor(Theme.goldLight)
                            }
                        }
                        Divider().background(Theme.border)
                        // Details grid
                        VStack(spacing: 4) {
                            morphRow(label: "المعنى", value: w.english)
                            if !w.transliteration.isEmpty {
                                morphRow(label: "النطق", value: w.transliteration)
                            }
                            morphRow(label: "نوع الكلمة", value: arabicPOS(w.pos))
                        }
                    }
                    .padding(12)
                    .background(Theme.card)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(posColor(w.pos).opacity(0.3), lineWidth: 1))
                }
            }
        }
    }

    private func morphRow(label: String, value: String) -> some View {
        HStack {
            Text(value)
                .font(.system(size: 13))
                .foregroundColor(Theme.text)
                .multilineTextAlignment(.leading)
            Spacer()
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
        }
    }

    // MARK: - Similar Verses Tab

    private var similarTab: some View {
        VStack(alignment: .trailing, spacing: 12) {
            if isLoadingSimilar {
                loadingView("جاري البحث عن الآيات المشابهة...")
            } else if similarVerses.isEmpty {
                emptyView("لم تُوجد آيات مشابهة")
            } else {
                Text("آيات تحمل ألفاظاً مشابهة")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                ForEach(similarVerses) { v in
                    VStack(alignment: .trailing, spacing: 8) {
                        Text(v.arabicText)
                            .font(.custom("Amiri", size: 18))
                            .foregroundColor(Theme.text)
                            .multilineTextAlignment(.trailing)
                            .lineSpacing(5)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        HStack {
                            Text(v.id)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Theme.gold.opacity(0.6))
                            Spacer()
                            Text("\(v.surahName) • الآية \(arabicNum(v.verseNum))")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.gold)
                        }
                    }
                    .padding(14)
                    .background(Theme.card)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                }
            }
        }
    }

    // MARK: - Info Tab

    private var infoTab: some View {
        VStack(alignment: .trailing, spacing: 12) {
            infoCard("السورة", value: ayah.surah.name)
            infoCard("رقم الآية", value: "\(arabicNum(ayah.numberInSurah)) من السورة")
            infoCard("الآية العالمية", value: arabicNum(ayah.number))
            infoCard("الجزء", value: ayah.juz.map { arabicNum($0) } ?? "—")
            infoCard("نوع السورة",
                     value: ayah.surah.revelationType == "Meccan" ? "مكية 🕋" : "مدنية 🕌")
            infoCard("اسم السورة بالإنجليزية", value: ayah.surah.englishName)
        }
    }

    // MARK: - Helper views

    private func loadingView(_ msg: String) -> some View {
        HStack(spacing: 10) {
            ProgressView().tint(Theme.gold)
            Text(msg).font(.system(size: 14)).foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(20)
    }

    private func emptyView(_ msg: String) -> some View {
        Text(msg)
            .font(.system(size: 14))
            .foregroundColor(Theme.textSecondary)
            .frame(maxWidth: .infinity).padding(20)
    }

    private func infoCard(_ label: String, value: String) -> some View {
        HStack {
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.text)
            Spacer()
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Theme.card)
        .cornerRadius(10)
    }

    private func comingSoonCard(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(Theme.gold.opacity(0.5))
                .frame(width: 50)
            VStack(alignment: .trailing, spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.text)
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Theme.card)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.gold.opacity(0.2), lineWidth: 1)
        )
    }

    private func posColor(_ pos: String) -> Color {
        switch pos.lowercased() {
        case let s where s.contains("verb"):   return .blue
        case let s where s.contains("noun"):   return .green
        case let s where s.contains("prep"):   return .orange
        case let s where s.contains("pron"):   return .purple
        case let s where s.contains("part"):   return .pink
        default: return Theme.gold
        }
    }

    private func arabicNum(_ n: Int) -> String {
        let map: [Character: Character] = [
            "0":"٠","1":"١","2":"٢","3":"٣","4":"٤",
            "5":"٥","6":"٦","7":"٧","8":"٨","9":"٩"
        ]
        return String(String(n).map { map[$0] ?? $0 })
    }

    // MARK: - API calls

    /// Map alquran.cloud edition ID → our server's tafsir ID (nil if not available)
    private func ownServerTafsirId(for edition: String) -> String? {
        switch edition {
        case "ar.muyassar":  return "muyassar"   // ✅ 6236 entries imported
        case "ar.jalalayn":  return "jalalayn"    // pending import
        case "ar.ibk":       return "ibn-kathir"  // pending import
        default:             return nil
        }
    }

    private func fetchTafsir() {
        let sura  = ayah.surah.number
        let verse = ayah.numberInSurah

        // ✅ Try our own server first
        if let ownId = ownServerTafsirId(for: tafsirEdition),
           let ownUrl = URL(string:
               "https://quran.meshari.tech/api/tafsir.php?action=verse&sura=\(sura)&verse=\(verse)&tafsir=\(ownId)") {
            URLSession.shared.dataTask(with: ownUrl) { [self] data, _, _ in
                DispatchQueue.main.async {
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let ok   = json["success"] as? Bool, ok,
                       let row  = json["data"] as? [String: Any],
                       let text = row["text"] as? String {
                        isLoadingTafsir = false
                        tafsirText = text
                        return
                    }
                    // Fallback to alquran.cloud
                    self.fetchTafsirFromAlquranCloud()
                }
            }.resume()
            return
        }
        fetchTafsirFromAlquranCloud()
    }

    private func fetchTafsirFromAlquranCloud() {
        guard let url = URL(string:
            "https://api.alquran.cloud/v1/ayah/\(ayah.number)/\(tafsirEdition)")
        else { isLoadingTafsir = false; return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                isLoadingTafsir = false
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let d    = json["data"] as? [String: Any],
                      let text = d["text"] as? String
                else { return }
                tafsirText = text
            }
        }.resume()
    }

    private func fetchTranslation() {
        let sura  = ayah.surah.number
        let verse = ayah.numberInSurah

        // ✅ Try our own server first — has en.sahih for all 6236 verses
        if let ownUrl = URL(string:
            "https://quran.meshari.tech/api/quran.php?action=verse&sura=\(sura)&verse=\(verse)&translation=en.sahih") {
            URLSession.shared.dataTask(with: ownUrl) { [self] data, _, _ in
                DispatchQueue.main.async {
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let ok   = json["success"] as? Bool, ok,
                       let row  = json["data"] as? [String: Any],
                       let translations = row["translations"] as? [[String: Any]],
                       let first = translations.first,
                       let text = first["text"] as? String {
                        isLoadingTranslation = false
                        translationText = text
                        return
                    }
                    // Fallback to alquran.cloud
                    self.fetchTranslationFromAlquranCloud()
                }
            }.resume()
            return
        }
        fetchTranslationFromAlquranCloud()
    }

    private func fetchTranslationFromAlquranCloud() {
        guard let url = URL(string:
            "https://api.alquran.cloud/v1/ayah/\(ayah.number)/en.sahih")
        else { isLoadingTranslation = false; return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                isLoadingTranslation = false
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let d    = json["data"] as? [String: Any],
                      let text = d["text"] as? String
                else { return }
                translationText = text
            }
        }.resume()
    }

    private func fetchWordMeanings() {
        // quran.com v4 — word-by-word with English translation & transliteration
        let key = "\(ayah.surah.number):\(ayah.numberInSurah)"
        let urlStr = "https://api.quran.com/api/v4/verses/by_key/\(key)?words=true&word_fields=text_uthmani,translation_text,transliteration"
        guard let url = URL(string: urlStr) else { isLoadingWords = false; return }

        URLSession.shared.dataTask(with: url) { data, response, _ in
            DispatchQueue.main.async {
                isLoadingWords = false
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let verse = json["verse"] as? [String: Any],
                      let words = verse["words"] as? [[String: Any]]
                else { return }

                wordMeanings = words.compactMap { w -> WordMeaning? in
                    guard let charType = w["char_type_name"] as? String,
                          charType == "word",
                          let arabic = w["text_uthmani"] as? String
                    else { return nil }

                    let translation = (w["translation"] as? [String: Any])?["text"] as? String ?? ""
                    let translit    = (w["transliteration"] as? [String: Any])?["text"] as? String ?? ""
                    let pos         = (w["pos"] as? String) ?? ""

                    return WordMeaning(
                        word: arabic,
                        transliteration: translit,
                        root: "",
                        pos: pos,
                        english: translation
                    )
                }
            }
        }.resume()
    }

    private func fetchSimilarVerses() {
        // Search quran.com for ayahs sharing the same words
        // Use first 2 distinct Arabic words as query
        let words = ayah.text
            .components(separatedBy: CharacterSet.whitespaces)
            .map { $0.trimmingCharacters(in: CharacterSet.punctuationCharacters) }
            .filter { !$0.isEmpty }
        let query = words.prefix(2).joined(separator: " ")
        guard !query.isEmpty,
              let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.quran.com/api/v4/search?q=\(encoded)&size=7&language=ar")
        else { isLoadingSimilar = false; return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                isLoadingSimilar = false
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let search = json["search"] as? [String: Any],
                      let results = search["results"] as? [[String: Any]]
                else { return }

                let currentKey = "\(ayah.surah.number):\(ayah.numberInSurah)"
                similarVerses = results.compactMap { r -> SimilarVerse? in
                    guard let verseKey = r["verse_key"] as? String,
                          verseKey != currentKey,
                          let verseObj = r["verse"] as? [String: Any],
                          let textUthmani = verseObj["text_uthmani"] as? String
                    else { return nil }

                    let parts = verseKey.split(separator: ":")
                    let verseNum = parts.count == 2 ? Int(parts[1]) ?? 0 : 0
                    // Try to get surah name from chapter data
                    let surahNameFallback = parts.count >= 1 ? "سورة \(parts[0])" : verseKey
                    return SimilarVerse(
                        id: verseKey,
                        arabicText: textUthmani,
                        surahName: (r["chapter_name"] as? String) ?? surahNameFallback,
                        verseNum: verseNum
                    )
                }
            }
        }.resume()
    }

    // Map English POS tag → Arabic label
    private func arabicPOS(_ pos: String) -> String {
        let p = pos.lowercased()
        if p.contains("verb")          { return "فعل" }
        if p.contains("noun")          { return "اسم" }
        if p.contains("prep")          { return "حرف جر" }
        if p.contains("pron")          { return "ضمير" }
        if p.contains("part")          { return "حرف" }
        if p.contains("conj")          { return "حرف عطف" }
        if p.contains("adj")           { return "صفة" }
        if p.contains("adv")           { return "ظرف" }
        if p.contains("proper noun")   { return "علم" }
        if pos.isEmpty                 { return "كلمة" }
        return pos
    }
}

// MARK: - Translation Picker Sheet

struct TranslationPickerSheet: View {
    @Binding var selectedKey: String
    @Binding var isShowing: Bool
    @Environment(\.dismiss) private var dismiss

    private let options = QuranTranslationCatalog.options

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {

                // Header
                HStack {
                    Text("لغة الترجمة")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Theme.goldLight)
                    Spacer()
                    Button("إغلاق") { dismiss() }
                        .font(.system(size: 15))
                        .foregroundColor(Theme.gold)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider().background(Theme.border)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(options) { opt in
                            Button {
                                selectedKey = opt.key
                                isShowing   = true
                                dismiss()
                            } label: {
                                HStack(spacing: 14) {
                                    VStack(alignment: .trailing, spacing: 3) {
                                        Text(opt.name)
                                            .font(.system(size: 16))
                                            .foregroundColor(Theme.text)
                                        Text(opt.language)
                                            .font(.system(size: 12))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    Spacer()
                                    if selectedKey == opt.key {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(Theme.gold)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                            }
                            .buttonStyle(.plain)

                            if opt.id != options.last?.id {
                                Divider().background(Theme.border).padding(.leading, 16)
                            }
                        }
                    }
                    .background(Theme.card)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                    .padding(16)
                }
            }
        }
    }
}
