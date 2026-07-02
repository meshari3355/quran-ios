import SwiftUI

// MARK: - IslamicLibraryView (entry point)

struct IslamicLibraryView: View {
    let filter: String   // "tafsir" | "hadith" | "translation"

    var body: some View {
        switch filter {
        case "tafsir":      TafsirBooksListView()
        case "hadith":      HadithPortalView()
        case "translation": QuranTranslationsView()
        default:            TafsirBooksListView()
        }
    }
}

// ══════════════════════════════════════════════════════════════
// MARK: - TAFSIR  (API-powered — full Quran, all 114 surahs)
// ══════════════════════════════════════════════════════════════

struct TafsirBooksListView: View {
    var body: some View {
        List(TafsirBook.allCases) { book in
            NavigationLink(destination: TafsirSurahListView(book: book)) {
                TafsirBookRow(book: book)
            }
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("كتب التفسير")
    }
}

struct TafsirBookRow: View {
    let book: TafsirBook

    private var iconColor: Color {
        switch book {
        case .ibnKathir: return .indigo
        case .saadi:     return .teal
        case .jalalyn:   return Color(red: 0.6, green: 0.3, blue: 0.1)
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 46, height: 46)
                Image(systemName: book.icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.text)
                Text(book.author)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.goldLight)
                Text(book.description)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Surah list for a tafsir book

struct TafsirSurahListView: View {
    let book: TafsirBook
    @State private var searchText = ""
    @StateObject private var svc = TafsirService.shared

    private var filtered: [Surah] {
        searchText.isEmpty ? allSurahs
            : allSurahs.filter {
                $0.name.contains(searchText) ||
                $0.nameEn.lowercased().contains(searchText.lowercased()) ||
                "\($0.id)".contains(searchText)
            }
    }

    var body: some View {
        List(filtered) { surah in
            NavigationLink(destination: TafsirSurahView(surah: surah, book: book)) {
                TafsirSurahRow(surah: surah, book: book)
            }
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .searchable(text: $searchText, prompt: "ابحث عن سورة...")
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TafsirSurahRow: View {
    let surah: Surah
    let book: TafsirBook
    @StateObject private var svc = TafsirService.shared

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.gold.opacity(0.12))
                    .frame(width: 40, height: 40)
                Text("\(surah.id)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.gold)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(surah.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.text)
                    Spacer()
                    Text(surah.type)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Theme.gold.opacity(0.1))
                        .clipShape(Capsule())
                }
                Text("\(surah.verses) آية")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }
            if svc.isCached(surah: surah.id, book: book) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Theme.gold.opacity(0.6))
                    .font(.system(size: 14))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Tafsir reader for one surah

struct TafsirSurahView: View {
    let surah: Surah
    let book: TafsirBook

    @StateObject private var svc = TafsirService.shared
    @State private var ayahs: [TafsirAyah] = []
    @State private var isLoading = true
    @State private var errorMsg: String? = nil
    @State private var searchText = ""

    private var displayed: [TafsirAyah] {
        searchText.isEmpty ? ayahs
            : ayahs.filter {
                $0.text.contains(searchText) || "\($0.id)".contains(searchText)
            }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(Theme.gold)
                        .scaleEffect(1.3)
                    Text("جارٍ تحميل التفسير...")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textSecondary)
                }

            } else if let err = errorMsg {
                VStack(spacing: 16) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 44))
                        .foregroundColor(Theme.gold.opacity(0.5))
                    Text("تعذّر تحميل التفسير")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Theme.text)
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button {
                        Task { await fetchTafsir() }
                    } label: {
                        Label("إعادة المحاولة", systemImage: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.background)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Theme.gold)
                            .clipShape(Capsule())
                    }
                }

            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        TafsirSurahHeader(surah: surah, book: book)
                            .padding(.bottom, 8)

                        ForEach(displayed) { ayah in
                            TafsirAyahCard(ayah: ayah)
                        }

                        if displayed.isEmpty && !searchText.isEmpty {
                            Text("لا توجد نتائج")
                                .foregroundColor(Theme.textSecondary)
                                .padding(.top, 40)
                        }
                        Spacer(minLength: 40)
                    }
                }
                .searchable(text: $searchText, prompt: "ابحث في التفسير...")
            }
        }
        .navigationTitle("\(surah.name) — \(book.title)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await fetchTafsir() }
    }

    private func fetchTafsir() async {
        isLoading = true
        errorMsg = nil
        do {
            ayahs = try await svc.load(surah: surah.id, book: book)
            isLoading = false
        } catch {
            isLoading = false
            errorMsg = error.localizedDescription
        }
    }
}

struct TafsirSurahHeader: View {
    let surah: Surah
    let book: TafsirBook

