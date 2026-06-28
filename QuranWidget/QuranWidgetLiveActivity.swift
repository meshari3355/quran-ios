import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Activity Attributes (mirror of PrayerLiveActivityAttributes.swift in the app target)
//
// Both targets compile this independently — no sharing / module import needed.

public struct PrayerLiveActivityAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        /// All five prayer times mapped to absolute Dates (device timezone).
        var prayerDates: [String: Date]
        /// Midnight of the NEXT day — staleDate for iOS.
        var expiresAt:   Date
        /// City display name
        var cityName:    String
    }

    public var appName: String
}

// MARK: - next/following computation (runs inside widget at render time)

extension PrayerLiveActivityAttributes.ContentState {

    static let prayerOrder = ["الفجر", "الظهر", "العصر", "المغرب", "العشاء"]

    /// Computes next & following prayer relative to `now` (device clock).
    /// Because this is called during body rendering, the result automatically
    /// advances when a prayer time passes — no BGTask update needed.
    func nextAndFollowing(now: Date = Date())
        -> (next: (name: String, date: Date), following: (name: String, date: Date))
    {
        let sorted: [(name: String, date: Date)] = Self.prayerOrder
            .compactMap { n -> (name: String, date: Date)? in
                guard let d = prayerDates[n] else { return nil }
                return (n, d)
            }
            .sorted { $0.date < $1.date }

        if let idx = sorted.firstIndex(where: { $0.date > now }) {
            let nxt = sorted[idx]
            let fol: (name: String, date: Date) = (idx + 1 < sorted.count)
                ? sorted[idx + 1]
                : (sorted[0].name, sorted[0].date.addingTimeInterval(86_400))
            return (nxt, fol)
        }
        // All prayers passed → Fajr / Dhuhr tomorrow
        let f = sorted.first  ?? (name: "الفجر", date: now.addingTimeInterval(3600))
        let s = sorted.dropFirst().first ?? f
        return ((f.name, f.date.addingTimeInterval(86_400)),
                (s.name, s.date.addingTimeInterval(86_400)))
    }

    /// Progress (0.0 … 1.0) through the current prayer period leading up to `nextDate`.
    func prayerProgress(nextDate: Date, now: Date = Date()) -> Double {
        let sorted: [(name: String, date: Date)] = Self.prayerOrder
            .compactMap { n -> (name: String, date: Date)? in
                guard let d = prayerDates[n] else { return nil }
                return (n, d)
            }
            .sorted { $0.date < $1.date }

        // The previous prayer is the last one that has already passed
        guard let prevDate = sorted.filter({ $0.date <= now }).last?.date else { return 0 }
        let total   = nextDate.timeIntervalSince(prevDate)
        let elapsed = now.timeIntervalSince(prevDate)
        guard total > 0 else { return 0 }
        return min(1.0, max(0, elapsed / total))
    }
}

// MARK: - Colours

private let gold     = Color(red: 0.86, green: 0.71, blue: 0.35)
private let goldSoft = Color(red: 0.95, green: 0.88, blue: 0.65)
private let bgDeep   = Color(red: 0.04, green: 0.06, blue: 0.22)
private let bgDark   = Color(red: 0.01, green: 0.03, blue: 0.12)

// MARK: - Live Activity Widget

@available(iOS 16.2, *)
struct PrayerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrayerLiveActivityAttributes.self) { context in

            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(Color.clear)  // الـ gradient داخل الـ view مباشرة
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in

            // Recomputed at every render from the device clock
            let (nxt, fol) = context.state.nextAndFollowing()

