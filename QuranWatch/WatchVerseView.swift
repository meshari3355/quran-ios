// =============================================================
// WatchVerseView.swift — آية اليوم على الساعة
// تعرض الآية المرسلة من الايفون أو من القائمة المحلية
// =============================================================

import SwiftUI

struct WatchVerseView: View {

    @EnvironmentObject var connectivity: WatchConnectivityService

    private let gold     = WatchContentView.gold
    private let goldSoft = WatchContentView.goldSoft
    private let navyBg1  = WatchContentView.navyBg1
    private let navyBg2  = WatchContentView.navyBg2

    // إذا لم تصل بيانات من الايفون نستخدم القائمة المحلية
    private var displayVerse: String {
        connectivity.dailyVerse.isEmpty
            ? currentWatchVerse().text
            : connectivity.dailyVerse
    }

    private var displayRef: String {
        connectivity.dailyVerseRef.isEmpty
            ? currentWatchVerse().ref
            : connectivity.dailyVerseRef
    }

    var body: some View {
        ZStack {
            // خلفية متدرجة نيلية
            LinearGradient(
                colors: [navyBg1, navyBg2],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // زخرفة خلفية خفيفة
            Image(systemName: "book.closed.fill")
                .font(.system(size: 60))
                .foregroundStyle(gold.opacity(0.04))
                .offset(x: 30, y: -20)

            VStack(spacing: 6) {

                // ── بسملة صغيرة ──
                Text("بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ")
                    .font(.system(size: 9))
                    .foregroundStyle(gold.opacity(0.5))

                // ── العنوان ──
                HStack(spacing: 4) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(gold)
                    Text("آية اليوم")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(gold)
                }

                // ── الخط الفاصل ──
                Rectangle()
                    .fill(LinearGradient(
                        colors: [gold.opacity(0), gold.opacity(0.4), gold.opacity(0)],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(height: 0.5)
                    .padding(.horizontal, 12)

                // ── نص الآية ──
                Text(displayVerse)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .lineLimit(4)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(gold.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(gold.opacity(0.2), lineWidth: 0.5)
                    )

                // ── المصدر ──
                HStack(spacing: 4) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(gold.opacity(0.7))
                    Text(displayRef)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(gold.opacity(0.8))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(gold.opacity(0.10))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("آية")
    }
}

// MARK: - Preview

#Preview {
    WatchVerseView()
        .environmentObject(WatchConnectivityService.shared)
}
