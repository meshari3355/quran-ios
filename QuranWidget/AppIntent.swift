//
//  AppIntent.swift
//  QuranWidget
//
//  Created by MESHARI ABO HLAIBAH on 10/7/47.
//  Copyright © 1447 AH Meshari Tech. All rights reserved.
//

import WidgetKit
import AppIntents

@available(iOS 17.0, *)
struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "This is an example widget." }

    // An example configurable parameter.
    @Parameter(title: "Favorite Emoji", default: "😃")
    var favoriteEmoji: String
}
