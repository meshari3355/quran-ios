import SwiftUI

// MARK: - MuslimToolsView (المزيد)
// NOTE: NavigationStack is intentionally absent here — it is provided by the
// parent (ContentView tab wrapper or HomeView quick-link).  Adding another
// NavigationStack here would create double back-buttons.

struct MuslimToolsView: View {
    @EnvironmentObject private var lang: LanguageManager
    @State private var showShareSheet = false
    private let hijriDate = IslamicCalendarService.shared.currentHijriDate()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {

                    // ── Header ────────────────────────────────────────────
                    headerView

                    // ── الأدوات ───────────────────────────────────────────
                    sectionTitle(lang.t("الأدوات", "Tools"), icon: "wrench.and.screwdriver.fill", color: .teal)
                    toolsGrid

                    // ── الصوتيات ──────────────────────────────────────────
                    sectionTitle(lang.t("الصوتيات", "Audio"), icon: "waveform", color: .indigo)
                    audioCard

                    // ── معلومات التطبيق ───────────────────────────────────
                    sectionTitle(lang.t("معلومات التطبيق", "App Info"), icon: "info.circle.fill", color: Theme.gold)
                    appInfoCard

                    // ── بطاقة التبرع ──────────────────────────────────────
                    donationCard

                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            let message = lang.t(
                "حمّل تطبيق القرآن الكريم وأوقات الصلاة",
                "Download Quran App and Prayer Times"
            )
            ShareSheet(activityItems: {
                var items: [Any] = [message]
                items.append(AppMetadata.appStoreURL)
                return items
            }())
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 4) {
            Text(lang.t("المزيد", "More"))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Theme.goldLight)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            Text(hijriDate.formatted)
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
        }
    }

    // MARK: - Section Title

    private func sectionTitle(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Tools Grid
    // NOTE: Use VStack+HStack instead of LazyVGrid to avoid SwiftUI bug where
    // NavigationLink items inside LazyVGrid disappear after scrolling.

    private var toolsGrid: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                NavigationLink(destination: QiblaView()) {
                    ToolCard(icon: "location.north.line.fill", color: .teal,
                             title: lang.t("اتجاه القبلة", "Qibla"),
                             subtitle: lang.t("بوصلة دقيقة للقبلة", "Accurate compass"))
                }.buttonStyle(.plain)

                NavigationLink(destination: IslamicCalendarView()) {
                    ToolCard(icon: "calendar", color: Color(red: 0.0, green: 0.6, blue: 0.4),
                             title: lang.t("التقويم الإسلامي", "Islamic Calendar"),
                             subtitle: lang.t("المناسبات والأعياد", "Events & occasions"))
                }.buttonStyle(.plain)
            }

            HStack(spacing: 14) {
                NavigationLink(destination: ZakatCalculatorView()) {
                    ToolCard(icon: "scalemass.fill", color: .orange,
                             title: lang.t("حاسبة الزكاة", "Zakat Calculator"),
                             subtitle: lang.t("احسب زكاتك بسهولة", "Calculate easily"))
                }.buttonStyle(.plain)

                // إحصائيات القراءة
                NavigationLink(destination: ReadingStatsView()) {
                    ToolCard(icon: "chart.bar.fill", color: Color(red: 0.85, green: 0.55, blue: 0.1),
                             title: lang.t("إحصائيات القراءة", "Reading Stats"),
                             subtitle: lang.t("تتبع تقدمك اليومي", "Daily progress"))
                }.buttonStyle(.plain)
            }

            HStack(spacing: 14) {
                NavigationLink(destination: FatwaListView()) {
                    ToolCard(icon: "questionmark.circle.fill", color: .purple,
                             title: lang.t("الفتاوى", "Fatwas"),
                             subtitle: lang.t("فتاوى إسلامية موثوقة", "Trusted Islamic Q&A"))
                }.buttonStyle(.plain)

                NavigationLink(destination: HadithPortalView()) {
                    ToolCard(icon: "book.closed.fill", color: Color(red: 0.5, green: 0.1, blue: 0.1),
                             title: lang.t("كتب الحديث", "Hadith Books"),
                             subtitle: lang.t("189 كتاب • 427,373 حديث", "189 books • 427,373 hadiths"))
                }.buttonStyle(.plain)
            }

            HStack(spacing: 14) {
                NavigationLink(destination: NearbyMosquesView()) {
                    ToolCard(icon: "mappin.and.ellipse", color: .green,
                             title: lang.t("المساجد القريبة", "Nearby Mosques"),
                             subtitle: lang.t("ابحث عن أقرب مسجد", "Find nearest mosque"))
                }.buttonStyle(.plain)

                NavigationLink(destination: TafsirBooksListView()) {
                    ToolCard(icon: "text.book.closed.fill", color: .brown,
                             title: lang.t("كتب التفسير", "Tafsir Books"),
                             subtitle: lang.t("ابن كثير • السعدي • الجلالين", "Ibn Kathir • Sa'di • Jalalayn"))
                }.buttonStyle(.plain)
            }

            HStack(spacing: 14) {
                NavigationLink(destination: QuranTranslationsView()) {
                    ToolCard(icon: "globe", color: .cyan,
                             title: lang.t("ترجمات القرآن", "Quran Translations"),
                             subtitle: lang.t("إنجليزي • فرنسي • تركي • أردو", "English • French • Turkish • Urdu"))
                }.buttonStyle(.plain)

                NavigationLink(destination: NawawiHadithView()) {
                    ToolCard(icon: "list.number", color: .indigo,
                             title: lang.t("الأربعون النووية", "Nawawi's 40"),
                             subtitle: lang.t("أحاديث جامعة ومختارة", "Essential selected hadiths"))
                }.buttonStyle(.plain)
            }
        }
    }

    // MARK: - Library Card

    private var libraryCard: some View {
        VStack(spacing: 0) {
            // ─ كتب التفسير ──────────────────────────────────────────────
            librarySectionHeader(title: lang.t("كتب التفسير", "Tafsir Books"), icon: "text.book.closed.fill", color: .brown)

            NavigationLink(destination: TafsirSurahListView(book: .ibnKathir)) {
                libRow(icon: "books.vertical.fill",  color: .indigo,
                       title:    lang.t("تفسير ابن كثير", "Tafsir Ibn Kathir"),
                       subtitle: lang.t("تفسير بالمأثور المعتمد", "Authoritative classical tafsir"))
            }.buttonStyle(.plain)
            Divider().background(Theme.border).padding(.leading, 66)

            NavigationLink(destination: TafsirSurahListView(book: .saadi)) {
                libRow(icon: "doc.text.fill", color: Color(red: 0.55, green: 0.35, blue: 0.05),
                       title:    lang.t("تفسير السعدي", "Tafsir Al-Sa'di"),
                       subtitle: lang.t("ميسّر وشامل للقراء", "Clear & comprehensive"))
            }.buttonStyle(.plain)
            Divider().background(Theme.border).padding(.leading, 66)

            NavigationLink(destination: TafsirSurahListView(book: .jalalyn)) {
                libRow(icon: "book.fill", color: Color(red: 0.4, green: 0.2, blue: 0.0),
                       title:    lang.t("تفسير الجلالين", "Tafsir Al-Jalalayn"),
                       subtitle: lang.t("مختصر معتمد في المدارس", "Concise & widely studied"))
            }.buttonStyle(.plain)

            // ─ كتب الحديث ───────────────────────────────────────────────
            Divider().background(Theme.border)
            librarySectionHeader(title: lang.t("كتب الحديث", "Hadith Books"), icon: "book.closed.fill", color: Color(red: 0.5, green: 0.1, blue: 0.1))

            NavigationLink(destination: HadithPortalChaptersView(book: PortalBook(id: 33, nameAr: "صحيح البخاري", categoryId: "sihah"))) {
                libRow(icon: "book.closed.fill", color: Color(red: 0.5, green: 0.1, blue: 0.1),
                       title:    lang.t("صحيح البخاري", "Sahih Al-Bukhari"),
                       subtitle: lang.t("أصح كتاب بعد القرآن الكريم", "Most authentic hadith collection"))
            }.buttonStyle(.plain)
            Divider().background(Theme.border).padding(.leading, 66)

            NavigationLink(destination: HadithPortalChaptersView(book: PortalBook(id: 31, nameAr: "صحيح مسلم", categoryId: "sihah"))) {
                libRow(icon: "book.closed.fill", color: Color(red: 0.4, green: 0.08, blue: 0.08),
                       title:    lang.t("صحيح مسلم", "Sahih Muslim"),
                       subtitle: lang.t("ثاني أصح كتاب في الحديث", "Second most authentic"))
            }.buttonStyle(.plain)
            Divider().background(Theme.border).padding(.leading, 66)

            NavigationLink(destination: NawawiHadithView()) {
                libRow(icon: "text.book.closed.fill", color: .indigo,
                       title:    lang.t("الأربعون النووية", "Nawawi's 40 Hadith"),
                       subtitle: lang.t("40 حديثاً أساسياً في الإسلام", "40 core Islamic hadiths"))
            }.buttonStyle(.plain)
            Divider().background(Theme.border).padding(.leading, 66)

            NavigationLink(destination: HadithPortalView()) {
                libRow(icon: "list.bullet.rectangle", color: Color(red: 0.35, green: 0.05, blue: 0.05),
                       title:    lang.t("كتب الحديث الستة", "The Six Hadith Books"),
                       subtitle: lang.t("أبوداود • الترمذي • النسائي • ابن ماجه", "Abu Dawud • Tirmidhi • Nasai • Ibn Majah"))
            }.buttonStyle(.plain)

            // ─ ترجمات القرآن ────────────────────────────────────────────
            Divider().background(Theme.border)
            librarySectionHeader(title: lang.t("ترجمات القرآن", "Quran Translations"), icon: "globe", color: .cyan)

            NavigationLink(destination: QuranTranslationsView()) {
                libRow(icon: "globe", color: .cyan,
                       title:    lang.t("ترجمات متعددة اللغات", "Multi-Language Translations"),
                       subtitle: lang.t("إنجليزي • فرنسي • تركي • أردو", "English • French • Turkish • Urdu"))
            }.buttonStyle(.plain)
        }
        .background(Theme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    private func librarySectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(color.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
            }
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Theme.card.opacity(0.6))
    }

    private func libRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9).fill(color.opacity(0.18)).frame(width: 40, height: 40)
                Image(systemName: icon).font(.system(size: 17)).foregroundColor(color)
            }
            VStack(alignment: .trailing, spacing: 3) {
                Text(title).font(.system(size: 15, weight: .medium)).foregroundColor(Theme.text)
                Text(subtitle).font(.system(size: 11)).foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.left")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - Audio Card

    private var audioCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(audioRows.enumerated()), id: \.offset) { idx, item in
                NavigationLink(destination: AudioLibraryView(filter: item.tag)) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9)
                                .fill(item.color.opacity(0.18))
                                .frame(width: 40, height: 40)
                            Image(systemName: item.icon)
                                .font(.system(size: 17))
                                .foregroundColor(item.color)
                        }
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(item.title)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Theme.text)
                            Text(item.subtitle)
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if idx < audioRows.count - 1 {
                    Divider().background(Theme.border).padding(.leading, 66)
                }
            }
        }
        .background(Theme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    private var audioRows: [(icon: String, color: Color, title: String, subtitle: String, tag: String)] {[
        ("mic.fill",          Color(red: 0.85, green: 0.70, blue: 0.35),
         lang.t("التلاوات المرتّلة", "Murattal Recitations"),
         lang.t("ماهر المعيقلي • مشاري العفاسي • السديس", "Maher • Mishary • Al-Sudais"),
         "murattal"),

        ("waveform",          .indigo,
         lang.t("التلاوات المجوّدة", "Mujawwad (Tajweed)"),
         lang.t("عبد الباسط • الحصري بأحكام التجويد", "Abdul Basit • Al-Husary"),
         "mujawwad"),

        ("house.fill",        .teal,
         lang.t("تلاوات الحرمين", "Haramain Recitations"),
         lang.t("أئمة المسجد الحرام والمسجد النبوي", "Masjid Al-Haram & Al-Nabawi"),
         "haram"),

        ("graduationcap.fill", .green,
         lang.t("التلاوات التعليمية", "Educational Recitations"),
         lang.t("الحصري التعليمي مع الترجمة", "Al-Husary & translations"),
         "educational"),
    ]}

    // MARK: - App Info Card

    private var appInfoCard: some View {
        VStack(spacing: 0) {
            // ── التحميل للاستخدام دون إنترنت ─────────────────
            NavigationLink(destination: OfflineDownloadsView()) {
                appInfoRow(icon: "arrow.down.circle.fill",
                           color: Color(red: 0.2, green: 0.6, blue: 0.3),
                           title: lang.t("التحميل للاستخدام دون إنترنت", "Offline Downloads"), chevron: "chevron.left")
            }.buttonStyle(.plain)
            Divider().background(Theme.border).padding(.leading, 66)

            // ── الإعدادات (NavigationLink) ───────────────────
            NavigationLink(destination: SettingsView()) {
                appInfoRow(icon: "gearshape.fill",
                           color: Color(red: 0.4, green: 0.4, blue: 0.45),
                           title: lang.t("الإعدادات", "Settings"), chevron: "chevron.left")
            }.buttonStyle(.plain)
            Divider().background(Theme.border).padding(.leading, 66)

            // ── من نحن ───────────────────────────────────────
            NavigationLink(destination: AboutDeveloperView()) {
                appInfoRow(icon: "person.2.fill", color: .blue,
                           title: lang.t("من نحن", "About Us"), chevron: "chevron.left")
            }.buttonStyle(.plain)
            Divider().background(Theme.border).padding(.leading, 66)

            // ── عن التطبيق ───────────────────────────────────
            NavigationLink(destination: AboutAppView()) {
                appInfoRow(icon: "info.circle.fill", color: Theme.gold,
                           title: lang.t("عن التطبيق", "About the App"), chevron: "chevron.left")
            }.buttonStyle(.plain)
            Divider().background(Theme.border).padding(.leading, 66)

            // ── تحديث التطبيق ────────────────────────────────
            Button {
                UIApplication.shared.open(AppMetadata.appStoreURL)
            } label: {
                appInfoRow(icon: "arrow.down.circle.fill", color: .green,
                           title: lang.t("تحديث التطبيق", "Update App"), chevron: "arrow.up.right")
            }.buttonStyle(.plain)
            Divider().background(Theme.border).padding(.leading, 66)

            // ── التواصل مع المطور ────────────────────────────
            Button {
                if let url = AppMetadata.developerPhoneURL { UIApplication.shared.open(url) }
            } label: {
                appInfoRow(icon: "phone.fill", color: .teal,
                           title: lang.t("التواصل مع المطور", "Contact Developer"), chevron: "arrow.up.right")
            }.buttonStyle(.plain)
            Divider().background(Theme.border).padding(.leading, 66)

            // ── مشاركة التطبيق ───────────────────────────────
            Button { showShareSheet = true } label: {
                appInfoRow(icon: "square.and.arrow.up", color: .orange,
                           title: lang.t("مشاركة التطبيق", "Share App"), chevron: "arrow.up.right")
            }.buttonStyle(.plain)
        }
        .background(Theme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    private func appInfoRow(icon: String, color: Color, title: String, chevron: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(color.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundColor(color)
            }
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Theme.text)
            Spacer()
            Image(systemName: chevron)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    // MARK: - Donation Card

    private var donationCard: some View {
        Button(action: {
            if let url = URL(string: "https://ehsan.sa") { UIApplication.shared.open(url) }
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.18))
                        .frame(width: 50, height: 50)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.green)
                }
                VStack(alignment: .trailing, spacing: 4) {
                    Text(lang.t("تبرّع عبر إحسان", "Donate via Ihsan"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.text)
                    Text(lang.t("منصة إحسان الخيرية الموثوقة", "Ihsan — Saudi Charity Platform"))
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.green)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.green.opacity(0.4), lineWidth: 1.5)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ToolCard

private struct ToolCard: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            HStack {
                Spacer()
                ZStack {
                    Circle().fill(color.opacity(0.15)).frame(width: 52, height: 52)
                    Image(systemName: icon).font(.system(size: 24)).foregroundColor(color)
                }
            }
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Theme.text)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(14)
        .background(Theme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
        .contentShape(Rectangle())
    }
}

