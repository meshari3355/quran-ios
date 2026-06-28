import SwiftUI
import CoreLocation
import UserNotifications
import WidgetKit
import ActivityKit

// MARK: - Models

struct PrayerTime: Identifiable {
    let id = UUID()
    let name: String
    let time: String        // raw "HH:mm" from API
    let icon: String

    /// Formatted as 12h with Arabic AM/PM
    var time12h: String {
        let clean = time.components(separatedBy: " ").first ?? time
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        guard let date = f.date(from: clean) else { return clean }
        let hour = Calendar.current.component(.hour, from: date)
        f.dateFormat = "h:mm"
        return "\(f.string(from: date)) \(hour < 12 ? "AM" : "PM")"
    }
}

// MARK: - Saved City (multi-city cache)

struct SavedCity: Codable, Identifiable {
    let id: UUID
    var name: String
    var date: String          // "yyyy-MM-dd" — when these times were fetched
    var times: [String: String] // prayer name → "HH:mm"
    init(name: String, date: String, times: [String: String]) {
        self.id = UUID()
        self.name = name; self.date = date; self.times = times
    }
}

// MARK: - PrayerTimesView

struct PrayerTimesView: View {
    @ObservedObject private var loc = SharedLocationManager.shared
    @EnvironmentObject private var lang: LanguageManager
    @AppStorage("prayerSoundPreference") private var soundPref          = "default"
    @AppStorage("prayerWarningMinutes")  private var warningMinutes     = 5
    @AppStorage("liveActivityEnabled")   private var liveActivityEnabled = true

    @State private var cityName = ""
    @State private var prayerTimes: [PrayerTime] = []
    @State private var isLoading = false
    @State private var hasData = false
    @State private var showSoundPicker = false
    @State private var showCalcPicker  = false
    @State private var lastFetchedDate: String = ""   // "yyyy-MM-dd" – for daily auto-refresh
    @State private var savedCities: [SavedCity] = []  // multi-city cache
    @State private var showCityHistory = false
    @State private var showQiblaSheet = false

