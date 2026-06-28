import SwiftUI

// ══════════════════════════════════════════════════════════════
// MARK: - DATA MODELS
// ══════════════════════════════════════════════════════════════

struct HBook: Identifiable, Hashable {
    let id: Int
    let name: String
    let author: String
    let deathYear: String
    let description: String
    let icon: String
    let accentColor: Color
    var hadithCount: Int { HadithStore.shared.hadiths(bookId: id).count }
    var chapterCount: Int { HadithStore.shared.chapters(bookId: id).count }
}

struct HChapter: Identifiable, Hashable {
    let id: Int
    let bookId: Int
    let number: Int
    let title: String
}

struct HHadith: Identifiable, Hashable {
    let id: Int
    let bookId: Int
    let chapterId: Int
    let number: Int
    let narrator: String
    let text: String
    let grade: String
    let reference: String
}

// ══════════════════════════════════════════════════════════════
// MARK: - IN-MEMORY DATABASE (SQLite-compatible schema in Swift)
// ══════════════════════════════════════════════════════════════
//
// Architecture: Lazy-loaded, indexed in-memory store.
// Persistence: Favorites + last-position via UserDefaults.
// Search: O(n) substring with Arabic diacritic-stripping normalization.
//
// To migrate to SQLite later: replace the arrays below with
//   sqlite3_prepare_v2 / sqlite3_step calls against the same schema.
//
// SQLite Schema (for future use):
//   CREATE TABLE hbooks (id INT PK, name TEXT, author TEXT, death_year TEXT, description TEXT, icon TEXT, accent TEXT);
//   CREATE TABLE hchapters (id INT PK, book_id INT, number INT, title TEXT);
//   CREATE TABLE hhadiths (id INT PK, book_id INT, chapter_id INT, number INT, narrator TEXT, text TEXT, grade TEXT, reference TEXT);
//   CREATE VIRTUAL TABLE hhadiths_fts USING fts5(text, narrator, content=hhadiths, content_rowid=id);
//   CREATE TABLE hfavorites (hadith_id INT PK, saved_at TEXT);
//   CREATE TABLE hpositions (book_id INT PK, hadith_id INT, updated_at TEXT);
//   CREATE INDEX idx_h_book   ON hhadiths(book_id);
//   CREATE INDEX idx_h_chap   ON hhadiths(chapter_id);
//   CREATE INDEX idx_ch_book  ON hchapters(book_id);

// ── Arabic diacritic stripping for better search matching ──
private func normalizeArabic(_ s: String) -> String {
    // Strip tashkeel (U+064B–U+065F, U+0670)
    let diacritics = CharacterSet(charactersIn: "\u{064B}\u{064C}\u{064D}\u{064E}\u{064F}\u{0650}\u{0651}\u{0652}\u{0653}\u{0654}\u{0655}\u{0656}\u{0657}\u{0658}\u{065F}\u{0670}")
    return s.unicodeScalars.filter { !diacritics.contains($0) }.map { String($0) }.joined()
}

// ══════════════════════════════════════════════════════════════
// MARK: - HADITH STORE  (singleton data service)
// ══════════════════════════════════════════════════════════════

final class HadithStore: ObservableObject {

    static let shared = HadithStore()

    // ── raw tables ──────────────────────────────────────────
    let allBooks: [HBook]
    private let allChapters: [HChapter]
    private let allHadiths: [HHadith]

    // ── indexes for O(1) lookup ──────────────────────────────
    private var chaptersByBook:  [Int: [HChapter]] = [:]
    private var hadithsByChapter:[Int: [HHadith]]  = [:]
    private var hadithsByBook:   [Int: [HHadith]]  = [:]
    private var hadithById:      [Int: HHadith]    = [:]

    // ── pre-normalized text for fast search ──────────────────
    private var normalizedText:  [Int: String] = [:]   // hadith.id → stripped text

    // ── UserDefaults keys ────────────────────────────────────
    private let favKey = "hadith_favorites_v1"
    private let posKey = "hadith_positions_v1"

    @Published private(set) var favoriteIDs: Set<Int> = []

    // MARK: init
    init() {
        allBooks    = HadithDataSource.books
        allChapters = HadithDataSource.chapters
        allHadiths  = HadithDataSource.hadiths

        // Build indexes
        for ch in allChapters { chaptersByBook[ch.bookId, default: []].append(ch) }
        for h  in allHadiths  {
            hadithsByChapter[h.chapterId, default: []].append(h)
            hadithsByBook[h.bookId, default: []].append(h)
            hadithById[h.id] = h
            normalizedText[h.id] = normalizeArabic(h.text + " " + h.narrator)
        }

        // Load persisted favorites
        let saved = UserDefaults.standard.array(forKey: favKey) as? [Int] ?? []
        favoriteIDs = Set(saved)
    }

    // MARK: - Queries
    func chapters(bookId: Int)  -> [HChapter] { chaptersByBook[bookId]  ?? [] }
    func hadiths(chapterId: Int)-> [HHadith]  { hadithsByChapter[chapterId] ?? [] }
    func hadiths(bookId: Int)   -> [HHadith]  { hadithsByBook[bookId]    ?? [] }
    func hadith(id: Int)        -> HHadith?   { hadithById[id] }

    /// Paginated hadith fetch for lazy list rendering
    func hadiths(chapterId: Int, page: Int, pageSize: Int = 20) -> [HHadith] {
        let all = hadithsByChapter[chapterId] ?? []
        let start = page * pageSize
        guard start < all.count else { return [] }
        return Array(all[start..<min(start + pageSize, all.count)])
    }

    // MARK: - Full-Text Search  (Arabic-normalised, ranked)
    func search(_ query: String) -> [HHadith] {
        let q = normalizeArabic(query.trimmingCharacters(in: .whitespaces))
        guard q.count >= 2 else { return [] }
        let terms = q.split(separator: " ").map(String.init)
        return allHadiths.filter { h in
            guard let norm = normalizedText[h.id] else { return false }
            return terms.allSatisfy { norm.contains($0) }
        }
        .sorted { a, b in
            // Rank: more term matches first
            let ca = terms.filter { normalizedText[a.id]?.contains($0) ?? false }.count
            let cb = terms.filter { normalizedText[b.id]?.contains($0) ?? false }.count
            return ca > cb
        }
    }

    // MARK: - Favorites
    func isFavorite(_ id: Int) -> Bool { favoriteIDs.contains(id) }

    func toggleFavorite(_ id: Int) {
        if favoriteIDs.contains(id) { favoriteIDs.remove(id) }
        else { favoriteIDs.insert(id) }
        UserDefaults.standard.set(Array(favoriteIDs), forKey: favKey)
        objectWillChange.send()
    }

    var favoriteHadiths: [HHadith] {
        favoriteIDs.compactMap { hadithById[$0] }
            .sorted { $0.id < $1.id }
    }

    // MARK: - Reading Position
    func lastHadithId(bookId: Int) -> Int? {
        let dict = UserDefaults.standard.dictionary(forKey: posKey) as? [String: Int] ?? [:]
        return dict["\(bookId)"]
    }

    func savePosition(bookId: Int, hadithId: Int) {
        var dict = UserDefaults.standard.dictionary(forKey: posKey) as? [String: Int] ?? [:]
        dict["\(bookId)"] = hadithId
        UserDefaults.standard.set(dict, forKey: posKey)
    }
}

// ══════════════════════════════════════════════════════════════
// MARK: - DATA SOURCE  (6 authentic books — expandable)
// ══════════════════════════════════════════════════════════════

enum HadithDataSource {

    // ── Books ────────────────────────────────────────────────
    static let books: [HBook] = [
        HBook(id: 1, name: "صحيح البخاري",
              author: "محمد بن إسماعيل البخاري",
              deathYear: "256هـ",
              description: "أصح كتاب بعد كتاب الله — انتقى من ستمائة ألف حديث",
              icon: "scroll.fill",
              accentColor: Color(red: 0.29, green: 0.0, blue: 0.51)),
        HBook(id: 2, name: "صحيح مسلم",
              author: "مسلم بن الحجاج النيسابوري",
              deathYear: "261هـ",
              description: "ثاني أصح كتاب — تميّز بترتيبه المنهجي وجمع طرق الأحاديث",
              icon: "book.closed.fill",
              accentColor: Color(red: 0.0, green: 0.48, blue: 0.40)),
        HBook(id: 3, name: "سنن أبي داود",
              author: "سليمان بن الأشعث الأزدي",
              deathYear: "275هـ",
              description: "من السنن الأربعة — جمع 5274 حديثاً مع التركيز على أحكام الفقه",
              icon: "books.vertical.fill",
              accentColor: Color(red: 0.55, green: 0.27, blue: 0.07)),
        HBook(id: 4, name: "جامع الترمذي",
              author: "محمد بن عيسى الترمذي",
              deathYear: "279هـ",
              description: "يتميز بالحكم على الأحاديث وبيان درجاتها ومذاهب الفقهاء",
              icon: "book.fill",
              accentColor: Color(red: 0.13, green: 0.55, blue: 0.13)),
        HBook(id: 5, name: "سنن النسائي",
              author: "أحمد بن شعيب النسائي",
              deathYear: "303هـ",
              description: "من أقل كتب السنة أحاديثَ ضعيفة — دقيق في الاشتراط والانتقاد",
              icon: "doc.text.fill",
              accentColor: Color(red: 0.40, green: 0.20, blue: 0.60)),
        HBook(id: 6, name: "سنن ابن ماجه",
              author: "محمد بن يزيد ابن ماجه القزويني",
              deathYear: "273هـ",
              description: "سادس كتب السنة — 4341 حديثاً، مرجع مهم في الأحكام والزهد",
              icon: "text.book.closed.fill",
              accentColor: Color(red: 0.70, green: 0.35, blue: 0.10)),
    ]

