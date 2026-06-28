import Foundation
import WidgetKit
import UserNotifications

// MARK: - PrayerTimesAutoSync
//
// Automatically fetches today's prayer times on every app foreground so that:
//   • Times are always accurate for the user's current location
//   • Notifications fire at the correct times every day
//   • The widget and Live Activity show correct times
//   • Background refresh succeeds (lat/lng are always saved)
//
// Call `PrayerTimesAutoSync.shared.syncIfNeeded()` from the `.active` scene phase.

@MainActor
final class PrayerTimesAutoSync {

    static let shared = PrayerTimesAutoSync()
    private init() {}

    private var isSyncing = false

    // MARK: - UserDefaults Keys

    // SharedLocationManager saves here (source of truth for location)
    private let cachedLatKey = "cachedLocationLat"
    private let cachedLonKey = "cachedLocationLon"

    // PrayerTimesView offline cache
    private let offTimesKey = "offline_prayer_times_v2"
    private let offCityKey  = "offline_prayer_city"
    private let offDateKey  = "offline_prayer_date"

    // PrayerBackgroundRefresh needs these for background fetches
    private let bgLatKey   = "last_prayer_lat"
    private let bgLonKey   = "last_prayer_lng"
    private let bgTimesKey = "bg_stored_prayer_times"
    private let bgCityKey  = "bg_stored_city_name"

    // Widget App Group
    private let appGroupID = "group.tech.meshari.QuranApp"

    // MARK: - Public entry point

    /// Call on every foreground. Skips if today's times are already cached.
    func syncIfNeeded() {
        guard !isSyncing else { return }

        let ud       = UserDefaults.standard
        let todayStr = Self.todayString()
        let lat = ud.double(forKey: cachedLatKey)
        let lon = ud.double(forKey: cachedLonKey)

        // Already have fresh times for today; still refresh widget + notifications
        // because app-group data can be empty after install, update, or simulator reset.
        if ud.string(forKey: offDateKey) == todayStr,
           let dict = ud.dictionary(forKey: offTimesKey) as? [String: String],
           !dict.isEmpty {
            let resolvedDict: [String: String]
            if lat != 0, lon != 0,
               let localDict = Self.localPrayerTimesDict(lat: lat, lon: lon, date: Date(), tz: .current) {
                resolvedDict = localDict
                ud.set(localDict, forKey: offTimesKey)
                ud.set(todayStr, forKey: offDateKey)
                ud.set(lat, forKey: bgLatKey)
                ud.set(lon, forKey: bgLonKey)
                ud.set(localDict, forKey: bgTimesKey)
            } else {
                resolvedDict = dict
            }

            writeWidgetData(resolvedDict)
            NotificationManager.shared.reschedulePrayerNotificationsFromStoredData()
            return
        }

        // Get the last known coordinates (set by SharedLocationManager)
        guard lat != 0, lon != 0 else {
            // Location not available yet — will retry on next foreground
            return
        }

        isSyncing = true
        Task {
            defer { isSyncing = false }
            await fetchAndSave(lat: lat, lon: lon)
        }
    }

    // MARK: - Fetch & Persist