    private var todayString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    // Countdown state
    @State private var nextPrayerName: String = ""
    @State private var nextPrayerDate: Date?  = nil
    @State private var countdownText: String  = ""
    @State private var currentTimeText: String = ""
    @State private var currentDateText: String = ""
    @State private var currentDayText:  String = ""
    @State private var currentHijriText: String = ""
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ──────────────────────────────────────────
                HStack(alignment: .bottom) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(lang.t("أوقات الصلاة", "Prayer Times"))
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(Theme.goldLight)
                        if !cityName.isEmpty {
                            HStack(spacing: 4) {
                                Text(cityName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Theme.textSecondary)
                                Image(systemName: "location.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.gold)
                            }
                        }
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        // ── Qibla button ──────────────────────────────
                        headerIconButton(
                            icon: "location.north.line.fill",
                            label: lang.t("القبلة", "Qibla"),
                            color: .teal
                        ) { showQiblaSheet = true }

                        if hasData {
                            // ── Calc method button ────────────────────
                            headerIconButton(
                                icon: "moon.stars.fill",
                                label: lang.t("الحساب", "Calc"),
                                color: .purple
                            ) { showCalcPicker = true }

                            // ── Sound button ──────────────────────────
                            headerIconButton(
                                icon: "bell.fill",
                                label: soundLabel,
                                color: Theme.gold
                            ) { showSoundPicker = true }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)

                // ── Date & Time Banner ───────────────────────────────
                DateTimeBanner(
                    dayName:   currentDayText,
                    gregDate:  currentDateText,
                    hijriDate: currentHijriText,
                    time:      currentTimeText
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

                // ── Next Prayer Countdown Banner ─────────────────────
                if hasData && !nextPrayerName.isEmpty {
                    NextPrayerBanner(prayerName: nextPrayerName, countdown: countdownText)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                }

                // ── Search row ──────────────────────────────────────
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        TextField(lang.t("اسم المدينة", "City name"), text: $cityName)
                            .font(.system(size: 14))
                            .foregroundColor(Theme.text)
                            .padding(12)
                            .background(Theme.card)
                            .cornerRadius(10)
                            .onSubmit { searchByCity() }

                        Button(action: searchByCity) {
                            Text(lang.t("بحث", "Search"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.background)
                                .frame(height: 44)
                                .frame(minWidth: 60)
                                .background(Theme.gold)
                                .cornerRadius(10)
                                .contentShape(Rectangle())
                        }
                    }

                    // Location button
                    Button(action: fetchByCurrentLocation) {
                        HStack(spacing: 6) {
                            if isLoading && !hasData {
                                ProgressView().scaleEffect(0.8).tint(Theme.gold)
                            } else {
                                Image(systemName: "location.fill").font(.system(size: 14))
                            }
                            Text(isLoading && !hasData ? lang.t("جاري التحديد...", "Detecting...") : lang.t("موقعي الحالي", "My Location"))
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(Theme.gold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(RoundedRectangle(cornerRadius: 10).stroke(Theme.gold, lineWidth: 1.5))
                        .contentShape(Rectangle())
                    }
                    .disabled(isLoading && !hasData)

                    if let err = loc.locationError {
                        Text(err).font(.system(size: 13)).foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                    }

                    // Recent cities chips
                    if !savedCities.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(savedCities) { city in
                                    Button {
                                        cityName = city.name
                                        loadFromSavedCity(city)
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "clock.arrow.circlepath")
                                                .font(.system(size: 10))
                                            Text(city.name)
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                        .foregroundColor(Theme.text)
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(Theme.card)
                                        .cornerRadius(20)
                                        .overlay(RoundedRectangle(cornerRadius: 20)
                                            .stroke(Theme.border, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }
                }
                .padding(.horizontal, 16)

                // ── Prayer list ─────────────────────────────────────
                if !hasData {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Theme.gold)
                        Text(lang.t("ابحث عن مدينتك أو استخدم موقعك الحالي", "Search for your city or use your current location"))
                            .font(.system(size: 15))
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .background(Theme.card)
                    .cornerRadius(14)
                    .padding(16)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 7) {
                            ForEach(prayerTimes) { p in
                                PrayerRow(prayer: p, isNext: isNextPrayer(p))
                            }

                            // Settings cards row
                            if hasData {
                                HStack(spacing: 8) {
                                    soundSettingsCard
                                    calcSettingsCard
                                }
                            }

                            // ── Moon phase card ─────────────────────
                            if hasData { MoonPhaseCard() }

                            // ── Friday hours card ───────────────────
                            if hasData {
                                FridayHoursCard(prayerTimes: prayerTimes)
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
        .onAppear {
            // Load multi-city cache
            savedCities = loadSavedCities()

            // ✅ Restore offline cache immediately (works without internet)
            if !hasData { restorePrayerTimesFromCache() }

            // Then try to refresh from network if date changed
            if let lat = loc.latitude, let lon = loc.longitude,
               (!hasData || lastFetchedDate != todayString) {
                fetchPrayerTimes(lat: lat, lon: lon)
            }
        }
        .onChange(of: loc.locationReceived) { received in
            if received, let lat = loc.latitude, let lon = loc.longitude {
                fetchPrayerTimes(lat: lat, lon: lon)
            }
        }
        .onChange(of: hasData) { ready in
            if ready { refreshNextPrayer() }
        }
        .onChange(of: liveActivityEnabled) { enabled in
            if #available(iOS 16.2, *) {
                if enabled, hasData {
                    Task { await startOrUpdateLiveActivity() }
                }
                // Disabling is handled by SettingsView via Activity.end()
            }
        }
        .onReceive(ticker) { _ in
            if hasData { updateCountdown() }
            updateDateTimeDisplay()
        }
        .onAppear { updateDateTimeDisplay() }
        .sheet(isPresented: $showSoundPicker) { soundPickerSheet }
        .sheet(isPresented: $showCalcPicker)  { calcPickerSheet  }
        .sheet(isPresented: $showQiblaSheet) { QiblaView() }
    }

    // MARK: - Countdown helpers

    private func refreshNextPrayer() {
        if let (name, date) = computeNextPrayer() {
            nextPrayerName = name
            nextPrayerDate = date
            updateCountdown()
            if #available(iOS 16.2, *) {
                // Only start Live Activity if the user has it enabled (default: true)
                let enabled = UserDefaults.standard.object(forKey: "liveActivityEnabled") as? Bool ?? true
                if enabled {
                    Task { await startOrUpdateLiveActivity() }
                }
            }
        }
    }

    // MARK: - Live Activity

    /// Builds a ContentState that contains ALL prayer times for today.
    /// The widget view computes next/following from the device clock at render time,
    /// so no per-prayer BGTask updates are needed — the island advances automatically.
    @available(iOS 16.2, *)
    func startOrUpdateLiveActivity() async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let enabled = UserDefaults.standard.object(forKey: "liveActivityEnabled") as? Bool ?? true
        guard enabled else {
            // User disabled the feature — end all active activities
            for activity in Activity<PrayerLiveActivityAttributes>.activities {
                await activity.end(dismissalPolicy: .immediate)
            }
            return
        }

        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        let now = Date()
        let cal = Calendar.current

        // Convert HH:mm strings → absolute Dates for today (device timezone)
        var prayerDates: [String: Date] = [:]
        for p in prayerTimes where p.name != "الشروق" {
            let clean = p.time.components(separatedBy: " ").first ?? p.time
            guard let parsed = fmt.date(from: clean) else { continue }
            var comps = cal.dateComponents([.hour, .minute], from: parsed)
            comps.year  = cal.component(.year,  from: now)
            comps.month = cal.component(.month, from: now)
            comps.day   = cal.component(.day,   from: now)
            if let full = cal.date(from: comps) {
                prayerDates[p.name] = full
            }
        }
        guard !prayerDates.isEmpty else { return }

        // staleDate = next midnight (tells iOS to refresh the activity tomorrow)
        var midnightComps        = cal.dateComponents([.year, .month, .day], from: now)
        midnightComps.hour       = 0
        midnightComps.minute     = 1
        let tomorrow             = cal.date(byAdding: .day, value: 1, to: now) ?? now
        var tomorrowComps        = cal.dateComponents([.year, .month, .day], from: tomorrow)
        tomorrowComps.hour       = 0
        tomorrowComps.minute     = 1
        let midnight             = cal.date(from: tomorrowComps) ?? now.addingTimeInterval(86_400)

        let state = PrayerLiveActivityAttributes.ContentState(
            prayerDates: prayerDates,
            expiresAt:   midnight,
            cityName:    cityName
        )
        let content = ActivityContent(state: state, staleDate: midnight)

        // End any existing activities, then start a fresh one
        for activity in Activity<PrayerLiveActivityAttributes>.activities {
            await activity.end(dismissalPolicy: .immediate)
        }

        let attrs = PrayerLiveActivityAttributes(appName: "القرآن الكريم")
        _ = try? Activity.request(attributes: attrs, content: content, pushType: nil)

        // Persist prayer times for BGTask daily refresh
        var timesDict: [String: String] = [:]
        prayerTimes.forEach { timesDict[$0.name] = $0.time }
        PrayerBackgroundRefresh.storePrayerTimes(timesDict, city: cityName)
    }

    private func updateDateTimeDisplay() {
        let now = Date()

        // ── Gregorian time (12h) ─────────────────────────────
        let timeFmt = DateFormatter()
        timeFmt.locale = Locale(identifier: "ar")
        timeFmt.dateFormat = "hh:mm:ss a"
        currentTimeText = timeFmt.string(from: now)

        // ── Gregorian date ────────────────────────────────────
        let dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: "ar")
        dateFmt.dateFormat = "d MMMM yyyy"
        currentDateText = dateFmt.string(from: now)

        // ── Day name ──────────────────────────────────────────
        let dayFmt = DateFormatter()
        dayFmt.locale = Locale(identifier: "ar")
        dayFmt.dateFormat = "EEEE"
        currentDayText = dayFmt.string(from: now)

        // ── Hijri date ────────────────────────────────────────
        let hijriCal = Calendar(identifier: .islamicUmmAlQura)
        let hijriFmt = DateFormatter()
        hijriFmt.locale = Locale(identifier: "ar")
        hijriFmt.calendar = hijriCal
        hijriFmt.dateFormat = "d MMMM yyyy هـ"
        currentHijriText = hijriFmt.string(from: now)
    }

    private func updateCountdown() {
        guard let target = nextPrayerDate else { return }
        let remaining = max(0, target.timeIntervalSinceNow)
        if remaining <= 0 {
            // Prayer passed — recalculate
            refreshNextPrayer(); return
        }
        let h = Int(remaining) / 3600
        let m = (Int(remaining) % 3600) / 60
        let s = Int(remaining) % 60
        countdownText = h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    private func computeNextPrayer() -> (String, Date)? {
        let now      = Date()
        let calendar = Calendar.current
        let fmt      = DateFormatter(); fmt.dateFormat = "HH:mm"
        let prayers  = prayerTimes.filter { $0.name != "الشروق" }

        for prayer in prayers {
            let clean = prayer.time.components(separatedBy: " ").first ?? prayer.time
            guard let t = fmt.date(from: clean) else { continue }
            var comps = calendar.dateComponents([.hour, .minute], from: t)
            comps.year  = calendar.component(.year,  from: now)
            comps.month = calendar.component(.month, from: now)
            comps.day   = calendar.component(.day,   from: now)
            if let full = calendar.date(from: comps), full > now { return (prayer.name, full) }
        }
        // After isha → fajr tomorrow
        if let fajr = prayers.first(where: { $0.name == "الفجر" }) {
            let clean = fajr.time.components(separatedBy: " ").first ?? fajr.time
            guard let t = fmt.date(from: clean) else { return nil }
            var comps = calendar.dateComponents([.hour, .minute], from: t)
            guard let tmrw = calendar.date(byAdding: .day, value: 1, to: now) else { return nil }
            comps.year  = calendar.component(.year,  from: tmrw)
            comps.month = calendar.component(.month, from: tmrw)
            comps.day   = calendar.component(.day,   from: tmrw)
            if let full = calendar.date(from: comps) { return (fajr.name, full) }
        }
        return nil
    }

    // MARK: - Sound Settings Card (shown at bottom of prayer list)

    @ViewBuilder
    private func headerIconButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(color)
            .frame(width: 52, height: 44)
            .background(color.opacity(0.12))
            .cornerRadius(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var soundSettingsCard: some View {
        Button(action: { showSoundPicker = true }) {
            HStack {
                Image(systemName: "bell.fill")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.gold)
                Text(lang.t("صوت التنبيه", "Alert Sound"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.text)
                Spacer()
                HStack(spacing: 4) {
                    Text(soundLabel)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.gold)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .padding(14)
            .background(Theme.card)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sound Picker Sheet

    private var soundPickerSheet: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text(lang.t("صوت تنبيه الصلاة", "Prayer Alert Sound"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Theme.goldLight)
                    Spacer()
                    Button(lang.t("تم", "Done")) { showSoundPicker = false }
                        .font(.system(size: 15))
                        .foregroundColor(Theme.gold)
                }
                .padding(16)

                Divider().background(Theme.border)

                ScrollView {
                    VStack(spacing: 12) {

                        // ── Section: General ────────────────────────────
                        VStack(spacing: 0) {
                            sectionHeader(lang.t("عام", "General"))
                            soundRow(id: "default", title: lang.t("صوت النظام", "System Sound"),
                                     subtitle: lang.t("التنبيه الافتراضي للجهاز", "Device default alert"), icon: "bell.fill")
                            Divider().background(Theme.border).padding(.horizontal, 16)
                            soundRow(id: "silent", title: lang.t("صامت", "Silent"),
                                     subtitle: lang.t("بدون صوت – إشعار بصري فقط", "No sound – visual notification only"), icon: "bell.slash.fill")
                        }
                        .background(Theme.card)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))

                        VStack(spacing: 0) {
                            sectionHeader(lang.t("تنبيه قبل الصلاة", "Before Prayer Alert"))
                            warningMinutesStepper
                        }
                        .background(Theme.card)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))

                        // ── Section: Muezzins ────────────────────────────
                        VStack(spacing: 0) {
                            sectionHeader(lang.t("أذان المؤذنين", "Muezzin Adhan"))
                            ForEach(Array(NotificationManager.muezzins.enumerated()), id: \.offset) { idx, muezzin in
                                soundRow(id: muezzin.id,
                                         title: muezzin.nameAr,
                                         subtitle: lang.t("29 ثانية من الأذان", "29 sec of Adhan"),
                                         icon: "waveform")
                                if idx < NotificationManager.muezzins.count - 1 {
                                    Divider().background(Theme.border).padding(.horizontal, 16)
                                }
                            }
                        }
                        .background(Theme.card)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))

                    }
                    .padding(16)
                }

