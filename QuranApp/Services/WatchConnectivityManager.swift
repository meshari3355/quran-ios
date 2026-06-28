// =============================================================
// WatchConnectivityManager.swift — خدمة التواصل (جانب الايفون)
// إرسال بيانات أوقات الصلاة والأذكار للساعة
// =============================================================

import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject {

    static let shared = WatchConnectivityManager()

    @Published var isWatchReachable = false

    private let appGroupID = "group.tech.meshari.QuranApp"
    private lazy var sharedUD: UserDefaults = {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }()

    override init() {
        super.init()
    }

    // MARK: - Activation

    /// يجب استدعاء هذه الدالة عند تشغيل التطبيق
    /// أضفها في QuranAppApp.swift init()
    func activate() {
        guard WCSession.isSupported() else {
            print("WCSession not supported (no paired watch)")
            return
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Send All Watch Data

    /// إرسال أوقات الصلاة + الموقع + آية اليوم + اسم المدينة للساعة
    /// استدعها بعد كل تحديث لأوقات الصلاة
    @discardableResult
    func sendPrayerTimes() -> Bool {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated else {
            return false
        }

        let context = buildWatchContext()
        var didQueueContext = false

        // إرسال عبر App Context (أفضل طريقة — يوصل حتى لو الساعة مو شغالة)
        do {
            try WCSession.default.updateApplicationContext(context)
            didQueueContext = true
            print("✅ Watch data sent via App Context")
        } catch {
            print("❌ Failed to send to watch: \(error)")
        }

        // إذا الساعة شغالة، أرسل رسالة مباشرة كمان (أسرع)
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(context, replyHandler: nil) { error in
                print("Watch message error: \(error)")
            }
        }

        return didQueueContext
    }

    /// إرسال عبر transferUserInfo (مضمون التوصيل في الخلفية)
    @discardableResult
    func sendPrayerTimesBackground() -> Bool {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated else {
            return false
        }
        WCSession.default.transferUserInfo(buildWatchContext())
        print("✅ Watch data queued for background transfer")
        return true
    }

    /// إرسال إعدادات الساعة فقط عند تغييرها من شاشة الإعدادات.
    @discardableResult
    func sendWatchSettings() -> Bool {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated else {
            return false
        }

        let settings = buildWatchSettingsPayload()
        var didSend = false

        do {
            var context = buildWatchContext()
            settings.forEach { context[$0.key] = $0.value }
            try WCSession.default.updateApplicationContext(context)
            didSend = true
        } catch {
            print("❌ Failed to update watch settings context: \(error)")
        }

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(settings, replyHandler: nil) { error in
                print("Watch settings message error: \(error)")
            }
            didSend = true
        } else {
            WCSession.default.transferUserInfo(settings)
            didSend = true
        }

        return didSend
    }

    // MARK: - Build Context

    private func buildWatchContext() -> [String: Any] {
        let ud = UserDefaults.standard

        // أوقات الصلاة من App Group (المصدر الأساسي للودجات والساعة)
        let prayerTimings = sharedUD.dictionary(forKey: "widget_prayerTimings") as? [String: String]
                         ?? ud.dictionary(forKey: "widget_prayerTimings") as? [String: String]
                         ?? [:]
        let nextPrayer    = sharedUD.string(forKey: "widget_nextPrayer")    ?? ""
        let nextPrayerDate = sharedUD.double(forKey: "widget_nextPrayerDate")
        let hijriDate     = sharedUD.string(forKey: "widget_hijriDate")     ?? ""

        // موقع + مدينة
        var lat = sharedUD.double(forKey: "last_prayer_lat")
        var lng = sharedUD.double(forKey: "last_prayer_lng")
        if lat == 0 { lat = ud.double(forKey: "last_prayer_lat") }
        if lng == 0 { lng = ud.double(forKey: "last_prayer_lng") }
        if lat == 0 { lat = ud.double(forKey: "cachedLocationLat") }
        if lng == 0 { lng = ud.double(forKey: "cachedLocationLon") }
        let cityName = sharedUD.string(forKey: "widget_cityName")
                    ?? ud.string(forKey: "offline_prayer_city")
                    ?? ud.string(forKey: "lastCityName")
                    ?? sharedUD.string(forKey: "lastCityName")
                    ?? ""

        // آية اليوم
        let dailyVerse    = ud.string(forKey: "dailyVerseText") ?? ""
        let dailyVerseRef = ud.string(forKey: "dailyVerseRef")  ?? ""

        // حفظ في App Group كذلك للودجات
        sharedUD.set(prayerTimings,   forKey: "widget_prayerTimings")
        sharedUD.set(nextPrayer,      forKey: "widget_nextPrayer")
        sharedUD.set(nextPrayerDate,  forKey: "widget_nextPrayerDate")
        sharedUD.set(hijriDate,       forKey: "widget_hijriDate")
        sharedUD.set(cityName,        forKey: "lastCityName")
        sharedUD.set(lat,             forKey: "last_prayer_lat")
        sharedUD.set(lng,             forKey: "last_prayer_lng")

        var context: [String: Any] = [
            "prayerTimings":   prayerTimings,
            "nextPrayer":      nextPrayer,
            "nextPrayerDate":  nextPrayerDate,
            "hijriDate":       hijriDate,
            "latitude":        lat,
            "longitude":       lng,
            "cityName":        cityName,
            "dailyVerse":      dailyVerse,
            "dailyVerseRef":   dailyVerseRef,
            "timestamp":       Date().timeIntervalSince1970,
            "appVersion":      Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        ]

        buildWatchSettingsPayload().forEach { context[$0.key] = $0.value }
        return context
    }

    private func buildWatchSettingsPayload() -> [String: Any] {
        let ud = UserDefaults.standard
        return [
            "notifEnabled":       ud.object(forKey: "watch_notif_enabled") as? Bool ?? true,
            "azkarEnabled":       ud.object(forKey: "watch_azkar_enabled") as? Bool ?? true,
            "hapticEnabled":      ud.object(forKey: "watch_haptic_enabled") as? Bool ?? true,
            "prayerAlertEnabled": ud.object(forKey: "watch_prayer_alert") as? Bool ?? true
        ]
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async { [weak self] in
            if activationState == .activated {
                print("iPhone WCSession activated")
                self?.isWatchReachable = session.isReachable
                // إرسال البيانات الحالية للساعة فوراً
                self?.sendPrayerTimes()
            }
        }
    }

    // مطلوب في iOS (ما يحتاجها watchOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        // إعادة تفعيل الجلسة (مهم لدعم تبديل الساعات)
        WCSession.default.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.isWatchReachable = session.isReachable
            if session.isReachable {
                // الساعة صارت متاحة — أرسل آخر البيانات
                self?.sendPrayerTimes()
            }
        }
    }

    // استقبال رسائل من الساعة (لو الساعة تطلب تحديث)
    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        if let action = message["action"] as? String, action == "requestUpdate" {
            sendPrayerTimes()
            // أرجع البيانات مباشرةً في الرد
            var reply = buildWatchContext()
            reply["status"] = "updated"
            replyHandler(reply)
        } else if let action = message["action"] as? String, action == "watchSettings" {
            // حفظ إعدادات الساعة
            if let v = message["notifEnabled"]       as? Bool { UserDefaults.standard.set(v, forKey: "watch_notif_enabled") }
            if let v = message["azkarEnabled"]       as? Bool { UserDefaults.standard.set(v, forKey: "watch_azkar_enabled") }
            if let v = message["hapticEnabled"]      as? Bool { UserDefaults.standard.set(v, forKey: "watch_haptic_enabled") }
            if let v = message["prayerAlertEnabled"] as? Bool { UserDefaults.standard.set(v, forKey: "watch_prayer_alert") }
            replyHandler(["status": "settings_saved"])
        } else {
            replyHandler(["status": "unknown_action"])
        }
    }

    // استقبال User Info من الساعة (إعدادات في الخلفية)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if let action = userInfo["action"] as? String, action == "watchSettings" {
            if let v = userInfo["notifEnabled"]       as? Bool { UserDefaults.standard.set(v, forKey: "watch_notif_enabled") }
            if let v = userInfo["azkarEnabled"]       as? Bool { UserDefaults.standard.set(v, forKey: "watch_azkar_enabled") }
            if let v = userInfo["hapticEnabled"]      as? Bool { UserDefaults.standard.set(v, forKey: "watch_haptic_enabled") }
            if let v = userInfo["prayerAlertEnabled"] as? Bool { UserDefaults.standard.set(v, forKey: "watch_prayer_alert") }
        }
    }
}
