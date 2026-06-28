// =============================================================
// QuranWidgetBundle.swift
// WIDGET EXTENSION TARGET — أضف هذا الملف إلى target "QuranWidget"
//
// خطوات الإضافة في Xcode:
// 1. File ▸ New ▸ Target ▸ Widget Extension
// 2. اسم الـ Target: QuranWidget
// 3. أضف App Group في Capabilities لكلا الـ Target:
//    group.tech.meshari.QuranApp
// 4. استخدم نفس المجموعة في SharedDefaults أدناه
// =============================================================

import WidgetKit
import SwiftUI

// MARK: - Shared UserDefaults (App Group)

let appGroupID = "group.tech.meshari.QuranApp"
let sharedDefaults = UserDefaults(suiteName: appGroupID) ?? .standard

@main
struct QuranWidgetBundle: WidgetBundle {
    var body: some Widget {
        PrayerTimesWidget()
        NextPrayerWidget()
        AzkarWidget()
        DailyVerseWidget()
    }
}