                Spacer()
            }
        }
    }

    // MARK: - Calculation Settings Card

    private var calcSettingsCard: some View {
        Button(action: { showCalcPicker = true }) {
            HStack {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.purple)
                Text(lang.t("طريقة الحساب", "Calc Method"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.text)
                Spacer()
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(14)
            .background(Theme.card)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Calculation Picker Sheet

    private var calcPickerSheet: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text(lang.t("طريقة حساب أوقات الصلاة", "Prayer Time Calculation"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Theme.goldLight)
                    Spacer()
                    Button(lang.t("تم", "Done")) { showCalcPicker = false }
                        .font(.system(size: 15))
                        .foregroundColor(Theme.gold)
                }
                .padding(16)

                Divider().background(Theme.border)

                ScrollView {
                    VStack(spacing: 12) {
                        CalcMethodPickerSection {
                            if let lat = loc.latitude, let lon = loc.longitude {
                                fetchPrayerTimes(lat: lat, lon: lon)
                            }
                        }
                    }
                    .padding(16)
                }

                Spacer()
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.gold.opacity(0.08))
    }

    private func soundRow(id: String, title: String, subtitle: String, icon: String) -> some View {
        Button(action: {
            soundPref = id
            scheduleNotificationsIfPermitted()
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(soundPref == id ? Theme.gold : Theme.textSecondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15))
                        .foregroundColor(Theme.text)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
                if soundPref == id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.gold)
                        .font(.system(size: 18))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var warningMinutesStepper: some View {
        HStack(spacing: 10) {
            Image(systemName: warningMinutes == 0 ? "bell.slash.fill" : "timer")
                .font(.system(size: 16))
                .foregroundColor(Theme.gold)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(warningMinutes == 0
                     ? lang.t("بدون تنبيه مسبق", "No early alert")
                     : lang.t("قبل الصلاة بـ \(warningMinutes) دقائق", "\(warningMinutes) minutes before prayer"))
                    .font(.system(size: 15))
                    .foregroundColor(Theme.text)
                Text(lang.t("يعمل مع كل صلاة مجدولة", "Applies to every scheduled prayer"))
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Stepper("", value: $warningMinutes, in: 0...60, step: 5)
                .labelsHidden()
                .onChange(of: warningMinutes) { _ in
                    scheduleNotificationsIfPermitted()
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var soundLabel: String {
        if soundPref == "default" { return lang.t("صوت النظام", "System Sound") }
        if soundPref == "silent"  { return lang.t("صامت", "Silent") }
        return NotificationManager.muezzins.first(where: { $0.id == soundPref })?.nameAr ?? lang.t("صوت النظام", "System Sound")
    }

    // MARK: - Next Prayer Highlight

    private func isNextPrayer(_ p: PrayerTime) -> Bool {
        guard p.name != "الشروق" else { return false }
        let now = Date()
        let cal = Calendar.current
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        let times = prayerTimes.filter { $0.name != "الشروق" }
        for t in times {
            let clean = t.time.components(separatedBy: " ").first ?? t.time
            if let d = f.date(from: clean) {
                var c = cal.dateComponents([.hour, .minute], from: d)
                c.year = cal.component(.year, from: now)
                c.month = cal.component(.month, from: now)
                c.day = cal.component(.day, from: now)
                if let full = cal.date(from: c), full > now {
                    return t.id == p.id
                }
            }
        }
        // After isha → next is fajr
        return p.name == "الفجر"
    }

    // MARK: - Notifications (always active — schedule silently after every fetch)

    private func scheduleNotificationsIfPermitted(lat: Double? = nil, lon: Double? = nil, tz: TimeZone = .current) {
        NotificationManager.shared.requestPermission { _ in
            let storedLat = lat ?? Self.storedCoordinate(primaryKey: "last_prayer_lat", fallbackKey: "cachedLocationLat")
            let storedLon = lon ?? Self.storedCoordinate(primaryKey: "last_prayer_lng", fallbackKey: "cachedLocationLon")

            if let storedLat, let storedLon {
                NotificationManager.shared.schedulePrayerNotifications(
                    lat: storedLat,
                    lng: storedLon,
                    tz: tz,
                    sound: self.soundPref
                )
            } else {
                NotificationManager.shared.schedulePrayerNotifications(self.prayerTimes, sound: self.soundPref)
            }
            // جدولة الأذكار بأوقات نسبية لأوقات الصلاة (بحث §٥.٢)
            if UserDefaults.standard.bool(forKey: "azkarNotifsEnabled") {
                NotificationManager.shared.scheduleAzkarRelativeToPrayers(self.prayerTimes)
            }
            // تحديث تذكير سورة الكهف بوقت الظهر الجديد الدقيق
            IslamicCalendarService.shared.refreshFridayKahfIfEnabled()
        }
    }

    private static func storedCoordinate(primaryKey: String, fallbackKey: String) -> Double? {
        let ud = UserDefaults.standard
        let primary = ud.double(forKey: primaryKey)
        if primary != 0 { return primary }
        let fallback = ud.double(forKey: fallbackKey)
        return fallback != 0 ? fallback : nil
    }

    // MARK: - Fetch

    private func fetchByCurrentLocation() {
        isLoading = true
        loc.requestLocation()
    }

    private func reverseGeocode(lat: Double, lon: Double) {
        let location = CLLocation(latitude: lat, longitude: lon)
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
            if let place = placemarks?.first {
                let name = place.locality
                    ?? place.subAdministrativeArea
                    ?? place.administrativeArea
                    ?? place.country
                    ?? ""
                DispatchQueue.main.async { self.cityName = name }
            }
        }
    }

    private func searchByCity() {
        guard !cityName.isEmpty else { return }

        // 1. Check multi-city cache first (today's data)
        let today = todayString
        if let cached = savedCities.first(where: {
            $0.name.lowercased() == cityName.lowercased() && $0.date == today
        }) {
            loadFromSavedCity(cached)
            return
        }

        // 2. Geocode city name → coordinates, then calculate locally
        isLoading = true
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(cityName) { [self] placemarks, error in
            guard let place = placemarks?.first,
                  let loc2  = place.location else {
                DispatchQueue.main.async { self.isLoading = false }
                return
            }
            let tz = place.timeZone ?? TimeZone.current
            let resolvedName = place.locality ?? place.subAdministrativeArea
                               ?? place.administrativeArea ?? place.country ?? cityName
            DispatchQueue.main.async {
                self.cityName = resolvedName
            }
            self.calcAndApplyTimes(lat: loc2.coordinate.latitude,
                                   lon: loc2.coordinate.longitude,
                                   tz: tz, cityName: resolvedName)
        }
    }

    private func loadFromSavedCity(_ city: SavedCity) {
        let iconMap: [String: String] = [
            "الفجر": "moon.fill", "الشروق": "sunrise.fill",
            "الظهر": "sun.max.fill", "العصر": "sun.haze.fill",
            "المغرب": "sunset.fill", "العشاء": "moon.stars.fill"
        ]
        let order = ["الفجر", "الشروق", "الظهر", "العصر", "المغرب", "العشاء"]
        let times = order.compactMap { name -> PrayerTime? in
            guard let t = city.times[name] else { return nil }
            return PrayerTime(name: name, time: t, icon: iconMap[name] ?? "clock.fill")
        }
        guard !times.isEmpty else { return }
        prayerTimes = times
        cityName = city.name
        hasData = true
        lastFetchedDate = city.date
    }

    private func fetchPrayerTimes(lat: Double, lon: Double) {
        reverseGeocode(lat: lat, lon: lon)
        // ✅ Fully offline — local PrayTimes algorithm, no network needed
        let tz = TimeZone.current
        calcAndApplyTimes(lat: lat, lon: lon, tz: tz, cityName: cityName)
    }

    // MARK: - Local Calculation (fully offline, no API)

    private func calcAndApplyTimes(lat: Double, lon: Double, tz: TimeZone, cityName name: String) {
        let calc  = PrayerTimesCalculator.fromUserDefaults()
        let now   = Date()
        guard let result = calc.calculate(lat: lat, lon: lon, date: now, tz: tz) else {
            DispatchQueue.main.async { self.isLoading = false }
            return
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        fmt.timeZone   = tz

        let times: [PrayerTime] = [
            PrayerTime(name: "الفجر",  time: fmt.string(from: result.fajr),    icon: "moon.fill"),
            PrayerTime(name: "الشروق", time: fmt.string(from: result.sunrise),  icon: "sunrise.fill"),
            PrayerTime(name: "الظهر",  time: fmt.string(from: result.dhuhr),    icon: "sun.max.fill"),
            PrayerTime(name: "العصر",  time: fmt.string(from: result.asr),      icon: "sun.haze.fill"),
            PrayerTime(name: "المغرب", time: fmt.string(from: result.maghrib),  icon: "sunset.fill"),
            PrayerTime(name: "العشاء", time: fmt.string(from: result.isha),     icon: "moon.stars.fill"),
        ]
        DispatchQueue.main.async {
            if !name.isEmpty { self.cityName = name }
            self.prayerTimes = times
            self.hasData     = true
            self.isLoading   = false
            self.lastFetchedDate = self.todayString
            let ud = UserDefaults.standard
            ud.set(lat, forKey: "last_prayer_lat")
            ud.set(lon, forKey: "last_prayer_lng")
            self.scheduleNotificationsIfPermitted(lat: lat, lon: lon, tz: tz)
            self.writeWidgetData(times)
            self.savePrayerTimesOffline(times)
        }
    }

    @discardableResult
    private func parseOurTimes(_ data: Data) -> Bool {
        guard let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = json["success"] as? Bool, success else { return false }

        let prayers: [String: Any]?
        if let d = json["data"] as? [String: Any],
           let p = d["prayers"] as? [String: Any] {
            prayers = p
        } else {
            prayers = nil
        }

        func prayerTime(_ key: String) -> String? {
            if let p = prayers, let entry = p[key] as? [String: Any] {
                return entry["time"] as? String
            }
            return json[key] as? String
        }

        var times: [PrayerTime] = []
        if let v = prayerTime("fajr")    { times.append(.init(name: "الفجر",  time: v, icon: "moon.fill")) }
        if let v = prayerTime("sunrise") { times.append(.init(name: "الشروق", time: v, icon: "sunrise.fill")) }
        if let v = prayerTime("dhuhr")   { times.append(.init(name: "الظهر",  time: v, icon: "sun.max.fill")) }
        if let v = prayerTime("asr")     { times.append(.init(name: "العصر",  time: v, icon: "sun.haze.fill")) }
        if let v = prayerTime("maghrib") { times.append(.init(name: "المغرب", time: v, icon: "sunset.fill")) }
        if let v = prayerTime("isha")    { times.append(.init(name: "العشاء", time: v, icon: "moon.stars.fill")) }
        guard !times.isEmpty else { return false }
        DispatchQueue.main.async {
            self.prayerTimes = times
            self.hasData     = true
            self.isLoading   = false
            self.lastFetchedDate = self.todayString
            self.scheduleNotificationsIfPermitted()
            self.writeWidgetData(times)
            self.savePrayerTimesOffline(times)
        }
        return true
    }

    // MARK: - Offline Prayer Cache keys
    private static let offTimesKey  = "offline_prayer_times_v2"   // [String:String]
    private static let offCityKey   = "offline_prayer_city"
    private static let offDateKey   = "offline_prayer_date"

    private func savePrayerTimesOffline(_ times: [PrayerTime]) {
        var dict: [String: String] = [:]
        times.forEach { dict[$0.name] = $0.time }
        let ud = UserDefaults.standard
        ud.set(dict, forKey: Self.offTimesKey)
        ud.set(cityName, forKey: Self.offCityKey)
        ud.set(todayString, forKey: Self.offDateKey)

        // Save lat/lng so PrayerBackgroundRefresh can fetch without user opening app
        if let lat = loc.latitude, let lon = loc.longitude {
            ud.set(lat, forKey: "last_prayer_lat")
            ud.set(lon, forKey: "last_prayer_lng")
        }
        // Save for background refresh fire-at-prayer cache
        ud.set(dict, forKey: "bg_stored_prayer_times")
        if !cityName.isEmpty { ud.set(cityName, forKey: "bg_stored_city_name") }

        // Also save to multi-city cache (max 10 cities)
        guard !cityName.isEmpty else { return }
        var cities = loadSavedCities()
        // Remove old entry for same city
        cities.removeAll { $0.name.lowercased() == cityName.lowercased() }
        let newCity = SavedCity(name: cityName, date: todayString, times: dict)
        cities.insert(newCity, at: 0)
        if cities.count > 10 { cities = Array(cities.prefix(10)) }
        if let data = try? JSONEncoder().encode(cities) {
            ud.set(data, forKey: Self.savedCitiesKey)
        }
        savedCities = cities
    }

    private static let savedCitiesKey = "saved_prayer_cities_v1"

    private func loadSavedCities() -> [SavedCity] {
        guard let data = UserDefaults.standard.data(forKey: Self.savedCitiesKey),
              let cities = try? JSONDecoder().decode([SavedCity].self, from: data) else { return [] }
        return cities
    }

    private func restorePrayerTimesFromCache() {
        let ud = UserDefaults.standard
        // Accept cached times even from yesterday — better than nothing offline
        guard let dict = ud.dictionary(forKey: Self.offTimesKey) as? [String: String],
              !dict.isEmpty else { return }

        let iconMap: [String: String] = [
            "الفجر": "moon.fill", "الشروق": "sunrise.fill",
            "الظهر": "sun.max.fill", "العصر": "sun.haze.fill",
            "المغرب": "sunset.fill", "العشاء": "moon.stars.fill"
        ]
        let order = ["الفجر", "الشروق", "الظهر", "العصر", "المغرب", "العشاء"]
        let times = order.compactMap { name -> PrayerTime? in
            guard let t = dict[name] else { return nil }
            return PrayerTime(name: name, time: t, icon: iconMap[name] ?? "clock.fill")
        }
        guard !times.isEmpty else { return }

        prayerTimes = times
        hasData     = true
        lastFetchedDate = ud.string(forKey: Self.offDateKey) ?? ""
        if let saved = ud.string(forKey: Self.offCityKey) { cityName = saved }
    }

    private func parseTimes(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let d = json["data"] as? [String: Any],
              let t = d["timings"] as? [String: String] else {
            DispatchQueue.main.async { self.isLoading = false }
            return
        }
        var times: [PrayerTime] = []
        if let v = t["Fajr"]    { times.append(.init(name: "الفجر",  time: v, icon: "moon.fill")) }
        if let v = t["Sunrise"] { times.append(.init(name: "الشروق", time: v, icon: "sunrise.fill")) }
        if let v = t["Dhuhr"]   { times.append(.init(name: "الظهر",  time: v, icon: "sun.max.fill")) }
        if let v = t["Asr"]     { times.append(.init(name: "العصر",  time: v, icon: "sun.haze.fill")) }
        if let v = t["Maghrib"] { times.append(.init(name: "المغرب", time: v, icon: "sunset.fill")) }
        if let v = t["Isha"]    { times.append(.init(name: "العشاء", time: v, icon: "moon.stars.fill")) }
        DispatchQueue.main.async {
            self.prayerTimes = times
            self.hasData = true
            self.isLoading = false
            self.lastFetchedDate = self.todayString
            self.scheduleNotificationsIfPermitted()
            self.writeWidgetData(times)
            // ✅ Persist for offline use
            self.savePrayerTimesOffline(times)
        }
    }

    // MARK: - Write to Widget shared defaults

    private func writeWidgetData(_ times: [PrayerTime]) {
        // App Group must match QuranWidgetBundle.swift: "group.tech.meshari.QuranApp"
        let appGroupID = "group.tech.meshari.QuranApp"
        guard let ud = UserDefaults(suiteName: appGroupID) else { return }

        var dict: [String: String] = [:]
        times.forEach { dict[$0.name] = $0.time }
        ud.set(dict, forKey: "widget_prayerTimings")
        ud.set(cityName, forKey: "widget_cityName")
        ud.set(Date().timeIntervalSince1970, forKey: "widget_updatedAt")

        if let (name, date) = computeNextPrayer() {
            ud.set(name, forKey: "widget_nextPrayer")
            ud.set(date.timeIntervalSince1970, forKey: "widget_nextPrayerDate")
        }

        // Reload all widgets
        // Notify WidgetKit to reload so countdown + next prayer update immediately
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - DateTimeBanner

private struct DateTimeBanner: View {
    let dayName:   String
    let gregDate:  String
    let hijriDate: String
    let time:      String

    var body: some View {
        HStack(alignment: .center, spacing: 0) {

            // ── Left: Hijri + Gregorian date ────────────────
            VStack(alignment: .leading, spacing: 3) {
                Text(hijriDate)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.gold)
                Text(gregDate)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            // ── Center: Day name ─────────────────────────────
            Text(dayName)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Theme.goldLight)

            Spacer()

            // ── Right: Current time ───────────────────────────
            Text(time)
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .foregroundColor(Theme.text)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

// MARK: - NextPrayerBanner

private struct NextPrayerBanner: View {
    let prayerName: String
    let countdown: String
    @EnvironmentObject private var lang: LanguageManager

    private let prayerIcons: [String: String] = [
        "الفجر": "moon.fill", "الظهر": "sun.max.fill", "العصر": "sun.haze.fill",
        "المغرب": "sunset.fill", "العشاء": "moon.stars.fill"
    ]

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle().fill(Theme.gold.opacity(0.18)).frame(width: 44, height: 44)
                Image(systemName: prayerIcons[prayerName] ?? "clock.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Theme.goldLight)
            }

            VStack(alignment: .trailing, spacing: 3) {
                Text(lang.t("الصلاة القادمة", "Next Prayer"))
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                Text(prayerName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.goldLight)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 3) {
                Text(lang.t("الوقت المتبقي", "Time Remaining"))
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                Text(countdown)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.gold)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.gold.opacity(0.4), lineWidth: 1.5)
        )
    }
}

// MARK: - PrayerRow

private struct PrayerRow: View {
    let prayer: PrayerTime
    let isNext: Bool
    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isNext ? Theme.gold.opacity(0.25) : Theme.gold.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: prayer.icon)
                    .font(.system(size: 17))
                    .foregroundColor(isNext ? Theme.goldLight : Theme.gold)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 5) {
                    if isNext {
                        Text(lang.t("التالية", "Next"))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Theme.background)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Theme.gold)
                            .cornerRadius(4)
                    }
                    Text(prayer.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isNext ? Theme.goldLight : Theme.text)
                }
                Text(prayer.time12h)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(isNext ? Theme.goldLight : Theme.text)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Theme.card)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isNext ? Theme.gold.opacity(0.5) : Theme.border, lineWidth: isNext ? 1.5 : 1)
        )
    }
}

