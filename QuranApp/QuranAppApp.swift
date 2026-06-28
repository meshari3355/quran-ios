import SwiftUI
import UserNotifications
import BackgroundTasks
import WidgetKit
import ActivityKit
import UIKit
import WatchConnectivity

// MARK: - App Delegate (handles APNs token + UNUserNotificationCenterDelegate)

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        NotificationManager.shared.registerNotificationCategories()

        // Request permission then register for remote notifications
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, _ in
            guard granted else {
                APIService.shared.registerDeviceWithoutToken()
                return
            }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
                NotificationManager.shared.onAppLaunch()
            }
        }
        return true
    }

    // ── Apple delivers the push token ──
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        APIService.shared.registerDevice(pushToken: token)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        APIService.shared.registerDeviceWithoutToken()
    }

    // ── Show notification banner even when app is foreground ──
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])

        // When a prayer notification fires while the app is in the foreground,
        // immediately refresh the Live Activity so it transitions to the new prayer.
        let id = notification.request.identifier
        if id.hasPrefix("prayer_") {
            let liveEnabled = UserDefaults.standard.object(forKey: "liveActivityEnabled") as? Bool ?? true
            if liveEnabled, #available(iOS 16.2, *) {
                Task { await PrayerBackgroundRefresh.updateLiveActivityFromStorage() }
            }
        }
    }

    // ── User tapped a notification ──
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Clear badge immediately when user interacts with a notification
        clearBadge()
        completionHandler()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        clearBadge()
    }

    private func clearBadge() {
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }
}

// MARK: - App Entry Point

@main
struct QuranAppApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @AppStorage("colorSchemePreference") private var colorSchemePreference = "light"
    @StateObject private var languageManager = LanguageManager.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // تفعيل التواصل مع Apple Watch
        WatchConnectivityManager.shared.activate()

        NotificationManager.shared.onAppLaunch()

        // Resume any incomplete downloads for users who already completed onboarding
        if UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            QuranOfflineCacheManager.shared.startFullDownloadIfNeeded()
            AudioOfflineCacheManager.shared.startFullDownloadIfNeeded()
        }

        // Default values for first-time users (won't override values already set)
        UserDefaults.standard.register(defaults: [
            "liveActivityEnabled": true   // Dynamic Island / Live Activity ON by default
        ])

        // مراقبة تغيير الوقت (منتصف الليل / DST) — بحث §٦.٤
        NotificationCenter.default.addObserver(
            forName: UIApplication.significantTimeChangeNotification,
            object: nil, queue: .main
        ) { _ in
            Task { @MainActor in
                PrayerTimesAutoSync.shared.syncIfNeeded()
                WidgetCenter.shared.reloadAllTimelines()
                WatchConnectivityManager.shared.sendPrayerTimes()
            }
        }

        // مراقبة تغيير المنطقة الزمنية (عند السفر) — بحث §٣.٢.١
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSSystemTimeZoneDidChange,
            object: nil, queue: .main
        ) { _ in
            Task { @MainActor in
                PrayerTimesAutoSync.shared.syncIfNeeded()
                WidgetCenter.shared.reloadAllTimelines()
                WatchConnectivityManager.shared.sendPrayerTimes()
            }
        }

        // Register 6-hour background refresh (prayer times + Live Activity rebuild)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "tech.meshari.QuranApp.prayerRefresh",
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            PrayerBackgroundRefresh.handle(task: refreshTask)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(preferredScheme)
                .environmentObject(languageManager)
                .environment(\.layoutDirection,
                              languageManager.isEnglish ? .leftToRight : .rightToLeft)
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                // Auto-fetch today's prayer times if not already cached for today.
                // This ensures times are always accurate regardless of which tab the user opens.
                PrayerTimesAutoSync.shared.syncIfNeeded()
                WidgetCenter.shared.reloadAllTimelines()
                // إرسال أحدث بيانات الصلاة للساعة
                WatchConnectivityManager.shared.sendPrayerTimes()
                APIService.shared.trackSessionStart()
                // Clear badge number when user opens the app
                if #available(iOS 16.0, *) {
                    UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
                } else {
                    UIApplication.shared.applicationIconBadgeNumber = 0
                }
                // Also clear delivered notifications from the notification centre
                UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                // Sync Live Activity with current prayer on every foreground — catches
                // any prayer transitions that happened while the app was in the background.
                let liveEnabled = UserDefaults.standard.object(forKey: "liveActivityEnabled") as? Bool ?? true
                if liveEnabled, #available(iOS 16.2, *) {
                    Task { await PrayerBackgroundRefresh.updateLiveActivityFromStorage() }
                }
            case .background:
                PrayerBackgroundRefresh.schedule()
                APIService.shared.trackSessionEnd()
                APIService.shared.resetSessionId()
            default:
                break
            }
        }
    }

    private var preferredScheme: ColorScheme? {
        switch colorSchemePreference {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }
}