// MARK: - ToolsSubtitleRow (kept for backward compatibility)

private struct ToolsSubtitleRow: View {
    let title: String
    var body: some View {
        HStack {
            Spacer()
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
            Rectangle().fill(Theme.border).frame(height: 1)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - IslamicCalendarView

struct IslamicCalendarView: View {
    private let service = IslamicCalendarService.shared
    @EnvironmentObject private var lang: LanguageManager

    private let events: [(icon: String, title: String, desc: String, color: Color, hMonth: Int, hDay: Int)] = [
        ("moon.fill",        "محرم - رأس السنة الهجرية",       "أول شهر من أشهر السنة الهجرية",              .indigo,                                    1,  1),
        ("star.fill",        "يوم عاشوراء (10 محرم)",          "صومه كفارة سنة ماضية — حديث مسلم",            .blue,                                      1, 10),
        ("moon.stars.fill",  "شهر رمضان المبارك",              "شهر الصيام والقيام وقراءة القرآن",             .purple,                                    9,  1),
        ("gift.fill",        "عيد الفطر (1 شوال)",             "تقبّل الله منا ومنكم صالح الأعمال",            .orange,                                   10,  1),
        ("leaf.fill",        "الأيام الستة من شوال",           "من صامها كصيام الدهر — حديث مسلم",            .green,                                    10,  2),
        ("mountain.2.fill",  "يوم عرفة (9 ذي الحجة)",         "صومه كفارة سنتين — من أفضل أيام الله",        Color(red: 0.0, green: 0.6, blue: 0.4),    12,  9),
        ("gift.circle.fill", "عيد الأضحى (10 ذي الحجة)",      "إحياء سنة إبراهيم عليه السلام",               .orange,                                   12, 10),
        ("moon.zzz.fill",    "أيام التشريق (11-13 ذي الحجة)", "أيام أكل وشرب وذكر الله",                     .brown,                                    12, 11),
    ]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    let h = service.currentHijriDate()
                    VStack(spacing: 6) {
                        Text(lang.t("التاريخ الهجري اليوم", "Today's Hijri Date"))
                            .font(.system(size: 13)).foregroundColor(Theme.textSecondary)
                        Text(h.formatted)
                            .font(.system(size: 24, weight: .bold)).foregroundColor(Theme.goldLight)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(Theme.card)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))

                    Text(lang.t("المناسبات الإسلامية", "Islamic Events"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    VStack(spacing: 0) {
                        ForEach(Array(events.enumerated()), id: \.offset) { idx, event in
                            let days = daysUntil(hijriMonth: event.hMonth, hijriDay: event.hDay)
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 9).fill(event.color.opacity(0.15)).frame(width: 40, height: 40)
                                    Image(systemName: event.icon).font(.system(size: 18)).foregroundColor(event.color)
                                }
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text(event.title).font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.text)
                                    Text(event.desc).font(.system(size: 11)).foregroundColor(Theme.textSecondary)
                                }
                                Spacer()
                                VStack(spacing: 1) {
                                    if days == 0 {
                                        Text(lang.t("اليوم", "Today"))
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(event.color)
                                    } else {
                                        Text("\(days)")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(event.color)
                                        Text(lang.t("يوم", "days"))
                                            .font(.system(size: 9))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                }
                                .frame(width: 38)
                                .padding(.vertical, 6)
                                .background(event.color.opacity(0.10))
                                .cornerRadius(8)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            if idx < events.count - 1 {
                                Divider().background(Theme.border).padding(.leading, 66)
                            }
                        }
                    }
                    .background(Theme.card).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                }
                .padding(16)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle(lang.t("التقويم الإسلامي", "Islamic Calendar"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func daysUntil(hijriMonth: Int, hijriDay: Int) -> Int {
        let islamicCal = Calendar(identifier: .islamicCivil)
        let today = Date()
        let currentYear = islamicCal.component(.year, from: today)
        var comps = DateComponents(calendar: islamicCal, year: currentYear, month: hijriMonth, day: hijriDay)
        var target = islamicCal.date(from: comps)
        let todayStart = Calendar.current.startOfDay(for: today)
        if target.map({ $0 < todayStart }) ?? true {
            comps.year = currentYear + 1
            target = islamicCal.date(from: comps)
        }
        guard let targetDate = target else { return 0 }
        let diff = Calendar.current.dateComponents([.day],
                                                    from: Calendar.current.startOfDay(for: today),
                                                    to: Calendar.current.startOfDay(for: targetDate))
        return max(0, diff.day ?? 0)
    }
}

// MARK: - AboutDeveloperView (من نحن)

struct AboutDeveloperView: View {
    @EnvironmentObject private var lang: LanguageManager

    private let gold      = Color(red: 0.86, green: 0.71, blue: 0.35)
    private let goldLight = Color(red: 0.95, green: 0.88, blue: 0.65)

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {

                    // ── App icon area ──────────────────────────────
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(gold.opacity(0.12))
                                .frame(width: 96, height: 96)
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 44))
                                .foregroundColor(goldLight)
                        }
                        Text("تطبيق القرآن الكريم")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(goldLight)
                        Text("الإصدار \(AppBuildInfo.version)")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.top, 20)

                    // ── Divider ─────────────────────────────────────
                    HStack {
                        Rectangle().fill(gold.opacity(0.25)).frame(height: 1)
                        Image(systemName: "star.fill").font(.system(size: 8)).foregroundColor(gold.opacity(0.6))
                        Rectangle().fill(gold.opacity(0.25)).frame(height: 1)
                    }
                    .padding(.horizontal, 30)

                    // ── Developer message ──────────────────────────
                    VStack(spacing: 18) {
                        Text("رسالة المطوّر")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(gold)

                        Text("""
أنا شاب سعودي عملت على إنشاء هذا التطبيق لوجه الله وحده، أسأل الله العلي العظيم أن يجعله في ميزان حسناتي وحسنات والديّ الكريمين، وأن يجعله نوراً لي يوم القيامة.

اللهم إنك تعلم أن هذا العمل ما كان إلا ابتغاء مرضاتك، فاجعله في ميزان حسنات كل من قرأ به آية، أو استمع تلاوة، أو ذكر الله.

أسأل الله أن ينفع به المسلمين في كل مكان، وأن يجعله صدقة جارية تبقى بعدي، وأن يكتب للمؤمنين أجمعين حسنات نشره وتوزيعه.
""")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Theme.text)
                        .multilineTextAlignment(.trailing)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(20)
                    .background(Theme.card)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(gold.opacity(0.30), lineWidth: 1))

                    // ── Dua card ────────────────────────────────────
                    VStack(spacing: 8) {
                        Image(systemName: "hands.sparkles.fill")
                            .font(.system(size: 26))
                            .foregroundColor(gold)
                        Text("اللهم اجعل هذا العمل في موازين حسناتي\nووالديَّ والمؤمنين أجمعين")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(goldLight)
                            .multilineTextAlignment(.center)
                            .lineSpacing(5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient(
                                colors: [gold.opacity(0.12), gold.opacity(0.06)],
                                startPoint: .top, endPoint: .bottom))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(gold.opacity(0.40), lineWidth: 1.5))
                    )

                    // ── Contact ─────────────────────────────────────
                    Button {
                        if let url = AppMetadata.developerPhoneURL { UIApplication.shared.open(url) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "phone.fill").foregroundColor(.teal)
                            Text("التواصل مع المطوّر")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.text)
                            Spacer()
                            Text(AppMetadata.developerPhoneDisplay)
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textSecondary)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(16)
                        .background(Theme.card)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle(lang.t("من نحن", "About Us"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