// MARK: - Moon Phase Card

struct MoonPhaseCard: View {

    // ── Moon phase calculation ────────────────────────────────────
    private var moonData: (phase: Double, name: String, arabicName: String,
                           illumination: Double, icon: String) {
        // Known new moon: Jan 6 2000 at 18:14 UTC → JDE 2451550.259
        let now = Date()
        let jde  = now.timeIntervalSince1970 / 86400.0 + 2440587.5
        let knownNewMoon = 2451550.259
        let cycleLen = 29.53059
        let raw = ((jde - knownNewMoon) / cycleLen)
            .truncatingRemainder(dividingBy: 1.0)
        let phase = raw < 0 ? raw + 1.0 : raw

        // illumination approximation
        let illum = (1 - cos(phase * 2 * .pi)) / 2 * 100

        switch phase {
        case 0..<0.03, 0.97...1.0:
            return (phase, "New Moon",      "المحاق",         illum, "moonphase.new.moon")
        case 0.03..<0.23:
            return (phase, "Waxing Crescent","هلال متزايد",    illum, "moonphase.waxing.crescent")
        case 0.23..<0.27:
            return (phase, "First Quarter", "التربيع الأول",   illum, "moonphase.first.quarter")
        case 0.27..<0.47:
            return (phase, "Waxing Gibbous","أحدب متزايد",    illum, "moonphase.waxing.gibbous")
        case 0.47..<0.53:
            return (phase, "Full Moon",     "البدر الكامل",   illum, "moonphase.full.moon")
        case 0.53..<0.73:
            return (phase, "Waning Gibbous","أحدب متناقص",   illum, "moonphase.waning.gibbous")
        case 0.73..<0.77:
            return (phase, "Last Quarter",  "التربيع الأخير", illum, "moonphase.last.quarter")
        default:
            return (phase, "Waning Crescent","هلال متناقص",   illum, "moonphase.waning.crescent")
        }
    }

