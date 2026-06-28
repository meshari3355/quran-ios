// =============================================================
// WatchAzkarView.swift — شاشة الأذكار على الساعة
// عرض ذكر يتغير مع أزرار التنقل
// =============================================================

import SwiftUI

struct WatchAzkarView: View {

    private let gold    = WatchContentView.gold
    private let navyBg1 = WatchContentView.navyBg1
    private let navyBg2 = WatchContentView.navyBg2

    @State private var currentIndex = 0

    // أذكار مختصرة للساعة
    private let azkar: [(text: String, category: String)] = [
        ("سُبْحَانَ اللَّهِ وَبِحَمْدِهِ", "تسبيح"),
        ("لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ", "توحيد"),
        ("اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ", "صلاة على النبي"),
        ("أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ وَأَتُوبُ إِلَيْهِ", "استغفار"),
        ("حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ", "توكل"),
        ("لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ", "تحصين"),
        ("سُبْحَانَ اللَّهِ وَبِحَمْدِهِ سُبْحَانَ اللَّهِ الْعَظِيمِ", "تسبيح"),
        ("اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ", "دعاء"),
        ("رَضِيتُ بِاللَّهِ رَبًّا وَبِالإِسْلَامِ دِينًا", "رضا"),
        ("أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ", "حماية"),
    ]

    var body: some View {
        ZStack {
            // خلفية خضراء داكنة
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.15, blue: 0.10),
                    Color(red: 0.01, green: 0.08, blue: 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 6) {

                // ── العنوان ──
                HStack(spacing: 4) {
                    Image(systemName: "hands.sparkles.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(gold)
                    Text("أذكار")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(gold)
                }

                // ── التصنيف ──
                Text(azkar[currentIndex].category)
                    .font(.system(size: 9))
                    .foregroundStyle(gold.opacity(0.6))

                // ── نص الذكر ──
                Text(azkar[currentIndex].text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)

                // ── أزرار التنقل ──
                HStack(spacing: 16) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentIndex = (currentIndex - 1 + azkar.count) % azkar.count
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(gold)
                    }
                    .buttonStyle(.plain)

                    // ── العداد ──
                    Text("\(currentIndex + 1)/\(azkar.count)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentIndex = (currentIndex + 1) % azkar.count
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(gold)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("أذكار")
    }
}
