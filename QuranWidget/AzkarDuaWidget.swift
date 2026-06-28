// =============================================================
// AzkarDuaWidget.swift  — Widget Extension Target
// ويدجت الأذكار اليومية والأدعية
// =============================================================

import WidgetKit
import SwiftUI

// MARK: - Azkar data (تدور كل ساعتين — 12 ذكراً في اليوم)

private let azkarWidgetItems: [(text: String, category: String)] = [
    ("سُبْحَانَ اللَّهِ وَبِحَمْدِهِ", "تسبيح"),
    ("لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ", "ذكر الصباح"),
    ("اللَّهُمَّ بِكَ أَصْبَحْنَا وَبِكَ أَمْسَيْنَا وَبِكَ نَحْيَا وَبِكَ نَمُوتُ وَإِلَيْكَ النُّشُورُ", "ذكر الصباح"),
    ("بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ", "الحماية"),
    ("اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَأَعُوذُ بِكَ مِنَ الْعَجْزِ وَالْكَسَلِ", "دعاء الصباح"),
    ("حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ", "توكل"),
    ("رَضِيتُ بِاللَّهِ رَبًّا وَبِالإِسْلَامِ دِينًا وَبِمُحَمَّدٍ ﷺ نَبِيًّا وَرَسُولاً", "رضا"),
    ("سُبْحَانَ اللَّهِ وَالْحَمْدُ لِلَّهِ وَلَا إِلَهَ إِلَّا اللَّهُ وَاللَّهُ أَكْبَرُ", "تسبيح"),
    ("اللَّهُمَّ صَلِّ وَسَلِّمْ وَبَارِكْ عَلَى نَبِيِّنَا مُحَمَّدٍ", "صلاة على النبي ﷺ"),
    ("أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ الَّذِي لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ وَأَتُوبُ إِلَيْهِ", "استغفار"),
    ("اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ", "سيد الاستغفار"),
    ("اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي", "ذكر الصباح"),
    ("لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ الْعَلِيِّ الْعَظِيمِ", "تحصين"),
    ("اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي الدُّنْيَا وَالآخِرَةِ", "دعاء المساء"),
    ("يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ", "توسل"),
    ("اللَّهُمَّ إِنِّي أَسْأَلُكَ الْجَنَّةَ وَأَعُوذُ بِكَ مِنَ النَّارِ", "دعاء المساء"),
    ("سُبْحَانَ اللَّهِ وَبِحَمْدِهِ سُبْحَانَ اللَّهِ الْعَظِيمِ", "تسبيح"),
    ("اللَّهُمَّ إِنَّكَ عَفُوٌّ تُحِبُّ الْعَفْوَ فَاعْفُ عَنِّي", "العفو"),
    ("اللَّهُمَّ أَصْلِحْ لِي دِينِي الَّذِي هُوَ عِصْمَةُ أَمْرِي، وَأَصْلِحْ لِي دُنْيَايَ الَّتِي فِيهَا مَعَاشِي", "دعاء الصلاح"),
    ("اللَّهُمَّ اهْدِنِي فِيمَنْ هَدَيْتَ وَعَافِنِي فِيمَنْ عَافَيْتَ", "دعاء القنوت"),
    ("أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ", "الحماية"),
    ("اللَّهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالإِكْرَامِ", "ذكر بعد الصلاة"),
    ("اللَّهُمَّ لَكَ أَسْلَمْتُ وَبِكَ آمَنْتُ وَعَلَيْكَ تَوَكَّلْتُ وَإِلَيْكَ أَنَبْتُ", "ذكر النوم"),
    ("بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا", "ذكر النوم"),
]

// MARK: - Dua data (تتغير يومياً)