    // ── Chapters ─────────────────────────────────────────────
    static let chapters: [HChapter] = [
        // ── البخاري ──
        HChapter(id: 101, bookId: 1, number: 1,  title: "كتاب بدء الوحي"),
        HChapter(id: 102, bookId: 1, number: 2,  title: "كتاب الإيمان"),
        HChapter(id: 103, bookId: 1, number: 3,  title: "كتاب العلم"),
        HChapter(id: 104, bookId: 1, number: 4,  title: "كتاب الصلاة"),
        HChapter(id: 105, bookId: 1, number: 5,  title: "كتاب الصوم"),
        HChapter(id: 106, bookId: 1, number: 6,  title: "كتاب الجهاد"),
        HChapter(id: 107, bookId: 1, number: 7,  title: "كتاب الزهد والرقائق"),
        HChapter(id: 108, bookId: 1, number: 8,  title: "كتاب الأدب"),
        // ── مسلم ──
        HChapter(id: 201, bookId: 2, number: 1,  title: "كتاب الإيمان"),
        HChapter(id: 202, bookId: 2, number: 2,  title: "كتاب الطهارة"),
        HChapter(id: 203, bookId: 2, number: 3,  title: "كتاب الصلاة"),
        HChapter(id: 204, bookId: 2, number: 4,  title: "كتاب الزكاة"),
        HChapter(id: 205, bookId: 2, number: 5,  title: "كتاب الذكر والدعاء"),
        HChapter(id: 206, bookId: 2, number: 6,  title: "كتاب الزهد والرقائق"),
        // ── أبو داود ──
        HChapter(id: 301, bookId: 3, number: 1,  title: "كتاب الطهارة"),
        HChapter(id: 302, bookId: 3, number: 2,  title: "كتاب الصلاة"),
        HChapter(id: 303, bookId: 3, number: 3,  title: "كتاب الزكاة"),
        HChapter(id: 304, bookId: 3, number: 4,  title: "كتاب الأدب"),
        HChapter(id: 305, bookId: 3, number: 5,  title: "كتاب السنة"),
        // ── الترمذي ──
        HChapter(id: 401, bookId: 4, number: 1,  title: "فضل العلم والعلماء"),
        HChapter(id: 402, bookId: 4, number: 2,  title: "كتاب الزهد"),
        HChapter(id: 403, bookId: 4, number: 3,  title: "آداب الطعام"),
        HChapter(id: 404, bookId: 4, number: 4,  title: "كتاب المعاملات"),
        HChapter(id: 405, bookId: 4, number: 5,  title: "كتاب البر والصلة"),
        // ── النسائي ──
        HChapter(id: 501, bookId: 5, number: 1,  title: "كتاب الصلاة وأوقاتها"),
        HChapter(id: 502, bookId: 5, number: 2,  title: "تحريم الظلم"),
        HChapter(id: 503, bookId: 5, number: 3,  title: "كتاب الصيام"),
        HChapter(id: 504, bookId: 5, number: 4,  title: "كتاب القضاء والعدل"),
        // ── ابن ماجه ──
        HChapter(id: 601, bookId: 6, number: 1,  title: "باب الإخلاص وإحضار النية"),
        HChapter(id: 602, bookId: 6, number: 2,  title: "باب التوبة"),
        HChapter(id: 603, bookId: 6, number: 3,  title: "باب الصبر"),
        HChapter(id: 604, bookId: 6, number: 4,  title: "باب الصدق"),
        HChapter(id: 605, bookId: 6, number: 5,  title: "باب المراقبة"),
        HChapter(id: 606, bookId: 6, number: 6,  title: "فضل الصلاة على النبي ﷺ"),
    ]

    // ── Hadiths ───────────────────────────────────────────────
    static let hadiths: [HHadith] = bukhariHadiths + muslimHadiths + abuDawudHadiths + tirmidhiHadiths + nasaiHadiths + ibnMajahHadiths

    // ══ البخاري ═══════════════════════════════════════════════
    static let bukhariHadiths: [HHadith] = [
        // ch 101 - بدء الوحي
        HHadith(id: 1001, bookId: 1, chapterId: 101, number: 1,
            narrator: "عمر بن الخطاب رضي الله عنه",
            text: "إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ، وَإِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى، فَمَنْ كَانَتْ هِجْرَتُهُ إِلَى اللَّهِ وَرَسُولِهِ فَهِجْرَتُهُ إِلَى اللَّهِ وَرَسُولِهِ، وَمَنْ كَانَتْ هِجْرَتُهُ لِدُنْيَا يُصِيبُهَا أَوِ امْرَأَةٍ يَنْكِحُهَا فَهِجْرَتُهُ إِلَى مَا هَاجَرَ إِلَيْهِ.",
            grade: "صحيح", reference: "البخاري: 1"),
        HHadith(id: 1002, bookId: 1, chapterId: 101, number: 2,
            narrator: "عائشة رضي الله عنها",
            text: "أَوَّلُ مَا بُدِئَ بِهِ رَسُولُ اللَّهِ ﷺ مِنَ الْوَحْيِ الرُّؤْيَا الصَّالِحَةُ فِي النَّوْمِ، فَكَانَ لاَ يَرَى رُؤْيَا إِلاَّ جَاءَتْ مِثْلَ فَلَقِ الصُّبْحِ.",
            grade: "صحيح", reference: "البخاري: 3"),
        // ch 102 - الإيمان
        HHadith(id: 1003, bookId: 1, chapterId: 102, number: 3,
            narrator: "أبو هريرة رضي الله عنه",
            text: "الإِيمَانُ بِضْعٌ وَسِتُّونَ شُعْبَةً، فَأَفْضَلُهَا قَوْلُ: لا إِلَهَ إِلاَّ اللَّهُ، وَأَدْنَاهَا إِمَاطَةُ الأَذَى عَنِ الطَّرِيقِ، وَالْحَيَاءُ شُعْبَةٌ مِنَ الإِيمَانِ.",
            grade: "صحيح", reference: "البخاري: 9"),
        HHadith(id: 1004, bookId: 1, chapterId: 102, number: 4,
            narrator: "عبد الله بن عمرو رضي الله عنهما",
            text: "الْمُسْلِمُ مَنْ سَلِمَ الْمُسْلِمُونَ مِنْ لِسَانِهِ وَيَدِهِ، وَالْمُهَاجِرُ مَنْ هَجَرَ مَا نَهَى اللَّهُ عَنْهُ.",
            grade: "صحيح", reference: "البخاري: 10"),
        HHadith(id: 1005, bookId: 1, chapterId: 102, number: 5,
            narrator: "أنس بن مالك رضي الله عنه",
            text: "لاَ يُؤْمِنُ أَحَدُكُمْ حَتَّى يُحِبَّ لأَخِيهِ مَا يُحِبُّ لِنَفْسِهِ.",
            grade: "صحيح", reference: "البخاري: 13"),
        // ch 103 - العلم
        HHadith(id: 1006, bookId: 1, chapterId: 103, number: 6,
            narrator: "معاوية رضي الله عنه",
            text: "مَنْ يُرِدِ اللَّهُ بِهِ خَيْرًا يُفَقِّهْهُ فِي الدِّينِ.",
            grade: "صحيح", reference: "البخاري: 71"),
        HHadith(id: 1007, bookId: 1, chapterId: 103, number: 7,
            narrator: "عبد الله بن عمرو رضي الله عنهما",
            text: "بَلِّغُوا عَنِّي وَلَوْ آيَةً، وَحَدِّثُوا عَنْ بَنِي إِسْرَائِيلَ وَلاَ حَرَجَ، وَمَنْ كَذَبَ عَلَيَّ مُتَعَمِّدًا فَلْيَتَبَوَّأْ مَقْعَدَهُ مِنَ النَّارِ.",
            grade: "صحيح", reference: "البخاري: 3461"),
        HHadith(id: 1008, bookId: 1, chapterId: 103, number: 8,
            narrator: "أبو هريرة رضي الله عنه",
            text: "مَنْ سُئِلَ عَنْ عِلْمٍ فَكَتَمَهُ أُلْجِمَ يَوْمَ الْقِيَامَةِ بِلِجَامٍ مِنْ نَارٍ.",
            grade: "حسن", reference: "أبو داود: 3658"),
        // ch 104 - الصلاة
        HHadith(id: 1009, bookId: 1, chapterId: 104, number: 9,
            narrator: "ابن مسعود رضي الله عنه",
            text: "سَأَلْتُ النَّبِيَّ ﷺ: أَيُّ الأَعْمَالِ أَحَبُّ إِلَى اللَّهِ؟ قَالَ: الصَّلاةُ عَلَى وَقْتِهَا. قَالَ: ثُمَّ أَيٌّ؟ قَالَ: بِرُّ الْوَالِدَيْنِ. قَالَ: ثُمَّ أَيٌّ؟ قَالَ: الْجِهَادُ فِي سَبِيلِ اللَّهِ.",
            grade: "صحيح", reference: "البخاري: 527"),
        HHadith(id: 1010, bookId: 1, chapterId: 104, number: 10,
            narrator: "أبو هريرة رضي الله عنه",
            text: "صَلاةُ الْجَمَاعَةِ تَفْضُلُ صَلاةَ الْفَذِّ بِسَبْعٍ وَعِشْرِينَ دَرَجَةً.",
            grade: "صحيح", reference: "البخاري: 645"),
        HHadith(id: 1011, bookId: 1, chapterId: 104, number: 11,
            narrator: "أبو هريرة رضي الله عنه",
            text: "لَوْ يَعْلَمُ النَّاسُ مَا فِي النِّدَاءِ وَالصَّفِّ الأَوَّلِ ثُمَّ لَمْ يَجِدُوا إِلاَّ أَنْ يَسْتَهِمُوا عَلَيْهِ لاَسْتَهَمُوا.",
            grade: "صحيح", reference: "البخاري: 615"),
        // ch 105 - الصوم
        HHadith(id: 1012, bookId: 1, chapterId: 105, number: 12,
            narrator: "أبو هريرة رضي الله عنه",
            text: "قَالَ اللَّهُ عَزَّ وَجَلَّ: كُلُّ عَمَلِ ابْنِ آدَمَ لَهُ إِلاَّ الصِّيَامَ؛ فَإِنَّهُ لِي وَأَنَا أَجْزِي بِهِ.",
            grade: "صحيح", reference: "البخاري: 1904"),
        HHadith(id: 1013, bookId: 1, chapterId: 105, number: 13,
            narrator: "أبو هريرة رضي الله عنه",
            text: "تَسَحَّرُوا فَإِنَّ فِي السَّحُورِ بَرَكَةً.",
            grade: "صحيح", reference: "البخاري: 1923"),
        // ch 106 - الجهاد
        HHadith(id: 1014, bookId: 1, chapterId: 106, number: 14,
            narrator: "أبو موسى الأشعري رضي الله عنه",
            text: "إِنَّ أَبْوَابَ الْجَنَّةِ تَحْتَ ظِلالِ السُّيُوفِ.",
            grade: "صحيح", reference: "مسلم: 1902"),
        HHadith(id: 1015, bookId: 1, chapterId: 106, number: 15,
            narrator: "أبو هريرة رضي الله عنه",
            text: "مَنْ مَاتَ وَلَمْ يَغْزُ وَلَمْ يُحَدِّثْ بِهِ نَفْسَهُ مَاتَ عَلَى شُعْبَةٍ مِنَ النِّفَاقِ.",
            grade: "صحيح", reference: "مسلم: 1910"),
        // ch 107 - الزهد
        HHadith(id: 1016, bookId: 1, chapterId: 107, number: 16,
            narrator: "ابن عمر رضي الله عنهما",
            text: "كُنْ فِي الدُّنْيَا كَأَنَّكَ غَرِيبٌ أَوْ عَابِرُ سَبِيلٍ.",
            grade: "صحيح", reference: "البخاري: 6416"),
        HHadith(id: 1017, bookId: 1, chapterId: 107, number: 17,
            narrator: "أبو هريرة رضي الله عنه",
            text: "انْظُرُوا إِلَى مَنْ هُوَ أَسْفَلَ مِنْكُمْ وَلاَ تَنْظُرُوا إِلَى مَنْ هُوَ فَوْقَكُمْ، فَهُوَ أَجْدَرُ أَنْ لاَ تَزْدَرُوا نِعْمَةَ اللَّهِ عَلَيْكُمْ.",
            grade: "صحيح", reference: "مسلم: 2963"),
        // ch 108 - الأدب
        HHadith(id: 1018, bookId: 1, chapterId: 108, number: 18,
            narrator: "أبو هريرة رضي الله عنه",
            text: "لَيْسَ الشَّدِيدُ بِالصُّرَعَةِ، إِنَّمَا الشَّدِيدُ الَّذِي يَمْلِكُ نَفْسَهُ عِنْدَ الْغَضَبِ.",
            grade: "صحيح", reference: "البخاري: 6114"),
        HHadith(id: 1019, bookId: 1, chapterId: 108, number: 19,
            narrator: "أبو هريرة رضي الله عنه",
            text: "مَنْ كَانَ يُؤْمِنُ بِاللَّهِ وَالْيَوْمِ الآخِرِ فَلْيَقُلْ خَيْرًا أَوْ لِيَصْمُتْ، وَمَنْ كَانَ يُؤْمِنُ بِاللَّهِ وَالْيَوْمِ الآخِرِ فَلْيُكْرِمْ جَارَهُ، وَمَنْ كَانَ يُؤْمِنُ بِاللَّهِ وَالْيَوْمِ الآخِرِ فَلْيُكْرِمْ ضَيْفَهُ.",
            grade: "صحيح", reference: "البخاري: 6018"),
        // ch 101 - بدء الوحي (إضافية)
        HHadith(id: 1020, bookId: 1, chapterId: 101, number: 20,
            narrator: "عائشة رضي الله عنها",
            text: "فَجَاءَهُ الْمَلَكُ فَقَالَ: اقْرَأْ. فَقَالَ ﷺ: مَا أَنَا بِقَارِئٍ. فَأَخَذَهُ فَغَطَّهُ حَتَّى بَلَغَ مِنْهُ الْجَهْدُ ثُمَّ أَرْسَلَهُ، فَقَالَ: اقْرَأْ بِاسْمِ رَبِّكَ الَّذِي خَلَقَ.",
            grade: "صحيح", reference: "البخاري: 4"),
        // ch 102 - الإيمان (إضافية)
        HHadith(id: 1021, bookId: 1, chapterId: 102, number: 21,
            narrator: "أبو هريرة رضي الله عنه",
            text: "مَنْ يَضْمَنُ لِي مَا بَيْنَ لَحْيَيْهِ وَمَا بَيْنَ رِجْلَيْهِ أَضْمَنُ لَهُ الْجَنَّةَ.",
            grade: "صحيح", reference: "البخاري: 6474"),
        HHadith(id: 1022, bookId: 1, chapterId: 102, number: 22,
            narrator: "عبد الله بن عمر رضي الله عنهما",
            text: "بُنِيَ الإِسْلاَمُ عَلَى خَمْسٍ: شَهَادَةِ أَنْ لاَ إِلَهَ إِلاَّ اللَّهُ وَأَنَّ مُحَمَّدًا رَسُولُ اللَّهِ، وَإِقَامِ الصَّلاةِ، وَإِيتَاءِ الزَّكَاةِ، وَالْحَجِّ، وَصَوْمِ رَمَضَانَ.",
            grade: "صحيح", reference: "البخاري: 8"),
        // ch 103 - العلم (إضافية)
        HHadith(id: 1023, bookId: 1, chapterId: 103, number: 23,
            narrator: "أنس بن مالك رضي الله عنه",
            text: "طَلَبُ الْعِلْمِ فَرِيضَةٌ عَلَى كُلِّ مُسْلِمٍ.",
            grade: "صحيح", reference: "ابن ماجه: 224"),
        HHadith(id: 1024, bookId: 1, chapterId: 103, number: 24,
            narrator: "عثمان بن عفان رضي الله عنه",
            text: "خَيْرُكُمْ مَنْ تَعَلَّمَ الْقُرْآنَ وَعَلَّمَهُ.",
            grade: "صحيح", reference: "البخاري: 5027"),
        // ch 104 - الصلاة (إضافية)
        HHadith(id: 1025, bookId: 1, chapterId: 104, number: 25,
            narrator: "أبو هريرة رضي الله عنه",
            text: "إِنَّ أَوَّلَ مَا يُحَاسَبُ بِهِ الْعَبْدُ يَوْمَ الْقِيَامَةِ مِنْ عَمَلِهِ صَلاَتُهُ، فَإِنْ صَلَحَتْ فَقَدْ أَفْلَحَ وَأَنْجَحَ، وَإِنْ فَسَدَتْ فَقَدْ خَابَ وَخَسِرَ.",
            grade: "صحيح", reference: "الترمذي: 413"),
        HHadith(id: 1026, bookId: 1, chapterId: 104, number: 26,
            narrator: "جابر بن عبد الله رضي الله عنه",
            text: "مَفَاتِيحُ الْجَنَّةِ الصَّلاةُ.",
            grade: "صحيح", reference: "الطبراني"),
        // ch 105 - الصوم (إضافية)
        HHadith(id: 1027, bookId: 1, chapterId: 105, number: 27,
            narrator: "أبو هريرة رضي الله عنه",
            text: "مَنْ لَمْ يَدَعْ قَوْلَ الزُّورِ وَالْعَمَلَ بِهِ فَلَيْسَ لِلَّهِ حَاجَةٌ فِي أَنْ يَدَعَ طَعَامَهُ وَشَرَابَهُ.",
            grade: "صحيح", reference: "البخاري: 1903"),
        HHadith(id: 1028, bookId: 1, chapterId: 105, number: 28,
            narrator: "سهل بن سعد رضي الله عنه",
            text: "إِنَّ فِي الْجَنَّةِ بَابًا يُقَالُ لَهُ الرَّيَّانُ، يَدْخُلُ مِنْهُ الصَّائِمُونَ يَوْمَ الْقِيَامَةِ.",
            grade: "صحيح", reference: "البخاري: 1896"),
        // ch 106 - الجهاد (إضافية)
        HHadith(id: 1029, bookId: 1, chapterId: 106, number: 29,
            narrator: "أبو هريرة رضي الله عنه",
            text: "الشَّهِيدُ لاَ يَجِدُ أَلَمَ الْقَتْلِ إِلاَّ كَمَا يَجِدُ أَحَدُكُمْ أَلَمَ الْقَرْصَةِ.",
            grade: "حسن صحيح", reference: "الترمذي: 1668"),
        // ch 107 - الزهد (إضافية)
        HHadith(id: 1030, bookId: 1, chapterId: 107, number: 30,
            narrator: "أبو هريرة رضي الله عنه",
            text: "لَيْسَ الْغِنَى عَنْ كَثْرَةِ الْعَرَضِ، وَلَكِنَّ الْغِنَى غِنَى النَّفْسِ.",
            grade: "صحيح", reference: "البخاري: 6446"),
        HHadith(id: 1031, bookId: 1, chapterId: 107, number: 31,
            narrator: "أبو هريرة رضي الله عنه",
            text: "يَقُولُ الْعَبْدُ: مَالِي مَالِي. وَإِنَّمَا لَهُ مِنْ مَالِهِ ثَلاَثٌ: مَا أَكَلَ فَأَفْنَى، أَوْ لَبِسَ فَأَبْلَى، أَوْ أَعْطَى فَاقْتَنَى.",
            grade: "صحيح", reference: "مسلم: 2959"),
        // ch 108 - الأدب (إضافية)
        HHadith(id: 1032, bookId: 1, chapterId: 108, number: 32,
            narrator: "أبو هريرة رضي الله عنه",
            text: "حَقُّ الْمُسْلِمِ عَلَى الْمُسْلِمِ سِتٌّ: إِذَا لَقِيتَهُ فَسَلِّمْ عَلَيْهِ، وَإِذَا دَعَاكَ فَأَجِبْهُ، وَإِذَا اسْتَنْصَحَكَ فَانْصَحْهُ، وَإِذَا عَطَسَ فَحَمِدَ اللَّهَ فَشَمِّتْهُ، وَإِذَا مَرِضَ فَعُدْهُ، وَإِذَا مَاتَ فَاتَّبِعْهُ.",
            grade: "صحيح", reference: "مسلم: 2162"),
        HHadith(id: 1033, bookId: 1, chapterId: 108, number: 33,
            narrator: "أبو هريرة رضي الله عنه",
            text: "لاَ تَحَاسَدُوا وَلاَ تَنَاجَشُوا وَلاَ تَبَاغَضُوا وَلاَ تَدَابَرُوا وَلاَ يَبِعْ بَعْضُكُمْ عَلَى بَيْعِ بَعْضٍ، وَكُونُوا عِبَادَ اللَّهِ إِخْوَانًا.",
            grade: "صحيح", reference: "مسلم: 2564"),
    ]

