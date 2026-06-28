// =============================================================
// QuranWidget.swift — Prayer Times & Next Prayer Widgets
// =============================================================

import WidgetKit
import SwiftUI

// MARK: - Shared Data Keys

private let kPrayerTimings  = "widget_prayerTimings"
private let kNextPrayer     = "widget_nextPrayer"
private let kNextPrayerDate = "widget_nextPrayerDate"
private let kWidgetCityName = "widget_cityName"
private let kWidgetUpdatedAt = "widget_updatedAt"

// MARK: - Entry

struct PrayerEntry: TimelineEntry {
    let date: Date
    let prayerTimes: [(name: String, time: String, icon: String)]
    let nextPrayerName: String
    let nextPrayerDate: Date?          // absolute Date — used for Text(.timer)
    let cityName: String
    let isUsingSampleData: Bool
}

// MARK: - Provider

struct PrayerProvider: TimelineProvider {
    typealias Entry = PrayerEntry

    func placeholder(in context: Context) -> PrayerEntry {
        PrayerEntry(date: .now, prayerTimes: sampleTimes(),
                    nextPrayerName: "العصر",
                    nextPrayerDate: Date().addingTimeInterval(3600),
                    cityName: "مكة المكرمة",
                    isUsingSampleData: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        completion(makeEntry(for: .now))
    }

    // ── Timeline: generate one entry NOW + one entry at each prayer transition
    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let ud = sharedDefaults
        let loaded = prayerDictionary()
        let dict = loaded.dict
        let cityName = ud.string(forKey: kWidgetCityName) ?? (loaded.isSample ? "مكة المكرمة" : "")
        let order  = ["الفجر", "الشروق", "الظهر", "العصر", "المغرب", "العشاء"]
        let icons  = ["الفجر": "moon.fill", "الشروق": "sunrise.fill",
                      "الظهر": "sun.max.fill", "العصر": "sun.haze.fill",
                      "المغرب": "sunset.fill", "العشاء": "moon.stars.fill"]

        // Build absolute prayer dates for today
        let times = order.compactMap { name -> (name: String, time: String, icon: String, date: Date)? in
            guard let rawTime = dict[name] else { return nil }
            guard let absDate = absoluteDate(from: rawTime) else { return nil }
            return (name, rawTime, icons[name] ?? "clock", absDate)
        }

        let displayTimes = times.map { (name: $0.name, time: $0.time, icon: $0.icon) }

        // Sort by time for timeline math only.
        let sorted = times.sorted { $0.date < $1.date }
        let prayerOnly = sorted.filter { $0.name != "الشروق" }

        // Build entries: one at each actual prayer boundary (so "next prayer" flips correctly)
        var entries: [PrayerEntry] = []

        for prayer in prayerOnly {
            let entryDate = prayer.date
            let next = nextPrayer(after: entryDate.addingTimeInterval(1), prayers: prayerOnly)

            entries.append(PrayerEntry(
                date:            entryDate,
                prayerTimes:     displayTimes,
                nextPrayerName:  next?.name ?? prayer.name,
                nextPrayerDate:  next?.date ?? prayer.date,
                cityName:        cityName,
                isUsingSampleData: loaded.isSample
            ))
        }

        // Always add an immediate "now" entry with correct next prayer
        let nowEntry = makeEntry(
            for: .now,
            times: sorted,
            displayTimes: displayTimes,
            cityName: cityName,
            isUsingSampleData: loaded.isSample
        )
        var allEntries = [nowEntry] + entries.filter { $0.date > .now }

        // If no future entries (all today's prayers passed), refresh after midnight
        if allEntries.count == 1 {
            let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
            allEntries.append(PrayerEntry(date: midnight,
                                          prayerTimes: displayTimes,
                                          nextPrayerName: prayerOnly.first?.name ?? "",
                                          nextPrayerDate: prayerOnly.first.map {
                                              Calendar.current.date(byAdding: .day, value: 1, to: $0.date) ?? $0.date
                                          },
                                          cityName: cityName,
                                          isUsingSampleData: loaded.isSample))
        }

        // Reload after midnight tomorrow so the next day's data (fetched by the app) kicks in
        let nextMidnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        completion(Timeline(entries: allEntries, policy: .after(nextMidnight)))
    }

    // MARK: - Helpers

