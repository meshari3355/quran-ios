import SwiftUI

// MARK: - OfflineDownloadsView
// All downloadable content in one place.

struct OfflineDownloadsView: View {

    @ObservedObject private var quranCache    = QuranOfflineCacheManager.shared
    @ObservedObject private var audioCache    = AudioOfflineCacheManager.shared
    @ObservedObject private var tafsirOffline = TafsirOfflineManager.shared
    @ObservedObject private var fatwaOffline  = FatwaOfflineManager.shared
    @ObservedObject private var reciterMgr    = ReciterOfflineCacheManager.shared
    @ObservedObject private var hadithMgr     = HadithOfflineManager.shared
    // MARK: - Reciters list (unique cdnIds, excluding Maher which AudioOfflineCacheManager handles)

    private let extraReciters: [(name: String, cdnId: String, size: String)] = [
        ("مشاري العفاسي",       "Alafasy_128kbps",                            "~3 GB"),
        ("محمد جبريل",          "Muhammad_Jibreel_128kbps",                    "~3 GB"),
        ("عبدالباسط عبدالصمد",  "Abdul_Basit_Mujawwad_128kbps",               "~3 GB"),
        ("عبدالرحمن السديس",    "Abdurrahmaan_As-Sudais_192kbps",              "~4 GB"),
        ("سعود الشريم",         "Saood_ash-Shuraym_128kbps",                  "~3 GB"),
        ("ناصر القطامي",        "Nasser_Alqatami_128kbps",                    "~3 GB"),
        ("سعد الغامدي",         "Ghamadi_40kbps",                             "~1 GB"),
        ("عبدالله الجهني",      "Abdullaah_3awwaad_Al-Juhaynee_128kbps",      "~3 GB"),
        ("محمد أيوب",           "Muhammad_Ayyoub_128kbps",                    "~3 GB"),
        ("أحمد العجمي",         "ahmed_ibn_ali_al_ajamy_128kbps",             "~3 GB"),
        ("علي الحذيفي",         "Hudhaify_128kbps",                           "~3 GB"),
        ("فارس عباد",           "Fares_Abbad_64kbps",                         "~1 GB"),
        ("أبو بكر الشاطري",     "Abu_Bakr_Ash-Shaatree_128kbps",             "~3 GB"),
        ("ياسر الدوسري",        "Yasser_Ad-Dussary_128kbps",                  "~3 GB"),
        ("خالد القحطاني",       "Khaalid_Abdullaah_al-Qahtaanee_192kbps",    "~4 GB"),
    ]

    // MARK: - Body

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // ── القرآن الكريم ────────────────────────────────
                    sectionHeader("القرآن الكريم", icon: "book.fill", color: Theme.gold)
                    quranSection

                    // ── القراء ───────────────────────────────────────
                    sectionHeader("تلاوات القراء", icon: "waveform", color: .cyan)
                    recitersSection

                    // ── التفسير ──────────────────────────────────────
                    sectionHeader("كتب التفسير", icon: "text.book.closed.fill", color: Color(red: 0.5, green: 0.25, blue: 0.05))
                    tafsirSection

                    // ── الحديث ───────────────────────────────────────
                    sectionHeader("كتب الحديث", icon: "scroll.fill", color: .indigo)
                    hadithSection

                    // ── الفتاوى ──────────────────────────────────────
                    sectionHeader("الفتاوى الإسلامية", icon: "questionmark.circle.fill", color: .purple)
                    fatwaSection

