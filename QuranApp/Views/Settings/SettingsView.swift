import SwiftUI
import CoreLocation
import UserNotifications
import ActivityKit

// MARK: - SettingsView

struct SettingsView: View {

    // ── Appearance
    @AppStorage("colorSchemePreference") private var colorSchemePreference = "light"
    @AppStorage("themeAccent")          private var themeAccent            = "gold"

    // ── Notifications
    @AppStorage("azkarNotifsEnabled")   private var azkarNotifsEnabled   = true
    @AppStorage("quranReminderEnabled") private var quranReminderEnabled  = true
    @AppStorage("prayerWarningMinutes") private var prayerWarningMinutes  = 5
    @AppStorage("fridayKahfEnabled")    private var fridayKahfEnabled     = true
    @AppStorage("islamicEventsEnabled") private var islamicEventsEnabled  = true

    // ── Live Activity (Dynamic Island)
    @AppStorage("liveActivityEnabled")  private var liveActivityEnabled   = true

    // ── Apple Watch Settings (مزامنة مع الساعة)
    @AppStorage("watch_notif_enabled")   private var watchNotifEnabled      = true
    @AppStorage("watch_azkar_enabled")   private var watchAzkarEnabled      = true
    @AppStorage("watch_haptic_enabled")  private var watchHapticEnabled     = true
    @AppStorage("watch_prayer_alert")    private var watchPrayerAlert       = true
    @State private var isWatchReachable  = false
    @State private var watchSyncState: WatchSyncState = .idle

    private enum WatchSyncState {
        case idle
        case sent
        case unavailable
    }

    // ── Language (injected from root)
    @EnvironmentObject private var lang: LanguageManager

    // ── Permissions live status
    @State private var locationStatus: CLAuthorizationStatus = .notDetermined
    @State private var notifStatus: UNAuthorizationStatus    = .notDetermined
    @State private var prayerNotifsActive = false

    @Environment(\.openURL)    private var openURL
    @Environment(\.scenePhase) private var scenePhase

