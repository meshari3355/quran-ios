// =============================================================
// QuranWatchApp.swift — Apple Watch App Entry Point
// تطبيق القرآن الكريم للساعة
// =============================================================

import SwiftUI
import WatchKit
import UserNotifications

// MARK: - Notification Controller (واجهة إشعار الصلاة المخصصة)

class PrayerNotificationController: WKUserNotificationHostingController<PrayerNotificationView> {

    var prayerName: String = ""
    var prayerTime: String = ""

    override var body: PrayerNotificationView {
        PrayerNotificationView(prayerName: prayerName, prayerTime: prayerTime)
    }

    override func didReceive(_ notification: UNNotification) {
        let content = notification.request.content

        // استخراج اسم الصلاة من الإشعار
        if let name = content.userInfo["prayerName"] as? String {
            prayerName = name
        } else {
            prayerName = content.title
        }

        if let time = content.userInfo["prayerTime"] as? String {
            prayerTime = time
        } else {
            prayerTime = content.body
        }
    }
}

// MARK: - App Entry Point

@main
struct QuranWatchApp: App {

    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }

        // إشعارات الصلاة المخصصة
        WKNotificationScene(
            controller: PrayerNotificationController.self,
            category: "PRAYER_REMINDER"
        )
    }
}

// MARK: - Watch App Delegate

class WatchAppDelegate: NSObject, WKApplicationDelegate {

    func applicationDidFinishLaunching() {
        WatchConnectivityService.shared.activate()
    }

    func applicationDidBecomeActive() {
        // تحديث عند كل مرة تفتح الساعة
        WatchConnectivityService.shared.requestUpdateFromPhone()
        WatchConnectivityService.shared.scheduleWatchNotifications()
    }
}
