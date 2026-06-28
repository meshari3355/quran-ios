// =============================================================
// QuranWatchWidgetBundle.swift — حزمة ويدجت واجهة الساعة
// Complications لواجهة Apple Watch
// =============================================================

import WidgetKit
import SwiftUI

// MARK: - Shared UserDefaults (نفس App Group الموجود)

let watchAppGroupID     = "group.tech.meshari.QuranApp"
let watchSharedDefaults = UserDefaults(suiteName: watchAppGroupID) ?? .standard

@main
struct QuranWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        PrayerTimesComplication()
        PrayerComplication()
        AzkarComplication()
    }
}