    // ── Accent palette
    private let accentOptions: [(id: String, label: String, color: Color)] = [
        ("purple",  "Purple",    Color.purple),
        ("rose",    "Rose",      Color.pink),
        ("emerald", "Emerald",   Color.green),
        ("indigo",  "Indigo",    Color.indigo),
        ("teal",    "Teal",      Color.teal),
        ("gold",    "Gold",      Color(red: 0.85, green: 0.70, blue: 0.35)),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {

                        pageTitle

                        // ─────────────────────────────────────────────
                        // MARK: Premium Banner
                        // ─────────────────────────────────────────────
                        premiumSection

                        // ─────────────────────────────────────────────
                        // MARK: Appearance
                        // ─────────────────────────────────────────────
                        SettingsSectionLabel(lang.t("المظهر والتخصيص", "Appearance"))

                        VStack(spacing: 0) {
                            appearanceRow
                            Divider().background(Theme.border).padding(.horizontal, 14)
                            accentRow
                            Divider().background(Theme.border).padding(.horizontal, 14)
                            languageRow
                        }
                        .settingsCard()

                        // ─────────────────────────────────────────────
                        // MARK: Notifications
                        // ─────────────────────────────────────────────
                        SettingsSectionLabel(lang.t("الإشعارات", "Notifications"))

                        VStack(spacing: 0) {

                            notifInfoRow(
                                icon: "bell.fill", bg: .orange,
                                title: lang.t("أوقات الصلاة", "Prayer Times"),
                                subtitle: prayerNotifsActive
                                    ? lang.t("مفعّل • \(prayerWarningSubtitle)", "Active • \(prayerWarningSubtitle)")
                                    : lang.t("غير مفعّل", "Inactive"),
                                isActive: prayerNotifsActive
                            )
                            prayerWarningStepper.padding(.leading, 66)
                            Divider().background(Theme.border).padding(.leading, 66)

                            notifToggleRow(
                                icon: "heart.fill", bg: .purple,
                                title: lang.t("تذكيرات الأذكار", "Adhkar Reminders"),
                                subtitle: lang.t("الصباح • المساء • النوم • بعد الصلوات",
                                                 "Morning • Evening • Night • After Prayers"),
                                isOn: $azkarNotifsEnabled,
                                onChange: { v in
                                    if v {
                                        NotificationManager.shared.requestPermission { g in
                                            if g { NotificationManager.shared.scheduleAzkarNotifications() }
                                            else { azkarNotifsEnabled = false }
                                        }
                                    } else {
                                        NotificationManager.shared.cancelAzkarNotifications()
                                    }
                                }
                            )
                            Divider().background(Theme.border).padding(.leading, 66)

                            notifToggleRow(
                                icon: "book.fill", bg: .green,
                                title: lang.t("تذكير قراءة القرآن", "Quran Reading Reminder"),
                                subtitle: lang.t("بعد 24 ساعة ثم 5 و10 أيام وما بعدها",
                                                 "After 24h, then 5 and 10 days, and beyond"),
                                isOn: $quranReminderEnabled,
                                onChange: { v in
                                    if v { NotificationManager.shared.scheduleQuranReminder() }
                                    else {
                                        NotificationManager.shared.cancelQuranReminders()
                                    }
                                }
                            )
                            Divider().background(Theme.border).padding(.leading, 66)

                            notifToggleRow(
                                icon: "calendar.badge.clock", bg: Color(red: 0.0, green: 0.6, blue: 0.4),
                                title: lang.t("تذكير سورة الكهف - يوم الجمعة",
                                              "Surah Al-Kahf Reminder - Friday"),
                                subtitle: lang.t("«من قرأ سورة الكهف في يوم الجمعة أضاء له النور ما بين الجمعتين»",
                                                 "Whoever reads Surah Al-Kahf on Friday, a light will shine for them between the two Fridays"),
                                isOn: $fridayKahfEnabled,
                                onChange: { v in
                                    UserDefaults.standard.set(v, forKey: IslamicCalendarService.keyFridayKahf)
                                    if v {
                                        NotificationManager.shared.requestPermission { g in
                                            if g { IslamicCalendarService.shared.scheduleFridayKahfReminder() }
                                            else { fridayKahfEnabled = false }
                                        }
                                    } else {
                                        IslamicCalendarService.shared.cancelFridayKahfReminder()
                                    }
                                }
                            )
                            Divider().background(Theme.border).padding(.leading, 66)

                            notifToggleRow(
                                icon: "moon.stars.fill", bg: .indigo,
                                title: lang.t("مناسبات إسلامية", "Islamic Events"),
                                subtitle: lang.t("رمضان • الأعياد • عرفة • يوم عاشوراء والمزيد",
                                                 "Ramadan • Eid • Arafah • Ashura and more"),
                                isOn: $islamicEventsEnabled,
                                onChange: { v in
                                    UserDefaults.standard.set(v, forKey: IslamicCalendarService.keyIslamicEvents)
                                    if v {
                                        NotificationManager.shared.requestPermission { g in
                                            if g { IslamicCalendarService.shared.scheduleIslamicEvents() }
                                            else { islamicEventsEnabled = false }
                                        }
                                    } else {
                                        IslamicCalendarService.shared.cancelIslamicEvents()
                                    }
                                }
                            )
                        }
                        .settingsCard()

                        // ─────────────────────────────────────────────
                        // MARK: Apple Watch
                        // ─────────────────────────────────────────────
                        SettingsSectionLabel(lang.t("Apple Watch", "Apple Watch"))

                        VStack(spacing: 0) {
                            watchConnectivityRow
                            Divider().background(Theme.border).padding(.leading, 66)
                            watchToggle(
                                icon: "bell.badge.fill", bg: .orange,
                                title: lang.t("إشعارات الصلاة", "Prayer Alerts"),
                                subtitle: lang.t("تنبيه بوقت كل صلاة", "Alert at each prayer time"),
                                isOn: $watchPrayerAlert
                            )
                            Divider().background(Theme.border).padding(.leading, 66)
                            watchToggle(
                                icon: "hands.sparkles.fill", bg: .green,
                                title: lang.t("أذكار الصباح والمساء", "Morning & Evening Adhkar"),
                                subtitle: lang.t("تذكير يومي بالأذكار", "Daily adhkar reminders"),
                                isOn: $watchAzkarEnabled
                            )
                            Divider().background(Theme.border).padding(.leading, 66)
                            watchToggle(
                                icon: "waveform.path", bg: .purple,
                                title: lang.t("الاهتزاز", "Haptics"),
                                subtitle: lang.t("اهتزاز عند الإشعارات", "Vibrate on notifications"),
                                isOn: $watchHapticEnabled
                            )
                            Divider().background(Theme.border).padding(.leading, 66)
                            watchToggle(
                                icon: "app.badge", bg: .indigo,
                                title: lang.t("إشعارات الساعة", "Watch Notifications"),
                                subtitle: lang.t("تفعيل جميع الإشعارات", "Enable all notifications"),
                                isOn: $watchNotifEnabled
                            )
                            Divider().background(Theme.border).padding(.horizontal, 14)
                            watchSyncButton
                        }
                        .settingsCard()
                        .onAppear { isWatchReachable = WatchConnectivityManager.shared.isWatchReachable }
                        .onReceive(WatchConnectivityManager.shared.$isWatchReachable) { isWatchReachable = $0 }

                        // ─────────────────────────────────────────────
                        // MARK: Dynamic Island / Live Activity
                        // ─────────────────────────────────────────────
                        SettingsSectionLabel(lang.t("الشاشة الديناميكية", "Dynamic Island"))

                        VStack(spacing: 0) {
                            liveActivityToggleRow
                        }
                        .settingsCard()

                        // ─────────────────────────────────────────────
                        // MARK: Permissions
                        // ─────────────────────────────────────────────
                        SettingsSectionLabel(lang.t("الأذونات", "Permissions"))

                        VStack(spacing: 0) {
                            PermissionRow(
                                icon: "location.fill", iconBg: Color.teal.opacity(0.2), iconFg: Color.teal,
                                title: lang.t("الموقع الجغرافي", "Location"),
                                subtitle: lang.t("أوقات الصلاة واتجاه القبلة", "Prayer times & Qibla direction"),
                                status: locationPermissionStatus, showDivider: true
                            ) { openAppSettings() }

                            PermissionRow(
                                icon: "bell.fill", iconBg: Color.orange.opacity(0.2), iconFg: .orange,
                                title: lang.t("الإشعارات", "Notifications"),
                                subtitle: lang.t("أذان الصلاة والتذكيرات", "Adhan & reminders"),
                                status: notifPermissionStatus, showDivider: false
                            ) { openAppSettings() }
                        }
                        .settingsCard()

                        // ─────────────────────────────────────────────
                        // MARK: Share App
                        // ─────────────────────────────────────────────
                        SettingsSectionLabel(lang.t("مشاركة التطبيق", "Share App"))

                        shareSection

                        // ─────────────────────────────────────────────
                        // MARK: About
                        // ─────────────────────────────────────────────
                        SettingsSectionLabel(lang.t("عن التطبيق", "About"))

                        VStack(spacing: 0) {
                            NavigationLink(destination: AboutAppView()) {
                                MoreRow(icon: "info.circle.fill", iconBg: Theme.gold.opacity(0.2),
                                        iconFg: Theme.gold,
                                        title: lang.t("حول التطبيق", "About App"),
                                        showDivider: true)
                            }.buttonStyle(.plain)

                            Button { callDeveloper() } label: {
                                MoreRow(icon: "phone.fill", iconBg: Color.green.opacity(0.2),
                                        iconFg: .green,
                                        title: lang.t("التواصل مع المطور", "Contact Developer"),
                                        subtitle: AppMetadata.developerPhoneDisplay, showDivider: false)
                            }.buttonStyle(.plain)
                        }
                        .settingsCard()

                        Text(lang.t("القرآن الكريم  •  الإصدار \(AppBuildInfo.version)", "Quran App  •  Version \(AppBuildInfo.version)"))
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.vertical, 8)
                            .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .onAppear { refreshPermissions(); checkPrayerNotifs() }
            .onChange(of: scenePhase) { p in if p == .active { refreshPermissions() } }
        }
    }

    // MARK: - Sub-views

    private var pageTitle: some View {
        Text(lang.t("الإعدادات", "Settings"))
            .font(.system(size: 26, weight: .bold))
            .foregroundColor(Theme.goldLight)
            .frame(maxWidth: .infinity)
            .padding(.top, 16).padding(.bottom, 4)
    }

    // ── Display mode picker
    private var appearanceRow: some View {
        VStack(alignment: lang.isEnglish ? .leading : .trailing, spacing: 0) {
            HStack(spacing: 10) {
                iconBox("circle.lefthalf.filled", bg: .indigo.opacity(0.2), fg: .indigo)
                Text(lang.t("وضع العرض", "Display Mode"))
                    .font(.system(size: 15)).foregroundColor(Theme.text)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 12)

            HStack(spacing: 8) {
                AppearanceButton(label: lang.t("داكن", "Dark"),
                                 icon: "moon.fill",
                                 isSelected: colorSchemePreference == "dark")   { colorSchemePreference = "dark" }
                AppearanceButton(label: lang.t("فاتح", "Light"),
                                 icon: "sun.max.fill",
                                 isSelected: colorSchemePreference == "light")  { colorSchemePreference = "light" }
                AppearanceButton(label: lang.t("الجهاز", "System"),
                                 icon: "iphone",
                                 isSelected: colorSchemePreference == "system") { colorSchemePreference = "system" }
            }
            .padding(.horizontal, 14).padding(.bottom, 12)
        }
    }

    // ── Accent color picker
    private var accentRow: some View {
        VStack(alignment: lang.isEnglish ? .leading : .trailing, spacing: 8) {
            HStack(spacing: 10) {
                iconBox("paintpalette.fill",
                        bg: Color(red: 0.85, green: 0.70, blue: 0.35).opacity(0.2),
                        fg: Color(red: 0.85, green: 0.70, blue: 0.35))
                Text(lang.t("لون التطبيق", "App Color"))
                    .font(.system(size: 15)).foregroundColor(Theme.text)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.top, 12)

            HStack(spacing: 10) {
                ForEach(accentOptions, id: \.id) { opt in
                    Button(action: {
                        themeAccent = opt.id
                        UserDefaults.standard.set(opt.id, forKey: "themeAccent")
                    }) {
                        ZStack {
                            Circle().fill(opt.color).frame(width: 32, height: 32)
                            if themeAccent == opt.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 14).padding(.bottom, 12)
        }
    }

    // ── Language picker — INSTANT switching via LanguageManager
    private var languageRow: some View {
        HStack(spacing: 10) {
            iconBox("globe", bg: Color.cyan.opacity(0.2), fg: .cyan)
            Text(lang.t("اللغة", "Language"))
                .font(.system(size: 15)).foregroundColor(Theme.text)
            Spacer()

            // Segmented control bound directly to LanguageManager
            Picker("", selection: Binding(
                get: { lang.isEnglish ? "en" : "ar" },
                set: { newVal in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        lang.isEnglish = (newVal == "en")
                    }
                }
            )) {
                Text("العربية").tag("ar")
                Text("English").tag("en")
            }
            .pickerStyle(.segmented)
            .frame(width: 150)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    private var prayerWarningStepper: some View {
        HStack {
            Text(lang.t("تنبيه قبل الصلاة", "Alert before prayer"))
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Stepper(
                prayerWarningSubtitle,
                value: $prayerWarningMinutes,
                in: 0...60,
                step: 5
            )
            .font(.system(size: 13))
            .foregroundColor(Theme.text)
            .onChange(of: prayerWarningMinutes) { _ in
                NotificationManager.shared.reschedulePrayerNotificationsFromStoredData()
                checkPrayerNotifs()
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Theme.gold.opacity(0.04))
    }

    private var prayerWarningSubtitle: String {
        prayerWarningMinutes == 0
            ? lang.t("بدون تنبيه مسبق", "No early alert")
            : lang.t("قبلها \(prayerWarningMinutes) دقائق", "\(prayerWarningMinutes) min before")
    }

    // ── Share section
    private var shareSection: some View {
        let appStoreURL = AppMetadata.appStoreURL
        let message = lang.t(
            "حمّل تطبيق القرآن الكريم وأوقات الصلاة\n\(AppMetadata.appStoreURLString)",
            "Download Quran App and Prayer Times\n\(AppMetadata.appStoreURLString)"
        )

        return ShareLink(item: appStoreURL, message: Text(message)) {
            HStack(spacing: 10) {
                iconBox("square.and.arrow.up", bg: Theme.gold.opacity(0.18), fg: Theme.gold)
                Text(lang.t("مشاركة التطبيق", "Share App"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.text)
                Spacer()
                Image(systemName: lang.isEnglish ? "chevron.right" : "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
            .background(Theme.card)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }


    // MARK: - Live Activity row

    @available(iOS 16.2, *)
    private var liveActivityToggleRowAvailable: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.86, green: 0.71, blue: 0.35).opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: "oval.tophalf.filled")
                    .font(.system(size: 17))
                    .foregroundColor(Theme.gold)
            }
            VStack(alignment: .trailing, spacing: 2) {
                Text(lang.t("الماجيك آيلاند وشاشة القفل", "Dynamic Island & Lock Screen"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.text)
                Text(lang.t(
                    "يعرض الصلاة القادمة والتالية مع العداد التنازلي",
                    "Shows next & following prayer with live countdown"
                ))
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.trailing)
            }
            Spacer()
            Toggle("", isOn: $liveActivityEnabled)
                .labelsHidden()
                .tint(Theme.gold)
                .onChange(of: liveActivityEnabled) { enabled in
                    Task {
                        if !enabled {
                            // End all active Live Activities
                            for activity in Activity<PrayerLiveActivityAttributes>.activities {
                                await activity.end(dismissalPolicy: .immediate)
                            }
                        }
                        // When re-enabled, PrayerTimesView will restart on next refresh
                    }
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var liveActivityToggleRow: some View {
        Group {
            if #available(iOS 16.2, *) {
                liveActivityToggleRowAvailable
            } else {
                HStack {
                    Spacer()
                    Text(lang.t("يتطلب iOS 16.2 أو أحدث", "Requires iOS 16.2 or later"))
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                }
                .padding(.vertical, 14)
            }
        }
    }

    // MARK: - Notification row helpers

    private func notifToggleRow(
        icon: String, bg: Color, title: String, subtitle: String,
        isOn: Binding<Bool>, onChange: @escaping (Bool) -> Void
    ) -> some View {
        HStack(spacing: 14) {
            iconBox(icon, bg: bg.opacity(0.2), fg: bg)
            VStack(alignment: lang.isEnglish ? .leading : .trailing, spacing: 2) {
                Text(title).font(.system(size: 15)).foregroundColor(Theme.text)
                Text(subtitle).font(.system(size: 11)).foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Theme.gold)
                .onChange(of: isOn.wrappedValue) { onChange($0) }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    private func notifInfoRow(
        icon: String, bg: Color, title: String, subtitle: String, isActive: Bool
    ) -> some View {
        HStack(spacing: 14) {
            iconBox(icon, bg: bg.opacity(0.2), fg: bg)
            VStack(alignment: lang.isEnglish ? .leading : .trailing, spacing: 2) {
                Text(title).font(.system(size: 15)).foregroundColor(Theme.text)
                Text(subtitle).font(.system(size: 11)).foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundColor(isActive ? .green : Theme.textSecondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    // MARK: - Permission helpers

    private var locationPermissionStatus: PermissionStatus {
        switch locationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return .granted
        case .denied, .restricted:                    return .denied
        default:                                      return .undetermined
        }
    }

    private var notifPermissionStatus: PermissionStatus {
        switch notifStatus {
        case .authorized, .provisional, .ephemeral: return .granted
        case .denied:                               return .denied
        default:                                    return .undetermined
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Free App Banner
    // ─────────────────────────────────────────────────────────────────────────

    private let gold = Color(red: 0.85, green: 0.70, blue: 0.35)

    private var premiumSection: some View {
        HStack(spacing: 14) {
            // أيقونة
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.04, green: 0.22, blue: 0.14),
                                     Color(red: 0.02, green: 0.12, blue: 0.08)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 46, height: 46)
                Image(systemName: "star.fill")
                    .font(.system(size: 20))
                    .foregroundColor(gold)
            }
            // النص
            VStack(alignment: .trailing, spacing: 3) {
                Text("جميع المزايا مجانية ✓")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(gold)
                Text("لا اشتراك ولا قيود — كل شيء متاح للجميع")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 22))
                .foregroundColor(gold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(gold.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(gold.opacity(0.3), lineWidth: 1.5)
        )
    }

    // ─────────────────────────────────────────────────────────────────────────

    private func refreshPermissions() {
        locationStatus = CLLocationManager().authorizationStatus
        UNUserNotificationCenter.current().getNotificationSettings { s in
            DispatchQueue.main.async { notifStatus = s.authorizationStatus }
        }
    }

    private func checkPrayerNotifs() {
        NotificationManager.shared.arePrayerNotificationsActive { active in
            prayerNotifsActive = active
        }
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }

    private func callDeveloper() {
        if let url = AppMetadata.developerPhoneURL { openURL(url) }
    }

    // MARK: - Apple Watch helpers

    private var watchConnectivityRow: some View {
        HStack(spacing: 14) {
            iconBox("applewatch", bg: Color(red: 0.1, green: 0.1, blue: 0.1).opacity(0.15), fg: .primary)
            VStack(alignment: lang.isEnglish ? .leading : .trailing, spacing: 2) {
                Text(lang.t("Apple Watch", "Apple Watch"))
                    .font(.system(size: 15)).foregroundColor(Theme.text)
                Text(isWatchReachable
                     ? lang.t("الساعة متصلة ✓", "Watch connected ✓")
                     : lang.t("الساعة غير متصلة", "Watch not reachable"))
                    .font(.system(size: 11))
                    .foregroundColor(isWatchReachable ? .green : Theme.textSecondary)
            }
            Spacer()
            Circle()
                .fill(isWatchReachable ? Color.green : Color.gray.opacity(0.4))
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    private func watchToggle(
        icon: String, bg: Color, title: String, subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 14) {
            iconBox(icon, bg: bg.opacity(0.2), fg: bg)
            VStack(alignment: lang.isEnglish ? .leading : .trailing, spacing: 2) {
                Text(title).font(.system(size: 15)).foregroundColor(Theme.text)
                Text(subtitle).font(.system(size: 11)).foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Theme.gold)
                .onChange(of: isOn.wrappedValue) { _ in
                    WatchConnectivityManager.shared.sendWatchSettings()
                }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    private var watchSyncButton: some View {
        Button {
            let didSendData = WatchConnectivityManager.shared.sendPrayerTimes()
            let didSendSettings = WatchConnectivityManager.shared.sendWatchSettings()
            withAnimation {
                watchSyncState = (didSendData || didSendSettings) ? .sent : .unavailable
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation { watchSyncState = .idle }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: watchSyncIcon)
                    .font(.system(size: 14))
                    .foregroundColor(watchSyncColor)
                Text(watchSyncTitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(watchSyncColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private var watchSyncTitle: String {
        switch watchSyncState {
        case .idle:
            return lang.t("مزامنة البيانات مع الساعة", "Sync data to Watch")
        case .sent:
            return lang.t("تم إرسال بيانات الساعة", "Watch data sent")
        case .unavailable:
            return lang.t("الساعة غير جاهزة للمزامنة", "Watch is not ready")
        }
    }

    private var watchSyncIcon: String {
        switch watchSyncState {
        case .idle: return "arrow.triangle.2.circlepath"
        case .sent: return "checkmark.circle.fill"
        case .unavailable: return "exclamationmark.triangle.fill"
        }
    }

    private var watchSyncColor: Color {
        switch watchSyncState {
        case .idle: return Theme.gold
        case .sent: return .green
        case .unavailable: return .orange
        }
    }

    // MARK: - Tiny helpers

    private func iconBox(_ name: String, bg: Color, fg: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9).fill(bg).frame(width: 38, height: 38)
            Image(systemName: name).font(.system(size: 17)).foregroundColor(fg)
        }
    }
}

// MARK: - SettingsSectionLabel

struct SettingsSectionLabel: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 4).padding(.top, 4)
    }
}

// MARK: - settingsCard modifier

private extension View {
    func settingsCard() -> some View {
        self
            .background(Theme.card)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }
}
