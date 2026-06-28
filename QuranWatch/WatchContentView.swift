// =============================================================
// WatchContentView.swift — الشاشة الرئيسية للساعة
// تنقل عمودي (watchOS 10+) بين الشاشات
// =============================================================

import SwiftUI

struct WatchContentView: View {

    @StateObject private var connectivityService = WatchConnectivityService.shared
    @State private var selectedTab = 0

    // ── Design Tokens (نفس ألوان تطبيق الايفون) ──
    static let gold     = Color(red: 0.86, green: 0.71, blue: 0.35)
    static let goldSoft = Color(red: 0.95, green: 0.88, blue: 0.65)
    static let navyBg1  = Color(red: 0.04, green: 0.14, blue: 0.28)
    static let navyBg2  = Color(red: 0.01, green: 0.06, blue: 0.14)

    var body: some View {
        TabView(selection: $selectedTab) {

            // ── 0: واجهة الساعة الإبداعية ──
            WatchFaceView()
                .tag(0)

            // ── 1: أوقات الصلاة ──
            WatchPrayerTimesView()
                .tag(1)

            // ── 2: القبلة ──
            WatchQiblaEntryView()
                .tag(2)

            // ── 3: الأذكار ──
            WatchAzkarView()
                .tag(3)

            // ── 4: الأدعية ──
            WatchDuaView()
                .tag(4)

            // ── 5: آية اليوم ──
            WatchVerseView()
                .tag(5)

            // ── 6: التسبيح ──
            WatchTasbihView()
                .tag(6)

            // ── 7: الإعدادات ──
            WatchSettingsView()
                .tag(7)
        }
        .tabViewStyle(.verticalPage)
        .environmentObject(connectivityService)
    }
}

// MARK: - Preview

#Preview {
    WatchContentView()
}
