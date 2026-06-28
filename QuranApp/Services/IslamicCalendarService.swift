import Foundation
import UserNotifications

// MARK: - Islamic Events Service

final class IslamicCalendarService {
    static let shared = IslamicCalendarService()
    private init() {}

    // UserDefaults keys for each toggle
    static let keyIslamicEvents = "islamicEventsEnabled"
    static let keyFridayKahf   = "fridayKahfEnabled"
    static let keySixShawwal   = "sixShawwalEnabled"

    // MARK: - Friday Surah Al-Kahf (قبل أذان الجمعة)

    /// يُجدول التذكير قبل أذان الجمعة مباشرةً بـ minutesBefore دقيقة
    /// يقرأ وقت الظهر المحفوظ (= وقت صلاة الجمعة) ويطرح منه الفارق
    /// - Parameter minutesBefore: الوقت قبل الأذان (افتراضي 45 دقيقة)
    func scheduleFridayKahfReminder(minutesBefore: Int = 45) {
        cancelFridayKahfReminder()

        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard settings.authorizationStatus == .authorized else { return }
            self?.doScheduleKahf(minutesBefore: minutesBefore)
        }
    }

    /// للتوافق مع الاستدعاءات القديمة التي تمرر hour:
    func scheduleFridayKahfReminder(hour: Int) {
        // تجاهل hour القديم — نستخدم وقت الجمعة
        scheduleFridayKahfReminder(minutesBefore: 45)
    }

    private func doScheduleKahf(minutesBefore: Int) {
        let tz  = TimeZone.current
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz

        // ── اقرأ وقت الظهر من App Group أولاً ثم UserDefaults ──────
        let appGroupUD = UserDefaults(suiteName: "group.tech.meshari.QuranApp")
        let ud         = UserDefaults.standard

        let prayerDict = appGroupUD?.dictionary(forKey: "widget_prayerTimings") as? [String: String]
                      ?? ud.dictionary(forKey: "widget_prayerTimings")          as? [String: String]
                      ?? ud.dictionary(forKey: "offline_prayer_times_v2")       as? [String: String]
                      ?? [:]

        // وقت الظهر = وقت صلاة الجمعة
        let rawDhuhr = prayerDict["الظهر"] ?? ""
        let fmt      = DateFormatter()
        fmt.dateFormat = "HH:mm"
        fmt.timeZone   = tz

        // استخرج الساعة والدقيقة من الوقت المحفوظ
        let cleanDhuhr  = rawDhuhr.components(separatedBy: " ").first ?? rawDhuhr
        let parsedDhuhr = fmt.date(from: cleanDhuhr)

        var fireHour:   Int
        var fireMinute: Int

        if let dhuhr = parsedDhuhr {
            // احسب الوقت قبل الأذان بـ minutesBefore دقيقة
            let dhuhrComps   = cal.dateComponents([.hour, .minute], from: dhuhr)
            let dhuhrH       = dhuhrComps.hour   ?? 12
            let dhuhrM       = dhuhrComps.minute ?? 0
            let totalMinutes = dhuhrH * 60 + dhuhrM - minutesBefore
            fireHour         = (totalMinutes / 60 + 24) % 24
            fireMinute       = ((totalMinutes % 60) + 60) % 60
        } else {
            // لا توجد بيانات — استخدم 11:15 كافتراضي معقول
            fireHour   = 11
            fireMinute = 15
        }

        let center = UNUserNotificationCenter.current()

        // ── إشعار رئيسي: قبل أذان الجمعة ─────────────────────────
        var comps          = DateComponents()
        comps.weekday      = 6           // الجمعة
        comps.hour         = fireHour
        comps.minute       = fireMinute
        comps.second       = 0
        comps.timeZone     = tz

        let minutesText = minutesBefore == 45 ? "٤٥ دقيقة" : "\(minutesBefore) دقيقة"

        let content            = UNMutableNotificationContent()
        content.title          = "📖 سورة الكهف — الجمعة"
        content.body           = "قبل أذان الجمعة بـ \(minutesText) • «من قرأ الكهف في الجمعة أضاء له النور ما بين الجمعتين»"
        content.sound          = .default
        content.categoryIdentifier = "ADHKAR_CATEGORY"
        content.threadIdentifier   = "friday"
        content.userInfo           = ["type": "friday_kahf",
                                      "minutesBefore": minutesBefore]
        if #available(iOS 15.0, *) { content.interruptionLevel = .timeSensitive }

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        center.add(UNNotificationRequest(identifier: "friday_kahf", content: content, trigger: trigger))

        // ── إشعار تذكير عند دخول الوقت (ثابت ليلة الخميس) ────────
        // «من قرأها ليلة الجمعة» — رواية أخرى صحيحة
        var eveningComps      = DateComponents()
        eveningComps.weekday  = 5           // الخميس
        eveningComps.hour     = 20          // بعد المغرب
        eveningComps.minute   = 30
        eveningComps.second   = 0
        eveningComps.timeZone = tz

        let eveningContent            = UNMutableNotificationContent()
        eveningContent.title          = "🌙 ليلة الجمعة"
        eveningContent.body           = "ابدأ بقراءة سورة الكهف الآن • فضلها يمتد من غروب الخميس"
        eveningContent.sound          = .default
        eveningContent.categoryIdentifier = "ADHKAR_CATEGORY"
        eveningContent.threadIdentifier   = "friday"
        if #available(iOS 15.0, *) { eveningContent.interruptionLevel = .active }

        let eveningTrigger = UNCalendarNotificationTrigger(dateMatching: eveningComps, repeats: true)
        center.add(UNNotificationRequest(identifier: "friday_kahf_evening",
                                         content: eveningContent, trigger: eveningTrigger))
    }

    /// يُعاد الاستدعاء من PrayerTimesView بعد كل تحديث لأوقات الصلاة
    /// لضمان أن التذكير يعكس وقت الظهر الجديد الدقيق
    func refreshFridayKahfIfEnabled() {
        guard UserDefaults.standard.bool(forKey: Self.keyFridayKahf) else { return }
        scheduleFridayKahfReminder()
    }

    func cancelFridayKahfReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["friday_kahf", "friday_kahf_evening"]
        )
    }

    func isFridayKahfActive(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { pending in
            DispatchQueue.main.async {
                completion(pending.contains { $0.identifier == "friday_kahf" })
            }
        }
    }

    // MARK: - Islamic Calendar Events

    /// Schedules yearly notifications for major Islamic events using the Umm Al-Qura Hijri calendar.
    func scheduleIslamicEvents() {
        cancelIslamicEvents()
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            self.doScheduleIslamicEvents()
        }
    }

    private func doScheduleIslamicEvents() {
        // Hijri calendar — iOS supports Islamic (Umm Al-Qura) natively
        let hijri   = Calendar(identifier: .islamicUmmAlQura)
        let now     = Date()
        let hijriNow = hijri.dateComponents([.year, .month, .day], from: now)
        let currentYear = hijriNow.year ?? 1446

        struct IslamicEvent {
            let id: String
            let month: Int
            let day: Int
            let title: String
            let body: String
            let advanceDays: Int   // notify N days before (0 = on the day)
        }

        let events: [IslamicEvent] = [
            IslamicEvent(id: "muharram",    month: 1,  day: 1,
                         title: "🌙 رأس السنة الهجرية",
                         body: "عام هجري جديد مبارك — اللهم اجعله عام خير وبركة",
                         advanceDays: 0),
            IslamicEvent(id: "ramadan",     month: 9,  day: 1,
                         title: "🌙 بداية شهر رمضان المبارك",
                         body: "رمضان كريم — شهر القرآن والصيام والقيام",
                         advanceDays: 0),
            IslamicEvent(id: "ramadan_pre", month: 8,  day: 25,
                         title: "🌙 رمضان على الأبواب",
                         body: "تبقى 5 أيام على شهر رمضان المبارك — استعدّ لاستقباله",
                         advanceDays: 0),
            IslamicEvent(id: "eid_fitr",    month: 10, day: 1,
                         title: "🎊 عيد الفطر المبارك",
                         body: "تقبّل الله منا ومنكم صالح الأعمال — عيد مبارك",
                         advanceDays: 0),
            IslamicEvent(id: "six_shawwal", month: 10, day: 2,
                         title: "🌟 الأيام الستة من شوال",
                         body: "من صام رمضان ثم أتبعه ستاً من شوال كان كصيام الدهر — حديث مسلم",
                         advanceDays: 0),
            IslamicEvent(id: "arafa",       month: 12, day: 9,
                         title: "🕌 يوم عرفة",
                         body: "صيام يوم عرفة كفارة سنتين — يوم من أفضل الأيام عند الله",
                         advanceDays: 0),
            IslamicEvent(id: "eid_adha",    month: 12, day: 10,
                         title: "🎊 عيد الأضحى المبارك",
                         body: "تقبّل الله منا ومنكم — عيد أضحى مبارك",
                         advanceDays: 0),
            IslamicEvent(id: "dhul_hijja",  month: 12, day: 1,
                         title: "🌙 بداية العشر من ذي الحجة",
                         body: "ما من أيام العمل الصالح فيها أحب إلى الله من هذه الأيام — حديث البخاري",
                         advanceDays: 0),
            IslamicEvent(id: "ashura",      month: 1,  day: 10,
                         title: "🌙 يوم عاشوراء",
                         body: "صوم يوم عاشوراء يكفّر السنة الماضية — حديث مسلم",
                         advanceDays: 0),
            IslamicEvent(id: "mawlid",      month: 3,  day: 12,
                         title: "🌟 ذكرى المولد النبوي",
                         body: "اللهم صلّ وسلّم وبارك على سيدنا محمد ﷺ",
                         advanceDays: 0),
        ]

        for event in events {
            // Try current year, then next year
            for yearOffset in 0...1 {
                var comps      = DateComponents()
                comps.calendar = hijri
                comps.year     = currentYear + yearOffset
                comps.month    = event.month
                comps.day      = event.day
                comps.hour     = 8
                comps.minute   = 0

                guard let eventDate = hijri.date(from: comps), eventDate > now else { continue }

                let content      = UNMutableNotificationContent()
                content.title    = event.title
                content.body     = event.body
                content.sound    = .default
                content.userInfo = ["type": "islamic_event", "id": event.id]

                let triggerComps  = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: eventDate)
                let trigger       = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: false)
                let req           = UNNotificationRequest(
                    identifier: "islamic_\(event.id)_\(currentYear + yearOffset)",
                    content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(req)
                break   // scheduled for nearest occurrence, stop trying
            }
        }
    }

    func cancelIslamicEvents() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { pending in
            let ids = pending.filter { $0.identifier.hasPrefix("islamic_") }.map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    func areIslamicEventsActive(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { pending in
            DispatchQueue.main.async {
                completion(!pending.filter { $0.identifier.hasPrefix("islamic_") }.isEmpty)
            }
        }
    }

    // MARK: - Current Hijri Date

    struct HijriDate {
        let day: Int
        let month: Int
        let year: Int
        let monthName: String

        static let monthNames: [Int: String] = [
            1: "محرم", 2: "صفر", 3: "ربيع الأول", 4: "ربيع الآخر",
            5: "جمادى الأولى", 6: "جمادى الآخرة", 7: "رجب",
            8: "شعبان", 9: "رمضان", 10: "شوال",
            11: "ذو القعدة", 12: "ذو الحجة"
        ]

        var formatted: String { "\(day) \(monthName) \(year)هـ" }
    }

    func currentHijriDate() -> HijriDate {
        let hijri    = Calendar(identifier: .islamicUmmAlQura)
        let comps    = hijri.dateComponents([.year, .month, .day], from: Date())
        let month    = comps.month ?? 1
        return HijriDate(
            day:       comps.day  ?? 1,
            month:     month,
            year:      comps.year ?? 1446,
            monthName: HijriDate.monthNames[month] ?? ""
        )
    }
}
