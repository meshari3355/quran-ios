import ActivityKit
import Foundation

// MARK: - Shared Live Activity Attributes
//
// ContentState stores ALL prayer times for the day as absolute Dates.
// The widget view computes nextPrayer / followingPrayer from Date() at
// render time, so the Dynamic Island auto-advances when a prayer passes
// WITHOUT needing any BGTask update between prayers.
//
// Only a once-per-day BGTask is needed to refresh times for the next
// calendar day. The middle-of-day per-prayer updates are eliminated.

public struct PrayerLiveActivityAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        /// All five prayer times for today mapped to absolute Dates.
        /// Keys: "الفجر", "الظهر", "العصر", "المغرب", "العشاء"
        var prayerDates: [String: Date]

        /// Midnight of the NEXT day — staleDate so iOS knows the activity
        /// data is no longer fresh when a new day begins.
        var expiresAt: Date

        /// Display name of the city (e.g. "الرياض")
        var cityName: String
    }

    public var appName: String
}

// MARK: - Canonical prayer order + next/following helper

extension PrayerLiveActivityAttributes.ContentState {

    static let prayerOrder = ["الفجر", "الظهر", "العصر", "المغرب", "العشاء"]

    /// Returns (nextPrayer, followingPrayer) computed relative to `now`.
    /// Falls back to Fajr+24h when all five prayers have passed.
    func nextAndFollowing(now: Date = Date())
        -> (next: (name: String, date: Date), following: (name: String, date: Date))
    {
        let sorted: [(name: String, date: Date)] = Self.prayerOrder
            .compactMap { name -> (name: String, date: Date)? in
                guard let d = prayerDates[name] else { return nil }
                return (name, d)
            }
            .sorted { $0.date < $1.date }

        if let nextIdx = sorted.firstIndex(where: { $0.date > now }) {
            let next = sorted[nextIdx]
            let following: (name: String, date: Date)
            if nextIdx + 1 < sorted.count {
                following = sorted[nextIdx + 1]
            } else {
                // After Isha → Fajr tomorrow
                let first = sorted[0]
                following = (first.name, first.date.addingTimeInterval(86_400))
            }
            return (next, following)
        }

        // All prayers passed for today → Fajr + Dhuhr tomorrow
        let first  = sorted.first  ?? (name: "الفجر",  date: now.addingTimeInterval(3600))
        let second = sorted.dropFirst().first ?? first
        return (
            (first.name,  first.date.addingTimeInterval(86_400)),
            (second.name, second.date.addingTimeInterval(86_400))
        )
    }
}