    // ══ مسلم ═══════════════════════════════════════════════════
    static let muslimHadiths: [HHadith] = [
        // ch 201 - الإيمان
        HHadith(id: 2001, bookId: 2, chapterId: 201, number: 1,
            narrator: "عمر بن الخطاب رضي الله عنه",
            text: "الإِيمَانُ أَنْ تُؤْمِنَ بِاللَّهِ وَمَلائِكَتِهِ وَكُتُبِهِ وَرُسُلِهِ وَالْيَوْمِ الآخِرِ وَتُؤْمِنَ بِالْقَدَرِ خَيْرِهِ وَشَرِّهِ.",
            grade: "صحيح", reference: "مسلم: 8"),
        HHadith(id: 2002, bookId: 2, chapterId: 201, number: 2,
            narrator: "أبو هريرة رضي الله عنه",
            text: "آيَةُ الْمُنَافِقِ ثَلاَثٌ: إِذَا حَدَّثَ كَذَبَ، وَإِذَا وَعَدَ أَخْلَفَ، وَإِذَا اؤْتُمِنَ خَانَ.",
            grade: "صحيح", reference: "مسلم: 59"),
        HHadith(id: 2003, bookId: 2, chapterId: 201, number: 3,
            narrator: "أبو ذر الغفاري رضي الله عنه",
            text: "اتَّقِ اللَّهَ حَيْثُمَا كُنْتَ، وَأَتْبِعِ السَّيِّئَةَ الْحَسَنَةَ تَمْحُهَا، وَخَالِقِ النَّاسَ بِخُلُقٍ حَسَنٍ.",
            grade: "حسن صحيح", reference: "الترمذي: 1987"),
        // ch 202 - الطهارة
        HHadith(id: 2004, bookId: 2, chapterId: 202, number: 4,
            narrator: "أبو مالك الأشعري رضي الله عنه",
            text: "الطُّهُورُ شَطْرُ الإِيمَانِ، وَالْحَمْدُ لِلَّهِ تَمْلأُ الْمِيزَانَ، وَسُبْحَانَ اللَّهِ وَالْحَمْدُ لِلَّهِ تَمْلآنِ — أَوْ تَمْلأُ — مَا بَيْنَ السَّمَوَاتِ وَالأَرْضِ.",
            grade: "صحيح", reference: "مسلم: 223"),
        HHadith(id: 2005, bookId: 2, chapterId: 202, number: 5,
            narrator: "أبو هريرة رضي الله عنه",
            text: "مَنْ تَوَضَّأَ فَأَحْسَنَ الْوُضُوءَ خَرَجَتْ خَطَايَاهُ مِنْ جَسَدِهِ حَتَّى تَخْرُجَ مِنْ تَحْتِ أَظْفَارِهِ.",
            grade: "صحيح", reference: "مسلم: 245"),
        // ch 203 - الصلاة
        HHadith(id: 2006, bookId: 2, chapterId: 203, number: 6,
            narrator: "جابر بن عبد الله رضي الله عنه",
            text: "بَيْنَ الرَّجُلِ وَبَيْنَ الشِّرْكِ وَالْكُفْرِ تَرْكُ الصَّلاةِ.",
            grade: "صحيح", reference: "مسلم: 82"),
        HHadith(id: 2007, bookId: 2, chapterId: 203, number: 7,
            narrator: "أبو هريرة رضي الله عنه",
            text: "أَرَأَيْتُمْ لَوْ أَنَّ نَهَرًا بِبَابِ أَحَدِكُمْ يَغْتَسِلُ فِيهِ كُلَّ يَوْمٍ خَمْسًا مَا تَقُولُ ذَلِكَ يُبْقِي مِنْ دَرَنِهِ؟ كَذَلِكَ مَثَلُ الصَّلَوَاتِ الْخَمْسِ يَمْحُو اللَّهُ بِهِنَّ الْخَطَايَا.",
            grade: "صحيح", reference: "مسلم: 667"),
        // ch 204 - الزكاة
        HHadith(id: 2008, bookId: 2, chapterId: 204, number: 8,
            narrator: "أبو هريرة رضي الله عنه",
            text: "مَا مِنْ يَوْمٍ يُصْبِحُ الْعِبَادُ فِيهِ إِلاَّ مَلَكَانِ يَنْزِلاَنِ: فَيَقُولُ أَحَدُهُمَا: اللَّهُمَّ أَعْطِ مُنْفِقًا خَلَفًا، وَيَقُولُ الآخَرُ: اللَّهُمَّ أَعْطِ مُمْسِكًا تَلَفًا.",
            grade: "صحيح", reference: "مسلم: 1010"),
        // ch 205 - الذكر والدعاء
        HHadith(id: 2009, bookId: 2, chapterId: 205, number: 9,
            narrator: "أبو هريرة رضي الله عنه",
            text: "الدُّعَاءُ هُوَ الْعِبَادَةُ.",
            grade: "صحيح", reference: "مسلم: 2693"),
        HHadith(id: 2010, bookId: 2, chapterId: 205, number: 10,
            narrator: "أبو هريرة رضي الله عنه",
            text: "أَفْضَلُ الدُّعَاءِ الْحَمْدُ لِلَّهِ، وَأَفْضَلُ الذِّكْرِ لاَ إِلَهَ إِلاَّ اللَّهُ.",
            grade: "حسن", reference: "الترمذي: 3383"),
        // ch 206 - الزهد
        HHadith(id: 2011, bookId: 2, chapterId: 206, number: 11,
            narrator: "ابن عمر رضي الله عنهما",
            text: "كُنْ فِي الدُّنْيَا كَأَنَّكَ غَرِيبٌ أَوْ عَابِرُ سَبِيلٍ، وَكَانَ ابْنُ عُمَرَ يَقُولُ: إِذَا أَمْسَيْتَ فَلاَ تَنْتَظِرِ الصَّبَاحَ.",
            grade: "صحيح", reference: "البخاري: 6416"),
        HHadith(id: 2012, bookId: 2, chapterId: 206, number: 12,
            narrator: "أبو هريرة رضي الله عنه",
            text: "عَجَبًا لأَمْرِ الْمُؤْمِنِ إِنَّ أَمْرَهُ كُلَّهُ خَيْرٌ: إِنْ أَصَابَتْهُ سَرَّاءُ شَكَرَ فَكَانَ خَيْرًا لَهُ، وَإِنْ أَصَابَتْهُ ضَرَّاءُ صَبَرَ فَكَانَ خَيْرًا لَهُ.",
            grade: "صحيح", reference: "مسلم: 2999"),
        // ch 201 - الإيمان (إضافية)
        HHadith(id: 2013, bookId: 2, chapterId: 201, number: 13,
            narrator: "أبو هريرة رضي الله عنه",
            text: "لاَ يَدْخُلُ أَحَدُكُمُ الْجَنَّةَ حَتَّى يُؤْمِنَ، وَلاَ يُؤْمِنُ حَتَّى يَتَحَابَّ. أَوَلاَ أَدُلُّكُمْ عَلَى شَيْءٍ إِذَا فَعَلْتُمُوهُ تَحَابَبْتُمْ: أَفْشُوا السَّلاَمَ بَيْنَكُمْ.",
            grade: "صحيح", reference: "مسلم: 54"),
        HHadith(id: 2014, bookId: 2, chapterId: 201, number: 14,
            narrator: "جبريل عليه السلام",
            text: "الإِسْلاَمُ أَنْ تَشْهَدَ أَنْ لاَ إِلَهَ إِلاَّ اللَّهُ وَأَنَّ مُحَمَّدًا رَسُولُ اللَّهِ، وَتُقِيمَ الصَّلاةَ، وَتُؤْتِيَ الزَّكَاةَ، وَتَصُومَ رَمَضَانَ، وَتَحُجَّ الْبَيْتَ إِنِ اسْتَطَعْتَ إِلَيْهِ سَبِيلاً.",
            grade: "صحيح", reference: "مسلم: 8"),
        // ch 202 - الطهارة (إضافية)
        HHadith(id: 2015, bookId: 2, chapterId: 202, number: 15,
            narrator: "عثمان بن عفان رضي الله عنه",
            text: "مَنْ تَوَضَّأَ فَأَحْسَنَ الْوُضُوءَ ثُمَّ صَلَّى رَكْعَتَيْنِ لاَ يُسَهِّي فِيهِمَا غُفِرَ لَهُ مَا تَقَدَّمَ مِنْ ذَنْبِهِ.",
            grade: "صحيح", reference: "البخاري: 160"),
        // ch 203 - الصلاة (إضافية)
        HHadith(id: 2016, bookId: 2, chapterId: 203, number: 16,
            narrator: "أبو هريرة رضي الله عنه",
            text: "مَثَلُ الصَّلَوَاتِ الْخَمْسِ كَمَثَلِ نَهَرٍ جَارٍ غَمْرٍ عَلَى بَابِ أَحَدِكُمْ يَغْتَسِلُ مِنْهُ كُلَّ يَوْمٍ خَمْسَ مَرَّاتٍ.",
            grade: "صحيح", reference: "مسلم: 668"),
        HHadith(id: 2017, bookId: 2, chapterId: 203, number: 17,
            narrator: "عبد الله بن مسعود رضي الله عنه",
            text: "مَنْ سَرَّهُ أَنْ يَلْقَى اللَّهَ غَدًا مُسْلِمًا فَلْيُحَافِظْ عَلَى هَؤُلاَءِ الصَّلَوَاتِ الْخَمْسِ حَيْثُ يُنَادَى بِهِنَّ.",
            grade: "صحيح", reference: "مسلم: 654"),
        // ch 204 - الزكاة (إضافية)
        HHadith(id: 2018, bookId: 2, chapterId: 204, number: 18,
            narrator: "أبو هريرة رضي الله عنه",
            text: "الصَّدَقَةُ لاَ تَنْقُصُ مَالاً، وَمَا زَادَ اللَّهُ عَبْدًا بِعَفْوٍ إِلاَّ عِزًّا، وَمَا تَوَاضَعَ أَحَدٌ لِلَّهِ إِلاَّ رَفَعَهُ اللَّهُ.",
            grade: "صحيح", reference: "مسلم: 2588"),
        // ch 205 - الذكر والدعاء (إضافية)
        HHadith(id: 2019, bookId: 2, chapterId: 205, number: 19,
            narrator: "أبو هريرة رضي الله عنه",
            text: "يَقُولُ اللَّهُ تَعَالَى: أَنَا عِنْدَ ظَنِّ عَبْدِي بِي، وَأَنَا مَعَهُ إِذَا ذَكَرَنِي؛ فَإِنْ ذَكَرَنِي فِي نَفْسِهِ ذَكَرْتُهُ فِي نَفْسِي.",
            grade: "صحيح", reference: "مسلم: 2675"),
        HHadith(id: 2020, bookId: 2, chapterId: 205, number: 20,
            narrator: "أبو موسى رضي الله عنه",
            text: "مَثَلُ الَّذِي يَذْكُرُ رَبَّهُ وَالَّذِي لاَ يَذْكُرُ رَبَّهُ مَثَلُ الْحَيِّ وَالْمَيِّتِ.",
            grade: "صحيح", reference: "البخاري: 6407"),
        // ch 206 - الزهد (إضافية)
        HHadith(id: 2021, bookId: 2, chapterId: 206, number: 21,
            narrator: "أبو هريرة رضي الله عنه",
            text: "كُونُوا فِي الدُّنْيَا كَأَنَّكُمْ غُرَبَاءُ أَوْ عَابِرُو سَبِيلٍ.",
            grade: "صحيح", reference: "البخاري: 6416"),
    ]