private let duaItems: [(text: String, occasion: String)] = [
    ("رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ", "دعاء شامل"),
    ("اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ", "دعاء العبادة"),
    ("رَبِّ اشْرَحْ لِي صَدْرِي وَيَسِّرْ لِي أَمْرِي وَاحْلُلْ عُقْدَةً مِنْ لِسَانِي يَفْقَهُوا قَوْلِي", "دعاء التيسير"),
    ("اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَافِيَةَ فِي الدُّنْيَا وَالآخِرَةِ", "دعاء العافية"),
    ("رَبِّ زِدْنِي عِلْماً وَارْزُقْنِي فَهْماً", "دعاء العلم"),
    ("اللَّهُمَّ اهْدِنِي وَسَدِّدْنِي وَاحْفَظْنِي مِنَ الشَّرِّ", "دعاء الهداية"),
    ("اللَّهُمَّ إِنِّي أَسْأَلُكَ حُبَّكَ وَحُبَّ مَنْ يُحِبُّكَ وَحُبَّ عَمَلٍ يُقَرِّبُنِي إِلَى حُبِّكَ", "دعاء المحبة"),
    ("اللَّهُمَّ أَصْلِحْ لِي دِينِي وَدُنْيَايَ وَآخِرَتِي وَاجْعَلِ الْحَيَاةَ زِيَادَةً لِي فِي كُلِّ خَيْرٍ", "دعاء الصلاح"),
    ("رَبِّ إِنِّي لِمَا أَنزَلْتَ إِلَيَّ مِنْ خَيْرٍ فَقِيرٌ", "دعاء الرزق"),
    ("اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْكُفْرِ وَالْفَقْرِ، وَأَعُوذُ بِكَ مِنْ عَذَابِ الْقَبْرِ", "دعاء الحماية"),
    ("اللَّهُمَّ اجْعَلْنِي مِنَ التَّوَّابِينَ وَاجْعَلْنِي مِنَ الْمُتَطَهِّرِينَ", "دعاء التوبة"),
    ("رَبَّنَا هَبْ لَنَا مِنْ أَزْوَاجِنَا وَذُرِّيَّاتِنَا قُرَّةَ أَعْيُنٍ وَاجْعَلْنَا لِلْمُتَّقِينَ إِمَامًا", "دعاء الأسرة"),
    ("اللَّهُمَّ احْفَظْنِي مِنْ بَيْنِ يَدَيَّ وَمِنْ خَلْفِي وَعَنْ يَمِينِي وَعَنْ شِمَالِي وَمِنْ فَوْقِي", "دعاء الحفظ"),
    ("اللَّهُمَّ فَرِّجْ هَمِّي وَاكْشِفْ كَرْبِي وَأَجِبْ دَعْوَتِي وَثَبِّتْ حُجَّتِي", "دعاء الفرج"),
]

// MARK: - Entries

struct AzkarEntry: TimelineEntry {
    let date: Date
    let zikr: String
    let category: String
    let isEvening: Bool
}

struct DuaEntry: TimelineEntry {
    let date: Date
    let dua: String
    let occasion: String
}

// MARK: - AzkarProvider (يتغير كل ساعتين)

