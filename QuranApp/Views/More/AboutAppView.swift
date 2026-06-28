import SwiftUI
import UIKit

// MARK: - AboutAppView

enum AppBuildInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }
}

enum AppMetadata {
    static let appStoreID = "6761058636"
    static let appStoreURLString = "https://apps.apple.com/app/id\(appStoreID)"
    static let appStoreURL = URL(string: appStoreURLString)!
    static let appStoreReviewURL = URL(string: "itms-apps://itunes.apple.com/app/id\(appStoreID)?action=write-review")!
    static let developerName = "Meshari Tech"
    static let developerPhoneDisplay = "+966 55 587 7723"
    static let developerPhoneDial = "+966555877723"
    static var developerPhoneURL: URL? { URL(string: "tel:\(developerPhoneDial)") }

    static var copyrightText: String {
        "© \(Calendar.current.component(.year, from: Date())) \(developerName)"
    }
}

struct AboutAppView: View {
    @EnvironmentObject private var lang: LanguageManager
    @State private var showShareSheet = false

    private let appVersion = AppBuildInfo.version

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // ── App Icon + Name ─────────────────────────────────
                    appHeaderSection

                    // ── Features ────────────────────────────────────────
                    featuresSection

                    // ── Links ────────────────────────────────────────────
                    linksSection

                    // ── Copyright ────────────────────────────────────────
                    copyrightSection

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(lang.t("عن التطبيق", "About"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            let message = lang.t(
                "تطبيق القرآن الكريم وأوقات الصلاة - تلاوة، تفسير، أذكار، وودجت للصلاة والساعة.",
                "Quran App and Prayer Times - recitation, tafsir, adhkar, prayer widgets, and Apple Watch support."
            )
            ShareSheet(activityItems: [message, AppMetadata.appStoreURL])
        }
    }

    // MARK: - Sections

    private var appHeaderSection: some View {
        VStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(colors: [
                            Color(red: 0.08, green: 0.06, blue: 0.18),
                            Color(red: 0.04, green: 0.04, blue: 0.11)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: Theme.gold.opacity(0.3), radius: 16, y: 4)

                if let uiImage = UIImage(named: "AppIcon") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 92, height: 92)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                } else {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(
                            LinearGradient(colors: [Theme.goldLight, Theme.gold],
                                           startPoint: .top, endPoint: .bottom)
                        )
                }
            }

            VStack(spacing: 4) {
                Text(lang.t("تطبيق القرآن الكريم", "Quran App"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Theme.goldLight)

                Text(lang.t("الإصدار \(appVersion)", "Version \(appVersion)"))
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)

                Text(lang.t("بسم الله الرحمن الرحيم", "In the Name of Allah"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.gold.opacity(0.85))
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Theme.card)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    private var featuresSection: some View {
        VStack(spacing: 0) {
            sectionHeader(title: lang.t("مميزات التطبيق", "App Features"),
                          icon: "star.fill", color: Theme.gold)

            let features: [(String, String, Color)] = [
                ("book.fill",                 lang.t("القرآن الكريم كاملاً", "Complete Quran"),                         Theme.gold),
                ("waveform",                  lang.t("تلاوات متعددة لكبار القراء", "Multiple Reciters"),                 .cyan),
                ("text.book.closed.fill",     lang.t("تفسير ابن كثير والجلالين", "Tafsir Books"),                       .brown),
                ("moon.stars.fill",           lang.t("أذكار الصباح والمساء", "Morning & Evening Adhkar"),                .orange),
                ("clock.fill",                lang.t("أوقات الصلاة الدقيقة", "Accurate Prayer Times"),                  .blue),
                ("location.north.line.fill",  lang.t("اتجاه القبلة بالبوصلة", "Qibla Direction"),                       .teal),
                ("applewatch",                lang.t("دعم Apple Watch وودجت أوقات الصلاة", "Apple Watch and Prayer Widgets"), .indigo),
                ("bell.fill",                 lang.t("إشعارات الصلاة وتذكيرات القراءة", "Prayer and Reading Reminders"), .orange),
                ("wifi.slash",                lang.t("يعمل بدون إنترنت للقراءة والبيانات المحفوظة", "Offline reading and cached data"), .green),
            ]

            ForEach(Array(features.enumerated()), id: \.offset) { idx, feat in
                let (icon, title, color) = feat
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(color.opacity(0.15))
                            .frame(width: 34, height: 34)
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .foregroundColor(color)
                    }
                    Text(title)
                        .font(.system(size: 15))
                        .foregroundColor(Theme.text)
                    Spacer()
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)

                if idx < features.count - 1 {
                    Divider().background(Theme.border).padding(.leading, 62)
                }
            }
        }
        .background(Theme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    private var linksSection: some View {
        VStack(spacing: 10) {
            // Share app
            Button {
                showShareSheet = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                    }
                    Text(lang.t("شارك التطبيق مع أصدقائك", "Share App with Friends"))
                        .font(.system(size: 15))
                        .foregroundColor(Theme.text)
                    Spacer()
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(14)
                .background(Theme.card)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Rate app
            Link(destination: AppMetadata.appStoreReviewURL) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.yellow.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                    }
                    Text(lang.t("قيّم التطبيق على App Store", "Rate on App Store"))
                        .font(.system(size: 15))
                        .foregroundColor(Theme.text)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(14)
                .background(Theme.card)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Link(destination: AppMetadata.appStoreURL) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.gold.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(Theme.gold)
                    }
                    Text(lang.t("صفحة التطبيق في App Store", "App Store Page"))
                        .font(.system(size: 15))
                        .foregroundColor(Theme.text)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(14)
                .background(Theme.card)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var copyrightSection: some View {
        VStack(spacing: 6) {
            Text(AppMetadata.copyrightText)
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)

            Text(lang.t(
                "جميع البيانات الإسلامية من مصادر موثوقة ومفتوحة المصدر",
                "All Islamic data from trusted open sources"
            ))
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 14))
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.background.opacity(0.5))
    }
}