    // ══ أبو داود ═══════════════════════════════════════════════
    static let abuDawudHadiths: [HHadith] = [
        // ch 301 - الطهارة
        HHadith(id: 3001, bookId: 3, chapterId: 301, number: 1,
            narrator: "عمر بن الخطاب رضي الله عنه",
            text: "مَا مِنْكُمْ مِنْ أَحَدٍ يَتَوَضَّأُ فَيُبْلِغُ — أَوْ فَيُسْبِغُ — الْوُضُوءَ ثُمَّ يَقُولُ: أَشْهَدُ أَنْ لاَ إِلَهَ إِلاَّ اللَّهُ وَأَنَّ مُحَمَّدًا عَبْدُهُ وَرَسُولُهُ؛ إِلاَّ فُتِحَتْ لَهُ أَبْوَابُ الْجَنَّةِ الثَّمَانِيَةُ.",
            grade: "صحيح", reference: "مسلم: 234"),
        HHadith(id: 3002, bookId: 3, chapterId: 301, number: 2,
            narrator: "أبو هريرة رضي الله عنه",
            text: "إِذَا اسْتَيْقَظَ أَحَدُكُمْ مِنْ مَنَامِهِ فَلاَ يَغْمِسَنَّ يَدَهُ فِي الإِنَاءِ حَتَّى يَغْسِلَهَا ثَلاَثًا، فَإِنَّهُ لاَ يَدْرِي أَيْنَ بَاتَتْ يَدُهُ.",
            grade: "صحيح", reference: "مسلم: 278"),
        // ch 302 - الصلاة
        HHadith(id: 3003, bookId: 3, chapterId: 302, number: 3,
            narrator: "أبو هريرة رضي الله عنه",
            text: "لَوْ يَعْلَمُ النَّاسُ مَا فِي النِّدَاءِ وَالصَّفِّ الأَوَّلِ ثُمَّ لَمْ يَجِدُوا إِلاَّ أَنْ يَسْتَهِمُوا عَلَيْهِ لاَسْتَهَمُوا، وَلَوْ يَعْلَمُونَ مَا فِي التَّهْجِيرِ لاَسْتَبَقُوا إِلَيْهِ.",
            grade: "صحيح", reference: "البخاري: 615"),
        HHadith(id: 3004, bookId: 3, chapterId: 302, number: 4,
            narrator: "ثوبان رضي الله عنه",
            text: "اسْتَقِيمُوا وَلَنْ تُحْصُوا، وَاعْلَمُوا أَنَّ خَيْرَ أَعْمَالِكُمُ الصَّلاةُ، وَلاَ يُحَافِظُ عَلَى الْوُضُوءِ إِلاَّ مُؤْمِنٌ.",
            grade: "صحيح", reference: "ابن ماجه: 277"),
        // ch 303 - الزكاة
        HHadith(id: 3005, bookId: 3, chapterId: 303, number: 5,
            narrator: "أبو هريرة رضي الله عنه",
            text: "مَا مِنْ يَوْمٍ يُصْبِحُ الْعِبَادُ فِيهِ إِلاَّ مَلَكَانِ يَنْزِلاَنِ فَيَقُولُ أَحَدُهُمَا: اللَّهُمَّ أَعْطِ مُنْفِقًا خَلَفًا، وَيَقُولُ الآخَرُ: اللَّهُمَّ أَعْطِ مُمْسِكًا تَلَفًا.",
            grade: "صحيح", reference: "البخاري: 1442"),
        // ch 304 - الأدب
        HHadith(id: 3006, bookId: 3, chapterId: 304, number: 6,
            narrator: "أبو هريرة رضي الله عنه",
            text: "أَكْمَلُ الْمُؤْمِنِينَ إِيمَانًا أَحْسَنُهُمْ خُلُقًا، وَخِيَارُكُمْ خِيَارُكُمْ لِنِسَائِهِمْ.",
            grade: "حسن صحيح", reference: "الترمذي: 1162"),
        HHadith(id: 3007, bookId: 3, chapterId: 304, number: 7,
            narrator: "جابر رضي الله عنه",
            text: "إِنَّ مِنْ أَحَبِّكُمْ إِلَيَّ وَأَقْرَبِكُمْ مِنِّي مَجْلِسًا يَوْمَ الْقِيَامَةِ أَحَاسِنُكُمْ أَخْلاَقًا.",
            grade: "حسن", reference: "الترمذي: 2018"),
        // ch 305 - السنة
        HHadith(id: 3008, bookId: 3, chapterId: 305, number: 8,
            narrator: "العرباض بن سارية رضي الله عنه",
            text: "عَلَيْكُمْ بِسُنَّتِي وَسُنَّةِ الْخُلَفَاءِ الرَّاشِدِينَ الْمَهْدِيِّينَ، تَمَسَّكُوا بِهَا وَعَضُّوا عَلَيْهَا بِالنَّوَاجِذِ، وَإِيَّاكُمْ وَمُحْدَثَاتِ الأُمُورِ.",
            grade: "صحيح", reference: "أبو داود: 4607"),
        // ch 301 - الطهارة (إضافية)
        HHadith(id: 3009, bookId: 3, chapterId: 301, number: 9,
            narrator: "أبو هريرة رضي الله عنه",
            text: "لاَ تُقْبَلُ صَلاةُ مَنْ أَحْدَثَ حَتَّى يَتَوَضَّأَ.",
            grade: "صحيح", reference: "البخاري: 135"),
        // ch 302 - الصلاة (إضافية)
        HHadith(id: 3010, bookId: 3, chapterId: 302, number: 10,
            narrator: "عبد الله بن عمر رضي الله عنهما",
            text: "إِذَا صَلَّى أَحَدُكُمْ فِي ثَوْبٍ وَاحِدٍ فَلْيُخَالِفْ بَيْنَ طَرَفَيْهِ.",
            grade: "صحيح", reference: "البخاري: 359"),
        HHadith(id: 3011, bookId: 3, chapterId: 302, number: 11,
            narrator: "عائشة رضي الله عنها",
            text: "قَالَتْ: فَقَدْتُ رَسُولَ اللَّهِ ﷺ لَيْلَةً فَلَمَسْتُهُ فَوَجَدَتْ يَدَهُ وَهُوَ رَاكِعٌ يَقُولُ: سُبْحَانَكَ وَبِحَمْدِكَ لاَ إِلَهَ إِلاَّ أَنْتَ.",
            grade: "صحيح", reference: "مسلم: 485"),
        // ch 303 - الزكاة (إضافية)
        HHadith(id: 3012, bookId: 3, chapterId: 303, number: 12,
            narrator: "أبو هريرة رضي الله عنه",
            text: "خَيْرُ الصَّدَقَةِ مَا كَانَ عَنْ ظَهْرِ غِنًى، وَابْدَأْ بِمَنْ تَعُولُ.",
            grade: "صحيح", reference: "البخاري: 1426"),
        // ch 304 - الأدب (إضافية)
        HHadith(id: 3013, bookId: 3, chapterId: 304, number: 13,
            narrator: "أبو هريرة رضي الله عنه",
            text: "مَنْ كَفَّ غَضَبَهُ كَفَّ اللَّهُ عَنْهُ عَذَابَهُ، وَمَنْ خَزَنَ لِسَانَهُ سَتَرَ اللَّهُ عَوْرَتَهُ.",
            grade: "حسن", reference: "الطبراني"),
        // ch 305 - السنة (إضافية)
        HHadith(id: 3014, bookId: 3, chapterId: 305, number: 14,
            narrator: "أبو هريرة رضي الله عنه",
            text: "تَرَكْتُ فِيكُمْ شَيْئَيْنِ لَنْ تَضِلُّوا بَعْدَهُمَا: كِتَابَ اللَّهِ وَسُنَّتِي.",
            grade: "صحيح", reference: "الحاكم"),
    ]