struct AzkarProvider: TimelineProvider {
    func placeholder(in context: Context) -> AzkarEntry {
        AzkarEntry(date: .now, zikr: azkarWidgetItems[0].text,
                   category: azkarWidgetItems[0].category, isEvening: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (AzkarEntry) -> Void) {
        completion(makeEntry(for: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AzkarEntry>) -> Void) {
        // ذكر جديد كل ساعتين — 12 ذكراً في اليوم
        let intervalSeconds = 2 * 60 * 60   // ساعتان
        var entries: [AzkarEntry] = []

        for i in 0..<12 {
            let entryDate = Date(timeIntervalSinceNow: Double(i * intervalSeconds))
            entries.append(makeEntry(for: entryDate))
        }

        let refreshDate = Date(timeIntervalSinceNow: Double(12 * intervalSeconds))
        completion(Timeline(entries: entries, policy: .after(refreshDate)))
    }

    private func makeEntry(for date: Date) -> AzkarEntry {
        let cal       = Calendar.current
        let dayOfYear = cal.ordinality(of: .day, in: .year, for: date) ?? 1
        let hour      = cal.component(.hour, from: date)
        // كل ساعتين يتغير الذكر، مع مراعاة اليوم لتجنب التكرار في أيام مختلفة
        let slot      = hour / 2
        let idx       = (dayOfYear * 12 + slot) % azkarWidgetItems.count
        let isEvening = hour >= 15
        return AzkarEntry(date: date,
                          zikr: azkarWidgetItems[idx].text,
                          category: azkarWidgetItems[idx].category,
                          isEvening: isEvening)
    }
}

// MARK: - DuaProvider (يتغير يومياً عند منتصف الليل)

struct DuaProvider: TimelineProvider {
    func placeholder(in context: Context) -> DuaEntry {
        DuaEntry(date: .now, dua: duaItems[0].text, occasion: duaItems[0].occasion)
    }

    func getSnapshot(in context: Context, completion: @escaping (DuaEntry) -> Void) {
        completion(makeEntry(for: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DuaEntry>) -> Void) {
        let entry = makeEntry(for: .now)
        // تحديث عند منتصف الليل القادم
        let tomorrow  = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? Date(timeIntervalSinceNow: 86400)
        let midnight  = Calendar.current.startOfDay(for: tomorrow)
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }

    private func makeEntry(for date: Date) -> DuaEntry {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let idx       = (dayOfYear - 1) % duaItems.count
        return DuaEntry(date: date, dua: duaItems[idx].text, occasion: duaItems[idx].occasion)
    }
}

// MARK: - Design Tokens

private let wGold   = Color(red: 0.86, green: 0.71, blue: 0.35)   // #DBB559
private let wGoldSoft = Color(red: 0.95, green: 0.88, blue: 0.65) // soft highlight

// Azkar: deep forest green
private let azkarBg1 = Color(red: 0.04, green: 0.22, blue: 0.14)
private let azkarBg2 = Color(red: 0.02, green: 0.10, blue: 0.07)

// Dua: deep royal navy
private let duaBg1   = Color(red: 0.06, green: 0.10, blue: 0.32)
private let duaBg2   = Color(red: 0.02, green: 0.04, blue: 0.18)

// Verse: deep amber/oud
private let verseBg1 = Color(red: 0.22, green: 0.13, blue: 0.02)
private let verseBg2 = Color(red: 0.10, green: 0.06, blue: 0.01)

// MARK: - Background Helpers

private struct AzkarBG: View {
    var isEvening: Bool
    var body: some View {
        ZStack {
            LinearGradient(colors: [azkarBg1, azkarBg2],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: isEvening ? "moon.stars.fill" : "sun.horizon.fill")
                .font(.system(size: 90))
                .foregroundStyle(wGold.opacity(0.07))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: -18, y: -18)
            // corner ornament bottom-right
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundStyle(wGold.opacity(0.10))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: -10, y: -10)
        }
    }
}

private struct DuaBG: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [duaBg1, duaBg2],
                           startPoint: .topTrailing, endPoint: .bottomLeading)
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 90))
                .foregroundStyle(wGold.opacity(0.07))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 18, y: -18)
            Image(systemName: "sparkles")
                .font(.system(size: 24))
                .foregroundStyle(wGold.opacity(0.10))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .offset(x: 10, y: -10)
        }
    }
}

private struct VerseBG: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [verseBg1, verseBg2],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "book.fill")
                .font(.system(size: 90))
                .foregroundStyle(wGold.opacity(0.07))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: -18, y: -18)
            Text("﷽")
                .font(.system(size: 22))
                .foregroundStyle(wGold.opacity(0.12))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: -10, y: -8)
        }
    }
}

// MARK: - AzkarWidget

struct AzkarWidget: Widget {
    let kind = "AzkarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AzkarProvider()) { entry in
            AzkarWidgetView(entry: entry)
                .compatibleWidgetBackground { AzkarBG(isEvening: entry.isEvening) }
                .widgetURL(URL(string: "quranapp://azkar"))
        }
        .configurationDisplayName("أذكار اليوم")
        .description("ذكر يتجدد كل ساعتين — صباحاً ومساءً")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline,
        ])
    }
}

// MARK: - DuaWidget

struct DuaWidget: Widget {
    let kind = "DuaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DuaProvider()) { entry in
            DuaWidgetView(entry: entry)
                .compatibleWidgetBackground { DuaBG() }
                .widgetURL(URL(string: "quranapp://azkar"))
        }
        .configurationDisplayName("دعاء اليوم")
        .description("دعاء جديد كل يوم من كنز الأدعية النبوية")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline,
        ])
    }
}

