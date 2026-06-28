// =============================================================
// WatchDuaView.swift — شاشة الأدعية على الساعة
// عرض دعاء اليوم مع إمكانية التصفح
// =============================================================

import SwiftUI

struct WatchDuaView: View {

    private let gold    = WatchContentView.gold
    private let navyBg1 = WatchContentView.navyBg1
    private let navyBg2 = WatchContentView.navyBg2

    @State private var currentIndex: Int = {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return (dayOfYear - 1) % watchDuaItems.count
    }()

    var body: some View {
        ZStack {
            // خلفية بنفسجية داكنة
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.04, blue: 0.18),
                    Color(red: 0.04, green: 0.02, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 6) {

                // ── العنوان ──
                HStack(spacing: 4) {
                    Image(systemName: "hands.and.sparkles.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(gold)
                    Text("أدعية")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(gold)
                }

                // ── مناسبة الدعاء ──
                Text(watchDuaItems[currentIndex].occasion)
                    .font(.system(size: 9))
                    .foregroundStyle(gold.opacity(0.6))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(gold.opacity(0.08))
                    .clipShape(Capsule())

                // ── نص الدعاء ──
                Text(watchDuaItems[currentIndex].text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(5)
                    .minimumScaleFactor(0.65)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(gold.opacity(0.15), lineWidth: 0.5)
                    )

                // ── أزرار التنقل ──
                HStack(spacing: 16) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            currentIndex = (currentIndex - 1 + watchDuaItems.count) % watchDuaItems.count
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(gold)
                    }
                    .buttonStyle(.plain)

                    Text("\(currentIndex + 1)/\(watchDuaItems.count)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))

                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            currentIndex = (currentIndex + 1) % watchDuaItems.count
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(gold)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("أدعية")
    }
}

// MARK: - Preview

#Preview {
    WatchDuaView()
}
