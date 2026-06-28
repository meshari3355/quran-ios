import SwiftUI
import Combine

// MARK: - LanguageManager
// Central language controller — change once, entire app re-renders instantly.

final class LanguageManager: ObservableObject {

    static let shared = LanguageManager()

    @Published var isEnglish: Bool {
        didSet {
            let lang = isEnglish ? "en" : "ar"
            UserDefaults.standard.set(lang, forKey: "appLanguage")
            UserDefaults.standard.synchronize()
        }
    }

    private init() {
        let stored = UserDefaults.standard.string(forKey: "appLanguage") ?? "ar"
        self.isEnglish = (stored == "en")
    }

    // ── Convenience helper — use t("Arabic", "English") in any view ──────────
    func t(_ arabic: String, _ english: String) -> String {
        isEnglish ? english : arabic
    }
}

// MARK: - Environment Key

private struct LanguageManagerKey: EnvironmentKey {
    static let defaultValue = LanguageManager.shared
}

extension EnvironmentValues {
    var languageManager: LanguageManager {
        get { self[LanguageManagerKey.self] }
        set { self[LanguageManagerKey.self] = newValue }
    }
}