    // ══ الترمذي ═════════════════════════════════════════════════
    static let tirmidhiHadiths: [HHadith] = [
        // ch 401 - العلم
        HHadith(id: 4001, bookId: 4, chapterId: 401, number: 1,
            narrator: "أبو هريرة رضي الله عنه",
            text: "مَنْ سَلَكَ طَرِيقًا يَلْتَمِسُ فِيهِ عِلْمًا سَهَّلَ اللَّهُ لَهُ طَرِيقًا إِلَى الْجَنَّةِ.",
            grade: "صحيح", reference: "مسلم: 2699"),
        HHadith(id: 4002, bookId: 4, chapterId: 401, number: 2,
            narrator: "أبو الدرداء رضي الله عنه",
            text: "فَضْلُ الْعَالِمِ عَلَى الْعَابِدِ كَفَضْلِ الْقَمَرِ لَيْلَةَ الْبَدْرِ عَلَى سَائِرِ الْكَوَاكِبِ.",
            grade: "صحيح", reference: "أبو داود: 3641"),
        HHadith(id: 4003, bookId: 4, chapterId: 401, number: 3,
            narrator: "أبو هريرة رضي الله عنه",
            text: "إِذَا مَاتَ ابْنُ آدَمَ انْقَطَعَ عَنْهُ عَمَلُهُ إِلاَّ مِنْ ثَلاَثَةٍ: إِلاَّ مِنْ صَدَقَةٍ جَارِيَةٍ، أَوْ عِلْمٍ يُنْتَفَعُ بِهِ، أَوْ وَلَدٍ صَالِحٍ يَدْعُو لَهُ.",
            grade: "صحيح", reference: "مسلم: 1631"),
        // ch 402 - الزهد
        HHadith(id: 4004, bookId: 4, chapterId: 402, number: 4,
            narrator: "أبو هريرة رضي الله عنه",
            text: "مَنْ أَصْبَحَ مِنْكُمْ آمِنًا فِي سِرْبِهِ مُعَافًى فِي جَسَدِهِ عِنْدَهُ قُوتُ يَوْمِهِ فَكَأَنَّمَا حِيزَتْ لَهُ الدُّنْيَا.",
            grade: "حسن", reference: "الترمذي: 2346"),
        HHadith(id: 4005, bookId: 4, chapterId: 402, number: 5,
            narrator: "عبد الله بن مسعود رضي الله عنه",
            text: "لاَ تَتَّخِذُوا الضَّيْعَةَ فَتَرْغَبُوا فِي الدُّنْيَا.",
            grade: "حسن", reference: "الترمذي: 2328"),
        // ch 403 - آداب الطعام
        HHadith(id: 4006, bookId: 4, chapterId: 403, number: 6,
            narrator: "عمر بن أبي سلمة رضي الله عنه",
            text: "يَا غُلامُ سَمِّ اللَّهَ وَكُلْ بِيَمِينِكَ وَكُلْ مِمَّا يَلِيكَ.",
            grade: "صحيح", reference: "البخاري: 5376"),
        HHadith(id: 4007, bookId: 4, chapterId: 403, number: 7,
            narrator: "أبو جحيفة رضي الله عنه",
            text: "لاَ آكُلُ مُتَّكِئًا. وَقَالَ ﷺ: أَمَّا أَنَا فَلاَ آكُلُ إِلاَّ جَالِسًا.",
            grade: "صحيح", reference: "البخاري: 5399"),
        // ch 404 - المعاملات
        HHadith(id: 4008, bookId: 4, chapterId: 404, number: 8,
            narrator: "جابر رضي الله عنه",
            text: "لَعَنَ رَسُولُ اللَّهِ ﷺ آكِلَ الرِّبَا وَمُوكِلَهُ وَكَاتِبَهُ وَشَاهِدَيْهِ، وَقَالَ: هُمْ سَوَاءٌ.",
            grade: "صحيح", reference: "مسلم: 1598"),
        // ch 405 - البر والصلة
        HHadith(id: 4009, bookId: 4, chapterId: 405, number: 9,
            narrator: "أبو هريرة رضي الله عنه",
            text: "مَنْ سَرَّهُ أَنْ يُبْسَطَ لَهُ فِي رِزْقِهِ وَيُنْسَأَ لَهُ فِي أَثَرِهِ فَلْيَصِلْ رَحِمَهُ.",
            grade: "صحيح", reference: "البخاري: 5985"),
        HHadith(id: 4010, bookId: 4, chapterId: 405, number: 10,
            narrator: "أنس بن مالك رضي الله عنه",
            text: "رَحِمَ اللَّهُ امْرَأً أَعَانَ وَلَدَهُ عَلَى بِرِّهِ.",
            grade: "حسن", reference: "ابن حبان"),
        // ch 401 - العلم (إضافية)
        HHadith(id: 4011, bookId: 4, chapterId: 401, number: 11,
            narrator: "عبد الله بن عمرو رضي الله عنهما",
            text: "الرَّاحِمُونَ يَرْحَمُهُمُ الرَّحْمَنُ، ارْحَمُوا مَنْ فِي الأَرْضِ يَرْحَمْكُمْ مَنْ فِي السَّمَاءِ.",
            grade: "صحيح", reference: "أبو داود: 4941"),
        HHadith(id: 4012, bookId: 4, chapterId: 401, number: 12,
            narrator: "معاذ بن جبل رضي الله عنه",
            text: "تَعَلَّمُوا الْعِلْمَ فَإِنَّ تَعَلُّمَهُ لِلَّهِ خَشْيَةٌ، وَطَلَبَهُ عِبَادَةٌ، وَمُذَاكَرَتَهُ تَسْبِيحٌ، وَالْبَحْثَ عَنْهُ جِهَادٌ.",
            grade: "حسن", reference: "الطبراني"),
        // ch 402 - الزهد (إضافية)
        HHadith(id: 4013, bookId: 4, chapterId: 402, number: 13,
            narrator: "أبو هريرة رضي الله عنه",
            text: "ازْهَدْ فِي الدُّنْيَا يُحِبَّكَ اللَّهُ، وَازْهَدْ فِيمَا عِنْدَ النَّاسِ يُحِبَّكَ النَّاسُ.",
            grade: "حسن", reference: "ابن ماجه: 4102"),
        // ch 403 - آداب الطعام (إضافية)
        HHadith(id: 4014, bookId: 4, chapterId: 403, number: 14,
            narrator: "أبو هريرة رضي الله عنه",
            text: "مَا مَلأَ آدَمِيٌّ وِعَاءً شَرًّا مِنْ بَطْنِهِ، بِحَسْبِ ابْنِ آدَمَ لُقَيْمَاتٌ يُقِمْنَ صُلْبَهُ.",
            grade: "حسن صحيح", reference: "الترمذي: 2380"),
        // ch 404 - المعاملات (إضافية)
        HHadith(id: 4015, bookId: 4, chapterId: 404, number: 15,
            narrator: "أبو هريرة رضي الله عنه",
            text: "الْبَيِّعَانِ بِالْخِيَارِ مَا لَمْ يَتَفَرَّقَا.",
            grade: "صحيح", reference: "البخاري: 2111"),
        // ch 405 - البر والصلة (إضافية)
        HHadith(id: 4016, bookId: 4, chapterId: 405, number: 16,
            narrator: "أبو هريرة رضي الله عنه",
            text: "لاَ يَجْزِي وَلَدٌ وَالِدَهُ إِلاَّ أَنْ يَجِدَهُ مَمْلُوكًا فَيَشْتَرِيَهُ فَيُعْتِقَهُ.",
            grade: "صحيح", reference: "مسلم: 1510"),
    ]