    var body: some View {
        VStack(spacing: 10) {
            // Don't show Basmala header for:
            // - Surah 9 (At-Tawbah) — doesn't start with Basmala
            // - Surah 1 (Al-Fatiha) — the Basmala IS verse 1, shown as part of Ayah 1 tafsir
            if surah.id != 9 && surah.id != 1 {
                Text("بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Theme.goldLight)
                    .multilineTextAlignment(.center)
            }
            Text(surah.name)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Theme.text)
            HStack(spacing: 20) {
                Label("\(surah.verses) آية", systemImage: "list.number")
                Label(surah.type, systemImage: surah.type == "مكية" ? "sun.max.fill" : "building.2.fill")
            }
            .font(.system(size: 13))
            .foregroundColor(Theme.textSecondary)
            Divider().background(Theme.gold.opacity(0.3))
            Text(book.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.gold)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }
}

struct TafsirAyahCard: View {
    let ayah: TafsirAyah
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text("الآية \(ayah.id)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.text)
                    ZStack {
                        Circle()
                            .fill(Theme.gold.opacity(0.15))
                            .frame(width: 34, height: 34)
                        Text("\(ayah.id)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Theme.gold)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.card)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(ayah.text)
                    .font(.system(size: 16))
                    .foregroundColor(Theme.text)
                    .lineSpacing(8)
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .background(Theme.background)
                    .environment(\.layoutDirection, .rightToLeft)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider()
                .background(Theme.gold.opacity(0.12))
                .padding(.trailing, 16)
        }
    }
}


// ══════════════════════════════════════════════════════════════
// MARK: - TRANSLATIONS VIEW
// ══════════════════════════════════════════════════════════════

struct QuranTranslationOption: Identifiable, Hashable {
    let key: String
    let name: String
    let language: String
    let description: String

    var id: String { key }
}

enum QuranTranslationCatalog {
    static let options: [QuranTranslationOption] = [
        QuranTranslationOption(key: "en.sahih", name: "Saheeh International", language: "🇬🇧 English", description: "ترجمة إنجليزية واضحة ومعتمدة"),
        QuranTranslationOption(key: "en.pickthall", name: "Pickthall", language: "🇬🇧 English", description: "ترجمة إنجليزية كلاسيكية"),
        QuranTranslationOption(key: "ur.jalandhry", name: "جالندھری", language: "🇵🇰 Urdu", description: "ترجمة أردية"),
        QuranTranslationOption(key: "fr.hamidullah", name: "Hamidullah", language: "🇫🇷 Français", description: "ترجمة فرنسية"),
        QuranTranslationOption(key: "tr.ates", name: "Ateş", language: "🇹🇷 Türkçe", description: "ترجمة تركية"),
        QuranTranslationOption(key: "ru.kuliev", name: "Kuliev", language: "🇷🇺 Русский", description: "ترجمة روسية")
    ]

    static func option(for key: String) -> QuranTranslationOption {
        options.first { $0.key == key } ?? options[0]
    }
}

struct QuranTranslationsView: View {
    @AppStorage("showTranslation") private var showTranslation = false
    @AppStorage("translationKey") private var translationKey = "en.sahih"
    @EnvironmentObject private var lang: LanguageManager

    private var selected: QuranTranslationOption {
        QuranTranslationCatalog.option(for: translationKey)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    headerCard
                    activationCard
                    translationsCard
                    readerCard
                }
                .padding(16)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(lang.t("ترجمات القرآن", "Quran Translations"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .trailing, spacing: 6) {
                Text(lang.t("ترجمات القرآن", "Quran Translations"))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Theme.goldLight)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Text(lang.t("المختارة: \(selected.name)", "Selected: \(selected.name)"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.16))
                    .frame(width: 58, height: 58)
                Image(systemName: "globe.europe.africa.fill")
                    .font(.system(size: 27))
                    .foregroundColor(.cyan)
            }
        }
        .padding(16)
        .background(Theme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var activationCard: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $showTranslation)
                .labelsHidden()
                .tint(Theme.gold)

            VStack(alignment: .trailing, spacing: 5) {
                Text(lang.t("إظهار الترجمة داخل المصحف", "Show translation in reader"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Text(lang.t("تظهر أسفل كل آية عند القراءة", "Shown below each verse while reading"))
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Image(systemName: showTranslation ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundColor(showTranslation ? Theme.gold : Theme.textSecondary)
        }
        .padding(16)
        .background(Theme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var translationsCard: some View {
        VStack(spacing: 0) {
            ForEach(QuranTranslationCatalog.options) { option in
                Button {
                    translationKey = option.key
                    showTranslation = true
                } label: {
                    translationRow(option)
                }
                .buttonStyle(.plain)

                if option.id != QuranTranslationCatalog.options.last?.id {
                    Divider()
                        .background(Theme.border)
                        .padding(.leading, 16)
                        .padding(.trailing, 66)
                }
            }
        }
        .background(Theme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func translationRow(_ option: QuranTranslationOption) -> some View {
        HStack(spacing: 12) {
            Image(systemName: translationKey == option.key ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundColor(translationKey == option.key ? Theme.gold : Theme.textSecondary.opacity(0.7))

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(option.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Text("\(option.language)  •  \(option.description)")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.cyan.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: "textformat.abc")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.cyan)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    @ViewBuilder
    private var readerCard: some View {
        if let firstSurah = allSurahs.first {
            NavigationLink(destination: QuranReaderView(surah: firstSurah)) {
                HStack(spacing: 12) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.background)

                    Spacer()

                    Text(lang.t("فتح المصحف بالترجمة", "Open reader with translation"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.background)

                    Image(systemName: "book.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Theme.background)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Theme.gold)
                .cornerRadius(14)
            }
            .buttonStyle(.plain)
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
}