    private func fetchAndSave(lat: Double, lon: Double) async {
        let today  = Self.todayString()
        let ud     = UserDefaults.standard
        let method = ud.integer(forKey: "prayer_method_id")
        let eff    = method > 0 ? method : 10   // default: Umm Al-Qura

        // ── Prefer local calculation: same source used by notifications and PrayerTimesView
        var dict = Self.localPrayerTimesDict(lat: lat, lon: lon, date: Date(), tz: .current)

        // ── Network fallback if local calculation cannot produce valid times ──
        if dict == nil, let url = URL(string:
            "https://quran.meshari.tech/api/prayer_times.php?lat=\(lat)&lng=\(lon)&date=\(today)&method=\(eff)"
        ), let (data, resp) = try? await URLSession.shared.data(from: url),
           (resp as? HTTPURLResponse)?.statusCode == 200 {
            dict = Self.parseOurServer(data)
        }

        // ── Fallback: aladhan.com ───────────────────────────────────────
        if dict == nil,
           let url = URL(string:
            "https://api.aladhan.com/v1/timings?latitude=\(lat)&longitude=\(lon)&method=4"
           ), let (data, _) = try? await URLSession.shared.data(from: url) {
            dict = Self.parseAladhan(data)
        }

        guard let timesDict = dict, !timesDict.isEmpty else { return }

        // ── Persist everything ──────────────────────────────────────────
        // 1. Main prayer cache (read by HomeView + PrayerTimesView)
        ud.set(timesDict, forKey: offTimesKey)
        ud.set(today,     forKey: offDateKey)

        // 2. Save lat/lng so PrayerBackgroundRefresh can fetch without user opening app
        ud.set(lat, forKey: bgLatKey)
        ud.set(lon, forKey: bgLonKey)

        // 3. Background refresh cache (fire-at-prayer-time task reads this)
        ud.set(timesDict, forKey: bgTimesKey)

        // 4. Keep city name if already known (set by PrayerTimesView's geocoder)
        let cityName = ud.string(forKey: offCityKey) ?? ""
        if !cityName.isEmpty {
            ud.set(cityName, forKey: bgCityKey)
        }

        // 5. Widget App Group — for QuranWidget
        writeWidgetData(timesDict)

        // 6. Reschedule prayer notifications with today's accurate times
        reschedulePrayerNotifications(timesDict, lat: lat, lon: lon)

        // 7. Update Live Activity / Dynamic Island with the correct next prayer
        if #available(iOS 16.2, *) {
            await PrayerBackgroundRefresh.updateLiveActivityFromStorage()
        }
    }

    private func writeWidgetData(_ timesDict: [String: String]) {
        guard let wud = UserDefaults(suiteName: appGroupID) else { return }
        let cityName = UserDefaults.standard.string(forKey: offCityKey) ?? ""

        wud.set(timesDict, forKey: "widget_prayerTimings")
        wud.set(cityName, forKey: "widget_cityName")
        wud.set(Date().timeIntervalSince1970, forKey: "widget_updatedAt")

        if let (name, date) = Self.computeNextPrayer(from: timesDict) {
            wud.set(name, forKey: "widget_nextPrayer")
            wud.set(date.timeIntervalSince1970, forKey: "widget_nextPrayerDate")
        } else {
            wud.removeObject(forKey: "widget_nextPrayer")
            wud.removeObject(forKey: "widget_nextPrayerDate")
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Notification Rescheduling

    private func reschedulePrayerNotifications(_ timesDict: [String: String], lat: Double, lon: Double) {
        let sound = UserDefaults.standard.string(forKey: "prayerSoundPreference") ?? "default"
        if lat != 0, lon != 0 {
            NotificationManager.shared.schedulePrayerNotifications(
                lat: lat,
                lng: lon,
                sound: sound
            )
        } else {
            let order = ["الفجر", "الشروق", "الظهر", "العصر", "المغرب", "العشاء"]
            let iconMap = [
                "الفجر": "moon.fill", "الشروق": "sunrise.fill",
                "الظهر": "sun.max.fill", "العصر": "sun.haze.fill",
                "المغرب": "sunset.fill", "العشاء": "moon.stars.fill"
            ]
            let prayerTimes = order.compactMap { name -> PrayerTime? in
                guard let time = timesDict[name] else { return nil }
                return PrayerTime(name: name, time: time, icon: iconMap[name] ?? "clock.fill")
            }
            NotificationManager.shared.schedulePrayerNotifications(prayerTimes, sound: sound)
        }
    }

    // MARK: - Parsing Helpers

    /// Parse our server: {success:true, data:{prayers:{fajr:{time:"HH:mm"}, ...}}}
    static func parseOurServer(_ data: Data) -> [String: String]? {
        guard let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = json["success"] as? Bool, success,
              let dataObj = json["data"]    as? [String: Any],
              let prayers = dataObj["prayers"] as? [String: Any]
        else { return nil }

        var dict: [String: String] = [:]
        let map: [(key: String, ar: String)] = [
            ("fajr",    "الفجر"),
            ("sunrise", "الشروق"),
            ("dhuhr",   "الظهر"),
            ("asr",     "العصر"),
            ("maghrib", "المغرب"),
            ("isha",    "العشاء"),
        ]
        for entry in map {
            if let p = prayers[entry.key] as? [String: Any],
               let t = p["time"] as? String {
                dict[entry.ar] = t
            }
        }
        return dict.isEmpty ? nil : dict
    }

    /// Parse aladhan.com: {data:{timings:{Fajr:"HH:mm", ...}}}
    static func parseAladhan(_ data: Data) -> [String: String]? {
        guard let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"]    as? [String: Any],
              let timings = dataObj["timings"] as? [String: String]
        else { return nil }

        var dict: [String: String] = [:]
        let map: [(key: String, ar: String)] = [
            ("Fajr",    "الفجر"),
            ("Sunrise", "الشروق"),
            ("Dhuhr",   "الظهر"),
            ("Asr",     "العصر"),
            ("Maghrib", "المغرب"),
            ("Isha",    "العشاء"),
        ]
        for entry in map {
            if let t = timings[entry.key] {
                // aladhan may return "HH:mm (EET)" — strip suffix
                let clean = t.components(separatedBy: " ").first ?? t
                dict[entry.ar] = clean
            }
        }
        return dict.isEmpty ? nil : dict
    }

    static func localPrayerTimesDict(
        lat: Double,
        lon: Double,
        date: Date,
        tz: TimeZone
    ) -> [String: String]? {
        let calc = PrayerTimesCalculator.fromUserDefaults()
        guard let result = calc.calculate(lat: lat, lon: lon, date: date, tz: tz) else { return nil }

        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        fmt.timeZone = tz

        return [
            "الفجر": fmt.string(from: result.fajr),
            "الشروق": fmt.string(from: result.sunrise),
            "الظهر": fmt.string(from: result.dhuhr),
            "العصر": fmt.string(from: result.asr),
            "المغرب": fmt.string(from: result.maghrib),
            "العشاء": fmt.string(from: result.isha)
        ]
    }

    // MARK: - Next Prayer Computation

    static func computeNextPrayer(
        from timesDict: [String: String]
    ) -> (name: String, date: Date)? {
        let order = ["الفجر", "الظهر", "العصر", "المغرب", "العشاء"]
        let fmt   = DateFormatter(); fmt.dateFormat = "HH:mm"
        let now   = Date(); let cal = Calendar.current

        for name in order {
            guard let raw = timesDict[name] else { continue }
            let clean = raw.components(separatedBy: " ").first ?? raw
            guard let parsed = fmt.date(from: clean) else { continue }
            var comps = cal.dateComponents([.hour, .minute], from: parsed)
            comps.year  = cal.component(.year,  from: now)
            comps.month = cal.component(.month, from: now)
            comps.day   = cal.component(.day,   from: now)
            guard let full = cal.date(from: comps), full > now else { continue }
            return (name, full)
        }

        // All prayers passed — return fajr tomorrow
        if let raw = timesDict["الفجر"] {
            let clean = raw.components(separatedBy: " ").first ?? raw
            if let parsed = fmt.date(from: clean) {
                var comps = cal.dateComponents([.hour, .minute], from: parsed)
                if let tmrw = cal.date(byAdding: .day, value: 1, to: now) {
                    comps.year  = cal.component(.year,  from: tmrw)
                    comps.month = cal.component(.month, from: tmrw)
                    comps.day   = cal.component(.day,   from: tmrw)
                    if let full = cal.date(from: comps) { return ("الفجر", full) }
                }
            }
        }
        return nil
    }

    // MARK: - Notification Sound

    nonisolated private static func notificationSound(for pref: String) -> UNNotificationSound? {
        switch pref {
        case "silent":  return nil
        case "default": return .default
        default:
            let muezzins = ["mishary": "adhan_mishary.caf",
                            "nasser":  "adhan_nasser.caf",
                            "ahmed":   "adhan_ahmed.caf",
                            "majed":   "adhan_majed.caf"]
            if let file = muezzins[pref] {
                return UNNotificationSound(named: UNNotificationSoundName(file))
            }
            return .default
        }
    }

    // MARK: - Date Helper

    static func todayString() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
