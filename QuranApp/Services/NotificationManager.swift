import Foundation
import UserNotifications

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - NotificationManager
// الإشعارات المحلية: الصلاة + الأذكار + القرآن + الجمعة
// المصدر: بحث تقني مفصل — 15 أبريل 2026
// ─────────────────────────────────────────────────────────────────────────────

final class NotificationManager {

    static let shared = NotificationManager()
    private init() {}

    static let prayerWarningMinutesKey = "prayerWarningMinutes"

    private let center = UNUserNotificationCenter.current()
    private let lastReadKey = "globalLastQuranReadDate"
    private static let prayerNotificationPrefixes = ["prayer_", "prayerWarn_", "prayer5min_", "bgprayer_"]
    private static let quranReminderPrefix = "quran_reminder"

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Permission
    // ─────────────────────────────────────────────────────────────────────────

    func requestPermission(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(
            options: [.alert, .sound, .badge, .providesAppNotificationSettings]
        ) { granted, _ in
            DispatchQueue.main.async {
                if granted { self.registerNotificationCategories() }
                completion(granted)
            }
        }
    }

    func isPermissionGranted(completion: @escaping (Bool) -> Void) {
        center.getNotificationSettings { s in
            DispatchQueue.main.async { completion(Self.canScheduleNotifications(s.authorizationStatus)) }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Notification Categories (أزرار تفاعلية)
    // بحث: الفصل الرابع §٤.٧
    // ─────────────────────────────────────────────────────────────────────────

    func registerNotificationCategories() {
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: "تذكيري بعد 5 دقائق",
            options: []
        )
        let prayedAction = UNNotificationAction(
            identifier: "PRAYED_ACTION",
            title: "✓ تم أداء الصلاة",
            options: [.foreground]
        )
        let openAction = UNNotificationAction(
            identifier: "OPEN_APP",
            title: "فتح التطبيق",
            options: [.foreground]
        )

        let prayerCategory = UNNotificationCategory(
            identifier: "PRAYER_CATEGORY",
            actions: [prayedAction, snoozeAction, openAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        let legacyPrayerCategory = UNNotificationCategory(
            identifier: "PRAYER_REMINDER",
            actions: [prayedAction, snoozeAction, openAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        let warnCategory = UNNotificationCategory(
            identifier: "PRAYER_WARNING",
            actions: [openAction],
            intentIdentifiers: [],
            options: []
        )
        let adhkarCategory = UNNotificationCategory(
            identifier: "ADHKAR_CATEGORY",
            actions: [openAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([prayerCategory, legacyPrayerCategory, warnCategory, adhkarCategory])
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Muezzins
    // ─────────────────────────────────────────────────────────────────────────

    struct Muezzin {
        let id: String
        let nameAr: String
        let fileName: String
    }

    static let muezzins: [Muezzin] = [
        Muezzin(id: "mishary",  nameAr: "مشاري راشد العفاسي",  fileName: "adhan_mishary.caf"),
        Muezzin(id: "nasser",   nameAr: "ناصر القطامي",         fileName: "adhan_nasser.caf"),
        Muezzin(id: "ahmed",    nameAr: "أحمد العماري",          fileName: "adhan_ahmed.caf"),
        Muezzin(id: "majed",    nameAr: "ماجد الحمذاني",         fileName: "adhan_majed.caf"),
    ]

    private func notificationSound(for pref: String) -> UNNotificationSound? {
        switch pref {
        case "silent":  return nil
        case "default": return .default
        default:
            if let m = NotificationManager.muezzins.first(where: { $0.id == pref }) {
                return UNNotificationSound(named: UNNotificationSoundName(m.fileName))
            }
            return .default
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Prayer Notifications
    // بحث §٤.٢: UNCalendarNotificationTrigger مع DateComponents + TimeZone
    // بحث §٨.١: repeats: false لأن الأوقات تتغير يومياً
    // ─────────────────────────────────────────────────────────────────────────

    struct ScheduledPrayerTime {
        let name: String
        let fireDate: Date
    }

    func schedulePrayerNotifications(_ times: [PrayerTime], sound: String = "default") {
        let scheduled = scheduledPrayerTimes(from: times, on: Date(), tz: .current)
        schedulePrayerNotifications(scheduled, sound: sound)
    }

    func schedulePrayerNotifications(
        lat: Double,
        lng: Double,
        tz: TimeZone = .current,
        sound: String = "default",
        daysAhead: Int = 6
    ) {
        let calc = PrayerTimesCalculator.fromUserDefaults()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let days = max(1, min(daysAhead, 6))
        var scheduled: [ScheduledPrayerTime] = []

        for dayOffset in 0..<days {
            guard let date = cal.date(byAdding: .day, value: dayOffset, to: Date()),
                  let result = calc.calculate(lat: lat, lon: lng, date: date, tz: tz)
            else { continue }

            scheduled.append(contentsOf: [
                ScheduledPrayerTime(name: "الفجر", fireDate: result.fajr),
                ScheduledPrayerTime(name: "الظهر", fireDate: result.dhuhr),
                ScheduledPrayerTime(name: "العصر", fireDate: result.asr),
                ScheduledPrayerTime(name: "المغرب", fireDate: result.maghrib),
                ScheduledPrayerTime(name: "العشاء", fireDate: result.isha),
            ])
        }

        schedulePrayerNotifications(scheduled, sound: sound)
    }

    func reschedulePrayerNotificationsFromStoredData(sound: String? = nil) {
        let ud = UserDefaults.standard
        let selectedSound = sound ?? ud.string(forKey: "prayerSoundPreference") ?? "default"

        let lat = storedCoordinate(primaryKey: "last_prayer_lat", fallbackKey: "cachedLocationLat")
        let lng = storedCoordinate(primaryKey: "last_prayer_lng", fallbackKey: "cachedLocationLon")
        if let lat, let lng {
            schedulePrayerNotifications(lat: lat, lng: lng, sound: selectedSound)
            return
        }

        guard let dict = ud.dictionary(forKey: "offline_prayer_times_v2") as? [String: String] else { return }
        let order = ["الفجر", "الشروق", "الظهر", "العصر", "المغرب", "العشاء"]
        let iconMap = [
            "الفجر": "moon.fill", "الشروق": "sunrise.fill",
            "الظهر": "sun.max.fill", "العصر": "sun.haze.fill",
            "المغرب": "sunset.fill", "العشاء": "moon.stars.fill"
        ]
        let times = order.compactMap { name -> PrayerTime? in
            guard let time = dict[name] else { return nil }
            return PrayerTime(name: name, time: time, icon: iconMap[name] ?? "clock.fill")
        }
        schedulePrayerNotifications(times, sound: selectedSound)
    }

    private func schedulePrayerNotifications(_ scheduled: [ScheduledPrayerTime], sound: String) {
        center.getNotificationSettings { [weak self] s in
            guard Self.canScheduleNotifications(s.authorizationStatus) else { return }
            self?.doSchedulePrayer(scheduled, sound: sound)
        }
    }

    private func doSchedulePrayer(_ scheduled: [ScheduledPrayerTime], sound: String) {
        // أزل إشعارات الصلاة القديمة فقط
        center.getPendingNotificationRequests { [weak self] pending in
            guard let self else { return }
            let oldIDs = pending.filter {
                Self.isPrayerNotificationID($0.identifier)
            }.map { $0.identifier }
            self.center.removePendingNotificationRequests(withIdentifiers: oldIDs)

            let now = Date()
            let tz = TimeZone.current
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = tz
            let idFormatter = DateFormatter()
            idFormatter.dateFormat = "yyyyMMddHHmm"
            idFormatter.timeZone = tz

            let warningMinutes = Self.prayerWarningMinutes()

            let prayerEmoji: [String: String] = [
                "الفجر": "🌙", "الظهر": "☀️", "العصر": "🌤",
                "المغرب": "🌅", "العشاء": "🌃"
            ]

            var addedRequests = 0
            let maxPrayerRequests = 60
            let upcoming = scheduled
                .filter { $0.name != "الشروق" && $0.fireDate > now }
                .sorted { $0.fireDate < $1.fireDate }

            for prayer in upcoming where addedRequests < maxPrayerRequests {
                let comps = self.calendarComponents(for: prayer.fireDate, calendar: cal, tz: tz)
                let emoji = prayerEmoji[prayer.name] ?? "🕌"
                let suffix = "\(Self.prayerIdentifierKey(for: prayer.name))_\(idFormatter.string(from: prayer.fireDate))"

                // ── إشعار دخول الوقت ───────────────────────────────────
                let atContent = UNMutableNotificationContent()
                atContent.title             = "\(emoji) حان وقت صلاة \(prayer.name)"
                atContent.body              = "الله أكبر • الله أكبر • الله أكبر"
                atContent.sound             = self.notificationSound(for: sound)
                atContent.categoryIdentifier = "PRAYER_CATEGORY"
                atContent.threadIdentifier  = "prayers"
                atContent.relevanceScore    = 1.0
                if #available(iOS 15.0, *) {
                    atContent.interruptionLevel = .timeSensitive
                }
                atContent.userInfo = ["route": "prayer", "prayer": prayer.name, "kind": "time"]

                let atTrigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                self.center.add(
                    UNNotificationRequest(identifier: "prayer_\(suffix)",
                                         content: atContent, trigger: atTrigger)
                )
                addedRequests += 1

                guard warningMinutes > 0, addedRequests < maxPrayerRequests else { continue }
                let warningDate = prayer.fireDate.addingTimeInterval(TimeInterval(-warningMinutes * 60))
                guard warningDate > now else { continue }
                let warnComps = self.calendarComponents(for: warningDate, calendar: cal, tz: tz)

                let warnContent = UNMutableNotificationContent()
                warnContent.title             = "\(emoji) قريباً — \(prayer.name)"
                warnContent.body              = "باقي \(warningMinutes) دقائق على دخول وقت صلاة \(prayer.name)"
                warnContent.sound             = .default
                warnContent.categoryIdentifier = "PRAYER_WARNING"
                warnContent.threadIdentifier  = "prayers"
                if #available(iOS 15.0, *) { warnContent.interruptionLevel = .active }
                warnContent.userInfo = ["route": "prayer", "prayer": prayer.name, "kind": "warning"]

                let warnTrigger = UNCalendarNotificationTrigger(dateMatching: warnComps, repeats: false)
                self.center.add(
                    UNNotificationRequest(identifier: "prayerWarn_\(suffix)",
                                         content: warnContent, trigger: warnTrigger)
                )
                addedRequests += 1
            }
        }
    }

    func cancelPrayerNotifications() {
        center.getPendingNotificationRequests { [weak self] pending in
            let ids = pending.filter { Self.isPrayerNotificationID($0.identifier) }.map { $0.identifier }
            self?.center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    func arePrayerNotificationsActive(completion: @escaping (Bool) -> Void) {
        center.getPendingNotificationRequests { pending in
            DispatchQueue.main.async {
                completion(pending.contains { Self.isPrayerNotificationID($0.identifier) })
            }
        }
    }

    private static func canScheduleNotifications(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    private static func isPrayerNotificationID(_ id: String) -> Bool {
        prayerNotificationPrefixes.contains { id.hasPrefix($0) }
    }

    private static func prayerWarningMinutes() -> Int {
        let stored = UserDefaults.standard.object(forKey: prayerWarningMinutesKey) as? Int
        return max(0, min(stored ?? 5, 60))
    }

    private static func prayerIdentifierKey(for name: String) -> String {
        switch name {
        case "الفجر": return "fajr"
        case "الظهر": return "dhuhr"
        case "العصر": return "asr"
        case "المغرب": return "maghrib"
        case "العشاء": return "isha"
        default:
            return name
                .unicodeScalars
                .filter { CharacterSet.alphanumerics.contains($0) }
                .map(String.init)
                .joined()
        }
    }

    private func storedCoordinate(primaryKey: String, fallbackKey: String) -> Double? {
        let ud = UserDefaults.standard
        let primary = ud.double(forKey: primaryKey)
        if primary != 0 { return primary }
        let fallback = ud.double(forKey: fallbackKey)
        return fallback != 0 ? fallback : nil
    }

    private func scheduledPrayerTimes(from times: [PrayerTime], on date: Date, tz: TimeZone) -> [ScheduledPrayerTime] {
        times.compactMap { prayer in
            guard prayer.name != "الشروق",
                  let fireDate = prayerDate(from: prayer.time, on: date, tz: tz)
            else { return nil }
            return ScheduledPrayerTime(name: prayer.name, fireDate: fireDate)
        }
    }

    private func prayerDate(from rawTime: String, on date: Date, tz: TimeZone) -> Date? {
        let clean = rawTime.components(separatedBy: " ").first ?? rawTime
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = tz

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz

        guard let parsed = formatter.date(from: clean) else { return nil }
        var timeComponents = calendar.dateComponents([.hour, .minute], from: parsed)
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        timeComponents.year = dateComponents.year
        timeComponents.month = dateComponents.month
        timeComponents.day = dateComponents.day
        timeComponents.second = 0
        timeComponents.timeZone = tz
        return calendar.date(from: timeComponents)
    }

    private func calendarComponents(for date: Date, calendar: Calendar, tz: TimeZone) -> DateComponents {
        var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        comps.second = 0
        comps.timeZone = tz
        return comps
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Azkar Relative to Prayer Times (الصحيح شرعاً وتقنياً)
    // بحث الفصل الخامس §٥.٢
    // ─────────────────────────────────────────────────────────────────────────

    /// يُستدعى بعد جلب/حساب أوقات الصلاة — يجدول الأذكار بالأوقات الصحيحة
    /// • أذكار الصباح: بعد الفجر بـ 15 دقيقة
    /// • أذكار المساء: بعد العصر بـ 30 دقيقة
    /// • أذكار بعد الصلاة: بعد كل صلاة بـ 5 دقائق
    func scheduleAzkarRelativeToPrayers(_ prayers: [PrayerTime]) {
        guard UserDefaults.standard.bool(forKey: "azkarNotifsEnabled") else { return }

        center.getNotificationSettings { [weak self] s in
            guard s.authorizationStatus == .authorized else { return }
            self?.doScheduleAzkarRelative(prayers)
        }
    }

    private func doScheduleAzkarRelative(_ prayers: [PrayerTime]) {
        // أزل الأذكار القديمة
        center.getPendingNotificationRequests { [weak self] pending in
            guard let self else { return }
            let oldIDs = pending.filter { $0.identifier.hasPrefix("azkar_") }.map { $0.identifier }
            self.center.removePendingNotificationRequests(withIdentifiers: oldIDs)

            let tz = TimeZone.current
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = tz
            let fmt = DateFormatter()
            fmt.dateFormat = "HH:mm"
            fmt.timeZone   = tz

            // استخرج أوقات الصلوات المطلوبة
            func time(for name: String) -> Date? {
                guard let p = prayers.first(where: { $0.name == name }),
                      let raw = p.time.components(separatedBy: " ").first,
                      let d = fmt.date(from: raw) else { return nil }
                return d
            }

            var toSchedule: [(id: String, title: String, body: String, base: Date, offset: TimeInterval)] = []

            // أذكار الصباح — بعد الفجر بـ 15 دقيقة
            if let fajr = time(for: "الفجر") {
                toSchedule.append((
                    "azkar_morning",
                    "🌅 أذكار الصباح",
                    "حصِّن يومك بأذكار الصباح • سبحان الله وبحمده",
                    fajr, 15 * 60
                ))
            }

            // أذكار المساء — بعد العصر بـ 30 دقيقة (قول الجمهور)
            if let asr = time(for: "العصر") {
                toSchedule.append((
                    "azkar_evening",
                    "🌤 أذكار المساء",
                    "لا تفوّت أذكار المساء • أعوذ بكلمات الله التامات",
                    asr, 30 * 60
                ))
            }

            // أذكار بعد الصلوات — كل صلاة بعد 5 دقائق
            let postPrayers: [(name: String, id: String, emoji: String)] = [
                ("الفجر",    "azkar_post_fajr",    "🌙"),
                ("الظهر",    "azkar_post_dhuhr",   "☀️"),
                ("العصر",    "azkar_post_asr",     "🌤"),
                ("المغرب",   "azkar_post_maghrib", "🌅"),
                ("العشاء",   "azkar_post_isha",    "🌃"),
            ]
            for pp in postPrayers {
                if let base = time(for: pp.name) {
                    toSchedule.append((
                        pp.id,
                        "\(pp.emoji) أذكار بعد صلاة \(pp.name)",
                        "سبحان الله ٣٣ • الحمد لله ٣٣ • الله أكبر ٣٤",
                        base, 5 * 60
                    ))
                }
            }

            // جدولة الأذكار
            for item in toSchedule {
                var comps = cal.dateComponents([.hour, .minute], from: item.base)
                // أضف الفترة الزمنية
                let totalMin = (comps.hour ?? 0) * 60 + (comps.minute ?? 0) + Int(item.offset / 60)
                comps.hour   = (totalMin / 60) % 24
                comps.minute = totalMin % 60
                comps.second  = 0
                comps.timeZone = tz

                let content = UNMutableNotificationContent()
                content.title             = item.title
                content.body              = item.body
                content.sound             = .default
                content.categoryIdentifier = "ADHKAR_CATEGORY"
                content.threadIdentifier  = "adhkar"
                if #available(iOS 15.0, *) { content.interruptionLevel = .active }

                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                self.center.add(
                    UNNotificationRequest(identifier: item.id, content: content, trigger: trigger)
                )
            }

            // أذكار النوم (ثابتة — يحددها المستخدم، 22:30 افتراضياً)
            self.scheduleSleepAzkar()
        }
    }

    /// أذكار النوم — وقت ثابت يختاره المستخدم (افتراضي 22:30)
    private func scheduleSleepAzkar() {
        center.removePendingNotificationRequests(withIdentifiers: ["azkar_sleep"])

        var comps = DateComponents()
        comps.hour     = UserDefaults.standard.integer(forKey: "azkar_sleep_hour").nonZero ?? 22
        comps.minute   = UserDefaults.standard.integer(forKey: "azkar_sleep_minute")
        comps.second   = 0
        comps.timeZone = TimeZone.current

        let content = UNMutableNotificationContent()
        content.title             = "🌙 أذكار النوم"
        content.body              = "اختم يومك بذكر الله • سورة الملك وآية الكرسي"
        content.sound             = .default
        content.categoryIdentifier = "ADHKAR_CATEGORY"
        content.threadIdentifier  = "adhkar"

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        center.add(UNNotificationRequest(identifier: "azkar_sleep", content: content, trigger: trigger))
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Legacy Azkar (fallback when no prayer times available)
    // ─────────────────────────────────────────────────────────────────────────

    func scheduleAzkarNotifications() {
        center.getNotificationSettings { [weak self] s in
            guard s.authorizationStatus == .authorized else { return }
            self?.doScheduleAzkarFallback()
        }
    }

    private func doScheduleAzkarFallback() {
        center.getPendingNotificationRequests { [weak self] pending in
            guard let self else { return }
            let oldIDs = pending.filter { $0.identifier.hasPrefix("azkar_") }.map { $0.identifier }
            self.center.removePendingNotificationRequests(withIdentifiers: oldIDs)

            let tz = TimeZone.current
            let items: [(id: String, title: String, body: String, h: Int, m: Int)] = [
                ("azkar_morning",       "🌅 أذكار الصباح",
                 "حصِّن يومك بأذكار الصباح",                          5, 30),
                ("azkar_evening",       "🌤 أذكار المساء",
                 "لا تفوّت أذكار المساء",                             15, 30),
                ("azkar_sleep",         "🌙 أذكار النوم",
                 "اختم يومك بذكر الله • سورة الملك وآية الكرسي",     22, 30),
            ]

            for item in items {
                var comps = DateComponents()
                comps.hour = item.h; comps.minute = item.m
                comps.second = 0; comps.timeZone = tz

                let content = UNMutableNotificationContent()
                content.title             = item.title
                content.body              = item.body
                content.sound             = .default
                content.categoryIdentifier = "ADHKAR_CATEGORY"
                content.threadIdentifier  = "adhkar"
                if #available(iOS 15.0, *) { content.interruptionLevel = .active }

                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                self.center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
            }
        }
    }

    func cancelAzkarNotifications() {
        center.getPendingNotificationRequests { [weak self] pending in
            let ids = pending.filter { $0.identifier.hasPrefix("azkar_") }.map { $0.identifier }
            self?.center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Quran Reading Reminder
    // ─────────────────────────────────────────────────────────────────────────

    private struct QuranReminderStage {
        let id: String
        let daysAfterLastRead: Int
        let title: String
        let body: String
    }

    private static let quranReminderStages: [QuranReminderStage] = [
        QuranReminderStage(
            id: "24h",
            daysAfterLastRead: 1,
            title: "📖 مرّ يوم على آخر قراءة",
            body: "خذ لك صفحة الآن، ولو دقائق قليلة مع القرآن"
        ),
        QuranReminderStage(
            id: "5d",
            daysAfterLastRead: 5,
            title: "📖 مضت 5 أيام بدون قراءة",
            body: "ارجع للورد اليومي بخطوة بسيطة: صفحة واحدة تكفي للبداية"
        ),
        QuranReminderStage(
            id: "10d",
            daysAfterLastRead: 10,
            title: "📖 مضت 10 أيام بدون قراءة",
            body: "لا تترك وردك يطول غيابه، افتح القرآن الآن وابدأ من آخر موضع"
        ),
        QuranReminderStage(
            id: "15d",
            daysAfterLastRead: 15,
            title: "📖 تذكير لطيف بالقرآن",
            body: "مضت 15 يوماً منذ آخر قراءة، عودة قصيرة اليوم تفرق"
        ),
        QuranReminderStage(
            id: "20d",
            daysAfterLastRead: 20,
            title: "📖 لا تنس وردك",
            body: "مضت 20 يوماً بدون قراءة، افتح المصحف وابدأ بآيات قليلة"
        ),
        QuranReminderStage(
            id: "25d",
            daysAfterLastRead: 25,
            title: "📖 القرآن ينتظرك",
            body: "مضت 25 يوماً منذ آخر قراءة، صفحة واحدة تعيدك للمسار"
        ),
        QuranReminderStage(
            id: "30d",
            daysAfterLastRead: 30,
            title: "📖 شهر بلا قراءة",
            body: "ابدأ اليوم من جديد، ولا تجعل الانقطاع يطول أكثر"
        ),
    ]

    func recordQuranRead() {
        UserDefaults.standard.set(Date(), forKey: lastReadKey)
        scheduleQuranReminder()
    }

    func scheduleQuranReminder() {
        center.getNotificationSettings { [weak self] s in
            guard let self, Self.canScheduleNotifications(s.authorizationStatus) else { return }
            let enabled = UserDefaults.standard.object(forKey: "quranReminderEnabled") as? Bool ?? true

            self.removePendingQuranReminderRequests {
                guard enabled else { return }

                let now = Date()
                let calendar = Calendar(identifier: .gregorian)
                let lastRead = UserDefaults.standard.object(forKey: self.lastReadKey) as? Date ?? now

                let overdueStage = Self.quranReminderStages
                    .filter { stage in
                        guard let fireDate = calendar.date(byAdding: .day, value: stage.daysAfterLastRead, to: lastRead) else {
                            return false
                        }
                        return fireDate <= now
                    }
                    .last

                for stage in Self.quranReminderStages {
                    guard let calculatedFireDate = calendar.date(
                        byAdding: .day,
                        value: stage.daysAfterLastRead,
                        to: lastRead
                    ) else { continue }

                    let fireDate: Date
                    if calculatedFireDate <= now {
                        guard overdueStage?.id == stage.id else { continue }
                        fireDate = now.addingTimeInterval(60)
                    } else {
                        fireDate = calculatedFireDate
                    }

                    var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                    comps.second = 0
                    comps.timeZone = TimeZone.current

                    let content = UNMutableNotificationContent()
                    content.title = stage.title
                    content.body = stage.body
                    content.sound = .default
                    content.threadIdentifier = "quran"
                    content.userInfo = [
                        "route": "quran",
                        "kind": "reading_reminder",
                        "daysSinceLastRead": stage.daysAfterLastRead
                    ]
                    if #available(iOS 15.0, *) { content.interruptionLevel = .active }

                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                    self.center.add(
                        UNNotificationRequest(
                            identifier: "\(Self.quranReminderPrefix)_\(stage.id)",
                            content: content,
                            trigger: trigger
                        )
                    )
                }
            }
        }
    }

    func cancelQuranReminders() {
        removePendingQuranReminderRequests()
    }

    func rescheduleQuranReminderIfNeeded() { scheduleQuranReminder() }

    private func removePendingQuranReminderRequests(completion: (() -> Void)? = nil) {
        center.getPendingNotificationRequests { [weak self] pending in
            guard let self else {
                completion?()
                return
            }
            let ids = pending
                .map(\.identifier)
                .filter { $0 == Self.quranReminderPrefix || $0.hasPrefix("\(Self.quranReminderPrefix)_") }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
            completion?()
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Friday Kahf & Islamic Events
    // ─────────────────────────────────────────────────────────────────────────

    func scheduleFridayKahfIfEnabled() {
        let enabled = UserDefaults.standard.bool(forKey: IslamicCalendarService.keyFridayKahf)
        if enabled { IslamicCalendarService.shared.scheduleFridayKahfReminder() }
        else        { IslamicCalendarService.shared.cancelFridayKahfReminder() }
    }

    func scheduleIslamicEventsIfEnabled() {
        let enabled = UserDefaults.standard.bool(forKey: IslamicCalendarService.keyIslamicEvents)
        if enabled { IslamicCalendarService.shared.scheduleIslamicEvents() }
        else        { IslamicCalendarService.shared.cancelIslamicEvents() }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - App Launch
    // ─────────────────────────────────────────────────────────────────────────

    func onAppLaunch() {
        registerNotificationCategories()
        reschedulePrayerNotificationsFromStoredData()

        let quranEnabled = UserDefaults.standard.object(forKey: "quranReminderEnabled") as? Bool ?? true
        if quranEnabled { scheduleQuranReminder() }

        let azkarEnabled = UserDefaults.standard.bool(forKey: "azkarNotifsEnabled")
        if azkarEnabled { scheduleAzkarNotifications() }   // fallback بدون أوقات صلاة

        scheduleFridayKahfIfEnabled()
        scheduleIslamicEventsIfEnabled()
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Helpers
// ─────────────────────────────────────────────────────────────────────────────

private extension Int {
    /// يرجع nil إذا كانت القيمة صفر (للتمييز بين "لم يُعيَّن" و"صفر مقصود")
    var nonZero: Int? { self != 0 ? self : nil }
}
