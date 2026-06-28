import Foundation
import SwiftUI

// MARK: - Reading Stats Service

final class ReadingStatsService: ObservableObject {
    static let shared = ReadingStatsService()

    private let statsKey   = "readingStats_pages"    // [dateString: pagesCount]
    private let ud = UserDefaults.standard

    @Published var todayPages:   Int = 0
    @Published var weeklyPages:  Int = 0
    @Published var monthlyPages: Int = 0
    @Published var totalPages:   Int = 0
    @Published var streak:       Int = 0            // consecutive reading days

    private var stats: [String: Int] {
        get { ud.dictionary(forKey: statsKey) as? [String: Int] ?? [:] }
        set { ud.set(newValue, forKey: statsKey) }
    }

    private init() { refreshStats() }

    // MARK: - Record

    /// Call every time the user views / flips a page
    func recordPageRead() {
        let key = todayKey()
        var s = stats
        s[key] = (s[key] ?? 0) + 1
        stats = s
        refreshStats()
        NotificationManager.shared.recordQuranRead()
    }

    // MARK: - Refresh aggregates

    func refreshStats() {
        let calendar = Calendar.current
        let now  = Date()
        let s    = stats

        todayPages   = s[todayKey()] ?? 0

        let weekStart  = calendar.date(byAdding: .day, value: -6,  to: startOfDay(now)) ?? .distantPast
        let monthStart = calendar.date(byAdding: .day, value: -29, to: startOfDay(now)) ?? .distantPast

        weeklyPages  = s.filter { (dateFrom($0.key) ?? .distantPast) >= weekStart  }.values.reduce(0, +)
        monthlyPages = s.filter { (dateFrom($0.key) ?? .distantPast) >= monthStart }.values.reduce(0, +)
        totalPages   = s.values.reduce(0, +)
        streak       = computeStreak(s: s)
    }

    // MARK: - Chart data (last N days)

    func chartData(days: Int) -> [(label: String, pages: Int)] {
        let calendar  = Calendar.current
        let now       = Date()
        let labelFmt  = DateFormatter(); labelFmt.dateFormat = "d/M"
        let s         = stats
        return (0..<days).reversed().compactMap { offset -> (String, Int)? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now) else { return nil }
            let key = dateKey(date)
            return (labelFmt.string(from: date), s[key] ?? 0)
        }
    }

    // MARK: - Pages in last N days

    func pagesInDays(_ days: Int) -> Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -(days - 1), to: startOfDay(Date())) ?? .distantPast
        return stats.filter { (dateFrom($0.key) ?? .distantPast) >= cutoff }.values.reduce(0, +)
    }

    // MARK: - Helpers

    private func computeStreak(s: [String: Int]) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var day = Date()
        while true {
            let key = dateKey(day)
            if (s[key] ?? 0) > 0 {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
                day = prev
            } else {
                break
            }
        }
        return streak
    }

    private func todayKey() -> String { dateKey(Date()) }

    private func dateKey(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func dateFrom(_ key: String) -> Date? {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.date(from: key)
    }

    private func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
}