    private func makeEntry(for now: Date,
                           times: [(name: String, time: String, icon: String, date: Date)]? = nil,
                           displayTimes: [(name: String, time: String, icon: String)]? = nil,
                           cityName: String? = nil,
                           isUsingSampleData: Bool? = nil) -> PrayerEntry {
        let ud    = sharedDefaults
        let loaded = prayerDictionary()
        let dict = loaded.dict
        let resolvedCity = cityName ?? ud.string(forKey: kWidgetCityName) ?? (loaded.isSample ? "مكة المكرمة" : "")
        let resolvedIsSample = isUsingSampleData ?? loaded.isSample
        let order = ["الفجر", "الشروق", "الظهر", "العصر", "المغرب", "العشاء"]
        let icons = ["الفجر": "moon.fill", "الشروق": "sunrise.fill",
                     "الظهر": "sun.max.fill", "العصر": "sun.haze.fill",
                     "المغرب": "sunset.fill", "العشاء": "moon.stars.fill"]

        let allTimes = order.compactMap { name -> (name: String, time: String, icon: String, date: Date)? in
            guard let raw = dict[name], let d = absoluteDate(from: raw) else { return nil }
            return (name, raw, icons[name] ?? "clock", d)
        }

        let dTimes = displayTimes ?? allTimes.map { (name: $0.name, time: $0.time, icon: $0.icon) }

        // Compute next prayer from NOW
        let prayerOnly = allTimes.sorted { $0.date < $1.date }.filter { $0.name != "الشروق" }
        let upcoming = prayerOnly.first { $0.date > now }
        let nextName: String
        let nextDate: Date?
        if let up = upcoming {
            nextName = up.name
            nextDate = up.date
        } else {
            // All passed — fajr tomorrow
            nextName = prayerOnly.first?.name ?? ""
            nextDate = prayerOnly.first.map {
                Calendar.current.date(byAdding: .day, value: 1, to: $0.date) ?? $0.date
            }
        }

        return PrayerEntry(date: now, prayerTimes: dTimes,
                           nextPrayerName: nextName,
                           nextPrayerDate: nextDate,
                           cityName: resolvedCity,
                           isUsingSampleData: resolvedIsSample)
    }

    private func prayerDictionary() -> (dict: [String: String], isSample: Bool) {
        if let dict = sharedDefaults.dictionary(forKey: kPrayerTimings) as? [String: String],
           !dict.isEmpty {
            return (dict, false)
        }

        let sample = Dictionary(uniqueKeysWithValues: sampleTimes().map { ($0.0, $0.1) })
        return (sample, true)
    }

    private func nextPrayer(
        after date: Date,
        prayers: [(name: String, time: String, icon: String, date: Date)]
    ) -> (name: String, date: Date)? {
        if let upcoming = prayers.first(where: { $0.date > date }) {
            return (upcoming.name, upcoming.date)
        }

        guard let first = prayers.first else { return nil }
        return (
            first.name,
            Calendar.current.date(byAdding: .day, value: 1, to: first.date) ?? first.date
        )
    }

    private func absoluteDate(from raw: String) -> Date? {
        let clean = raw.components(separatedBy: " ").first ?? raw
        let tz  = TimeZone.current
        let f   = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone   = tz
        guard let t = f.date(from: clean) else { return nil }
        var cal       = Calendar(identifier: .gregorian)
        cal.timeZone  = tz
        var c         = cal.dateComponents([.hour, .minute], from: t)
        let now       = Date()
        c.year        = cal.component(.year,  from: now)
        c.month       = cal.component(.month, from: now)
        c.day         = cal.component(.day,   from: now)
        c.timeZone    = tz
        return cal.date(from: c)
    }

    private func sampleTimes() -> [(String, String, String)] {
        [("الفجر","05:12","moon.fill"),("الشروق","06:30","sunrise.fill"),
         ("الظهر","12:10","sun.max.fill"),("العصر","15:30","sun.haze.fill"),
         ("المغرب","18:20","sunset.fill"),("العشاء","19:50","moon.stars.fill")]
    }
}

// MARK: - Prayer Design Tokens

private let pGold      = Color(red: 0.86, green: 0.71, blue: 0.35)
private let pGoldSoft  = Color(red: 0.95, green: 0.88, blue: 0.65)
private let prayerBg1  = Color(red: 0.04, green: 0.14, blue: 0.28)   // deep navy
private let prayerBg2  = Color(red: 0.01, green: 0.06, blue: 0.14)

private struct PrayerBG: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [prayerBg1, prayerBg2],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 90))
                .foregroundStyle(pGold.opacity(0.06))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 20, y: -20)
            Image(systemName: "sparkles")
                .font(.system(size: 30))
                .foregroundStyle(pGold.opacity(0.08))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .offset(x: 12, y: -12)
        }
    }
}

// MARK: - Prayer Times Widget

struct PrayerTimesWidget: Widget {
    let kind = "PrayerTimesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerProvider()) { entry in
            PrayerTimesWidgetView(entry: entry)
                .compatibleWidgetBackground { PrayerBG() }
                .widgetURL(URL(string: "quranapp://prayer"))
        }
        .configurationDisplayName("أوقات الصلاة")
        .description("عرض أوقات الصلاة الخمس")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Next Prayer Widget

