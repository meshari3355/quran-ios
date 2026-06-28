// =============================================================
// WatchConnectivityService.swift — خدمة التواصل (جانب الساعة)
// =============================================================

import Foundation
import WatchConnectivity
import WidgetKit
import UserNotifications

class WatchConnectivityService: NSObject, ObservableObject {

    static let shared = WatchConnectivityService()

    // ── البيانات المستقبلة ──────────────────────────────────────────────────
    @Published var prayerTimes:    [String: String] = [:]
    @Published var nextPrayerName: String = ""
    @Published var hijriDate:      String = ""
    @Published var cityName:       String = ""
    @Published var latitude:       Double = 0
    @Published var longitude:      Double = 0
    @Published var dailyVerse:     String = ""
    @Published var dailyVerseRef:  String = ""

    // ── حالة الاتصال ────────────────────────────────────────────────────────
    @Published var isPhoneReachable:     Bool = false
    @Published var isWatchPaired:        Bool = false
    @Published var isWatchAppInstalled:  Bool = false
    @Published var connectionStatus:     String = "جاري الاتصال..."

    // ── إعدادات الساعة ──────────────────────────────────────────────────────
    @Published var watchNotifEnabled:       Bool = true { didSet { saveAndSync("watch_notif_enabled",     watchNotifEnabled) } }
    @Published var watchAzkarEnabled:       Bool = true { didSet { saveAndSync("watch_azkar_enabled",     watchAzkarEnabled) } }
    @Published var watchHapticEnabled:      Bool = true { didSet { saveAndSync("watch_haptic_enabled",    watchHapticEnabled) } }
    @Published var watchPrayerAlertEnabled: Bool = true { didSet { saveAndSync("watch_prayer_alert",      watchPrayerAlertEnabled) } }
    @Published var watchTheme:              Int  = 0    { didSet { watchUD.set(watchTheme, forKey: "watch_theme"); scheduleWatchNotifications() } }

    // ── App Group ───────────────────────────────────────────────────────────
    private let appGroupID = "group.tech.meshari.QuranApp"
    private lazy var sharedUD: UserDefaults = { UserDefaults(suiteName: appGroupID) ?? .standard }()
    private let watchUD = UserDefaults.standard

    // ── Timer لإعادة محاولة الاتصال ────────────────────────────────────────
    private var retryTimer: Timer?
    private var isApplyingRemoteSettings = false

    override init() {
        super.init()
        loadCachedData()
    }

    // MARK: - Activation