    // ══ النسائي ═════════════════════════════════════════════════
    static let nasaiHadiths: [HHadith] = [
        // ch 501 - الصلاة
        HHadith(id: 5001, bookId: 5, chapterId: 501, number: 1,
            narrator: "عبد الله بن عمرو رضي الله عنهما",
            text: "وَقْتُ الظُّهْرِ إِذَا زَالَتِ الشَّمْسُ وَكَانَ ظِلُّ الرَّجُلِ كَطُولِهِ مَا لَمْ يَحْضُرِ الْعَصْرُ، وَوَقْتُ الْعَصْرِ مَا لَمْ تَصْفَرَّ الشَّمْسُ.",
            grade: "صحيح", reference: "مسلم: 612"),
        HHadith(id: 5002, bookId: 5, chapterId: 501, number: 2,
            narrator: "أبو هريرة رضي الله عنه",
            text: "إِنَّ الصَّلاةَ الَّتِي تُدْرَكُ أَوَّلُهَا خَيْرٌ مِنْ أَنْ يُدْرَكَ آخِرُهَا.",
            grade: "صحيح", reference: "النسائي: 864"),
        // ch 502 - تحريم الظلم
        HHadith(id: 5003, bookId: 5, chapterId: 502, number: 3,
            narrator: "أبو ذر الغفاري رضي الله عنه",
            text: "يَا عِبَادِي إِنِّي حَرَّمْتُ الظُّلْمَ عَلَى نَفْسِي وَجَعَلْتُهُ بَيْنَكُمْ مُحَرَّمًا فَلاَ تَظَالَمُوا.",
            grade: "صحيح", reference: "مسلم: 2577"),
        HHadith(id: 5004, bookId: 5, chapterId: 502, number: 4,
            narrator: "أبو هريرة رضي الله عنه",
            text: "اتَّقُوا الظُّلْمَ فَإِنَّ الظُّلْمَ ظُلُمَاتٌ يَوْمَ الْقِيَامَةِ.",
            grade: "صحيح", reference: "مسلم: 2578"),
        // ch 503 - الصيام
        HHadith(id: 5005, bookId: 5, chapterId: 503, number: 5,
            narrator: "أبو هريرة رضي الله عنه",
            text: "مَنْ صَامَ رَمَضَانَ إِيمَانًا وَاحْتِسَابًا غُفِرَ لَهُ مَا تَقَدَّمَ مِنْ ذَنْبِهِ.",
            grade: "صحيح", reference: "البخاري: 38"),
        HHadith(id: 5006, bookId: 5, chapterId: 503, number: 6,
            narrator: "أبو سعيد الخدري رضي الله عنه",
            text: "مَنْ صَامَ يَوْمًا فِي سَبِيلِ اللَّهِ بَعَّدَ اللَّهُ وَجْهَهُ عَنِ النَّارِ سَبْعِينَ خَرِيفًا.",
            grade: "صحيح", reference: "مسلم: 1153"),
        // ch 504 - القضاء
        HHadith(id: 5007, bookId: 5, chapterId: 504, number: 7,
            narrator: "أبو هريرة رضي الله عنه",
            text: "إِنَّ الْمُقْسِطِينَ عِنْدَ اللَّهِ عَلَى مَنَابِرَ مِنْ نُورٍ عَنْ يَمِينِ الرَّحْمَنِ، الَّذِينَ يَعْدِلُونَ فِي حُكْمِهِمْ وَأَهْلِيهِمْ وَمَا وَلُوا.",
            grade: "صحيح", reference: "مسلم: 1827"),
        // ch 501 - الصلاة وأوقاتها (إضافية)
        HHadith(id: 5008, bookId: 5, chapterId: 501, number: 8,
            narrator: "أبو هريرة رضي الله عنه",
            text: "مَنْ أَدْرَكَ رَكْعَةً مِنَ الصَّلاةِ فَقَدْ أَدْرَكَ الصَّلاةَ.",
            grade: "صحيح", reference: "البخاري: 580"),
        HHadith(id: 5009, bookId: 5, chapterId: 501, number: 9,
            narrator: "عائشة رضي الله عنها",
            text: "أَحَبُّ الأَعْمَالِ إِلَى اللَّهِ أَدْوَمُهَا وَإِنْ قَلَّ.",
            grade: "صحيح", reference: "البخاري: 6464"),
        // ch 502 - تحريم الظلم (إضافية)
        HHadith(id: 5010, bookId: 5, chapterId: 502, number: 10,
            narrator: "ابن عمر رضي الله عنهما",
            text: "الظُّلْمُ ظُلُمَاتٌ يَوْمَ الْقِيَامَةِ.",
            grade: "صحيح", reference: "البخاري: 2447"),
        // ch 503 - الصيام (إضافية)
        HHadith(id: 5011, bookId: 5, chapterId: 503, number: 11,
            narrator: "أبو هريرة رضي الله عنه",
            text: "مَنْ قَامَ رَمَضَانَ إِيمَانًا وَاحْتِسَابًا غُفِرَ لَهُ مَا تَقَدَّمَ مِنْ ذَنْبِهِ.",
            grade: "صحيح", reference: "البخاري: 37"),
        HHadith(id: 5012, bookId: 5, chapterId: 503, number: 12,
            narrator: "أبو هريرة رضي الله عنه",
            text: "إِذَا جَاءَ رَمَضَانُ فُتِّحَتْ أَبْوَابُ الْجَنَّةِ وَغُلِّقَتْ أَبْوَابُ النَّارِ وَصُفِّدَتِ الشَّيَاطِينُ.",
            grade: "صحيح", reference: "البخاري: 1899"),
        // ch 504 - القضاء والعدل (إضافية)
        HHadith(id: 5013, bookId: 5, chapterId: 504, number: 13,
            narrator: "أبو هريرة رضي الله عنه",
            text: "اتَّقُوا الظُّلْمَ فَإِنَّ الظُّلْمَ ظُلُمَاتٌ يَوْمَ الْقِيَامَةِ، وَاتَّقُوا الشُّحَّ فَإِنَّ الشُّحَّ أَهْلَكَ مَنْ كَانَ قَبْلَكُمْ.",
            grade: "صحيح", reference: "مسلم: 2578"),
    ]

