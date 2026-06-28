import SwiftUI

// MARK: - ReadingStatsView

struct ReadingStatsView: View {
    @StateObject private var stats = ReadingStatsService.shared
    @State private var selectedRange = 7   // days: 7, 30, 90

    // ── Khatmah goal ─────────────────────────────────────────
    @AppStorage("khatmahActive")          private var khatmahActive      = false
    @AppStorage("khatmahStartTotalPages") private var khatmahStartPages  = 0
    @AppStorage("khatmahStartDate")       private var khatmahStartDate   = Date().timeIntervalSince1970

    private static let khatmahTotal = 604   // صفحات المصحف

    /// Pages read since the current khatmah started
    private var khatmahProgress: Int {
        guard khatmahActive else { return 0 }
        return min(Self.khatmahTotal, max(0, stats.totalPages - khatmahStartPages))
    }
    /// 0.0 – 1.0
    private var khatmahPercent: Double { Double(khatmahProgress) / Double(Self.khatmahTotal) }

    /// Estimated days to complete based on daily average since start
    private var daysToComplete: Int? {
        guard khatmahActive, khatmahProgress > 0 else { return nil }
        let daysSinceStart = max(1, Int(Date().timeIntervalSince1970 - khatmahStartDate) / 86400)
        let pagesPerDay = Double(khatmahProgress) / Double(daysSinceStart)
        guard pagesPerDay > 0 else { return nil }
        let remaining = Self.khatmahTotal - khatmahProgress
        return Int(ceil(Double(remaining) / pagesPerDay))
    }

