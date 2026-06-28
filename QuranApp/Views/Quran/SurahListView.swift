import SwiftUI

struct SurahListView: View {
    @State private var searchText = ""
    @State private var showSearch = false
    @State private var filterType: String = "الكل"  // internal key: الكل / مكية / مدنية
    @EnvironmentObject private var lang: LanguageManager

    // filter options: (internal key, Arabic label, English label)
    private let filterOptions: [(key: String, ar: String, en: String)] = [
        ("الكل",  "الكل",  "All"),
        ("مكية",  "مكية",  "Meccan"),
        ("مدنية", "مدنية", "Medinan"),
    ]

    var filtered: [Surah] {
        allSurahs.filter { surah in
            let matchesType = filterType == "الكل" || surah.type == filterType
            let matchesSearch = searchText.isEmpty ||
                surah.name.contains(searchText) ||
                surah.nameEn.lowercased().contains(searchText.lowercased()) ||
                String(surah.id).contains(searchText)
            return matchesType && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 0) {

                    // ─── Header ──────────────────────────────────
                    VStack(spacing: 0) {
                        HStack(alignment: .center) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showSearch.toggle()
                                    if !showSearch { searchText = "" }
                                }
                            }) {
                                Image(systemName: showSearch ? "xmark" : "magnifyingglass")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(Theme.gold)
                            }
                            Spacer()
                            VStack(spacing: 3) {
                                Text(lang.t("القرآن الكريم", "The Holy Quran"))
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(Theme.goldLight)
                                Text(lang.t("١١٤ سورة  •  ٦٠٤ صفحة", "114 Surahs  •  604 Pages"))
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 18))
                                .foregroundColor(.clear)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 6)

                        // Basmala — always Arabic
                        if !showSearch {
                            Text("بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(Theme.gold.opacity(0.85))
                                .frame(maxWidth: .infinity)
                                .padding(.bottom, 10)
                        }

                        // Search bar
                        if showSearch {
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.textSecondary)
                                TextField(lang.t("ابحث باسم السورة أو رقمها...", "Search by name or number..."),
                                          text: $searchText)
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.text)
                                    .autocorrectionDisabled()
                                if !searchText.isEmpty {
                                    Button(action: { searchText = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                }
                            }
                            .padding(12)
                            .background(Theme.card)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                            .padding(.horizontal, 16)
                            .padding(.bottom, 10)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Filter pills
                        if !showSearch {
                            HStack(spacing: 10) {
                                ForEach(filterOptions, id: \.key) { opt in
                                    Button(action: { filterType = opt.key }) {
                                        Text(lang.t(opt.ar, opt.en))
                                            .font(.system(size: 13, weight: filterType == opt.key ? .semibold : .regular))
                                            .foregroundColor(filterType == opt.key ? Theme.background : Theme.textSecondary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 7)
                                            .background(filterType == opt.key ? Theme.gold : Theme.card)
                                            .cornerRadius(20)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(filterType == opt.key ? Theme.gold : Theme.border, lineWidth: 1)
                                            )
                                    }
                                }
                                Spacer()
                                Text(lang.t("\(filtered.count) سورة", "\(filtered.count) Surahs"))
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 10)
                        }
                    }
                    .background(Theme.card)

                    Divider().background(Theme.border)

                    // ─── List ──────────────────────────────────────
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if filtered.isEmpty {
                                VStack(spacing: 14) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 32))
                                        .foregroundColor(Theme.textSecondary)
                                    Text(lang.t("لا توجد نتائج", "No results"))
                                        .font(.system(size: 15))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 60)
                            } else {
                                ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, surah in
                                    SurahRow(surah: surah)
                                    if idx < filtered.count - 1 {
                                        Divider()
                                            .background(Theme.border)
                                            .padding(.leading, 74)
                                    }
                                }
                            }
                        }
                        .background(Theme.card)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
                        .padding(16)
                        .padding(.bottom, 4)
                    }
                }
            }
        }
    }
}

// MARK: - Surah row

struct SurahRow: View {
    let surah: Surah
    @EnvironmentObject private var lang: LanguageManager

    private var lastPage: Int {
        UserDefaults.standard.integer(forKey: "lastPage_\(surah.id)")
    }

    var body: some View {
        NavigationLink(destination: QuranReaderView(surah: surah)) {
            HStack(spacing: 14) {

                // Number badge
                ZStack {
                    Image(systemName: "seal.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.gold.opacity(0.13))
                    Text("\(surah.id)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.gold)
                }
                .frame(width: 46, height: 46)

                // Surah info
                VStack(alignment: lang.isEnglish ? .leading : .trailing, spacing: 5) {
                    Text(surah.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Theme.text)

                    HStack(spacing: 6) {
                        // Last read bookmark
                        if lastPage > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "bookmark.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(Theme.gold)
                                Text(lang.t("ص \(lastPage)", "p.\(lastPage)"))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(Theme.gold)
                            }
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Theme.gold.opacity(0.13))
                            .cornerRadius(6)
                        }

                        // Makki/Madani
                        Text(lang.t(surah.type, surah.type == "مكية" ? "Meccan" : "Medinan"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(surah.type == "مكية" ? .orange : Color(red: 0.3, green: 0.6, blue: 1.0))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background((surah.type == "مكية" ? Color.orange : Color.blue).opacity(0.12))
                            .cornerRadius(6)

                        // Verse count
                        Text(lang.t("\(surah.verses) آية", "\(surah.verses) verses"))
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                    }
                }

                Spacer()

                // English name
                Text(surah.nameEn)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)

                Image(systemName: lang.isEnglish ? "chevron.right" : "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
