import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("colorSchemePreference")  private var colorSchemePreference   = "system"
    @AppStorage("themeAccent")           private var themeAccent              = "gold"
    @State private var selectedTab = 0
    @EnvironmentObject private var lang: LanguageManager

    private var preferredScheme: ColorScheme? {
        switch colorSchemePreference {
        case "light":  return .light
        case "dark":   return .dark
        default:       return nil
        }
    }

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView()
            } else {
                mainTabView
                    // Force full re-render when accent OR language changes
                    .id(themeAccent + (lang.isEnglish ? "en" : "ar"))
            }
        }
        .preferredColorScheme(preferredScheme)
        .onOpenURL { routeDeepLink($0) }
    }

    // MARK: - Main Tab View

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {

            // ── Home / الرئيسية ──────────────────────────────
            HomeView()
                .tabItem {
                    Label(lang.t("الرئيسية", "Home"), systemImage: "house.fill")
                }
                .tag(0)

            // ── Quran / القرآن ───────────────────────────────
            SurahListView()
                .tabItem {
                    Label(lang.t("القرآن", "Quran"), systemImage: "book.fill")
                }
                .tag(1)

            // ── Adhkar / الأذكار ──────────────────────────────
            AzkarView()
                .tabItem {
                    Label(lang.t("أذكار وأدعية", "Adhkar & Dua"), systemImage: "heart.fill")
                }
                .tag(2)

            // ── Prayer / الصلاة ──────────────────────────────
            PrayerTimesView()
                .tabItem {
                    Label(lang.t("الصلاة", "Prayer"), systemImage: "clock.fill")
                }
                .tag(3)

            // ── More / المزيد ────────────────────────────────
            NavigationStack {
                MuslimToolsView()
            }
            .tabItem {
                Label(lang.t("المزيد", "More"), systemImage: "square.grid.2x2.fill")
            }
            .tag(4)
        }
        .accentColor(Theme.gold)
    }

    private func routeDeepLink(_ url: URL) {
        guard url.scheme == "quranapp" else { return }

        let route = url.host?.lowercased()
        switch route {
        case "quran":
            selectedTab = 1
        case "azkar":
            selectedTab = 2
        case "prayer":
            selectedTab = 3
        case "more":
            selectedTab = 4
        default:
            selectedTab = 0
        }
    }
}
