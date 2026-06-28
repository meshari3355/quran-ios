// =============================================================
// PrayerComplication.swift — ويدجت الصلاة القادمة لواجهة الساعة
// يدعم: accessoryCircular, accessoryRectangular,
//        accessoryInline, accessoryCorner
// =============================================================

import WidgetKit
import SwiftUI

// MARK: - Entry

struct PrayerComplicationEntry: TimelineEntry {
    let date: Date
    let nextPrayerName: String
    let nextPrayerTime: String
    let nextPrayerDate: Date?
}

// MARK: - Provider

struct PrayerComplicationProvider: TimelineProvider {

    typealias Entry = PrayerComplicationEntry

    private let prayerOrder = ["الفجر", "الظهر", "العصر", "المغرب", "العشاء"]

    func placeholder(in context: Context) -> PrayerComplicationEntry {
        PrayerComplicationEntry(
            date: .now,
            nextPrayerName: "العصر",
            nextPrayerTime: "3:30 م",
            nextPrayerDate: Date().addingTimeInterval(3600)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerComplicationEntry) -> Void) {
        completion(makeEntry(for: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerComplicationEntry>) -> Void) {
        let dict = prayerDictionary()

        // بناء أوقات مطلقة
        let times = prayerOrder.compactMap { name -> (name: String, time: String, date: Date)? in
            guard let raw = dict[name], let d = absoluteDate(from: raw) else { return nil }
            return (name, raw, d)
        }.sorted { $0.date < $1.date }

        var entries: [PrayerComplicationEntry] = []

        // إضافة entry حالي
        entries.append(makeEntry(for: .now))

        // إضافة entry عند كل وقت صلاة (عشان يتغير "الصلاة القادمة")
        for i in 0..<times.count {
            let entryDate = times[i].date
            guard entryDate > .now else { continue }

            let nextIndex = (i + 1) % times.count
            let nextName  = times[nextIndex].name
            let nextTime  = times[nextIndex].time
            let nextDate  = nextIndex > i
                ? times[nextIndex].date
                : Calendar.current.date(byAdding: .day, value: 1, to: times[nextIndex].date) ?? times[nextIndex].date

            entries.append(PrayerComplicationEntry(
                date: entryDate,
                nextPrayerName: nextName,
                nextPrayerTime: formattedTime(nextTime),
                nextPrayerDate: nextDate
            ))
        }

        let nextMidnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        completion(Timeline(entries: entries, policy: .after(nextMidnight)))
    }

    // MARK: - Helpers

    private func makeEntry(for now: Date) -> PrayerComplicationEntry {
        let dict = prayerDictionary()

        let times = prayerOrder.compactMap { name -> (name: String, time: String, date: Date)? in
            guard let raw = dict[name], let d = absoluteDate(from: raw) else { return nil }
            return (name, raw, d)
        }.sorted { $0.date < $1.date }

        // الصلاة القادمة
        if let upcoming = times.first(where: { $0.date > now }) {
            return PrayerComplicationEntry(
                date: now,
                nextPrayerName: upcoming.name,
                nextPrayerTime: formattedTime(upcoming.time),
                nextPrayerDate: upcoming.date
            )
        }

        // كل الأوقات مرت — فجر بكرة
        let fajrName = times.first?.name ?? "الفجر"
        let fajrTime = times.first?.time ?? ""
        let fajrDate = times.first.map {
            Calendar.current.date(byAdding: .day, value: 1, to: $0.date) ?? $0.date
        }

        return PrayerComplicationEntry(
            date: now,
            nextPrayerName: fajrName,
            nextPrayerTime: formattedTime(fajrTime),
            nextPrayerDate: fajrDate
        )
    }

    private func absoluteDate(from raw: String) -> Date? {
        let clean  = raw.components(separatedBy: " ").first ?? raw
        let tz     = TimeZone.current
        let f      = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone   = tz
        guard let t = f.date(from: clean) else { return nil }
        var cal      = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        var c        = cal.dateComponents([.hour, .minute], from: t)
        let now      = Date()
        c.year       = cal.component(.year,  from: now)
        c.month      = cal.component(.month, from: now)
        c.day        = cal.component(.day,   from: now)
        c.timeZone   = tz
        return cal.date(from: c)
    }

    private func formattedTime(_ raw: String) -> String {
        let clean = raw.components(separatedBy: " ").first ?? raw
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        guard let d = f.date(from: clean) else { return clean }
        let h = Calendar.current.component(.hour, from: d)
        f.dateFormat = "h:mm"
        return "\(f.string(from: d)) \(h < 12 ? "ص" : "م")"
    }

    private func prayerDictionary() -> [String: String] {
        if let dict = watchSharedDefaults.dictionary(forKey: "widget_prayerTimings") as? [String: String],
           !dict.isEmpty {
            return dict
        }

        return [
            "الفجر": "05:12",
            "الظهر": "12:10",
            "العصر": "15:30",
            "المغرب": "18:20",
            "العشاء": "19:50"
        ]
    }
}

// MARK: - Design Tokens

private let wGold = Color(red: 0.86, green: 0.71, blue: 0.35)

// MARK: - Widget Definition

struct PrayerComplication: Widget {
    let kind = "PrayerComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerComplicationProvider()) { entry in
            PrayerComplicationView(entry: entry)
        }
        .configurationDisplayName("الصلاة القادمة")
        .description("عداد تنازلي للصلاة القادمة على واجهة الساعة")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

struct PrayerTimesComplication: Widget {
    let kind = "PrayerTimesComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerComplicationProvider()) { entry in
            WatchPrayerTimesComplicationView(entry: entry)
        }
        .configurationDisplayName("أوقات الصلاة")
        .description("أوقات الصلاة المختصرة على واجهة الساعة")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

// MARK: - Views

struct PrayerComplicationView: View {