    private var hijriDay: String {
        let cal = Calendar(identifier: .islamicUmmAlQura)
        let day = cal.component(.day, from: Date())
        return "\(day)"
    }

    var body: some View {
        let m = moonData
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "moon.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.cyan.opacity(0.9))
                    Text("حالة القمر")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.text)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().background(Theme.border)

            HStack(spacing: 20) {
                // Moon icon
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(red:0.1,green:0.1,blue:0.25),
                                         Color(red:0.05,green:0.05,blue:0.15)],
                                center: .center,
                                startRadius: 0, endRadius: 48
                            )
                        )
                        .frame(width: 96, height: 96)

                    Image(systemName: m.icon)
                        .font(.system(size: 54))
                        .foregroundStyle(.white, Color(red:0.12,green:0.12,blue:0.28))
                        .symbolRenderingMode(.palette)
                }

                VStack(alignment: .trailing, spacing: 10) {
                    // Phase name
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(m.arabicName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Theme.goldLight)
                        Text(m.name)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                    }

                    Divider().background(Theme.border)

                    // Stats row
                    HStack(spacing: 16) {
                        VStack(spacing: 2) {
                            Text(String(format: "%.0f%%", m.illumination))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Theme.gold)
                            Text("الإضاءة")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textSecondary)
                        }
                        VStack(spacing: 2) {
                            Text("\(hijriDay)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Theme.gold)
                            Text("يوم هجري")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }

                    // Progress bar
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.card)
                                .frame(height: 5)
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [.cyan.opacity(0.6), .white.opacity(0.9)],
                                    startPoint: .leading, endPoint: .trailing))
                                .frame(width: g.size.width * m.phase, height: 5)
                        }
                    }
                    .frame(height: 5)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(16)
        }
        .background(
            LinearGradient(
                colors: [Color(red:0.06,green:0.06,blue:0.18),
                         Color(red:0.04,green:0.04,blue:0.12)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius:16)
            .stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}

// MARK: - Friday Hours Card (ساعات الجمعة)

struct FridayHoursCard: View {
    let prayerTimes: [PrayerTime]

    private var isFriday: Bool {
        Calendar.current.component(.weekday, from: Date()) == 6 // 6 = Friday
    }

    private var fridayHours: [Date] {
        guard let fajrStr = prayerTimes.first(where: { $0.name == "الفجر" })?.time,
              let dhuhrStr = prayerTimes.first(where: { $0.name == "الظهر" })?.time
        else { return [] }

        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        guard let fajrDate = fmt.date(from: fajrStr.components(separatedBy: " ").first ?? fajrStr),
              let dhuhrDate = fmt.date(from: dhuhrStr.components(separatedBy: " ").first ?? dhuhrStr)
        else { return [] }

        // Combine with today's date
        var fComp = cal.dateComponents([.hour,.minute], from: fajrDate)
        var dComp = cal.dateComponents([.hour,.minute], from: dhuhrDate)
        fComp.year  = cal.component(.year,  from: today)
        fComp.month = cal.component(.month, from: today)
        fComp.day   = cal.component(.day,   from: today)
        dComp.year  = fComp.year
        dComp.month = fComp.month
        dComp.day   = fComp.day

        guard let fajr  = cal.date(from: fComp),
              let dhuhr = cal.date(from: dComp)
        else { return [] }

        let totalSec = dhuhr.timeIntervalSince(fajr)
        guard totalSec > 0 else { return [] }
        let interval = totalSec / 5.0

        return (0..<5).map { i in fajr.addingTimeInterval(Double(i) * interval) }
    }

    private var currentHourIndex: Int? {
        let now = Date()
        let hours = fridayHours
        guard hours.count == 5 else { return nil }
        for i in 0..<(hours.count - 1) {
            if now >= hours[i] && now < hours[i+1] { return i }
        }
        if let last = hours.last, now >= last { return hours.count - 1 }
        return nil
    }

    private let ordinals = ["الأولى","الثانية","الثالثة","الرابعة","الخامسة"]

    var body: some View {
        let hours = fridayHours
        let currentIdx = currentHourIndex

        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green.opacity(0.9))
                    Text("ساعات الجمعة")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.text)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().background(Theme.border)

            if hours.isEmpty {
                Text("يتوفر عند معرفة أوقات الصلاة")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
                    .padding(16)
            } else {
                // 5 hours row
                HStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { i in
                        let isActive = isFriday && currentIdx == i
                        let isPast   = isFriday && (currentIdx ?? -1) > i

                        VStack(spacing: 5) {
                            Text(ordinals[i])
                                .font(.system(size: 10, weight: isActive ? .bold : .regular))
                                .foregroundColor(isActive ? Theme.goldLight :
                                                  isPast  ? Theme.textSecondary.opacity(0.5)
                                                          : Theme.textSecondary)

                            let fmt = DateFormatter()
                            let _ = { fmt.dateFormat = "h:mm" }()
                            Text(fmt.string(from: hours[i]))
                                .font(.system(size: 13, weight: isActive ? .bold : .medium))
                                .foregroundColor(isActive ? Theme.goldLight :
                                                  isPast  ? Theme.textSecondary.opacity(0.5)
                                                          : Theme.text)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isActive ? Theme.gold.opacity(0.15) : Color.clear)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isActive ? Theme.gold.opacity(0.5) : Color.clear,
                                        lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                Divider().background(Theme.border).padding(.horizontal, 16)

                // Hadith
                Text("«من اغتسل يوم الجمعة غسل الجنابة ثم راح، فكأنما قرَّب بَدَنَة، ومن راح في الساعة الثانية فكأنما قرَّب بقرة، ومن راح في الساعة الثالثة فكأنما قرَّب كبشاً أقرن، ومن راح في الساعة الرابعة فكأنما قرَّب دجاجة، ومن راح في الساعة الخامسة فكأنما قرَّب بيضة، فإذا خرج الإمام حضرت الملائكة يستمعون الذكر»")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.trailing)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                if !isFriday {
                    Text("• الساعات تُحدَّث كل جمعة •")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textSecondary.opacity(0.5))
                        .padding(.bottom, 6)
                }
            }
        }
        .background(Theme.card)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius:16)
            .stroke(Theme.border, lineWidth: 1))
    }
}

