// =============================================================
// WatchNotificationView.swift — واجهة إشعار الصلاة المخصصة
// تظهر عند وصول إشعار الصلاة على الساعة (Long Look)
// =============================================================

import SwiftUI

struct PrayerNotificationView: View {

    let prayerName: String
    let prayerTime: String

    private let gold    = WatchContentView.gold
    private let navyBg1 = WatchContentView.navyBg1
    private let navyBg2 = WatchContentView.navyBg2

    private let prayerIcons: [String: String] = [
        "الفجر": "moon.fill",
        "الشروق": "sunrise.fill",
        "الظهر": "sun.max.fill",
        "العصر": "sun.haze.fill",
        "المغرب": "sunset.fill",
        "العشاء": "moon.stars.fill"
    ]

    var body: some View {
        VStack(spacing: 10) {

            // ── أيقونة الصلاة ──
            ZStack {
                Circle()
                    .fill(gold.opacity(0.18))
                    .frame(width: 50, height: 50)

                Image(systemName: prayerIcons[prayerName] ?? "clock.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(gold)
            }

            // ── اسم الصلاة ──
            Text("حان وقت صلاة")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.7))

            Text(prayerName)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)

            // ── الوقت ──
            if !prayerTime.isEmpty {
                Text(prayerTime)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(gold)
            }

            // ── ديكور ──
            Rectangle()
                .fill(LinearGradient(
                    colors: [gold.opacity(0), gold.opacity(0.4), gold.opacity(0)],
                    startPoint: .leading, endPoint: .trailing
                ))
                .frame(height: 0.5)
                .padding(.horizontal, 20)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    PrayerNotificationView(prayerName: "المغرب", prayerTime: "6:20 م")
}
