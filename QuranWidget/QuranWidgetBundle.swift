// =============================================================
// QuranWidgetBundle.swift — QuranWidget Extension Target
// =============================================================

import WidgetKit
import SwiftUI

// MARK: - Shared UserDefaults (App Group)

let appGroupID    = "group.tech.meshari.QuranApp"
let sharedDefaults = UserDefaults(suiteName: appGroupID) ?? .standard

@main
struct QuranWidgetBundle: WidgetBundle {
    var body: some Widget {
        PrayerTimesWidget()
        NextPrayerWidget()
        AzkarWidget()
        DuaWidget()
        DailyVerseWidget()
        if #available(iOS 16.2, *) {
            PrayerLiveActivity()
        }
    }
}

extension View {
    @ViewBuilder
    func compatibleWidgetBackground<Background: View>(
        @ViewBuilder _ background: () -> Background
    ) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget, content: background)
        } else {
            self.background(background())
        }
    }
}