// MARK: - Calculation Method Picker Section

private struct CalcMethodPickerSection: View {
    var onChanged: () -> Void

    @State private var selectedMethod:  Int = UserDefaults.standard.integer(forKey: PrayerTimesCalculator.methodKey) == 0
                                            ? PrayerCalculationMethod.makkah.rawValue
                                            : UserDefaults.standard.integer(forKey: PrayerTimesCalculator.methodKey)
    @State private var selectedAsr:     Int = UserDefaults.standard.integer(forKey: PrayerTimesCalculator.asrKey) == 0
                                            ? AsrMethod.shafii.rawValue
                                            : UserDefaults.standard.integer(forKey: PrayerTimesCalculator.asrKey)

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.gold)
                Text("طريقة الحساب")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Theme.gold.opacity(0.08))

            // Calculation Method rows
            ForEach(PrayerCalculationMethod.allCases, id: \.rawValue) { method in
                Button {
                    selectedMethod = method.rawValue
                    UserDefaults.standard.set(method.rawValue, forKey: PrayerTimesCalculator.methodKey)
                    onChanged()
                } label: {
                    HStack {
                        Text(method.nameAr)
                            .font(.system(size: 13))
                            .foregroundColor(Theme.text)
                        Spacer()
                        if selectedMethod == method.rawValue {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Theme.gold)
                                .font(.system(size: 16))
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if method != PrayerCalculationMethod.allCases.last {
                    Divider().background(Theme.border).padding(.horizontal, 16)
                }
            }

            Divider().background(Theme.border).padding(.horizontal, 16)

            // Asr method
            HStack {
                Image(systemName: "sun.haze.fill")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.gold)
                Text("حساب العصر")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Theme.gold.opacity(0.05))

            ForEach(AsrMethod.allCases, id: \.rawValue) { m in
                Button {
                    selectedAsr = m.rawValue
                    UserDefaults.standard.set(m.rawValue, forKey: PrayerTimesCalculator.asrKey)
                    onChanged()
                } label: {
                    HStack {
                        Text(m.nameAr)
                            .font(.system(size: 13))
                            .foregroundColor(Theme.text)
                        Spacer()
                        if selectedAsr == m.rawValue {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Theme.gold)
                                .font(.system(size: 16))
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if m != AsrMethod.allCases.last {
                    Divider().background(Theme.border).padding(.horizontal, 16)
                }
            }
        }
        .background(Theme.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }
}