// MARK: - AzkarWidgetView

struct AzkarWidgetView: View {
    let entry: AzkarEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {

        // ── شاشة القفل: سطر واحد ──────────────────────────────────
        case .accessoryInline:
            Label {
                Text(entry.zikr).lineLimit(1)
            } icon: {
                Image(systemName: entry.isEvening ? "moon.stars.fill" : "sun.horizon.fill")
            }

        // ── شاشة القفل: دائرة ──────────────────────────────────────
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 2) {
                    Image(systemName: entry.isEvening ? "moon.stars.fill" : "sun.horizon.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text(entry.category)
                        .font(.system(size: 7, weight: .bold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
            }

        // ── شاشة القفل: مستطيل ─────────────────────────────────────
        case .accessoryRectangular:
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Spacer()
                    Image(systemName: entry.isEvening ? "moon.stars.fill" : "sun.horizon.fill")
                        .font(.system(size: 9, weight: .semibold))
                    Text(entry.category)
                        .font(.system(size: 9, weight: .bold))
                }
                Text(entry.zikr)
                    .font(.system(size: 11))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

        // ── شاشة الرئيسية (Small + Medium) ────────────────────────
        default:
            let isSmall = family == .systemSmall
            VStack(alignment: .trailing, spacing: 0) {

                // ── Header: category badge ─────────────────────────
                HStack(spacing: 6) {
                    Spacer()
                    Image(systemName: entry.isEvening ? "moon.stars.fill" : "sun.horizon.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(wGold)
                    Text(entry.category)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(wGold)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(wGold.opacity(0.15))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(wGold.opacity(0.4), lineWidth: 0.8))
                }

                // ── Gold divider ───────────────────────────────────
                Rectangle()
                    .fill(
                        LinearGradient(colors: [wGold.opacity(0), wGold.opacity(0.6), wGold.opacity(0)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(height: 0.8)
                    .padding(.vertical, isSmall ? 7 : 9)

                // ── Zikr text ──────────────────────────────────────
                Text(entry.zikr)
                    .font(.system(size: isSmall ? 12 : 14, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
                    .lineSpacing(isSmall ? 4 : 6)
                    .minimumScaleFactor(0.65)
                    .lineLimit(isSmall ? 4 : 6)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Spacer(minLength: 0)

                // ── Footer ─────────────────────────────────────────
                HStack {
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 8))
                        Text("كل ساعتين")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(wGoldSoft.opacity(0.55))
                }
            }
            .padding(isSmall ? 12 : 16)
        }
    }
}

// MARK: - DuaWidgetView

struct DuaWidgetView: View {
    let entry: DuaEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {

        case .accessoryInline:
            Label { Text(entry.dua).lineLimit(1) }
                icon: { Image(systemName: "hand.raised.fill") }

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 2) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text(entry.occasion)
                        .font(.system(size: 7, weight: .bold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2).minimumScaleFactor(0.7)
                }
            }

        case .accessoryRectangular:
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Spacer()
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 9, weight: .semibold))
                    Text(entry.occasion).font(.system(size: 9, weight: .bold))
                }
                Text(entry.dua)
                    .font(.system(size: 11)).multilineTextAlignment(.trailing)
                    .lineLimit(3).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

        case .systemLarge:
            VStack(alignment: .trailing, spacing: 0) {
                HStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(wGold)
                    Text(entry.occasion)
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(wGold)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(wGold.opacity(0.15)).clipShape(Capsule())
                        .overlay(Capsule().stroke(wGold.opacity(0.4), lineWidth: 0.8))
                }
                Rectangle()
                    .fill(LinearGradient(colors: [wGold.opacity(0), wGold.opacity(0.6), wGold.opacity(0)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(height: 0.8).padding(.vertical, 12)
                Text(entry.dua)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
                    .lineSpacing(10).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Spacer()
                Text("﴿ ادْعُونِي أَسْتَجِبْ لَكُمْ ﴾")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(wGoldSoft.opacity(0.65))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(16)

        default:
            let isSmall = family == .systemSmall
            VStack(alignment: .trailing, spacing: 0) {
                HStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(wGold)
                    Text(entry.occasion)
                        .font(.system(size: 10, weight: .bold)).foregroundStyle(wGold)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(wGold.opacity(0.15)).clipShape(Capsule())
                        .overlay(Capsule().stroke(wGold.opacity(0.4), lineWidth: 0.8))
                }
                Rectangle()
                    .fill(LinearGradient(colors: [wGold.opacity(0), wGold.opacity(0.6), wGold.opacity(0)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(height: 0.8).padding(.vertical, isSmall ? 7 : 9)
                Text(entry.dua)
                    .font(.system(size: isSmall ? 12 : 14, weight: .medium))
                    .foregroundStyle(.white).multilineTextAlignment(.trailing)
                    .lineSpacing(isSmall ? 4 : 6).minimumScaleFactor(0.65)
                    .lineLimit(isSmall ? 4 : 7)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Spacer(minLength: 0)
                HStack {
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "calendar").font(.system(size: 8))
                        Text("دعاء اليوم").font(.system(size: 9))
                    }.foregroundStyle(wGoldSoft.opacity(0.55))
                }
            }
            .padding(isSmall ? 12 : 16)
        }
    }
}