                    noteView
                        .padding(.bottom, 40)
                }
                .padding(16)
            }
        }
        .navigationTitle("التحميل دون إنترنت")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Section header

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 13)).foregroundColor(color)
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    // MARK: - Quran section

    private var quranSection: some View {
        card {
            row(icon: "book.fill", iconColor: Theme.gold,
                title: "صفحات القرآن الكريم",
                subtitle: quranCache.isComplete
                    ? "مكتمل — 604 صفحة ✓"
                    : quranCache.isDownloading
                        ? "جارٍ التحميل \(quranCache.downloadedPages)/\(quranCache.totalPages)"
                        : "604 صفحة • نصوص مصحف المدينة • ~15 MB",
                isComplete: quranCache.isComplete,
                isDownloading: quranCache.isDownloading,
                progress: quranCache.progress,
                onDownload: { quranCache.startFullDownloadIfNeeded() },
                onCancel:   { quranCache.cancel() },
                onDelete:   {
                    quranCache.cancel()
                    try? FileManager.default.removeItem(at: quranCache.cacheDir)
                },
                showDivider: false)
        }
    }

    // MARK: - Reciters section

    private var recitersSection: some View {
        card {
            // Maher — managed by AudioOfflineCacheManager
            row(icon: "waveform", iconColor: .cyan,
                title: "ماهر المعيقلي",
                subtitle: audioCache.isComplete
                    ? "مكتمل — 6236 آية ✓"
                    : audioCache.isDownloading
                        ? "جارٍ التحميل \(audioCache.downloadedFiles)/\(audioCache.totalFiles)"
                        : "6236 آية MP3 • ~3 GB",
                isComplete: audioCache.isComplete,
                isDownloading: audioCache.isDownloading,
                progress: audioCache.progress,
                onDownload: { audioCache.startFullDownloadIfNeeded() },
                onCancel:   { audioCache.cancel() },
                onDelete:   {
                    audioCache.cancel()
                    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    try? FileManager.default.removeItem(at: docs.appendingPathComponent("audio_cache/MaherAlMuaiqly128kbps"))
                },
                showDivider: !extraReciters.isEmpty)

            // Extra reciters — ReciterOfflineCacheManager
            ForEach(Array(extraReciters.enumerated()), id: \.element.cdnId) { idx, reciter in
                let cdnId       = reciter.cdnId
                let isComplete  = reciterMgr.isComplete(cdnId: cdnId)
                let isDLoading  = reciterMgr.isActivelyDownloading(cdnId: cdnId)
                let prog        = reciterMgr.progress(cdnId: cdnId)
                let dl          = reciterMgr.downloaded(cdnId: cdnId)

                row(icon: "waveform", iconColor: .cyan,
                    title: reciter.name,
                    subtitle: isComplete
                        ? "مكتمل — 6236 آية ✓"
                        : isDLoading
                            ? "جارٍ التحميل \(dl)/\(reciterMgr.totalFiles)"
                            : "6236 آية MP3 • \(reciter.size)",
                    isComplete: isComplete,
                    isDownloading: isDLoading,
                    progress: prog,
                    onDownload: { Task { @MainActor in reciterMgr.startDownload(cdnId: cdnId) } },
                    onCancel:   { Task { @MainActor in reciterMgr.cancel(cdnId: cdnId) } },
                    onDelete:   { Task { @MainActor in reciterMgr.delete(cdnId: cdnId) } },
                    showDivider: idx < extraReciters.count - 1)
            }
        }
    }

    // MARK: - Tafsir section

    private let tafsirs: [(id: String, name: String, detail: String, color: Color)] = [
        ("ibn-kathir", "تفسير ابن كثير",  "6236 آية — تفسير مطوّل • ~20 MB",  Color(red: 0.5, green: 0.25, blue: 0.05)),
        ("muyassar",   "تفسير السعدي",    "6236 آية — تفسير ميسّر • ~10 MB",   .teal),
        ("jalalayn",   "تفسير الجلالين",  "6236 آية — تفسير مختصر • ~8 MB",   .orange),
    ]

    private var tafsirSection: some View {
        card {
            ForEach(Array(tafsirs.enumerated()), id: \.element.id) { idx, t in
                let isComplete  = tafsirOffline.isAvailableOffline(tafsirId: t.id)
                let isDLoading  = tafsirOffline.downloadingBooks.contains(t.id)
                let prog        = tafsirOffline.bookProgress[t.id] ?? 0

                row(icon: "book.closed.fill", iconColor: t.color,
                    title: t.name,
                    subtitle: isComplete
                        ? "مكتمل ✓"
                        : isDLoading
                            ? "جارٍ التحميل \(Int(prog * 100))%"
                            : t.detail,
                    isComplete: isComplete,
                    isDownloading: isDLoading,
                    progress: prog,
                    onDownload: { Task { await tafsirOffline.download(tafsirId: t.id) } },
                    onCancel:   { },
                    onDelete:   { tafsirOffline.clearCache(tafsirId: t.id) },
                    showDivider: idx < tafsirs.count - 1)
            }
        }
    }

    // MARK: - Hadith section

    private var hadithSection: some View {
        card {
            ForEach(Array(HadithOfflineManager.allCollections.enumerated()), id: \.element.id) { idx, col in
                let isAvail  = hadithMgr.isAvailable(col.id)
                let isDL     = hadithMgr.isDownloading(col.id)
                let prog     = hadithMgr.progress(col.id)
                let dl       = hadithMgr.downloadedCount(col.id)
                let total    = hadithMgr.totalCount(col.id)
                let iconColor: Color = hadithIconColor(col.color)

                row(icon: col.icon, iconColor: iconColor,
                    title: col.nameAr,
                    subtitle: isAvail
                        ? "مكتمل — \(dl) حديث ✓"
                        : isDL
                            ? (total > 0 ? "جارٍ التحميل \(dl)/\(total)" : "جارٍ التحميل \(Int(prog * 100))%")
                            : "\(col.estimatedCount) حديث",
                    isComplete: isAvail,
                    isDownloading: isDL,
                    progress: prog,
                    onDownload: { Task { await hadithMgr.download(collectionId: col.id) } },
                    onCancel:   { },
                    onDelete:   { hadithMgr.clearCache(collectionId: col.id) },
                    showDivider: idx < HadithOfflineManager.allCollections.count - 1)
            }
        }
    }

    private func hadithIconColor(_ colorName: String) -> Color {
        switch colorName {
        case "purple": return Color(red: 0.29, green: 0.0, blue: 0.51)
        case "green":  return Color(red: 0.0, green: 0.48, blue: 0.40)
        case "brown":  return Color(red: 0.55, green: 0.27, blue: 0.07)
        case "teal":   return .teal
        case "indigo": return .indigo
        case "orange": return .orange
        case "cyan":   return .cyan
        case "blue":   return .blue
        case "red":    return .red
        case "pink":   return .pink
        case "mint":   return .mint
        case "gold":   return Theme.gold
        case "yellow": return .yellow
        default:       return .blue
        }
    }

    // MARK: - Fatwa section

    private var fatwaSection: some View {
        card {
            row(icon: "questionmark.circle.fill", iconColor: .purple,
                title: "فتاوى ابن باز",
                subtitle: fatwaOffline.isAvailableOffline
                    ? "مكتمل — \(fatwaOffline.cachedCount) فتوى ✓"
                    : fatwaOffline.isDownloading
                        ? "جارٍ التحميل \(fatwaOffline.downloadedCount)/\(fatwaOffline.totalCount)"
                        : "2565 فتوى إسلامية • ~5 MB",
                isComplete: fatwaOffline.isAvailableOffline,
                isDownloading: fatwaOffline.isDownloading,
                progress: fatwaOffline.progress,
                onDownload: { Task { await fatwaOffline.downloadAll() } },
                onCancel:   { },
                onDelete:   { fatwaOffline.clearCache() },
                showDivider: false)
        }
    }


    // MARK: - Note

    private var noteView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("ملاحظات مهمة", systemImage: "info.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.text)
            Text("• الأذكار والأدعية وأوقات الصلاة والقبلة وحاسبة الزكاة تعمل دون إنترنت تلقائياً")
                .font(.system(size: 12)).foregroundColor(Theme.textSecondary)
            Text("• كل قارئ يحتاج ~3 GB — تأكد من توفر المساحة قبل التحميل")
                .font(.system(size: 12)).foregroundColor(Theme.textSecondary)
            Text("• يُنصح بالتحميل على شبكة Wi-Fi")
                .font(.system(size: 12)).foregroundColor(Theme.textSecondary)
        }
        .padding(14)
        .background(Theme.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Card container

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Theme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Generic row

    @ViewBuilder
    private func row(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        isComplete: Bool,
        isDownloading: Bool,
        progress: Double,
        onDownload: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        showDivider: Bool
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill((isComplete ? Color.green : iconColor).opacity(0.14))
                        .frame(width: 40, height: 40)
                    Image(systemName: isComplete ? "checkmark.circle.fill" : icon)
                        .font(.system(size: 17))
                        .foregroundColor(isComplete ? .green : iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.text)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(isDownloading ? iconColor : Theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                // Action button
                if isDownloading {
                    Button(action: onCancel) {
                        Text("إيقاف")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                } else if isComplete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(Color.red.opacity(0.55))
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: onDownload) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill").font(.system(size: 13))
                            Text("تحميل").font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(iconColor)
                        .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if isDownloading {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Theme.border).frame(height: 3)
                        Rectangle().fill(iconColor)
                            .frame(width: geo.size.width * CGFloat(min(max(progress, 0), 1)), height: 3)
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }

            if showDivider {
                Divider().background(Theme.border).padding(.leading, 67)
            }
        }
    }
}