    private var daysSinceStart: Int {
        max(0, Int(Date().timeIntervalSince1970 - khatmahStartDate) / 86400)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {

                    // ── Streak + summary cards ────────────────────
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(
                            value: "\(stats.todayPages)",
                            label: "اليوم",
                            icon: "book.fill",
                            color: Theme.gold
                        )
                        StatCard(
                            value: "\(stats.streak)",
                            label: "أيام متتالية",
                            icon: "flame.fill",
                            color: .orange
                        )
                        StatCard(
                            value: "\(stats.weeklyPages)",
                            label: "هذا الأسبوع",
                            icon: "calendar.badge.clock",
                            color: .teal
                        )
                        StatCard(
                            value: "\(stats.totalPages)",
                            label: "إجمالي الصفحات",
                            icon: "chart.bar.fill",
                            color: .indigo
                        )
                    }

                    // ── Chart range picker ────────────────────────
                    VStack(spacing: 10) {
                        HStack {
                            Text("نشاط القراءة")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Theme.text)
                            Spacer()
                            Picker("", selection: $selectedRange) {
                                Text("7 أيام").tag(7)
                                Text("30 يوم").tag(30)
                                Text("90 يوم").tag(90)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 180)
                        }

                        // Simple bar chart
                        BarChartView(data: stats.chartData(days: selectedRange))
                    }
                    .padding(16)
                    .background(Theme.card)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))

                    // ── Monthly summary ───────────────────────────
                    VStack(alignment: .trailing, spacing: 12) {
                        Text("ملخص هذا الشهر")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Theme.text)

                        HStack(spacing: 0) {
                            Spacer()
                            VStack(spacing: 4) {
                                Text("\(stats.monthlyPages)")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.gold)
                                Text("صفحة مقروءة").font(.system(size: 12)).foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                            Divider().frame(height: 50).background(Theme.border)
                            Spacer()
                            VStack(spacing: 4) {
                                Text(String(format: "%.1f", Double(stats.monthlyPages) / 30))
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.gold)
                                Text("معدل يومي").font(.system(size: 12)).foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                            Divider().frame(height: 50).background(Theme.border)
                            Spacer()
                            VStack(spacing: 4) {
                                Text("\(stats.streak)")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.orange)
                                Text("يوم سلسلة").font(.system(size: 12)).foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                        }
                    }
                    .padding(16)
                    .background(Theme.card)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))

                    // ── Encouragement message ─────────────────────
                    encouragementCard

                    // ── Khatmah goal ──────────────────────────────
                    khatmahCard

                }
                .padding(16).padding(.bottom, 30)
            }
        }
        .navigationTitle("إحصائيات القراءة")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { stats.refreshStats() }
    }

    // MARK: - Khatmah Card

    private var khatmahCard: some View {
        VStack(alignment: .trailing, spacing: 14) {
            HStack {
                if khatmahActive {
                    Button {
                        khatmahActive      = false
                        khatmahStartPages  = 0
                        khatmahStartDate   = Date().timeIntervalSince1970
                    } label: {
                        Text("ختمة جديدة")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Theme.border.opacity(0.4))
                            .cornerRadius(8)
                    }
                }
                Spacer()
                Text("هدف الختمة")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.text)
            }

            if khatmahActive {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .trailing) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Theme.gold.opacity(0.12))
                            .frame(height: 12)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(khatmahPercent >= 1.0 ? Color.green : Theme.gold)
                            .frame(width: max(12, geo.size.width * khatmahPercent), height: 12)
                    }
                }
                .frame(height: 12)

                // Stats row
                HStack(spacing: 0) {
                    Spacer()
                    VStack(spacing: 3) {
                        Text("\(khatmahProgress)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.gold)
                        Text("من \(ReadingStatsView.khatmahTotal) صفحة")
                            .font(.system(size: 11)).foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    Divider().frame(height: 40).background(Theme.border)
                    Spacer()
                    VStack(spacing: 3) {
                        Text(String(format: "%.0f%%", khatmahPercent * 100))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(khatmahPercent >= 1.0 ? .green : Theme.gold)
                        Text("مكتمل").font(.system(size: 11)).foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    Divider().frame(height: 40).background(Theme.border)
                    Spacer()
                    VStack(spacing: 3) {
                        if let days = daysToComplete, khatmahPercent < 1.0 {
                            Text("\(days)").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(.teal)
                            Text("يوم متوقع").font(.system(size: 11)).foregroundColor(Theme.textSecondary)
                        } else if khatmahPercent >= 1.0 {
                            Text("✅").font(.system(size: 22))
                            Text("اكتملت!").font(.system(size: 11)).foregroundColor(.green)
                        } else {
                            Text("\(daysSinceStart)").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(.orange)
                            Text("يوم منذ البداية").font(.system(size: 11)).foregroundColor(Theme.textSecondary)
                        }
                    }
                    Spacer()
                }

            } else {
                // No active khatmah
                VStack(spacing: 12) {
                    Text("📖")
                        .font(.system(size: 36))
                    Text("لم تبدأ ختمة بعد")
                        .font(.system(size: 14)).foregroundColor(Theme.textSecondary)
                    Button {
                        khatmahStartPages = stats.totalPages
                        khatmahStartDate  = Date().timeIntervalSince1970
                        khatmahActive     = true
                    } label: {
                        Text("بدء ختمة جديدة")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background(Theme.gold)
                            .cornerRadius(10)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .padding(16)
        .background(Theme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    private var encouragementCard: some View {
        let (emoji, message) = encouragementText
        return HStack(spacing: 12) {
            Text(emoji).font(.system(size: 28))
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(14)
        .background(Theme.gold.opacity(0.08))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.gold.opacity(0.2), lineWidth: 1))
    }

    private var encouragementText: (String, String) {
        switch stats.streak {
        case 0:      return ("📖", "ابدأ رحلتك مع القرآن اليوم")
        case 1...3:  return ("✨", "أحسنت! استمر في القراءة يومياً")
        case 4...7:  return ("🔥", "أسبوع متواصل! أنت على الطريق الصحيح")
        case 8...14: return ("⭐", "عشرة أيام سلسلة رائعة! لا تتوقف")
        default:     return ("🏆", "واو! \(stats.streak) يوماً متواصلاً — بارك الله فيك")
        }
    }
}

// MARK: - StatCard

private struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack {
                Spacer()
                ZStack {
                    Circle().fill(color.opacity(0.15)).frame(width: 38, height: 38)
                    Image(systemName: icon).font(.system(size: 16)).foregroundColor(color)
                }
            }
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(14)
        .background(Theme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }
}

// MARK: - BarChartView

private struct BarChartView: View {
    let data: [(label: String, pages: Int)]
    private var maxPages: Int { max(data.map(\.pages).max() ?? 1, 1) }

    var body: some View {
        VStack(spacing: 4) {
            // Bars
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 3) {
                        if item.pages > 0 {
                            Text("\(item.pages)")
                                .font(.system(size: 8))
                                .foregroundColor(Theme.textSecondary)
                        }
                        RoundedRectangle(cornerRadius: 3)
                            .fill(item.pages > 0 ? Theme.gold : Theme.border)
                            .frame(height: max(4, CGFloat(item.pages) / CGFloat(maxPages) * 120))
                    }
                }
            }
            .frame(height: 140, alignment: .bottom)

            // Labels (show every Nth for readability)
            HStack(spacing: 3) {
                ForEach(Array(data.enumerated()), id: \.offset) { idx, item in
                    let step = data.count > 14 ? data.count / 7 : 1
                    Text(idx % step == 0 ? item.label : "")
                        .font(.system(size: 7))
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
