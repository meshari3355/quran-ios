// =============================================================
// PrayerTimesWidget.swift  — Widget Extension Target
// يعرض أوقات الصلاة أو العداد التنازلي للصلاة القادمة
// =============================================================

import WidgetKit
import SwiftUI

// MARK: - Shared Data Keys (write from main app, read here)

private let kPrayerTimings  = "widget_prayerTimings"   // [String: String]  name→time
private let kNextPrayer     = "widget_nextPrayer"      // String  name
private let kNextPrayerDate = "widget_nextPrayerDate"  // Double  timeIntervalSince1970

// MARK: - Entry

struct PrayerEntry: TimelineEntry {
    let date: Date
    let prayerTimes: [(name: String, time: String, icon: String)]
    let nextPrayerName: String
    let nextPrayerDate: Date?
}

// MARK: - Provider

struct PrayerProvider: TimelineProvider {

    typealias Entry = PrayerEntry

    func placeholder(in context: Context) -> PrayerEntry {
        PrayerEntry(date: .now, prayerTimes: sampleTimes(), nextPrayerName: "العصر", nextPrayerDate: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let entry   = makeEntry()
        // Refresh every minute (for countdown) or at next prayer time
        let refresh = Calendar.current.date(byAdding: .minute, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func makeEntry() -> PrayerEntry {
        let ud      = sharedDefaults
        let dict    = ud.dictionary(forKey: kPrayerTimings) as? [String: String] ?? [:]
        let order   = ["الفجر", "الشروق", "الظهر", "العصر", "المغرب", "العشاء"]
        let icons   = ["الفجر": "moon.fill", "الشروق": "sunrise.fill",
                       "الظهر": "sun.max.fill", "العصر": "sun.haze.fill",
                       "المغرب": "sunset.fill", "العشاء": "moon.stars.fill"]
        let times   = order.compactMap { name -> (String, String, String)? in
            guard let t = dict[name] else { return nil }
            return (name, t, icons[name] ?? "clock")
        }

        let nextName = ud.string(forKey: kNextPrayer) ?? ""
        let nextTS   = ud.double(forKey: kNextPrayerDate)
        let nextDate = nextTS > 0 ? Date(timeIntervalSince1970: nextTS) : nil

        return PrayerEntry(date: .now, prayerTimes: times,
                           nextPrayerName: nextName, nextPrayerDate: nextDate)
    }

    private func sampleTimes() -> [(String, String, String)] {
        [("الفجر","05:12","moon.fill"),("الظهر","12:10","sun.max.fill"),
         ("العصر","15:30","sun.haze.fill"),("المغرب","18:20","sunset.fill"),
         ("العشاء","19:50","moon.stars.fill")]
    }
}

// MARK: - All Prayers Widget (systemMedium / systemLarge)

struct PrayerTimesWidget: Widget {
    let kind = "PrayerTimesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerProvider()) { entry in
            PrayerTimesWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("أوقات الصلاة")
        .description("عرض أوقات الصلاة الخمس")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - Next Prayer Widget (systemSmall / accessoryCircular)

struct NextPrayerWidget: Widget {
    let kind = "NextPrayerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerProvider()) { entry in
            NextPrayerWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("الصلاة القادمة")
        .description("عداد تنازلي للصلاة القادمة")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Views

struct PrayerTimesWidgetView: View {
    let entry: PrayerEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .trailing, spacing: 5) {
            // Header
            HStack {
                if let target = entry.nextPrayerDate {
                    // Live countdown in header for medium/large
                    HStack(spacing: 3) {
                        Text(timerInterval: Date()...target, countsDown: true)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.yellow)
                            .monospacedDigit()
                        Text("متبقي")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Text("أوقات الصلاة")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
            }

            Divider().opacity(0.4)

            ForEach(entry.prayerTimes.prefix(family == .systemLarge ? 6 : 5), id: \.name) { p in
                let isNext = p.name == entry.nextPrayerName
                HStack(spacing: 8) {
                    Text(formattedTime(p.time))
                        .font(.system(size: 13, weight: isNext ? .semibold : .regular, design: .monospaced))
                        .foregroundColor(isNext ? .yellow : .primary.opacity(0.7))
                    Spacer()
                    Text(p.name)
                        .font(.system(size: 13, weight: isNext ? .bold : .regular))
                        .foregroundColor(isNext ? .yellow : .primary)
                    Image(systemName: p.icon)
                        .font(.system(size: isNext ? 12 : 10))
                        .foregroundColor(isNext ? .yellow : .secondary)
                }
                .padding(.vertical, isNext ? 2 : 0)
                .padding(.horizontal, isNext ? 4 : 0)
                .background(isNext ? Color.yellow.opacity(0.08) : Color.clear)
                .cornerRadius(5)
            }
        }
        .padding(12)
    }

    private func formattedTime(_ raw: String) -> String {
        let clean = raw.components(separatedBy: " ").first ?? raw
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        guard let d = f.date(from: clean) else { return clean }
        let h = Calendar.current.component(.hour, from: d)
        f.dateFormat = "h:mm"
        return "\(f.string(from: d)) \(h < 12 ? "ص" : "م")"
    }
}

struct NextPrayerWidgetView: View {
    let entry: PrayerEntry
    @Environment(\.widgetFamily) private var family

    /// Formatted prayer time string, e.g. "٥:٣٠ م"
    private var nextPrayerTimeStr: String {
        guard let d = entry.nextPrayerDate else { return "" }
        return formatWidgetTime(d)
    }

    /// Icon for the next prayer
    private var nextIcon: String {
        entry.prayerTimes.first(where: { $0.name == entry.nextPrayerName })?.icon ?? "clock.fill"
    }

    var body: some View {
        switch family {

        case .systemSmall:
            VStack(spacing: 5) {
                Image(systemName: nextIcon)
                    .font(.system(size: 22))
                    .foregroundColor(.yellow)

                Text(entry.nextPrayerName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)

                Text(nextPrayerTimeStr)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                if let target = entry.nextPrayerDate {
                    Text(timerInterval: Date()...target, countsDown: true)
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundColor(.yellow)
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                }

                Text("متبقي")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(8)

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Text(entry.nextPrayerName)
                        .font(.system(size: 9, weight: .bold))
                    if let target = entry.nextPrayerDate {
                        Text(timerInterval: Date()...target, countsDown: true)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                }
            }

        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: nextIcon)
                    .font(.system(size: 14))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(entry.nextPrayerName)
                            .font(.system(size: 12, weight: .bold))
                        Text(nextPrayerTimeStr)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    if let target = entry.nextPrayerDate {
                        Text(timerInterval: Date()...target, countsDown: true)
                            .font(.system(size: 11, design: .rounded))
                            .monospacedDigit()
                    }
                }
            }

        default: // systemMedium
            HStack(alignment: .center, spacing: 16) {
                // Icon badge
                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: nextIcon)
                        .font(.system(size: 26))
                        .foregroundColor(.yellow)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("الصلاة القادمة")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(entry.nextPrayerName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                        Text(nextPrayerTimeStr)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.yellow.opacity(0.8))
                    }

                    if let target = entry.nextPrayerDate {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(timerInterval: Date()...target, countsDown: true)
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundColor(.yellow)
                                .monospacedDigit()
                                .minimumScaleFactor(0.7)
                            Text("متبقي")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()
            }
            .padding(14)
        }
    }
}

private func formatWidgetTime(_ date: Date) -> String {
    let fmt = DateFormatter()
    fmt.dateFormat = "h:mm"
    let h = Calendar.current.component(.hour, from: date)
    return "\(fmt.string(from: date)) \(h < 12 ? "ص" : "م")"
}
