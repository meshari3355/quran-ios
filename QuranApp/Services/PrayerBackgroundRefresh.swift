import Foundation
import BackgroundTasks
import CoreLocation
import ActivityKit
import UserNotifications
import WidgetKit

/// Handles BGAppRefreshTask for refreshing prayer times in the background.
///
/// ## Design
///   - The task is scheduled to fire at each upcoming prayer time (not a fixed interval).
///   - When the task fires, it updates the Live Activity ContentState so the Dynamic
///     Island / Lock Screen transitions to the new current prayer automatically.
///   - A full API fetch is done at each fire to keep times accurate.
///   - Falls back to a 6-hour interval when no prayer times are stored yet.
enum PrayerBackgroundRefresh {

    private static let taskIdentifier          = "tech.meshari.QuranApp.prayerRefresh"
    private static let fallbackInterval: TimeInterval = 6 * 60 * 60  // 6 h fallback

    // UserDefaults keys
    private static let storedTimesKey = "bg_stored_prayer_times"
    private static let storedCityKey  = "bg_stored_city_name"

    // MARK: - Schedule at next prayer time (call from scenePhase .background)

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)

        // Try to fire right after the next prayer time so Live Activity updates promptly
        let ud = UserDefaults.standard
        if let stored = ud.dictionary(forKey: storedTimesKey) as? [String: String],
           let next   = computeNextPrayer(from: stored) {
            // Fire 15 seconds after the prayer starts — enough for the transition
            let fireAt = next.nextDate.addingTimeInterval(15)
            request.earliestBeginDate = fireAt.timeIntervalSinceNow > 30
                ? fireAt
                : Date(timeIntervalSinceNow: fallbackInterval)
        } else {
            request.earliestBeginDate = Date(timeIntervalSinceNow: fallbackInterval)
        }

        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - Persist prayer times for the background handler

    /// Called by PrayerTimesView after fetching / updating prayer times.
    static func storePrayerTimes(_ times: [String: String], city: String) {
        UserDefaults.standard.set(times, forKey: storedTimesKey)
        UserDefaults.standard.set(city,  forKey: storedCityKey)
    }

    // MARK: - Handle BGAppRefreshTask

    static func handle(task: BGAppRefreshTask) {
        // ── ١. جدولة المهمة التالية فوراً لإبقاء السلسلة ──────────
        schedule()
        task.expirationHandler = { task.setTaskCompleted(success: false) }

        // ── ٢. تحديث Live Activity فوراً من البيانات المحفوظة ──────
        if #available(iOS 16.2, *) {
            Task { await updateLiveActivityFromStorage() }
        }

        let ud = UserDefaults.standard
        var lat = ud.double(forKey: "last_prayer_lat")
        var lng = ud.double(forKey: "last_prayer_lng")
        if lat == 0 || lng == 0 {
            lat = ud.double(forKey: "cachedLocationLat")
            lng = ud.double(forKey: "cachedLocationLon")
        }
        guard lat != 0, lng != 0 else {
            task.setTaskCompleted(success: false)
            return
        }

        let method = ud.integer(forKey: "prayer_method_id")
        let effectiveMethod = method > 0 ? method : 4  // Umm Al-Qura افتراضياً

        Task {
            // ── ٣. إعادة جدولة إشعارات الصلاة أوفلاين (بدون إنترنت) ─
            // هذا يضمن دقة الأوقات حتى لو ما دخل المستخدم للتطبيق
            rescheduleNotificationsOffline(lat: lat, lng: lng, method: effectiveMethod)

            // ── ٤. تخزين أوقات اليوم محلياً للودجت واللايف أكتفتي ──────
            if let dict = localPrayerTimesDict(lat: lat, lng: lng, date: Date(), tz: .current) {
                persistPrayerTimesDict(dict, lat: lat, lng: lng)
                savePrayerTimesForWidget(dict)

                IslamicCalendarService.shared.refreshFridayKahfIfEnabled()

                let liveEnabled = ud.object(forKey: "liveActivityEnabled") as? Bool ?? true
                if liveEnabled, #available(iOS 16.2, *) {
                    await updateLiveActivityFromStorage()
                }

                task.setTaskCompleted(success: true)
                return
            }

            // ── ٥. احتياطي: جلب الأوقات من الإنترنت إذا فشل الحساب المحلي ─
            do {
                let times = try await PrayerService.shared.fetchTimes(
                    lat: lat, lng: lng, method: effectiveMethod
                )

                var dict: [String: String] = [:]
                if let v = times.fajr    { dict["الفجر"]  = v }
                if let v = times.sunrise { dict["الشروق"] = v }
                if let v = times.dhuhr   { dict["الظهر"]  = v }
                if let v = times.asr     { dict["العصر"]  = v }
                if let v = times.maghrib { dict["المغرب"] = v }
                if let v = times.isha    { dict["العشاء"] = v }

                persistPrayerTimesDict(dict, lat: lat, lng: lng)
                savePrayerTimesForWidget(dict)

                // إعادة جدولة أدق من البيانات الحقيقية
                rescheduleNotificationsFromServer(times)

                // تحديث تذكير الكهف بوقت الجمعة الدقيق الجديد
                IslamicCalendarService.shared.refreshFridayKahfIfEnabled()

                let liveEnabled = ud.object(forKey: "liveActivityEnabled") as? Bool ?? true
                if liveEnabled, #available(iOS 16.2, *) {
                    await rebuildLiveActivity(times: times)
                }
                task.setTaskCompleted(success: true)

            } catch {
                // الإنترنت غير متاح — الإشعارات مجدولة أوفلاين بالفعل (خطوة ٣)
                task.setTaskCompleted(success: true)
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - إعادة جدولة الإشعارات بالحساب المحلي (بدون إنترنت)
    // يحسب 10 أيام مقدماً باستخدام PrayerTimesCalculator
    // ─────────────────────────────────────────────────────────────────────────

    static func rescheduleNotificationsOffline(lat: Double, lng: Double, method _: Int) {
        let tz        = TimeZone.current
        let soundPref = UserDefaults.standard.string(forKey: "prayerSoundPreference") ?? "default"
        NotificationManager.shared.schedulePrayerNotifications(
            lat: lat,
            lng: lng,
            tz: tz,
            sound: soundPref,
            daysAhead: 6
        )
    }

    private static func localPrayerTimesDict(
        lat: Double,
        lng: Double,
        date: Date,
        tz: TimeZone
    ) -> [String: String]? {
        let calc = PrayerTimesCalculator.fromUserDefaults()
        guard let result = calc.calculate(lat: lat, lon: lng, date: date, tz: tz) else { return nil }

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

    private static func persistPrayerTimesDict(_ dict: [String: String], lat: Double, lng: Double) {
        let today: String = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: Date())
        }()

        let ud = UserDefaults.standard
        ud.set(dict, forKey: "offline_prayer_times_v2")
        ud.set(today, forKey: "offline_prayer_date")
        ud.set(dict, forKey: storedTimesKey)
        ud.set(lat, forKey: "last_prayer_lat")
        ud.set(lng, forKey: "last_prayer_lng")
    }

    // إعادة جدولة أوقات اليوم من بيانات الخادم (أدق من الحساب المحلي)
    private static func rescheduleNotificationsFromServer(_: ServerPrayerTimes) {
        let soundPref = UserDefaults.standard.string(forKey: "prayerSoundPreference") ?? "default"
        NotificationManager.shared.reschedulePrayerNotificationsFromStoredData(sound: soundPref)
    }

    // MARK: - Rebuild Live Activity from background

    @available(iOS 16.2, *)
    private static func rebuildLiveActivity(times: ServerPrayerTimes) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let cal = Calendar.current
        let now = Date()
        let fmt = DateFormatter(); fmt.dateFormat = "HH:mm"

        var prayerDates: [String: Date] = [:]

        func toDate(name: String, raw: String?) {
            guard let raw else { return }
            let clean = raw.components(separatedBy: " ").first ?? raw
            guard let parsed = fmt.date(from: clean) else { return }
            var comps = cal.dateComponents([.hour, .minute], from: parsed)
            comps.year  = cal.component(.year,  from: now)
            comps.month = cal.component(.month, from: now)
            comps.day   = cal.component(.day,   from: now)
            if let full = cal.date(from: comps) {
                prayerDates[name] = full
            }
        }
        toDate(name: "الفجر",  raw: times.fajr)
        toDate(name: "الظهر",  raw: times.dhuhr)
        toDate(name: "العصر",  raw: times.asr)
        toDate(name: "المغرب", raw: times.maghrib)
        toDate(name: "العشاء", raw: times.isha)

        guard !prayerDates.isEmpty else { return }

        // staleDate = the NEXT prayer time (not midnight).
        // When iOS reaches this date it re-renders the Live Activity, and
        // nextAndFollowing(now: Date()) automatically returns the correct
        // new next prayer — so the Dynamic Island advances with no BGTask needed.
        let nextPrayerDate: Date = {
            let order = ["الفجر", "الظهر", "العصر", "المغرب", "العشاء"]
            return order
                .compactMap { prayerDates[$0] }
                .filter { $0 > now }
                .min()
                ?? (cal.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86_400))
        }()

        let tomorrow    = cal.date(byAdding: .day, value: 1, to: now) ?? now
        var midComps    = cal.dateComponents([.year, .month, .day], from: tomorrow)
        midComps.hour   = 0
        midComps.minute = 1
        let midnight    = cal.date(from: midComps) ?? now.addingTimeInterval(86_400)

        let city = UserDefaults.standard.string(forKey: storedCityKey) ?? ""
        let state = PrayerLiveActivityAttributes.ContentState(
            prayerDates: prayerDates,
            expiresAt:   midnight,
            cityName:    city
        )
        // Use next prayer as staleDate so iOS triggers re-render at each prayer transition
        let content = ActivityContent(state: state, staleDate: nextPrayerDate)

        // Update existing activities
        var updated = false
        for activity in Activity<PrayerLiveActivityAttributes>.activities {
            await activity.update(content)
            updated = true
        }

        // If none exist, start a new one
        if !updated {
            let attrs = PrayerLiveActivityAttributes(appName: "القرآن الكريم")
            _ = try? Activity.request(attributes: attrs, content: content, pushType: nil)
        }
    }

    // MARK: - Fast Live Activity update from stored prayer times (no network)
    //
    // Call this whenever the app becomes active or a prayer notification fires.
    // Reads the last-stored HH:mm strings from UserDefaults, converts them to
    // today's Dates, and pushes a fresh ContentState to every running activity.
    // Because `nextAndFollowing()` recomputes from Date() at render time, even
    // a ContentState with identical values will trigger a widget re-render and
    // advance the displayed prayer automatically.

    @available(iOS 16.2, *)
    static func updateLiveActivityFromStorage() async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let ud = UserDefaults.standard
        guard let stored = ud.dictionary(forKey: storedTimesKey) as? [String: String],
              !stored.isEmpty else { return }
        let city = ud.string(forKey: storedCityKey) ?? ""

        let cal = Calendar.current
        let now = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"

        var prayerDates: [String: Date] = [:]
        func toDate(_ name: String) {
            guard let raw   = stored[name] else { return }
            let clean       = raw.components(separatedBy: " ").first ?? raw
            guard let parsed = fmt.date(from: clean) else { return }
            var comps        = cal.dateComponents([.hour, .minute], from: parsed)
            comps.year       = cal.component(.year,  from: now)
            comps.month      = cal.component(.month, from: now)
            comps.day        = cal.component(.day,   from: now)
            if let full = cal.date(from: comps) { prayerDates[name] = full }
        }
        toDate("الفجر"); toDate("الظهر"); toDate("العصر")
        toDate("المغرب"); toDate("العشاء")

        guard !prayerDates.isEmpty else { return }

        // staleDate = the NEXT prayer time so iOS re-renders at each prayer transition
        let order = ["الفجر", "الظهر", "العصر", "المغرب", "العشاء"]
        let nextPrayerDate: Date = order
            .compactMap { prayerDates[$0] }
            .filter { $0 > now }
            .min()
            ?? (cal.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86_400))

        let tomorrow   = cal.date(byAdding: .day, value: 1, to: now) ?? now
        var midComps   = cal.dateComponents([.year, .month, .day], from: tomorrow)
        midComps.hour  = 0; midComps.minute = 1
        let midnight   = cal.date(from: midComps) ?? now.addingTimeInterval(86_400)

        let state   = PrayerLiveActivityAttributes.ContentState(
            prayerDates: prayerDates, expiresAt: midnight, cityName: city
        )
        let content = ActivityContent(state: state, staleDate: nextPrayerDate)

        var updated = false
        for activity in Activity<PrayerLiveActivityAttributes>.activities {
            await activity.update(content)
            updated = true
        }

        // If no existing activity, start a new one
        if !updated {
            let attrs = PrayerLiveActivityAttributes(appName: "القرآن الكريم")
            _ = try? Activity.request(attributes: attrs, content: content, pushType: nil)
        }
    }

    // MARK: - Next prayer computation (used by widget daily reset)

    /// Computes next + following prayer from a stored [name: "HH:mm"] dictionary.
    static func computeNextPrayer(
        from times: [String: String]
    ) -> (nextName: String, nextDate: Date,
          followingName: String, followingDate: Date)? {

        let order = ["الفجر", "الظهر", "العصر", "المغرب", "العشاء"]
        let fmt = DateFormatter(); fmt.dateFormat = "HH:mm"
        let now = Date(); let cal = Calendar.current

        var sorted: [(name: String, date: Date)] = []
        for name in order {
            guard let raw = times[name] else { continue }
            let clean = raw.components(separatedBy: " ").first ?? raw
            guard let parsed = fmt.date(from: clean) else { continue }
            var comps = cal.dateComponents([.hour, .minute], from: parsed)
            comps.year = cal.component(.year, from: now)
            comps.month = cal.component(.month, from: now)
            comps.day   = cal.component(.day,   from: now)
            guard let full = cal.date(from: comps) else { continue }
            sorted.append((name, full))
        }

        guard let nextIdx = sorted.firstIndex(where: { $0.date > now }) else { return nil }
        let nxt = sorted[nextIdx]
        let fol: (String, Date) = nextIdx + 1 < sorted.count
            ? (sorted[nextIdx + 1].name, sorted[nextIdx + 1].date)
            : (sorted[0].name, sorted[0].date.addingTimeInterval(86_400))
        return (nxt.name, nxt.date, fol.0, fol.1)
    }

    // MARK: - Widget data (App Group)

    static func savePrayerTimesForWidget(_ times: ServerPrayerTimes) {
        var dict: [String: String] = [:]
        if let v = times.fajr    { dict["الفجر"]  = v }
        if let v = times.sunrise { dict["الشروق"] = v }
        if let v = times.dhuhr   { dict["الظهر"]  = v }
        if let v = times.asr     { dict["العصر"]  = v }
        if let v = times.maghrib { dict["المغرب"] = v }
        if let v = times.isha    { dict["العشاء"] = v }
        savePrayerTimesForWidget(dict)
    }

    static func savePrayerTimesForWidget(_ dict: [String: String]) {
        let appGroupID = "group.tech.meshari.QuranApp"
        guard let ud = UserDefaults(suiteName: appGroupID) else { return }
        ud.set(dict, forKey: "widget_prayerTimings")
        ud.set(UserDefaults.standard.string(forKey: storedCityKey) ?? "", forKey: "widget_cityName")
        ud.set(Date().timeIntervalSince1970, forKey: "widget_updatedAt")

        if let next = computeNextPrayer(from: dict) {
            ud.set(next.nextName, forKey: "widget_nextPrayer")
            ud.set(next.nextDate.timeIntervalSince1970, forKey: "widget_nextPrayerDate")
        } else {
            ud.removeObject(forKey: "widget_nextPrayer")
            ud.removeObject(forKey: "widget_nextPrayerDate")
        }

        WidgetCenter.shared.reloadAllTimelines()
    }
}
