// =============================================================
// WatchPrayerTimesView.swift — شاشة أوقات الصلاة على الساعة
// عرض أوقات الصلاة مع العداد التنازلي للصلاة القادمة
// =============================================================

import SwiftUI

struct WatchPrayerTimesView: View {

    @EnvironmentObject var connectivity: WatchConnectivityService

    private let gold     = WatchContentView.gold
    private let goldSoft = WatchContentView.goldSoft
    private let navyBg1  = WatchContentView.navyBg1
    private let navyBg2  = WatchContentView.navyBg2

    // أوقات الصلاة بالترتيب
    private let prayerOrder = ["الفجر", "الشروق", "الظهر", "العصر", "المغرب", "العشاء"]
    private let prayerIcons: [String: String] = [
        "الفجر": "moon.fill",
        "الشروق": "sunrise.fill",
        "الظهر": "sun.max.fill",
        "العصر": "sun.haze.fill",
        "المغرب": "sunset.fill",
        "العشاء": "moon.stars.fill"
    ]

    var body: some View {
        ZStack {
            // خلفية متدرجة
            LinearGradient(
                colors: [navyBg1, navyBg2],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 4) {
                // ── العنوان ──
                HStack(spacing: 4) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(gold)
                    Text("أوقات الصلاة")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(gold)
                }
                .padding(.top, 2)

                // ── الخط الفاصل ──
                Rectangle()
                    .fill(LinearGradient(
                        colors: [gold.opacity(0), gold.opacity(0.5), gold.opacity(0)],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(height: 0.5)
                    .padding(.horizontal, 8)

                // ── العداد التنازلي للصلاة القادمة ──
                if let nextPrayer = findNextPrayer() {
                    VStack(spacing: 2) {
                        Text(nextPrayer.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)

                        if let targetDate = nextPrayer.date {
                            Text(targetDate, style: .timer)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(gold)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(gold.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(gold.opacity(0.3), lineWidth: 0.5)
                    )
                }

                // ── قائمة الأوقات ──
                VStack(spacing: 2) {
                    ForEach(prayerOrder, id: \.self) { name in
                        if let time = connectivity.prayerTimes[name] {
                            let isNext = name == findNextPrayer()?.name

                            HStack(spacing: 4) {
                                Text(formattedTime(time))
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(isNext ? gold : .white.opacity(0.7))

                                Spacer()

                                Text(name)
                                    .font(.system(size: 11, weight: isNext ? .bold : .regular))
                                    .foregroundStyle(isNext ? .white : .white.opacity(0.7))

                                Image(systemName: prayerIcons[name] ?? "clock")
                                    .font(.system(size: 9))
                                    .foregroundStyle(isNext ? gold : gold.opacity(0.5))
                                    .frame(width: 16)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(isNext ? gold.opacity(0.12) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("الصلاة")
    }

    // MARK: - Helpers

    private struct NextPrayerInfo {
        let name: String
        let date: Date?
    }

    private func findNextPrayer() -> NextPrayerInfo? {
        let now = Date()
        let cal = Calendar.current

        for name in prayerOrder {
            guard let rawTime = connectivity.prayerTimes[name],
                  let date = absoluteDate(from: rawTime) else { continue }
            if date > now {
                return NextPrayerInfo(name: name, date: date)
            }
        }

        // كل الأوقات مرت — الفجر بكرة
        if let fajrTime = connectivity.prayerTimes["الفجر"],
           let fajrDate = absoluteDate(from: fajrTime) {
            let tomorrow = cal.date(byAdding: .day, value: 1, to: fajrDate)
            return NextPrayerInfo(name: "الفجر", date: tomorrow)
        }

        return nil
    }

    private func absoluteDate(from raw: String) -> Date? {
        let clean = raw.components(separatedBy: " ").first ?? raw
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        guard let t = f.date(from: clean) else { return nil }
        let cal = Calendar.current
        var c = cal.dateComponents([.hour, .minute], from: t)
        let now = Date()
        c.year  = cal.component(.year, from: now)
        c.month = cal.component(.month, from: now)
        c.day   = cal.component(.day, from: now)
        return cal.date(from: c)
    }

    private func formattedTime(_ raw: String) -> String {
        let clean = raw.components(separatedBy: " ").first ?? raw
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        guard let d = f.date(from: clean) else { return clean }
        let h = Calendar.current.component(.hour, from: d)
        f.dateFormat = "h:mm"
        return "\(f.string(from: d)) \(h < 12 ? "ص" : "م")"
    }
}