    // ══ ابن ماجه ═════════════════════════════════════════════════
    static let ibnMajahHadiths: [HHadith] = [
        // ch 601 - الإخلاص
        HHadith(id: 6001, bookId: 6, chapterId: 601, number: 1,
            narrator: "عمر بن الخطاب رضي الله عنه",
            text: "إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ.",
            grade: "صحيح", reference: "البخاري: 1"),
        HHadith(id: 6002, bookId: 6, chapterId: 601, number: 2,
            narrator: "أبو هريرة رضي الله عنه",
            text: "إِنَّ اللَّهَ لاَ يَنْظُرُ إِلَى صُوَرِكُمْ وَأَمْوَالِكُمْ وَلَكِنْ يَنْظُرُ إِلَى قُلُوبِكُمْ وَأَعْمَالِكُمْ.",
            grade: "صحيح", reference: "مسلم: 2564"),
        // ch 602 - التوبة
        HHadith(id: 6003, bookId: 6, chapterId: 602, number: 3,
            narrator: "أبو هريرة رضي الله عنه",
            text: "التَّائِبُ مِنَ الذَّنْبِ كَمَنْ لاَ ذَنْبَ لَهُ.",
            grade: "حسن", reference: "ابن ماجه: 4250"),
        HHadith(id: 6004, bookId: 6, chapterId: 602, number: 4,
            narrator: "أنس بن مالك رضي الله عنه",
            text: "كُلُّ بَنِي آدَمَ خَطَّاءٌ، وَخَيْرُ الْخَطَّائِينَ التَّوَّابُونَ.",
            grade: "حسن", reference: "الترمذي: 2499"),
        HHadith(id: 6005, bookId: 6, chapterId: 602, number: 5,
            narrator: "أبو موسى الأشعري رضي الله عنه",
            text: "إِنَّ اللَّهَ يَبْسُطُ يَدَهُ بِاللَّيْلِ لِيَتُوبَ مُسِيءُ النَّهَارِ، وَيَبْسُطُ يَدَهُ بِالنَّهَارِ لِيَتُوبَ مُسِيءُ اللَّيْلِ، حَتَّى تَطْلُعَ الشَّمْسُ مِنْ مَغْرِبِهَا.",
            grade: "صحيح", reference: "مسلم: 2759"),
        // ch 603 - الصبر
        HHadith(id: 6006, bookId: 6, chapterId: 603, number: 6,
            narrator: "أبو سعيد الخدري رضي الله عنه",
            text: "مَا أُعْطِيَ أَحَدٌ عَطَاءً خَيْرًا وَأَوْسَعَ مِنَ الصَّبْرِ.",
            grade: "صحيح", reference: "البخاري: 1469"),
        HHadith(id: 6007, bookId: 6, chapterId: 603, number: 7,
            narrator: "أبو هريرة رضي الله عنه",
            text: "عَجَبًا لأَمْرِ الْمُؤْمِنِ إِنَّ أَمْرَهُ كُلَّهُ خَيْرٌ، إِنْ أَصَابَتْهُ سَرَّاءُ شَكَرَ فَكَانَ خَيْرًا لَهُ، وَإِنْ أَصَابَتْهُ ضَرَّاءُ صَبَرَ فَكَانَ خَيْرًا لَهُ.",
            grade: "صحيح", reference: "مسلم: 2999"),
        // ch 604 - الصدق
        HHadith(id: 6008, bookId: 6, chapterId: 604, number: 8,
            narrator: "عبد الله بن مسعود رضي الله عنه",
            text: "عَلَيْكُمْ بِالصِّدْقِ فَإِنَّ الصِّدْقَ يَهْدِي إِلَى الْبِرِّ وَإِنَّ الْبِرَّ يَهْدِي إِلَى الْجَنَّةِ، وَإِيَّاكُمْ وَالْكَذِبَ فَإِنَّ الْكَذِبَ يَهْدِي إِلَى الْفُجُورِ وَإِنَّ الْفُجُورَ يَهْدِي إِلَى النَّارِ.",
            grade: "صحيح", reference: "البخاري: 6094"),
        // ch 605 - المراقبة
        HHadith(id: 6009, bookId: 6, chapterId: 605, number: 9,
            narrator: "عمر بن الخطاب رضي الله عنه",
            text: "أَنْ تَعْبُدَ اللَّهَ كَأَنَّكَ تَرَاهُ، فَإِنْ لَمْ تَكُنْ تَرَاهُ فَإِنَّهُ يَرَاكَ.",
            grade: "صحيح", reference: "البخاري: 50"),
        // ch 606 - الصلاة على النبي
        HHadith(id: 6010, bookId: 6, chapterId: 606, number: 10,
            narrator: "أبو هريرة رضي الله عنه",
            text: "مَنْ صَلَّى عَلَيَّ وَاحِدَةً صَلَّى اللَّهُ عَلَيْهِ عَشْرًا.",
            grade: "صحيح", reference: "مسلم: 408"),
        HHadith(id: 6011, bookId: 6, chapterId: 606, number: 11,
            narrator: "الحسين بن علي رضي الله عنهما",
            text: "الْبَخِيلُ مَنْ ذُكِرْتُ عِنْدَهُ فَلَمْ يُصَلِّ عَلَيَّ.",
            grade: "صحيح", reference: "الترمذي: 3546"),
        // ch 601 - الإخلاص (إضافية)
        HHadith(id: 6012, bookId: 6, chapterId: 601, number: 12,
            narrator: "معاذ بن جبل رضي الله عنه",
            text: "أَخْلِصْ دِينَكَ يَكْفِكَ الْعَمَلُ الْقَلِيلُ.",
            grade: "صحيح", reference: "الحاكم"),
        HHadith(id: 6013, bookId: 6, chapterId: 601, number: 13,
            narrator: "أبو هريرة رضي الله عنه",
            text: "قَالَ اللَّهُ تَعَالَى: أَنَا أَغْنَى الشُّرَكَاءِ عَنِ الشِّرْكِ، مَنْ عَمِلَ عَمَلاً أَشْرَكَ مَعِي فِيهِ غَيْرِي تَرَكْتُهُ وَشِرْكَهُ.",
            grade: "صحيح", reference: "مسلم: 2985"),
        // ch 602 - التوبة (إضافية)
        HHadith(id: 6014, bookId: 6, chapterId: 602, number: 14,
            narrator: "أبو هريرة رضي الله عنه",
            text: "مَنْ تَابَ قَبْلَ أَنْ تَطْلُعَ الشَّمْسُ مِنْ مَغْرِبِهَا تَابَ اللَّهُ عَلَيْهِ.",
            grade: "صحيح", reference: "مسلم: 2703"),
        // ch 603 - الصبر (إضافية)
        HHadith(id: 6015, bookId: 6, chapterId: 603, number: 15,
            narrator: "صهيب رضي الله عنه",
            text: "عَجَبًا لأَمْرِ الْمُؤْمِنِ إِنَّ أَمْرَهُ كُلَّهُ لَهُ خَيْرٌ، وَلَيْسَ ذَلِكَ لأَحَدٍ إِلاَّ لِلْمُؤْمِنِ.",
            grade: "صحيح", reference: "مسلم: 2999"),
        HHadith(id: 6016, bookId: 6, chapterId: 603, number: 16,
            narrator: "أنس بن مالك رضي الله عنه",
            text: "إِنَّ عِظَمَ الْجَزَاءِ مَعَ عِظَمِ الْبَلاءِ، وَإِنَّ اللَّهَ إِذَا أَحَبَّ قَوْمًا ابْتَلاَهُمْ.",
            grade: "حسن صحيح", reference: "الترمذي: 2396"),
        // ch 604 - الصدق (إضافية)
        HHadith(id: 6017, bookId: 6, chapterId: 604, number: 17,
            narrator: "أبو بكر الصديق رضي الله عنه",
            text: "عَلَيْكُمْ بِالصِّدْقِ فَإِنَّهُ مَعَ الْبِرِّ وَهُمَا فِي الْجَنَّةِ، وَإِيَّاكُمْ وَالْكَذِبَ فَإِنَّهُ مَعَ الْفُجُورِ وَهُمَا فِي النَّارِ.",
            grade: "صحيح", reference: "أحمد"),
        // ch 605 - المراقبة (إضافية)
        HHadith(id: 6018, bookId: 6, chapterId: 605, number: 18,
            narrator: "جبريل عليه السلام",
            text: "الإِحْسَانُ أَنْ تَعْبُدَ اللَّهَ كَأَنَّكَ تَرَاهُ، فَإِنْ لَمْ تَكُنْ تَرَاهُ فَإِنَّهُ يَرَاكَ.",
            grade: "صحيح", reference: "البخاري: 50"),
        HHadith(id: 6019, bookId: 6, chapterId: 605, number: 19,
            narrator: "أبو هريرة رضي الله عنه",
            text: "مَنْ حَسُنَ إِسْلاَمُ الْمَرْءِ تَرْكُهُ مَا لاَ يَعْنِيهِ.",
            grade: "حسن", reference: "الترمذي: 2317"),
        // ch 606 - الصلاة على النبي (إضافية)
        HHadith(id: 6020, bookId: 6, chapterId: 606, number: 20,
            narrator: "أنس بن مالك رضي الله عنه",
            text: "مَنْ صَلَّى عَلَيَّ صَلاةً وَاحِدَةً صَلَّى اللَّهُ عَلَيْهِ عَشْرَ صَلَوَاتٍ وَحُطَّتْ عَنْهُ عَشْرُ خَطِيئَاتٍ وَرُفِعَتْ لَهُ عَشْرُ دَرَجَاتٍ.",
            grade: "صحيح", reference: "النسائي: 1297"),
    ]
}

// ══════════════════════════════════════════════════════════════
// MARK: - VIEWS
// ══════════════════════════════════════════════════════════════

// ── 1. Books List ─────────────────────────────────────────────
struct HadithBooksView: View {

    @StateObject private var store = HadithStore.shared
    @State private var searchText  = ""
    @State private var showSearch  = false
    @State private var showFavs    = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {

                // Header
                HStack(alignment: .center) {
                    // Back button
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Theme.gold)
                            .frame(width: 36, height: 36)
                            .background(Theme.card)
                            .clipShape(Circle())
                    }
                    Spacer()
                    VStack(alignment: .center, spacing: 3) {
                        Text("كتب الحديث")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Theme.goldLight)
                        Text("الكتب الستة الصحاح")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        // Favorites toggle
                        Button { withAnimation { showFavs.toggle() } } label: {
                            Image(systemName: showFavs ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 17))
                                .foregroundColor(showFavs ? Theme.gold : Theme.textSecondary)
                                .frame(width: 36, height: 36)
                                .background(Theme.card)
                                .clipShape(Circle())
                        }
                        // Search toggle
                        Button { withAnimation { showSearch.toggle() } } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 17))
                                .foregroundColor(showSearch ? Theme.gold : Theme.textSecondary)
                                .frame(width: 36, height: 36)
                                .background(Theme.card)
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                // Search bar
                if showSearch {
                    NavigationLink(destination: HadithSearchView(initialQuery: searchText)) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Theme.textSecondary)
                                .font(.system(size: 14))
                            Text("ابحث في جميع الكتب...")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                        }
                        .padding(12)
                        .background(Theme.card)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Divider().background(Theme.border)

                // Saved hadiths banner
                if showFavs {
                    HadithFavoritesView()
                        .transition(.opacity)
                } else {
                    // Books list
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            ForEach(store.allBooks) { book in
                                NavigationLink(destination: HadithBookDetailView(book: book)) {
                                    HBookCard(book: book)
                                }
                                .buttonStyle(.plain)
                            }
                            // Stats footer
                            VStack(spacing: 4) {
                                Text("المجموع: \(store.allBooks.reduce(0) { $0 + $1.hadithCount }) حديثاً")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textSecondary)
                                Text("يعمل بالكامل بدون إنترنت")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textSecondary.opacity(0.6))
                            }
                            .padding(.vertical, 16)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }
}

// ── Book card ──────────────────────────────────────────────────
struct HBookCard: View {
    let book: HBook
    @ObservedObject private var store = HadithStore.shared

    private var lastRead: HHadith? {
        guard let id = store.lastHadithId(bookId: book.id) else { return nil }
        return store.hadith(id: id)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(book.accentColor.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: book.icon)
                    .font(.system(size: 22))
                    .foregroundColor(book.accentColor)
            }

            // Info
            VStack(alignment: .trailing, spacing: 5) {
                Text(book.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.text)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text("\(book.author) (\(book.deathYear))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(book.accentColor.opacity(0.85))
                Text(book.description)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                HStack(spacing: 6) {
                    Spacer()
                    if lastRead != nil {
                        Label("متابعة القراءة", systemImage: "bookmark.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.gold)
                    }
                    HadithCountBadge(count: book.hadithCount, color: book.accentColor)
                }
            }

            Image(systemName: "chevron.left")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(14)
        .background(Theme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }
}

struct HadithCountBadge: View {
    let count: Int
    let color: Color
    var body: some View {
        Text("\(count) حديث")
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color)
            .cornerRadius(8)
    }
}

// ── 2. Book Detail (Chapters) ─────────────────────────────────
struct HadithBookDetailView: View {
    let book: HBook
    @StateObject private var store = HadithStore.shared
    @State private var searchText  = ""