// MARK: - Daily Verse Widget (آية اليوم)

struct DailyVerseWidget: Widget {
    let kind = "DailyVerseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VerseProvider()) { entry in
            VerseWidgetView(entry: entry)
                .compatibleWidgetBackground { VerseBG() }
                .widgetURL(URL(string: "quranapp://quran"))
        }
        .configurationDisplayName("آية اليوم")
        .description("آية قرآنية تتغير يومياً")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline,
        ])
    }
}

struct VerseEntry: TimelineEntry {
    let date: Date
    let verse: String
    let ref: String      // e.g. "البقرة:255"
}

struct VerseProvider: TimelineProvider {
    private let verses: [(String, String)] = [
        ("اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ", "البقرة:255"),
        ("وَمَنْ يَتَوَكَّلْ عَلَى اللَّهِ فَهُوَ حَسْبُهُ ۚ إِنَّ اللَّهَ بَالِغُ أَمْرِهِ", "الطلاق:3"),
        ("فَإِنَّ مَعَ الْعُسْرِ يُسْرًا ۞ إِنَّ مَعَ الْعُسْرِ يُسْرًا", "الشرح:5-6"),
        ("وَإِذَا سَأَلَكَ عِبَادِي عَنِّي فَإِنِّي قَرِيبٌ ۖ أُجِيبُ دَعْوَةَ الدَّاعِ إِذَا دَعَانِ", "البقرة:186"),
        ("إِنَّمَا يُوَفَّى الصَّابِرُونَ أَجْرَهُمْ بِغَيْرِ حِسَابٍ", "الزمر:10"),
        ("قُلْ يَا عِبَادِيَ الَّذِينَ أَسْرَفُوا عَلَىٰ أَنفُسِهِمْ لَا تَقْنَطُوا مِن رَّحْمَةِ اللَّهِ", "الزمر:53"),
        ("وَلَسَوْفَ يُعْطِيكَ رَبُّكَ فَتَرْضَىٰ", "الضحى:5"),
        ("أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ", "الرعد:28"),
        ("وَقُل رَّبِّ زِدْنِي عِلْمًا", "طه:114"),
        ("إِنَّ اللَّهَ مَعَ الصَّابِرِينَ", "البقرة:153"),
        ("وَعَسَىٰ أَن تَكْرَهُوا شَيْئًا وَهُوَ خَيْرٌ لَّكُمْ", "البقرة:216"),
        ("فَاذْكُرُونِي أَذْكُرْكُمْ وَاشْكُرُوا لِي وَلَا تَكْفُرُونِ", "البقرة:152"),
        ("وَاللَّهُ يُحِبُّ الصَّابِرِينَ", "آل عمران:146"),
        ("إِنَّ اللَّهَ لَا يُضِيعُ أَجْرَ الْمُحْسِنِينَ", "التوبة:120"),
    ]

