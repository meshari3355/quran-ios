import SwiftUI

// MARK: - Theme struct  (static base colors)

struct Theme {

    // MARK: - Background / Surface

    static let background = Color(UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1)   // neutral dark — not blue
            : UIColor(red: 0.97, green: 0.94, blue: 0.87, alpha: 1)
    }))

    static let card = Color(UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.14, green: 0.14, blue: 0.14, alpha: 1)   // neutral dark card
            : UIColor(red: 1.00, green: 0.98, blue: 0.94, alpha: 1)
    }))

    // MARK: - Text

    static let text = Color(UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.95, green: 0.93, blue: 0.88, alpha: 1)
            : UIColor(red: 0.12, green: 0.09, blue: 0.05, alpha: 1)
    }))

    static let textSecondary = Color(UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.65, green: 0.63, blue: 0.58, alpha: 1)
            : UIColor(red: 0.45, green: 0.38, blue: 0.27, alpha: 1)
    }))

    // MARK: - Base gold tones (used when accent == "gold")

    static let goldBase = Color(UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.85, green: 0.70, blue: 0.35, alpha: 1)
            : UIColor(red: 0.72, green: 0.52, blue: 0.10, alpha: 1)
    }))

    static let goldLightBase = Color(UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.95, green: 0.85, blue: 0.55, alpha: 1)
            : UIColor(red: 0.50, green: 0.35, blue: 0.05, alpha: 1)
    }))
}

// MARK: - Dynamic accent-aware computed colors
// gold / goldLight / border are computed vars so they change when themeAccent changes.
// ContentView uses .id(themeAccent) to force a full re-render when accent is updated.

extension Theme {

    /// Primary accent color — driven by the user's accent preference.
    static var gold: Color {
        switch UserDefaults.standard.string(forKey: "themeAccent") ?? "gold" {
        case "teal":    return Color.teal
        case "indigo":  return Color.indigo
        case "emerald": return Color.green
        case "rose":    return Color.pink
        case "purple":  return Color.purple
        default:        return goldBase
        }
    }

    /// Lighter / title variant of the accent color.
    static var goldLight: Color {
        switch UserDefaults.standard.string(forKey: "themeAccent") ?? "gold" {
        case "teal":    return Color.teal
        case "indigo":  return Color.indigo
        case "emerald": return Color.green
        case "rose":    return Color.pink
        case "purple":  return Color.purple
        default:        return goldLightBase
        }
    }

    /// Subtle border derived from the current accent.
    static var border: Color { gold.opacity(0.25) }

    /// Alias kept for legacy call-sites.
    static var accentColor: Color { gold }
}