    func activate() {
        guard WCSession.isSupported() else {
            updateConnectionStatus()
            return
        }
        WCSession.default.delegate = self
        WCSession.default.activate()

        // إعادة المحاولة كل 30 ثانية إذا لم يكن الاتصال مكتملاً
        retryTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.updateConnectionStatus()
            if WCSession.default.activationState != .activated {
                WCSession.default.activate()
            }
        }
        if let retryTimer {
            RunLoop.main.add(retryTimer, forMode: .common)
        }
    }

    // MARK: - Cache

    private func loadCachedData() {
        if let cached = sharedUD.dictionary(forKey: "widget_prayerTimings") as? [String: String] {
            prayerTimes = cached
        }
        nextPrayerName  = sharedUD.string(forKey: "widget_nextPrayer") ?? ""
        hijriDate       = sharedUD.string(forKey: "widget_hijriDate")  ?? ""
        latitude        = sharedUD.double(forKey: "last_prayer_lat")
        longitude       = sharedUD.double(forKey: "last_prayer_lng")
        cityName        = watchUD.string(forKey: "watch_city_name")        ?? ""
        dailyVerse      = watchUD.string(forKey: "watch_daily_verse")      ?? ""
        dailyVerseRef   = watchUD.string(forKey: "watch_daily_verse_ref")  ?? ""

        watchNotifEnabled       = watchUD.object(forKey: "watch_notif_enabled")  as? Bool ?? true
        watchAzkarEnabled       = watchUD.object(forKey: "watch_azkar_enabled")  as? Bool ?? true
        watchHapticEnabled      = watchUD.object(forKey: "watch_haptic_enabled") as? Bool ?? true
        watchPrayerAlertEnabled = watchUD.object(forKey: "watch_prayer_alert")   as? Bool ?? true
        watchTheme              = watchUD.integer(forKey: "watch_theme")
    }

    private func savePrayerData(_ data: [String: String]) {
        sharedUD.set(data, forKey: "widget_prayerTimings")
        // أيضاً في UserDefaults العادي كـ fallback
        watchUD.set(data, forKey: "widget_prayerTimings")
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func saveAndSync(_ key: String, _ value: Bool) {
        watchUD.set(value, forKey: key)
        if key == "watch_notif_enabled" || key == "watch_prayer_alert" || key == "watch_haptic_enabled" {
            scheduleWatchNotifications()
        }
        if !isApplyingRemoteSettings {
            syncSettingsToPhone()
        }
    }

    // MARK: - Connection Status

    private func updateConnectionStatus() {
        guard WCSession.isSupported() else {
            connectionStatus = "الساعة غير مدعومة"
            return
        }
        let session = WCSession.default
        isPhoneReachable    = session.isReachable
        isWatchPaired       = true   // نحن على الساعة، دائماً true
        isWatchAppInstalled = true   // نحن نشغّل التطبيق على الساعة

        switch session.activationState {
        case .activated:
            connectionStatus = session.isReachable ? "الايفون متصل ✓" : "الايفون غير متصل"
        case .inactive:
            connectionStatus = "جلسة غير نشطة"
        case .notActivated:
            connectionStatus = "لم يتم التفعيل"
        @unknown default:
            connectionStatus = "حالة غير معروفة"
        }
    }

    // MARK: - Request Update

    func requestUpdateFromPhone() {
        guard WCSession.default.activationState == .activated else { return }

        if WCSession.default.isReachable {
            // رسالة مباشرة (أسرع)
            WCSession.default.sendMessage(
                ["action": "requestUpdate"],
                replyHandler: { [weak self] reply in
                    DispatchQueue.main.async { self?.processReceivedData(reply) }
                },
                errorHandler: { [weak self] _ in
                    // fallback: طلب عبر User Info
                    WCSession.default.transferUserInfo(["action": "requestUpdate"])
                    DispatchQueue.main.async { self?.updateConnectionStatus() }
                }
            )
        } else {
            // أرسل طلب في الخلفية
            WCSession.default.transferUserInfo(["action": "requestUpdate"])
        }
    }

    // MARK: - Sync Settings

    func syncSettingsToPhone() {
        guard WCSession.default.activationState == .activated else { return }
        let payload: [String: Any] = [
            "action":               "watchSettings",
            "notifEnabled":         watchNotifEnabled,
            "azkarEnabled":         watchAzkarEnabled,
            "hapticEnabled":        watchHapticEnabled,
            "prayerAlertEnabled":   watchPrayerAlertEnabled,
        ]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: { _ in
                WCSession.default.transferUserInfo(payload)
            })
        } else {
            WCSession.default.transferUserInfo(payload)
        }
    }

    // MARK: - Local Watch Notifications

    /// جدولة إشعارات الصلاة محلياً على الساعة (تشتغل بدون الايفون)
    func scheduleWatchNotifications() {
        guard watchNotifEnabled && watchPrayerAlertEnabled else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            return
        }
        guard !prayerTimes.isEmpty else { return }

        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            guard let self,
                  Self.canScheduleNotifications(settings.authorizationStatus) else { return }
            self.scheduleAuthorizedWatchNotifications(center: center)
        }
    }

    private static func canScheduleNotifications(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func scheduleAuthorizedWatchNotifications(center: UNUserNotificationCenter) {
        // امسح القديم
        let prayerNames = ["الفجر","الظهر","العصر","المغرب","العشاء"]
        center.removePendingNotificationRequests(withIdentifiers:
            prayerNames.flatMap { ["watch_prayer_\($0)", "watch_iqama_\($0)"] }
        )

        let fmt = DateFormatter(); fmt.dateFormat = "HH:mm"
        let cal = Calendar.current
        let prayers = ["الفجر": "moon.fill", "الظهر": "sun.max.fill",
                       "العصر": "sun.haze.fill", "المغرب": "sunset.fill", "العشاء": "moon.stars.fill"]

        for (name, _) in prayers {
            guard let raw   = prayerTimes[name],
                  let time  = fmt.date(from: raw.components(separatedBy: " ").first ?? raw) else { continue }

            var comps = cal.dateComponents([.year, .month, .day], from: Date())
            let tc    = cal.dateComponents([.hour, .minute], from: time)
            comps.hour = tc.hour; comps.minute = tc.minute; comps.second = 0

            guard let fireDate = cal.date(from: comps), fireDate > Date() else { continue }

            let content         = UNMutableNotificationContent()
            content.title       = "🕌 \(name)"
            content.body        = "حان وقت صلاة \(name)"
            content.sound       = watchHapticEnabled ? .default : nil
            content.categoryIdentifier = "PRAYER_REMINDER"
            content.userInfo    = ["prayerName": name]

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: cal.dateComponents([.year,.month,.day,.hour,.minute], from: fireDate),
                repeats: false
            )
            center.add(UNNotificationRequest(
                identifier: "watch_prayer_\(name)",
                content: content, trigger: trigger
            ))

            let iqamaDate = fireDate.addingTimeInterval(15 * 60)
            guard iqamaDate > Date() else { continue }

            let iqamaContent = UNMutableNotificationContent()
            iqamaContent.title       = "🕌 إقامة صلاة \(name)"
            iqamaContent.body        = "مرّت 15 دقيقة على أذان \(name)"
            iqamaContent.sound       = watchHapticEnabled ? .default : nil
            iqamaContent.categoryIdentifier = "PRAYER_REMINDER"
            iqamaContent.userInfo    = ["prayerName": name, "kind": "iqama"]

            let iqamaTrigger = UNCalendarNotificationTrigger(
                dateMatching: cal.dateComponents([.year,.month,.day,.hour,.minute], from: iqamaDate),
                repeats: false
            )
            center.add(UNNotificationRequest(
                identifier: "watch_iqama_\(name)",
                content: iqamaContent, trigger: iqamaTrigger
            ))
        }
    }

    // MARK: - Process Received Data

    private func processReceivedData(_ data: [String: Any]) {
        var didGetPrayerTimes = false
        var didGetSettings = false

        if let prayers = data["prayerTimings"] as? [String: String] {
            prayerTimes = prayers
            savePrayerData(prayers)
            didGetPrayerTimes = true
        }
        if let next  = data["nextPrayer"]  as? String { nextPrayerName = next;  sharedUD.set(next,  forKey: "widget_nextPrayer") }
        if let hijri = data["hijriDate"]   as? String { hijriDate = hijri;       sharedUD.set(hijri, forKey: "widget_hijriDate") }
        if let city  = data["cityName"]    as? String, !city.isEmpty  { cityName = city;    watchUD.set(city, forKey: "watch_city_name") }
        if let lat   = data["latitude"]    as? Double, lat  != 0      { latitude = lat;     sharedUD.set(lat, forKey: "last_prayer_lat") }
        if let lon   = data["longitude"]   as? Double, lon  != 0      { longitude = lon;    sharedUD.set(lon, forKey: "last_prayer_lng") }
        if let verse = data["dailyVerse"]  as? String, !verse.isEmpty { dailyVerse = verse; watchUD.set(verse, forKey: "watch_daily_verse") }
        if let ref   = data["dailyVerseRef"] as? String, !ref.isEmpty { dailyVerseRef = ref; watchUD.set(ref, forKey: "watch_daily_verse_ref") }

        isApplyingRemoteSettings = true
        if let value = data["notifEnabled"] as? Bool {
            watchNotifEnabled = value
            didGetSettings = true
        }
        if let value = data["azkarEnabled"] as? Bool {
            watchAzkarEnabled = value
            didGetSettings = true
        }
        if let value = data["hapticEnabled"] as? Bool {
            watchHapticEnabled = value
            didGetSettings = true
        }
        if let value = data["prayerAlertEnabled"] as? Bool {
            watchPrayerAlertEnabled = value
            didGetSettings = true
        }
        isApplyingRemoteSettings = false

        // بعد استلام الأوقات نجدول الإشعارات محلياً على الساعة
        if didGetPrayerTimes || didGetSettings { scheduleWatchNotifications() }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {

    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.updateConnectionStatus()
            if state == .activated {
                self?.requestUpdateFromPhone()
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.updateConnectionStatus()
            // الايفون صار متاح — اطلب تحديث فوري
            if session.isReachable { self?.requestUpdateFromPhone() }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext ctx: [String: Any]) {
        DispatchQueue.main.async { [weak self] in self?.processReceivedData(ctx) }
    }

    func session(_ session: WCSession, didReceiveMessage msg: [String: Any]) {
        DispatchQueue.main.async { [weak self] in self?.processReceivedData(msg) }
    }

    func session(_ session: WCSession, didReceiveMessage msg: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async { [weak self] in self?.processReceivedData(msg) }
        replyHandler(["status": "received"])
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        DispatchQueue.main.async { [weak self] in self?.processReceivedData(userInfo) }
    }
}
