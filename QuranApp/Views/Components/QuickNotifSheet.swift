import SwiftUI
import UserNotifications

// MARK: - Quick Notification Sheet
// A compact popup (sheet) accessible from the Home page bell button
// that lets the user control all notification types + Magic Island

struct QuickNotifSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL)  private var openURL

    // ── Same AppStorage keys used by SettingsView ──────────────────
    @AppStorage("azkarNotifsEnabled")   private var azkarNotifsEnabled   = true
    @AppStorage("quranReminderEnabled") private var quranReminderEnabled  = true
    @AppStorage("prayerWarningMinutes") private var prayerWarningMinutes  = 5
    @AppStorage("fridayKahfEnabled")    private var fridayKahfEnabled     = true
    @AppStorage("islamicEventsEnabled") private var islamicEventsEnabled  = true
    @AppStorage("liveActivityEnabled")  private var liveActivityEnabled   = true

    @State private var notifStatus: UNAuthorizationStatus = .notDetermined
    @State private var prayerNotifsActive = false

    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // ── Header banner ──────────────────────────
                        headerBanner

                        // ── Notification rows ──────────────────────
                        VStack(spacing: 0) {
                            sectionLabel("الإشعارات")

                            notifCard
                        }

                        // ── Magic Island / Live Activity ───────────
                        VStack(spacing: 0) {
                            sectionLabel("الشاشة الديناميكية")

                            liveActivityCard
                        }

                        // ── Open full settings ─────────────────────
                        if notifStatus == .denied {
                            deniedCard
                        }

                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .navigationTitle("الإشعارات والإعدادات")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("إغلاق") { dismiss() }
                        .foregroundColor(Theme.gold)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { refreshStatus() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var headerBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.gold.opacity(0.15))
                    .frame(width: 54, height: 54)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Theme.gold)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("التحكم في الإشعارات")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.text)
                Text(statusSubtitle)
                    .font(.system(size: 12))
                    .foregroundColor(statusColor)
            }

            Spacer()

            // Status dot
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
        }
        .padding(14)
        .background(Theme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(Theme.gold.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Notification Card

    private var notifCard: some View {
        VStack(spacing: 0) {
            // Prayer times row (status-only)
            QuickNotifRow(
                icon: "bell.fill",
                iconBg: Color.orange.opacity(0.15),
                iconFg: Color.orange,
                title: "أوقات الصلاة",
                subtitle: prayerNotifsActive ? "مفعّل • \(prayerWarningSubtitle)" : "غير مفعّل • فعّلها من أوقات الصلاة"
            ) {
                AnyView(
                    Circle()
                        .fill(prayerNotifsActive ? Color.green : Color.gray.opacity(0.4))
                        .frame(width: 8, height: 8)
                        .padding(.trailing, 4)
                )
            }

            warningMinutesRow

            Divider().background(Theme.border).padding(.leading, 54)

            // Azkar reminders
            QuickToggleRow(
                icon: "heart.fill", iconBg: Color.purple.opacity(0.15), iconFg: Color.purple,
                title: "تذكيرات الأذكار",
                subtitle: "الصباح • المساء • النوم • بعد الصلوات",
                isOn: $azkarNotifsEnabled
            ) { v in
                if v {
                    NotificationManager.shared.requestPermission { g in
                        if g { NotificationManager.shared.scheduleAzkarNotifications() }
                        else { azkarNotifsEnabled = false }
                    }
                } else {
                    NotificationManager.shared.cancelAzkarNotifications()
                }
            }

            Divider().background(Theme.border).padding(.leading, 54)

            // Quran reminder
            QuickToggleRow(
                icon: "book.fill", iconBg: Color.green.opacity(0.15), iconFg: Color.green,
                title: "تذكير قراءة القرآن",
                subtitle: "بعد 24 ساعة ثم 5 و10 أيام وما بعدها",
                isOn: $quranReminderEnabled
            ) { v in
                if v { NotificationManager.shared.scheduleQuranReminder() }
                else {
                    NotificationManager.shared.cancelQuranReminders()
                }
            }

            Divider().background(Theme.border).padding(.leading, 54)

            // Friday Kahf
            QuickToggleRow(
                icon: "calendar.badge.clock",
                iconBg: Color(red: 0.0, green: 0.6, blue: 0.4).opacity(0.15),
                iconFg: Color(red: 0.0, green: 0.6, blue: 0.4),
                title: "تذكير سورة الكهف - يوم الجمعة",
                subtitle: "«من قرأ سورة الكهف في يوم الجمعة أضاء له النور»",
                isOn: $fridayKahfEnabled
            ) { v in
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

            Divider().background(Theme.border).padding(.leading, 54)

            // Islamic Events
            QuickToggleRow(
                icon: "moon.stars.fill", iconBg: Color.indigo.opacity(0.15), iconFg: Color.indigo,
                title: "مناسبات إسلامية",
                subtitle: "رمضان • الأعياد • عرفة • يوم عاشوراء والمزيد",
                isOn: $islamicEventsEnabled
            ) { v in
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
        }
        .background(Theme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Live Activity Card

    private var liveActivityCard: some View {
        VStack(spacing: 0) {
            // Magic Island toggle
            QuickToggleRow(
                icon: "oval.tophalf.filled",
                iconBg: Color.black.opacity(0.12),
                iconFg: Color.primary,
                title: "الماجيك آيلاند وشاشة القفل",
                subtitle: "يعرض الصلاة القادمة والعد التنازلي مع الأقراص الديناميكية",
                isOn: $liveActivityEnabled
            ) { _ in }

            Divider().background(Theme.border).padding(.leading, 54)

            // Widget info row
            QuickNotifRow(
                icon: "apps.iphone",
                iconBg: Color.blue.opacity(0.15),
                iconFg: Color.blue,
                title: "ويدجت الشاشة الرئيسية",
                subtitle: "أضف الويدجت من قائمة التعديل لرؤية وقت الصلاة القادمة"
            ) {
                AnyView(
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                )
            }
        }
        .background(Theme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Denied Card

    private var deniedCard: some View {
        Button(action: openAppSettings) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("الإشعارات موقوفة")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.text)
                    Text("اضغط هنا لفتح الإعدادات وتفعيلها")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(Theme.gold)
            }
            .padding(14)
            .background(Color.orange.opacity(0.08))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.bottom, 6)
    }

    private var statusSubtitle: String {
        switch notifStatus {
        case .authorized:  return "الإشعارات مفعّلة"
        case .denied:      return "الإشعارات موقوفة من الإعدادات"
        case .provisional: return "إشعارات مؤقتة"
        default:           return "اضغط لتفعيل الإشعارات"
        }
    }

    private var statusColor: Color {
        switch notifStatus {
        case .authorized:  return .green
        case .denied:      return .red
        default:           return .orange
        }
    }

    private var warningMinutesRow: some View {
        HStack {
            Spacer()
            Text("تنبيه قبل الصلاة")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
            Stepper("", value: $prayerWarningMinutes, in: 0...60, step: 5)
                .labelsHidden()
                .onChange(of: prayerWarningMinutes) { _ in
                    NotificationManager.shared.reschedulePrayerNotificationsFromStoredData()
                    refreshStatus()
                }
            Text(prayerWarningSubtitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.gold)
                .frame(width: 120, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.gold.opacity(0.05))
    }

    private var prayerWarningSubtitle: String {
        prayerWarningMinutes == 0 ? "بدون تنبيه مسبق" : "قبلها \(prayerWarningMinutes) دقائق"
    }

    private func refreshStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            DispatchQueue.main.async { notifStatus = s.authorizationStatus }
        }
        UNUserNotificationCenter.current().getPendingNotificationRequests { reqs in
            DispatchQueue.main.async {
                prayerNotifsActive = reqs.contains {
                    $0.identifier.hasPrefix("prayer_")
                    || $0.identifier.hasPrefix("prayerWarn_")
                    || $0.identifier.hasPrefix("prayer5min_")
                    || $0.identifier.hasPrefix("bgprayer_")
                }
            }
        }
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}

// MARK: - QuickToggleRow

private struct QuickToggleRow: View {
    let icon: String
    let iconBg: Color
    let iconFg: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconBg)
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconFg)
            }

            VStack(alignment: .trailing, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }

            Toggle("", isOn: $isOn)
                .tint(Theme.gold)
                .labelsHidden()
                .onChange(of: isOn, perform: onChange)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - QuickNotifRow (non-toggle, info only)

private struct QuickNotifRow<TrailingContent: View>: View {
    let icon: String
    let iconBg: Color
    let iconFg: Color
    let title: String
    let subtitle: String
    let trailing: () -> TrailingContent

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconBg)
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconFg)
            }

            VStack(alignment: .trailing, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }

            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .environment(\.layoutDirection, .rightToLeft)
    }
}
