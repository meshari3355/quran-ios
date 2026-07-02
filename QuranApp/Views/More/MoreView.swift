import SwiftUI
import CoreLocation
import UserNotifications

// MARK: - MoreView

struct MoreView: View {
    @AppStorage("colorSchemePreference") private var colorSchemePreference = "system"
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("azkarNotifsEnabled")         private var azkarNotifsEnabled         = false
    @AppStorage("quranReminderEnabled")       private var quranReminderEnabled       = true
    @State private var prayerNotifsEnabled   = false
    @State private var locationStatus: CLAuthorizationStatus  = .notDetermined
    @State private var notifStatus: UNAuthorizationStatus     = .notDetermined
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {

                        // Header
                        Text("المزيد")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(Theme.goldLight)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 16)
                            .padding(.bottom, 8)

                        // ── المظهر ────────────────────────────────────
                        SectionLabel(title: "المظهر")

                        VStack(spacing: 0) {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 9)
                                        .fill(Color.indigo.opacity(0.2))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: "circle.lefthalf.filled")
                                        .font(.system(size: 17))
                                        .foregroundColor(Color.indigo)
                                }
                                Text("وضع العرض")
                                    .font(.system(size: 16))
                                    .foregroundColor(Theme.text)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)

                            Divider().background(Theme.border).padding(.horizontal, 14)

                            // Appearance selector
                            HStack(spacing: 8) {
                                AppearanceButton(
                                    label: "داكن",
                                    icon: "moon.fill",
                                    isSelected: colorSchemePreference == "dark"
                                ) { colorSchemePreference = "dark" }

                                AppearanceButton(
                                    label: "فاتح",
                                    icon: "sun.max.fill",
                                    isSelected: colorSchemePreference == "light"
                                ) { colorSchemePreference = "light" }

                                AppearanceButton(
                                    label: "حسب الجهاز",
                                    icon: "iphone",
                                    isSelected: colorSchemePreference == "system"
                                ) { colorSchemePreference = "system" }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                        }
                        .background(Theme.card)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))

                        // ── الإشعارات ─────────────────────────────────
                        SectionLabel(title: "الإشعارات")

                        VStack(spacing: 0) {
                            // Prayer notifications toggle
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 9)
                                        .fill(Color.orange.opacity(0.2))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.orange)
                                }
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("تنبيهات أوقات الصلاة")
                                        .font(.system(size: 15))
                                        .foregroundColor(Theme.text)
                                    Text("تفعيل من صفحة أوقات الصلاة")
                                        .font(.system(size: 11))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: prayerNotifsEnabled ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(prayerNotifsEnabled ? .green : Theme.textSecondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)

                            Divider().background(Theme.border).padding(.horizontal, 66)

                            // Quran reading reminder toggle
                            Button(action: toggleQuranReminder) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 9)
                                            .fill(Color.green.opacity(0.2))
                                            .frame(width: 38, height: 38)
                                        Image(systemName: "book.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.green)
                                    }
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("تذكير قراءة القرآن")
                                            .font(.system(size: 15))
                                            .foregroundColor(Theme.text)
                                        Text("بعد 24 ساعة ثم 5 و10 أيام وما بعدها")
                                            .font(.system(size: 11))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: quranReminderEnabled ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundColor(quranReminderEnabled ? .green : Theme.textSecondary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 13)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Divider().background(Theme.border).padding(.horizontal, 66)

                            // Azkar notifications toggle
                            Button(action: toggleAzkarNotifs) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 9)
                                            .fill(Color.purple.opacity(0.2))
                                            .frame(width: 38, height: 38)
                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.purple)
                                    }
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("تذكيرات الأذكار")
                                            .font(.system(size: 15))
                                            .foregroundColor(Theme.text)
                                        Text("الصباح • المساء • النوم • بعد الفجر والعصر")
                                            .font(.system(size: 11))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: azkarNotifsEnabled ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundColor(azkarNotifsEnabled ? .purple : Theme.textSecondary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 13)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .background(Theme.card)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))

                        // ── الأذونات ─────────────────────────────────
                        SectionLabel(title: "الأذونات")

                        VStack(spacing: 0) {
                            // Location
                            PermissionRow(
                                icon:    "location.fill",
                                iconBg:  Color.teal.opacity(0.2),
                                iconFg:  Color.teal,
                                title:   "الموقع الجغرافي",
                                subtitle: "أوقات الصلاة والقبلة",
                                status:  locationPermissionStatus,
                                showDivider: true
                            ) { openAppSettings() }

                            // Notifications
                            PermissionRow(
                                icon:    "bell.fill",
                                iconBg:  Color.orange.opacity(0.2),
                                iconFg:  Color.orange,
                                title:   "الإشعارات",
                                subtitle: "أذان الصلاة والتذكيرات",
                                status:  notifPermissionStatus,
                                showDivider: false
                            ) { openAppSettings() }
                        }
                        .background(Theme.card)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))

                        // ── الميزات ──────────────────────────────────
                        SectionLabel(title: "الميزات")

                        VStack(spacing: 0) {
                            NavigationLink(destination: QiblaView()) {
                                MoreRow(
                                    icon: "location.north.line.fill",
                                    iconBg: Color.teal.opacity(0.2),
                                    iconFg: Color.teal,
                                    title: "اتجاه القبلة",
                                    showDivider: true
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink(destination: FatwaListView()) {
                                MoreRow(
                                    icon: "questionmark.circle.fill",
                                    iconBg: Color.purple.opacity(0.25),
                                    iconFg: Color.purple,
                                    title: "الفتاوى الإسلامية",
                                    showDivider: true
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink(destination: ZakatCalculatorView()) {
                                MoreRow(
                                    icon: "scalemass.fill",
                                    iconBg: Color.orange.opacity(0.25),
                                    iconFg: Color.orange,
                                    title: "حاسبة الزكاة",
                                    showDivider: true
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink(destination: HadithPortalView()) {
                                MoreRow(
                                    icon: "scroll.fill",
                                    iconBg: Color.indigo.opacity(0.2),
                                    iconFg: Color.indigo,
                                    title: "بوابة الحديث النبوي",
                                    subtitle: "189 كتاب • بحث وتحميل",
                                    showDivider: true
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink(destination: NearbyMosquesView()) {
                                MoreRow(
                                    icon: "mappin.and.ellipse",
                                    iconBg: Color.green.opacity(0.2),
                                    iconFg: Color.green,
                                    title: "المساجد القريبة",
                                    subtitle: "ابحث عن أقرب مسجد إليك",
                                    showDivider: true
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink(destination: OfflineDownloadsView()) {
                                MoreRow(
                                    icon: "arrow.down.circle.fill",
                                    iconBg: Color.green.opacity(0.2),
                                    iconFg: Color.green,
                                    title: "التحميل للاستخدام دون إنترنت",
                                    showDivider: false
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .background(Theme.card)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))

                        // ── التواصل والمعلومات ──────────────────────
                        SectionLabel(title: "التواصل والمعلومات")

                        VStack(spacing: 0) {
                            NavigationLink(destination: AboutAppView()) {
                                MoreRow(
                                    icon: "info.circle.fill",
                                    iconBg: Theme.gold.opacity(0.2),
                                    iconFg: Theme.gold,
                                    title: "حول التطبيق",
                                    showDivider: true
                                )
                            }
                            .buttonStyle(.plain)

                            Button { callDeveloper() } label: {
                                MoreRow(
                                    icon: "phone.fill",
                                    iconBg: Color.green.opacity(0.25),
                                    iconFg: Color.green,
                                    title: "التواصل مع المطور",
                                    subtitle: AppMetadata.developerPhoneDisplay,
                                    showDivider: false
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .background(Theme.card)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))

                        Text("القرآن الكريم  •  الإصدار \(AppBuildInfo.version)")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.top, 4)
                            .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .onAppear {
                checkPrayerNotifStatus()
                refreshPermissions()
                // Re-schedule reading reminder if still enabled
                if quranReminderEnabled {
                    NotificationManager.shared.scheduleQuranReminder()
                }
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active { refreshPermissions() }
            }
        }
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

    private func refreshPermissions() {
        locationStatus = CLLocationManager().authorizationStatus
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { self.notifStatus = settings.authorizationStatus }
        }
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }

    private func callDeveloper() {
        if let url = AppMetadata.developerPhoneURL { openURL(url) }
    }

    private func toggleQuranReminder() {
        if quranReminderEnabled {
            NotificationManager.shared.cancelQuranReminders()
            quranReminderEnabled = false
        } else {
            NotificationManager.shared.requestPermission { granted in
                if granted {
                    self.quranReminderEnabled = true
                    NotificationManager.shared.scheduleQuranReminder()
                }
            }
        }
    }

    private func toggleAzkarNotifs() {
        if azkarNotifsEnabled {
            NotificationManager.shared.cancelAzkarNotifications()
            azkarNotifsEnabled = false
        } else {
            NotificationManager.shared.requestPermission { granted in
                if granted {
                    NotificationManager.shared.scheduleAzkarNotifications()
                    self.azkarNotifsEnabled = true
                }
            }
        }
    }

    private func checkPrayerNotifStatus() {
        NotificationManager.shared.arePrayerNotificationsActive { active in
            prayerNotifsEnabled = active
        }
    }
}

// MARK: - Permission Status

enum PermissionStatus {
    case granted, denied, undetermined

    var label: String {
        switch self {
        case .granted:     return "مسموح"
        case .denied:      return "مرفوض"
        case .undetermined: return "غير محدد"
        }
    }

    var color: Color {
        switch self {
        case .granted:      return .green
        case .denied:       return .red
        case .undetermined: return .orange
        }
    }

    var icon: String {
        switch self {
        case .granted:      return "checkmark.circle.fill"
        case .denied:       return "xmark.circle.fill"
        case .undetermined: return "questionmark.circle.fill"
        }
    }
}

// MARK: - PermissionRow

struct PermissionRow: View {
    let icon:        String
    let iconBg:      Color
    let iconFg:      Color
    let title:       String
    let subtitle:    String
    let status:      PermissionStatus
    let showDivider: Bool
    let onTap:       () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { if status != .granted { onTap() } }) {
                HStack(spacing: 14) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(iconBg)
                            .frame(width: 38, height: 38)
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .foregroundColor(iconFg)
                    }

                    // Title + subtitle
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(title)
                            .font(.system(size: 15))
                            .foregroundColor(Theme.text)
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                    }

                    Spacer()

                    // Status badge
                    HStack(spacing: 5) {
                        if status != .granted {
                            Text("فتح الإعدادات")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Theme.gold)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: status.icon)
                                .font(.system(size: 13))
                            Text(status.label)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(status.color)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(status.color.opacity(0.12))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showDivider {
                Divider().background(Theme.border).padding(.leading, 66)
            }
        }
    }
}

// MARK: - AppearanceButton

struct AppearanceButton: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? Theme.gold : Theme.textSecondary)
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Theme.gold : Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Theme.gold.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Theme.gold.opacity(0.5) : Theme.border, lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SectionLabel

private struct SectionLabel: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 4)
            .padding(.top, 4)
    }
}

// MARK: - MoreRow

struct MoreRow: View {
    let icon: String
    let iconBg: Color
    let iconFg: Color
    let title: String
    var subtitle: String? = nil
    let showDivider: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(iconBg)
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 17))
                        .foregroundColor(iconFg)
                }
                VStack(alignment: .trailing, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16))
                        .foregroundColor(Theme.text)
                    if let sub = subtitle {
                        Text(sub)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)

            if showDivider {
                Divider()
                    .background(Theme.border)
                    .padding(.leading, 66)
            }
        }
    }
}
