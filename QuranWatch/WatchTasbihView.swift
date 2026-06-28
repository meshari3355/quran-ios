// =============================================================
// WatchTasbihView.swift — عداد التسبيح على الساعة
// عداد بسيط مع اهتزاز عند كل ضغطة
// =============================================================

import SwiftUI
import WatchKit

struct WatchTasbihView: View {

    private let gold    = WatchContentView.gold
    private let navyBg1 = WatchContentView.navyBg1
    private let navyBg2 = WatchContentView.navyBg2

    @State private var count = 0
    @State private var selectedZikr = 0

    private let tasbihOptions = [
        "سُبْحَانَ اللَّهِ",
        "الْحَمْدُ لِلَّهِ",
        "اللَّهُ أَكْبَرُ",
        "لَا إِلَهَ إِلَّا اللَّهُ",
        "أَسْتَغْفِرُ اللَّهَ"
    ]

    var body: some View {
        ZStack {
            // خلفية
            LinearGradient(
                colors: [navyBg1, navyBg2],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 8) {

                // ── نص التسبيح ──
                Text(tasbihOptions[selectedZikr])
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .onTapGesture {
                        selectedZikr = (selectedZikr + 1) % tasbihOptions.count
                    }

                // ── العداد الكبير ──
                Button {
                    count += 1
                    // اهتزاز خفيف
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    ZStack {
                        Circle()
                            .fill(gold.opacity(0.15))
                            .overlay(
                                Circle()
                                    .stroke(gold.opacity(0.5), lineWidth: 2)
                            )
                            .frame(width: 90, height: 90)

                        VStack(spacing: 2) {
                            Text("\(count)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(gold)

                            // إشارة للهدف
                            if count > 0 && count % 33 == 0 {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)

                // ── زر إعادة الضبط ──
                Button {
                    count = 0
                    WKInterfaceDevice.current().play(.stop)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10))
                        Text("إعادة")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(gold.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("تسبيح")
    }
}