            return DynamicIsland {

                // Expanded – Leading: icon + next prayer name + time
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: prayerIcon(nxt.name))
                            .foregroundColor(gold)
                            .font(.system(size: 14))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(nxt.name)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text(formatTime(nxt.date))
                                .font(.system(size: 10))
                                .foregroundColor(goldSoft.opacity(0.85))
                        }
                    }
                }

                // Expanded – Trailing: live countdown to next prayer
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date()...nxt.date, countsDown: true)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(gold)
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                }

                // Expanded – Bottom: city + following prayer
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 10) {
                        Label(context.state.cityName, systemImage: "location.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(1)

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: prayerIcon(fol.name))
                                .font(.system(size: 10))
                                .foregroundColor(gold.opacity(0.5))
                            Text(fol.name)
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.55))
                            Text(formatTime(fol.date))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(gold.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                }

            } compactLeading: {
                // Compact – Leading: prayer icon + name
                HStack(spacing: 4) {
                    Image(systemName: prayerIcon(nxt.name))
                        .foregroundColor(gold)
                        .font(.system(size: 11))
                    Text(nxt.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

            } compactTrailing: {
                // Compact – Trailing: live countdown
                Text(timerInterval: Date()...nxt.date, countsDown: true)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(gold)
                    .monospacedDigit()
                    .frame(width: 60)

            } minimal: {
                // Minimal (when another app's Live Activity is prominent)
                Text(timerInterval: Date()...nxt.date, countsDown: true)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(gold)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Lock Screen / Banner View

@available(iOS 16.2, *)
private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<PrayerLiveActivityAttributes>

    var body: some View {
        let (nxt, fol) = context.state.nextAndFollowing()
        let progress   = context.state.prayerProgress(nextDate: nxt.date)

        ZStack {
            // Deep navy gradient background
            LinearGradient(colors: [bgDeep, bgDark],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)

            VStack(spacing: 0) {

                // ── Header: city + label ──────────────────────────────
                HStack(spacing: 5) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 9))
                        .foregroundColor(gold.opacity(0.6))
                    Text(context.state.cityName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                    Spacer()
                    Text("مواقيت الصلاة")
                        .font(.system(size: 10))
                        .foregroundColor(gold.opacity(0.45))
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 6)

                // ── Main row: prayer info + countdown ─────────────────
                HStack(alignment: .center, spacing: 12) {

                    // Left: icon + name + time
                    HStack(spacing: 8) {
                        // Prayer icon badge
                        ZStack {
                            Circle()
                                .fill(gold.opacity(0.15))
                                .frame(width: 38, height: 38)
                            Image(systemName: prayerIcon(nxt.name))
                                .font(.system(size: 17))
                                .foregroundColor(gold)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(nxt.name)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(goldSoft)
                            Text(formatTime(nxt.date))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }

                    Spacer()

                    // Right: live countdown
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(timerInterval: Date()...nxt.date, countsDown: true)
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundColor(gold)
                            .monospacedDigit()
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.trailing)
                        Text("متبقي")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(gold.opacity(0.55))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)

                // ── Progress bar ──────────────────────────────────────
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Track
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.white.opacity(0.08))
                            .frame(height: 4)
                        // Fill
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [gold.opacity(0.55), gold],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(progress), height: 4)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 16)
                .padding(.top, 10)

                // ── Following prayer footer ───────────────────────────
                HStack(spacing: 0) {
                    Spacer()
                    HStack(spacing: 5) {
                        Text("التالية:")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.3))
                        Image(systemName: prayerIcon(fol.name))
                            .font(.system(size: 10))
                            .foregroundColor(gold.opacity(0.4))
                        Text(fol.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                        Text(formatTime(fol.date))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(gold.opacity(0.55))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 7)
                .padding(.bottom, 10)
            }
        }
    }
}

// MARK: - Helpers

private func formatTime(_ date: Date) -> String {
    let fmt = DateFormatter()
    fmt.dateFormat = "h:mm"
    let h = Calendar.current.component(.hour, from: date)
    return "\(fmt.string(from: date)) \(h < 12 ? "ص" : "م")"
}

private func prayerIcon(_ name: String) -> String {
    switch name {
    case "الفجر":  return "moon.fill"
    case "الشروق": return "sunrise.fill"
    case "الظهر":  return "sun.max.fill"
    case "العصر":  return "sun.haze.fill"
    case "المغرب": return "sunset.fill"
    case "العشاء": return "moon.stars.fill"
    default:        return "clock.fill"
    }
}