    func placeholder(in context: Context) -> VerseEntry {
        VerseEntry(date: .now, verse: verses[0].0, ref: verses[0].1)
    }

    func getSnapshot(in context: Context, completion: @escaping (VerseEntry) -> Void) {
        let idx = dayIndex()
        completion(VerseEntry(date: .now, verse: verses[idx].0, ref: verses[idx].1))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VerseEntry>) -> Void) {
        let idx   = dayIndex()
        let entry = VerseEntry(date: .now, verse: verses[idx].0, ref: verses[idx].1)
        // تحديث عند منتصف الليل
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? Date(timeIntervalSinceNow: 86400)
        let midnight = Calendar.current.startOfDay(for: tomorrow)
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }

    private func dayIndex() -> Int {
        ((Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 1) - 1) % verses.count
    }
}

struct VerseWidgetView: View {
    let entry: VerseEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {

        case .accessoryInline:
            Label { Text(entry.verse).lineLimit(1) }
                icon: { Image(systemName: "book.fill") }

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 2) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("آية")
                        .font(.system(size: 9, weight: .bold))
                    Text(entry.ref)
                        .font(.system(size: 7))
                        .multilineTextAlignment(.center)
                        .lineLimit(2).minimumScaleFactor(0.7)
                }
            }

        case .accessoryRectangular:
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Spacer()
                    Image(systemName: "book.fill").font(.system(size: 9, weight: .semibold))
                    Text("آية اليوم").font(.system(size: 9, weight: .bold))
                }
                Text(entry.verse)
                    .font(.system(size: 11)).multilineTextAlignment(.trailing)
                    .lineLimit(3).minimumScaleFactor(0.65)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                HStack { Spacer(); Text("﴾ \(entry.ref) ﴿").font(.system(size: 8)) }
            }

        case .systemLarge:
            VStack(alignment: .trailing, spacing: 0) {
                HStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "book.fill")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(wGold)
                    Text("آية اليوم")
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(wGold)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(wGold.opacity(0.15)).clipShape(Capsule())
                        .overlay(Capsule().stroke(wGold.opacity(0.4), lineWidth: 0.8))
                }
                Rectangle()
                    .fill(LinearGradient(colors: [wGold.opacity(0), wGold.opacity(0.6), wGold.opacity(0)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(height: 0.8).padding(.vertical, 14)
                Text(entry.verse)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white).multilineTextAlignment(.trailing)
                    .lineSpacing(12).minimumScaleFactor(0.65)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Spacer()
                HStack {
                    Spacer()
                    Text("﴾ \(entry.ref) ﴿")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(wGoldSoft.opacity(0.8))
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(wGold.opacity(0.12)).clipShape(Capsule())
                }
            }
            .padding(16)

        default:
            let isSmall = family == .systemSmall
            VStack(alignment: .trailing, spacing: 0) {
                HStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "book.fill")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(wGold)
                    Text("آية اليوم")
                        .font(.system(size: 10, weight: .bold)).foregroundStyle(wGold)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(wGold.opacity(0.15)).clipShape(Capsule())
                        .overlay(Capsule().stroke(wGold.opacity(0.4), lineWidth: 0.8))
                }
                Rectangle()
                    .fill(LinearGradient(colors: [wGold.opacity(0), wGold.opacity(0.6), wGold.opacity(0)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(height: 0.8).padding(.vertical, isSmall ? 7 : 9)
                Text(entry.verse)
                    .font(.system(size: isSmall ? 11 : 13, weight: .medium))
                    .foregroundStyle(.white).multilineTextAlignment(.trailing)
                    .lineSpacing(isSmall ? 4 : 6).minimumScaleFactor(0.62)
                    .lineLimit(isSmall ? 5 : 8)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Spacer(minLength: 0)
                HStack {
                    Spacer()
                    Text("﴾ \(entry.ref) ﴿")
                        .font(.system(size: isSmall ? 9 : 10, weight: .semibold))
                        .foregroundStyle(wGoldSoft.opacity(0.75))
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(wGold.opacity(0.10)).clipShape(Capsule())
                }
            }
            .padding(isSmall ? 12 : 16)
        }
    }
}