struct NextPrayerWidget: Widget {
    let kind = "NextPrayerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerProvider()) { entry in
            NextPrayerWidgetView(entry: entry)
                .compatibleWidgetBackground { PrayerBG() }
                .widgetURL(URL(string: "quranapp://prayer"))
        }
        .configurationDisplayName("الصلاة القادمة")
        .description("عداد تنازلي للصلاة القادمة")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Prayer Times View

struct PrayerTimesWidgetView: View {
    let entry: PrayerEntry
    @Environment(\.widgetFamily) private var family

    private var statusLabel: String {
        entry.isUsingSampleData
            ? "افتح التطبيق للتحديث"
            : (entry.cityName.isEmpty ? "اليوم" : entry.cityName)
    }

    var body: some View {
        switch family {

        // ── Small: الصلاة القادمة فقط ──────────────────────────────
        case .systemSmall:
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 4) {
                    Spacer()
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 9)).foregroundStyle(pGold)
                    Text("أوقات الصلاة")
                        .font(.system(size: 9, weight: .bold)).foregroundStyle(pGold)
                }
                Text(statusLabel)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(pGoldSoft.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Spacer()
                // الصلاة القادمة بشكل بارز
                VStack(alignment: .trailing, spacing: 3) {
                    Text(entry.nextPrayerName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                    if let d = entry.nextPrayerDate {
                        Text(d, style: .timer)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(pGold)
                            .multilineTextAlignment(.trailing)
                    }
                    Text("الصلاة القادمة")
                        .font(.system(size: 9))
                        .foregroundStyle(pGoldSoft.opacity(0.55))
                }
                Spacer()
                // 3 صلوات مختصرة
                VStack(spacing: 2) {
                    ForEach(entry.prayerTimes.prefix(3), id: \.name) { p in
                        HStack {
                            Text(formattedTime(p.time))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(p.name == entry.nextPrayerName ? pGold : .white.opacity(0.5))
                            Spacer()
                            Text(p.name)
                                .font(.system(size: 9))
                                .foregroundStyle(p.name == entry.nextPrayerName ? .white : .white.opacity(0.5))
                        }
                    }
                }
            }
            .padding(12)

        // ── Large: كل الصلوات مع بنر وعداد ────────────────────────
        case .systemLarge:
            VStack(alignment: .trailing, spacing: 0) {
                // Header
                HStack(spacing: 6) {
                    Spacer()
                    Text(statusLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(pGoldSoft.opacity(0.58))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(pGold)
                    Text("أوقات الصلاة")
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(pGold)
                }
                // Countdown banner
                if let d = entry.nextPrayerDate {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("الصلاة القادمة")
                                .font(.system(size: 10)).foregroundStyle(pGoldSoft.opacity(0.6))
                            Text(entry.nextPrayerName)
                                .font(.system(size: 24, weight: .bold)).foregroundStyle(.white)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(d, style: .timer)
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .foregroundStyle(pGold).monospacedDigit()
                            Text("متبقي")
                                .font(.system(size: 10)).foregroundStyle(pGoldSoft.opacity(0.5))
                        }
                    }
                    .padding(10)
                    .background(pGold.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(pGold.opacity(0.3), lineWidth: 1))
                    .padding(.vertical, 8)
                }
                Rectangle()
                    .fill(LinearGradient(colors: [pGold.opacity(0), pGold.opacity(0.5), pGold.opacity(0)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(height: 0.7).padding(.bottom, 8)
                // All 6 prayers
                VStack(spacing: 6) {
                    ForEach(entry.prayerTimes, id: \.name) { p in
                        let isNext = p.name == entry.nextPrayerName
                        HStack(spacing: 8) {
                            Text(formattedTime(p.time))
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundStyle(isNext ? pGold : .white.opacity(0.7))
                            Spacer()
                            Text(p.name)
                                .font(.system(size: 14, weight: isNext ? .bold : .regular))
                                .foregroundStyle(isNext ? .white : .white.opacity(0.7))
                            ZStack {
                                Circle().fill(isNext ? pGold : pGold.opacity(0.12))
                                    .frame(width: 28, height: 28)
                                Image(systemName: p.icon).font(.system(size: 12))
                                    .foregroundStyle(isNext ? .black : pGold.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, isNext ? 8 : 5)
                        .background(isNext ? pGold.opacity(0.15) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(isNext ? pGold.opacity(0.4) : Color.clear, lineWidth: 1))
                    }
                }
            }
            .padding(14)

        // ── Medium (default): 5 صلوات ──────────────────────────────
        default:
            VStack(alignment: .trailing, spacing: 0) {
                HStack {
                    Spacer()
                    HStack(spacing: 5) {
                        Text(statusLabel)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(pGoldSoft.opacity(0.55))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(pGold)
                        Text("أوقات الصلاة")
                            .font(.system(size: 12, weight: .bold)).foregroundStyle(pGold)
                    }
                }
                Rectangle()
                    .fill(LinearGradient(colors: [pGold.opacity(0), pGold.opacity(0.5), pGold.opacity(0)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(height: 0.7).padding(.vertical, 6)
                VStack(spacing: 4) {
                    ForEach(entry.prayerTimes.prefix(5), id: \.name) { p in
                        let isNext = p.name == entry.nextPrayerName
                        HStack(spacing: 6) {
                            Text(formattedTime(p.time))
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(isNext ? pGold : .white.opacity(0.75))
                            Spacer()
                            Text(p.name)
                                .font(.system(size: 12, weight: isNext ? .bold : .regular))
                                .foregroundStyle(isNext ? .white : .white.opacity(0.75))
                            ZStack {
                                Circle().fill(isNext ? pGold : pGold.opacity(0.12))
                                    .frame(width: 22, height: 22)
                                Image(systemName: p.icon).font(.system(size: 10))
                                    .foregroundStyle(isNext ? .black : pGold.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 8).padding(.vertical, isNext ? 5 : 3)
                        .background(isNext ? pGold.opacity(0.15) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(isNext ? pGold.opacity(0.4) : Color.clear, lineWidth: 0.8))
                    }
                }
            }
            .padding(12)
        }
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

// MARK: - Next Prayer View

struct NextPrayerWidgetView: View {
    let entry: PrayerEntry
    @Environment(\.widgetFamily) private var family

    private var statusLabel: String {
        entry.isUsingSampleData
            ? "افتح التطبيق للتحديث"
            : (entry.cityName.isEmpty ? "اليوم" : entry.cityName)
    }

    var body: some View {
        switch family {

        // ── Small ──────────────────────────────────────────────────
        case .systemSmall:
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(pGold.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "clock.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(pGold)
                }
                Text(entry.nextPrayerName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                if let target = entry.nextPrayerDate {
                    Text(target, style: .timer)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(pGold)
                        .multilineTextAlignment(.center)
                }
                Text("متبقي")
                    .font(.system(size: 10))
                    .foregroundStyle(pGoldSoft.opacity(0.6))
                Text(statusLabel)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(pGoldSoft.opacity(0.52))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(10)

        // ── Lock screen circular ───────────────────────────────────
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Text(entry.nextPrayerName)
                        .font(.system(size: 9, weight: .bold))
                    if let target = entry.nextPrayerDate {
                        Text(target, style: .timer)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .multilineTextAlignment(.center)
                    }
                }
            }

        // ── Lock screen inline ─────────────────────────────────────
        case .accessoryInline:
            if let target = entry.nextPrayerDate {
                Label {
                    Text(target, style: .timer)
                } icon: {
                    Image(systemName: "clock.fill")
                }
            } else {
                Label(entry.nextPrayerName, systemImage: "clock.fill")
            }

        // ── Lock screen rectangular ────────────────────────────────
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "clock.fill").font(.system(size: 14))
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.nextPrayerName).font(.system(size: 12, weight: .bold))
                    if let target = entry.nextPrayerDate {
                        Text(target, style: .timer)
                            .font(.system(size: 11, design: .monospaced))
                    }
                }
            }

        // ── Medium ─────────────────────────────────────────────────
        default:
            HStack(spacing: 0) {
                // Left: countdown
                VStack(alignment: .leading, spacing: 4) {
                    Text("الصلاة القادمة")
                        .font(.system(size: 10))
                        .foregroundStyle(pGoldSoft.opacity(0.6))
                    Text(statusLabel)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(pGoldSoft.opacity(0.5))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(entry.nextPrayerName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    if let target = entry.nextPrayerDate {
                        Text(target, style: .timer)
                            .font(.system(size: 26, weight: .bold, design: .monospaced))
                            .foregroundStyle(pGold)
                    }
                    Text("متبقي")
                        .font(.system(size: 10))
                        .foregroundStyle(pGoldSoft.opacity(0.5))
                }
                Spacer()
                // Right: gold clock circle
                ZStack {
                    Circle()
                        .fill(pGold.opacity(0.15))
                        .overlay(Circle().stroke(pGold.opacity(0.4), lineWidth: 1))
                        .frame(width: 60, height: 60)
                    Image(systemName: "clock.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(pGold)
                }
            }
            .padding(14)
        }
    }
}