    let entry: PrayerComplicationEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {

        // ── دائري: أيقونة + وقت ──
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(wGold)
                    Text(entry.nextPrayerName)
                        .font(.system(size: 9, weight: .bold))
                    if let target = entry.nextPrayerDate {
                        Text(target, style: .timer)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .multilineTextAlignment(.center)
                    }
                }
            }

        // ── مستطيل: اسم + وقت + عداد ──
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                    Text("الصلاة القادمة")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Text(entry.nextPrayerName)
                    .font(.system(size: 14, weight: .bold))

                HStack(spacing: 4) {
                    Text(entry.nextPrayerTime)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    if let target = entry.nextPrayerDate {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(target, style: .timer)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                }
            }

        // ── سطر واحد ──
        case .accessoryInline:
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                Text("\(entry.nextPrayerName) \(entry.nextPrayerTime)")
            }

        // ── زاوية ──
        case .accessoryCorner:
            ZStack {
                Text(entry.nextPrayerName)
                    .font(.system(size: 12, weight: .bold))
            }
            .widgetLabel {
                if let target = entry.nextPrayerDate {
                    Text(target, style: .timer)
                }
            }

        @unknown default:
            Text(entry.nextPrayerName)
        }
    }
}

struct WatchPrayerTimesComplicationView: View {

    let entry: PrayerComplicationEntry
    @Environment(\.widgetFamily) private var family

    private struct DisplayPrayer: Identifiable {
        let name: String
        let time: String
        var id: String { name }
    }

    private let order = ["الفجر", "الظهر", "العصر", "المغرب", "العشاء"]
    private var timings: [String: String] {
        if let dict = watchSharedDefaults.dictionary(forKey: "widget_prayerTimings") as? [String: String],
           !dict.isEmpty {
            return dict
        }
        return [
            "الفجر": "05:12",
            "الظهر": "12:10",
            "العصر": "15:30",
            "المغرب": "18:20",
            "العشاء": "19:50"
        ]
    }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label("أوقات الصلاة", systemImage: "moon.stars.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)

                ForEach(visiblePrayers()) { item in
                    HStack(spacing: 4) {
                        Text(item.name)
                            .font(.system(size: 10, weight: item.name == entry.nextPrayerName ? .bold : .regular))
                        Spacer()
                        Text(item.time)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                    }
                }
            }

        case .accessoryInline:
            Text("\(entry.nextPrayerName) \(entry.nextPrayerTime)")

        case .accessoryCorner:
            Text(entry.nextPrayerName)
                .font(.system(size: 12, weight: .bold))
                .widgetLabel {
                    Text(entry.nextPrayerTime)
                }

        default:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 10))
                    Text(entry.nextPrayerName)
                        .font(.system(size: 9, weight: .bold))
                    Text(entry.nextPrayerTime)
                        .font(.system(size: 9, design: .monospaced))
                }
            }
        }
    }

    private func visiblePrayers() -> [DisplayPrayer] {
        let currentIndex = order.firstIndex(of: entry.nextPrayerName) ?? 0
        return (0..<3).compactMap { offset in
            let name = order[(currentIndex + offset) % order.count]
            guard let time = timings[name] else { return nil }
            return DisplayPrayer(name: name, time: shortTime(time))
        }
    }

    private func shortTime(_ raw: String) -> String {
        let clean = raw.components(separatedBy: " ").first ?? raw
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        guard let date = f.date(from: clean) else { return clean }
        f.dateFormat = "H:mm"
        return f.string(from: date)
    }
}

// MARK: - Preview

#Preview(as: .accessoryCircular) {
    PrayerComplication()
} timeline: {
    PrayerComplicationEntry(
        date: .now,
        nextPrayerName: "المغرب",
        nextPrayerTime: "6:20 م",
        nextPrayerDate: Date().addingTimeInterval(3600)
    )
}