    private var filteredChapters: [HChapter] {
        let all = store.chapters(bookId: book.id)
        if searchText.isEmpty { return all }
        let q = searchText.lowercased()
        return all.filter { $0.title.contains(q) }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {

                // Gradient header
                ZStack(alignment: .bottomTrailing) {
                    LinearGradient(
                        colors: [book.accentColor, book.accentColor.opacity(0.55)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    .frame(height: 130)

                    VStack(alignment: .trailing, spacing: 6) {
                        Text(book.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        HStack(spacing: 10) {
                            Text("\(store.chapters(bookId: book.id).count) كتاباً")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.85))
                            Text("•")
                                .foregroundColor(.white.opacity(0.5))
                            Text("\(book.hadithCount) حديثاً")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }

                // Search
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.textSecondary)
                        .font(.system(size: 14))
                    TextField("ابحث في الأبواب...", text: $searchText)
                        .font(.system(size: 14))
                        .foregroundColor(Theme.text)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
                .padding(11)
                .background(Theme.card)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                // Chapters list
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredChapters) { chapter in
                            NavigationLink(destination: HadithChapterView(chapter: chapter, book: book)) {
                                HChapterRow(chapter: chapter, book: book)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
    }
}

struct HChapterRow: View {
    let chapter: HChapter
    let book: HBook
    @StateObject private var store = HadithStore.shared

    var body: some View {
        HStack(spacing: 12) {
            // Number badge
            Text("\(chapter.number)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(book.accentColor)
                .clipShape(Circle())

            VStack(alignment: .trailing, spacing: 4) {
                Text(chapter.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text("\(store.hadiths(chapterId: chapter.id).count) أحاديث")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Image(systemName: "chevron.left")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(13)
        .background(Theme.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }
}

// ── 3. Chapter View (Hadiths list) ────────────────────────────
struct HadithChapterView: View {
    let chapter: HChapter
    let book: HBook
    @StateObject private var store = HadithStore.shared

    private var hadiths: [HHadith] {
        store.hadiths(chapterId: chapter.id)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    // Chapter header
                    VStack(spacing: 8) {
                        Text(chapter.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(book.accentColor)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        Divider().background(book.accentColor.opacity(0.3))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                    // Hadith cards
                    ForEach(hadiths) { hadith in
                        NavigationLink(destination: HadithDetailView(hadith: hadith, book: book, allHadiths: hadiths)) {
                            HHadithCard(hadith: hadith, book: book, compact: true)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 30)
                }
            }
        }
        .navigationTitle(chapter.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// ── Hadith preview card ────────────────────────────────────────
struct HHadithCard: View {
    let hadith: HHadith
    let book: HBook
    let compact: Bool
    @ObservedObject private var store = HadithStore.shared

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            // Top row: hadith number + grade + bookmark
            HStack {
                Button { store.toggleFavorite(hadith.id) } label: {
                    Image(systemName: store.isFavorite(hadith.id) ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 14))
                        .foregroundColor(store.isFavorite(hadith.id) ? book.accentColor : Theme.textSecondary)
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 6) {
                    Text(hadith.grade)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(hadith.grade == "صحيح" ? Color.green.opacity(0.8) : Color.orange.opacity(0.8))
                        .cornerRadius(6)
                    Text("حديث \(hadith.number)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(book.accentColor)
                        .cornerRadius(6)
                }
            }

            // Narrator
            if !hadith.narrator.isEmpty {
                Text("عن \(hadith.narrator)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(book.accentColor.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            // Hadith text
            Text(hadith.text)
                .font(.system(size: compact ? 14 : 16))
                .foregroundColor(Theme.text)
                .lineSpacing(6)
                .lineLimit(compact ? 3 : nil)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .multilineTextAlignment(.trailing)

            // Reference
            HStack {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Text(hadith.reference)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                    .italic()
            }
        }
        .padding(14)
        .background(Theme.card)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(store.isFavorite(hadith.id) ? book.accentColor.opacity(0.4) : Theme.border, lineWidth: 1)
        )
    }
}

// ── 4. Full Hadith Detail ─────────────────────────────────────
struct HadithDetailView: View {
    let hadith: HHadith
    let book: HBook
    let allHadiths: [HHadith]  // for prev/next
    @ObservedObject private var store = HadithStore.shared
    @State private var fontSize: CGFloat = 18
    @State private var showShareSheet = false

    private var currentIndex: Int? {
        allHadiths.firstIndex(where: { $0.id == hadith.id })
    }

    private var shareText: String {
        """
        \(hadith.text)

        عن \(hadith.narrator)
        \(hadith.reference) — \(book.name)
        """
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .trailing, spacing: 18) {

                    // Book + chapter badge row
                    HStack {
                        Text(hadith.reference)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                            .italic()
                        Spacer()
                        Text(book.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(book.accentColor)
                            .cornerRadius(8)
                    }

                    // Grade badge
                    HStack {
                        Spacer()
                        Text(hadith.grade)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(hadith.grade == "صحيح" ? Color.green.opacity(0.8) : Color.orange.opacity(0.8))
                            .cornerRadius(8)
                    }

                    // Narrator
                    if !hadith.narrator.isEmpty {
                        HStack {
                            Spacer()
                            Label("عن \(hadith.narrator)", systemImage: "person.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(book.accentColor)
                        }
                    }

                    Divider().background(book.accentColor.opacity(0.3))

                    // Main hadith text
                    Text(hadith.text)
                        .font(.system(size: fontSize))
                        .foregroundColor(Theme.text)
                        .lineSpacing(10)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(.trailing)
                        .padding(.vertical, 4)

                    Divider().background(book.accentColor.opacity(0.15))

                    // Font size control
                    HStack {
                        Spacer()
                        Text("حجم الخط")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                        HStack(spacing: 4) {
                            Button { if fontSize > 13 { fontSize -= 1 } } label: {
                                Image(systemName: "textformat.size.smaller")
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.gold)
                                    .frame(width: 32, height: 32)
                                    .background(Theme.card)
                                    .cornerRadius(8)
                            }
                            Button { if fontSize < 26 { fontSize += 1 } } label: {
                                Image(systemName: "textformat.size.larger")
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.gold)
                                    .frame(width: 32, height: 32)
                                    .background(Theme.card)
                                    .cornerRadius(8)
                            }
                        }
                    }

                    // Prev / Next
                    if let idx = currentIndex {
                        HStack {
                            if idx < allHadiths.count - 1 {
                                NavigationLink(destination: HadithDetailView(hadith: allHadiths[idx + 1], book: book, allHadiths: allHadiths)) {
                                    Label("التالي", systemImage: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16).padding(.vertical, 8)
                                        .background(book.accentColor)
                                        .cornerRadius(10)
                                }
                            }
                            Spacer()
                            if idx > 0 {
                                NavigationLink(destination: HadithDetailView(hadith: allHadiths[idx - 1], book: book, allHadiths: allHadiths)) {
                                    Label("السابق", systemImage: "chevron.left")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16).padding(.vertical, 8)
                                        .background(book.accentColor.opacity(0.7))
                                        .cornerRadius(10)
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("حديث \(hadith.number)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button { showShareSheet = true } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(Theme.gold)
                }
                Button {
                    store.toggleFavorite(hadith.id)
                    store.savePosition(bookId: hadith.bookId, hadithId: hadith.id)
                } label: {
                    Image(systemName: store.isFavorite(hadith.id) ? "bookmark.fill" : "bookmark")
                        .foregroundColor(store.isFavorite(hadith.id) ? book.accentColor : Theme.textSecondary)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [shareText])
        }
        .onAppear {
            store.savePosition(bookId: hadith.bookId, hadithId: hadith.id)
        }
    }
}

// ── 5. Search View (Full-Text) ────────────────────────────────
struct HadithSearchView: View {
    let initialQuery: String
    @StateObject private var store = HadithStore.shared
    @State private var query       = ""
    @State private var results:   [HHadith] = []
    @State private var isSearching = false
    @State private var searchWorkItem: DispatchWorkItem? = nil
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {

                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.textSecondary)
                    TextField("ابحث في كل الأحاديث...", text: $query)
                        .font(.system(size: 15))
                        .foregroundColor(Theme.text)
                        .focused($focused)
                        .submitLabel(.search)
                        .onSubmit { runSearch() }
                        .onChange(of: query) { _ in
                            searchWorkItem?.cancel()
                            let item = DispatchWorkItem { runSearch() }
                            searchWorkItem = item
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: item)
                        }
                    if !query.isEmpty {
                        Button { query = ""; results = [] } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
                .padding(12)
                .background(Theme.card)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                // Results count
                if !query.isEmpty {
                    Text(isSearching ? "جارٍ البحث..." : "\(results.count) نتيجة")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 16)
                        .padding(.bottom, 4)
                }

                Divider().background(Theme.border)

                if results.isEmpty && !query.isEmpty && !isSearching {
                    // Empty state
                    VStack(spacing: 14) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 44))
                            .foregroundColor(Theme.textSecondary.opacity(0.4))
                        Text("لا توجد نتائج لـ «\(query)»")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.textSecondary)
                        Text("حاول بكلمات مختلفة أو بدون تشكيل")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.textSecondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if query.isEmpty {
                    // Hints
                    VStack(spacing: 14) {
                        Image(systemName: "text.magnifyingglass")
                            .font(.system(size: 44))
                            .foregroundColor(Theme.gold.opacity(0.4))
                        Text("ابحث في الكتب الستة")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                        VStack(alignment: .trailing, spacing: 8) {
                            ForEach(["الصبر", "التوبة", "الصلاة", "النية", "الزكاة"], id: \.self) { hint in
                                Button { query = hint; runSearch() } label: {
                                    HStack {
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 11))
                                        Text(hint)
                                            .font(.system(size: 13))
                                    }
                                    .foregroundColor(Theme.gold)
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(Theme.gold.opacity(0.10))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(results) { hadith in
                                if let book = HadithStore.shared.allBooks.first(where: { $0.id == hadith.bookId }) {
                                    NavigationLink(destination: HadithDetailView(
                                        hadith: hadith,
                                        book: book,
                                        allHadiths: store.hadiths(chapterId: hadith.chapterId)
                                    )) {
                                        HSearchResultCard(hadith: hadith, book: book, query: query)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .navigationTitle("البحث في الأحاديث")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            query = initialQuery
            focused = true
            if !initialQuery.isEmpty { runSearch() }
        }
    }

    private func runSearch() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { results = []; return }
        isSearching = true
        DispatchQueue.global(qos: .userInitiated).async {
            let found = store.search(query)
            DispatchQueue.main.async {
                results = found
                isSearching = false
            }
        }
    }
}

struct HSearchResultCard: View {
    let hadith: HHadith
    let book: HBook
    let query: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack {
                Text(hadith.reference)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Text(book.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(book.accentColor)
                    .cornerRadius(6)
            }
            Text(hadith.text)
                .font(.system(size: 13))
                .foregroundColor(Theme.text)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .multilineTextAlignment(.trailing)
        }
        .padding(12)
        .background(Theme.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }
}

// ── 6. Favorites View ──────────────────────────────────────────
struct HadithFavoritesView: View {
    @ObservedObject private var store = HadithStore.shared

    var body: some View {
        Group {
            if store.favoriteHadiths.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "bookmark.slash")
                        .font(.system(size: 44))
                        .foregroundColor(Theme.textSecondary.opacity(0.4))
                    Text("لا توجد أحاديث محفوظة")
                        .font(.system(size: 15))
                        .foregroundColor(Theme.textSecondary)
                    Text("اضغط على 🔖 في أي حديث لحفظه")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(store.favoriteHadiths) { hadith in
                            if let book = store.allBooks.first(where: { $0.id == hadith.bookId }) {
                                NavigationLink(destination: HadithDetailView(
                                    hadith: hadith,
                                    book: book,
                                    allHadiths: store.hadiths(chapterId: hadith.chapterId)
                                )) {
                                    HHadithCard(hadith: hadith, book: book, compact: true)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.bottom, 24)
                }
            }
        }
    }
}
