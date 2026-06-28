// =============================================================
// AzkarComplication.swift — ويدجت الأذكار لواجهة الساعة
// يعرض ذكر يتغير كل ساعتين
// يدعم: accessoryCircular, accessoryRectangular, accessoryInline
// =============================================================

import WidgetKit
import SwiftUI

// MARK: - Entry

struct AzkarComplicationEntry: TimelineEntry {
    let date: Date
    let zikr: String
    let category: String
}

// MARK: - أذكار مختصرة للساعة

private let watchAzkar: [(text: String, category: String)] = [
    ("سُبْحَانَ اللَّهِ وَبِحَمْدِهِ", "تسبيح"),
    ("لَا إِلَهَ إِلَّا اللَّهُ", "توحيد"),
    ("اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ", "صلاة على النبي"),
    ("أَسْتَغْفِرُ اللَّهَ", "استغفار"),
    ("حَسْبِيَ اللَّهُ وَنِعْمَ الْوَكِيلُ", "توكل"),
    ("لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ", "تحصين"),
    ("سُبْحَانَ اللَّهِ الْعَظِيمِ", "تسبيح"),
    ("الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ", "حمد"),
    ("اللَّهُ أَكْبَرُ", "تكبير"),
    ("رَضِيتُ بِاللَّهِ رَبًّا", "رضا"),
    ("أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ", "حماية"),
    ("اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَافِيَةَ", "دعاء"),
]

// MARK: - Provider (يتغير كل ساعتين)

struct AzkarComplicationProvider: TimelineProvider {

    typealias Entry = AzkarComplicationEntry

    func placeholder(in context: Context) -> AzkarComplicationEntry {
        AzkarComplicationEntry(date: .now, zikr: watchAzkar[0].text, category: watchAzkar[0].category)
    }

    func getSnapshot(in context: Context, completion: @escaping (AzkarComplicationEntry) -> Void) {
        let index = currentAzkarIndex()
        completion(AzkarComplicationEntry(
            date: .now,
            zikr: watchAzkar[index].text,
            category: watchAzkar[index].category
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AzkarComplicationEntry>) -> Void) {
        var entries: [AzkarComplicationEntry] = []
        let cal = Calendar.current
        let now = Date()

        // إنشاء entries كل ساعتين لباقي اليوم
        let currentHour = cal.component(.hour, from: now)
        var nextSlotHour = currentHour - (currentHour % 2) + 2

        // Entry الحالي
        let currentIndex = currentAzkarIndex()
        entries.append(AzkarComplicationEntry(
            date: now,
            zikr: watchAzkar[currentIndex].text,
            category: watchAzkar[currentIndex].category
        ))

        // Entries المستقبلية (كل ساعتين)
        while nextSlotHour < 24 {
            let slotIndex = (nextSlotHour / 2) % watchAzkar.count
            var components = cal.dateComponents([.year, .month, .day], from: now)
            components.hour = nextSlotHour
            components.minute = 0

            if let entryDate = cal.date(from: components) {
                entries.append(AzkarComplicationEntry(
                    date: entryDate,
                    zikr: watchAzkar[slotIndex].text,
                    category: watchAzkar[slotIndex].category
                ))
            }

            nextSlotHour += 2
        }

        // تحديث بعد منتصف الليل
        let nextMidnight = cal.startOfDay(for: now.addingTimeInterval(86400))
        completion(Timeline(entries: entries, policy: .after(nextMidnight)))
    }

    private func currentAzkarIndex() -> Int {
        let hour = Calendar.current.component(.hour, from: Date())
        return (hour / 2) % watchAzkar.count
    }
}

// MARK: - Widget Definition

struct AzkarComplication: Widget {
    let kind = "AzkarComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AzkarComplicationProvider()) { entry in
            AzkarComplicationView(entry: entry)
        }
        .configurationDisplayName("أذكار")
        .description("ذكر يتغير كل ساعتين على واجهة الساعة")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

// MARK: - Views

private let aGold = Color(red: 0.86, green: 0.71, blue: 0.35)

struct AzkarComplicationView: View {

    let entry: AzkarComplicationEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {

        // ── دائري ──
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: "hands.sparkles.fill")
                        .font(.system(size: 12))
                    Text(entry.category)
                        .font(.system(size: 8, weight: .medium))
                        .lineLimit(1)
                }
            }

        // ── مستطيل: النص الكامل ──
        case .accessoryRectangular:
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    Spacer()
                    Text(entry.category)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Image(systemName: "hands.sparkles.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }

                Text(entry.zikr)
                    .font(.system(size: 12, weight: .medium))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
            }

        // ── سطر واحد ──
        case .accessoryInline:
            Text(entry.zikr)
                .lineLimit(1)

        case .accessoryCorner:
            Text(entry.category)
                .font(.system(size: 12, weight: .bold))
                .widgetLabel {
                    Text(entry.zikr)
                }

        @unknown default:
            Text(entry.zikr)
        }
    }
}

// MARK: - Preview

#Preview(as: .accessoryRectangular) {
    AzkarComplication()
} timeline: {
    AzkarComplicationEntry(
        date: .now,
        zikr: "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ",
        category: "تسبيح"
    )
}
