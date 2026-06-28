import SwiftUI
import WidgetKit

// MARK: - HomeView

struct HomeView: View {
    @ObservedObject private var loc   = SharedLocationManager.shared
    @ObservedObject private var stats = ReadingStatsService.shared
    @EnvironmentObject private var lang: LanguageManager

    // Prayer countdown
    @State private var prayerTimes: [PrayerTime] = []
    @State private var nextPrayerName = ""
    @State private var nextPrayerTime = ""
    @State private var nextPrayerDate: Date? = nil
    @State private var prevPrayerDate: Date? = nil  // start of current interval
    @State private var countdownText  = ""
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Last reading (cached in @State so it refreshes on every onAppear)
    @State private var lastReadEntry: (Surah, Int)? = nil

    // Navigation
    @State private var navigateToSurah: Surah? = nil
    @State private var navigateToPage: Int = 0

    // Quick notification sheet
    @State private var showNotifSheet = false

    // Qibla mini-compass
    @State private var qiblaAngle: Double = 0
    @State private var qiblaCalculated = false
    @State private var showQiblaFull = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {

                        // ── بانر التحديث (يظهر فقط عند وجود إصدار جديد) ──
                        AppUpdateBanner()

                        // ── Header ─────────────────────────────────────
                        headerSection

                        // ── Next Prayer ─────────────────────────────────
                        nextPrayerCard

                        // ── Qibla Mini Compass ───────────────────────────
                        miniQiblaCard

                        // ── Last Reading ────────────────────────────────
                        lastReadingCard

                        // ── Moon Phase ──────────────────────────────────
                        MoonPhaseCard()

                        // ── Reading Stats ────────────────────────────────
                        readingStatsCard

                        // ── Quick Links ─────────────────────────────────
                        quickLinksRow

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { navigateToSurah != nil },
                set: { if !$0 { navigateToSurah = nil } }
            )) {
                if let surah = navigateToSurah {
                    QuranReaderView(surah: surah)
                }
            }
        }
        .onAppear {
            loadPrayerTimes()
            stats.refreshStats()
            lastReadEntry = findLastRead()
            loc.startHeadingUpdates()
            if let lat = loc.latitude, let lon = loc.longitude {
                computeQiblaAngle(lat: lat, lon: lon)
            }
        }
        .onChange(of: loc.locationReceived) { _ in
            loadPrayerTimes()
            if let lat = loc.latitude, let lon = loc.longitude {
                computeQiblaAngle(lat: lat, lon: lon)
            }
        }
        .onReceive(ticker) { _ in updateCountdown() }
        .sheet(isPresented: $showNotifSheet) {
            QuickNotifSheet()
        }
        .sheet(isPresented: $showQiblaFull) {
            QiblaView()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .trailing, spacing: 4) {
                Text(greetingText)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Theme.goldLight)
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.gold)
                    Text(hijriDate)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            Spacer()
            // Notification bell shortcut button
            Button(action: { showNotifSheet = true }) {
                ZStack {
                    Circle()
                        .fill(Theme.card)
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                    Image(systemName: "bell.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.gold)
                }
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)

            // App logo
            ZStack {
                Circle()
                    .fill(Theme.gold.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Next Prayer Card

    private var nextPrayerCard: some View {
        VStack(spacing: 0) {
            // top label
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(.green)
                        .frame(width: 7, height: 7)
                    Text("الصلاة القادمة")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.text)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().background(Theme.border)

            HStack(alignment: .center, spacing: 16) {
                // Prayer icon + name
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(Theme.gold.opacity(0.15))
                            .frame(width: 52, height: 52)
                        Image(systemName: prayerIcon(nextPrayerName))
                            .font(.system(size: 22))
                            .foregroundColor(Theme.goldLight)
                    }
                    Text(nextPrayerName.isEmpty ? "---" : nextPrayerName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.goldLight)
                    if !nextPrayerTime.isEmpty {
                        Text(nextPrayerTime)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .frame(width: 80)

                // Divider
                Rectangle()
                    .fill(Theme.border)
                    .frame(width: 1, height: 80)

                // Countdown
                VStack(alignment: .trailing, spacing: 6) {
                    Text("بقي على الصلاة")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                    Text(countdownText.isEmpty ? "--:--" : countdownText)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.gold)
                        .monospacedDigit()

                    // Progress arc
                    if let next = nextPrayerDate, let prev = prevPrayerDate {
                        let total   = next.timeIntervalSince(prev)
                        let elapsed = Date().timeIntervalSince(prev)
                        let prog    = max(0, min(1, total > 0 ? elapsed / total : 0))

                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Theme.border)
                                    .frame(height: 5)
                                Capsule()
                                    .fill(LinearGradient(
                                        colors: [Theme.gold.opacity(0.7), Theme.goldLight],
                                        startPoint: .leading, endPoint: .trailing))
                                    .frame(width: g.size.width * prog, height: 5)
                            }
                        }
                        .frame(height: 5)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(16)
        }
        .background(Theme.card)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(Theme.gold.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Last Reading Card

    private var lastReadingCard: some View {
        let lastEntry = lastReadEntry   // uses @State refreshed in onAppear
        return VStack(spacing: 0) {
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.gold)
                    Text("آخر موقف قراءة")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.text)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().background(Theme.border)

            if let (surah, page) = lastEntry {
                HStack(spacing: 14) {
                    // Surah number badge
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.gold.opacity(0.15))
                            .frame(width: 54, height: 54)
                        VStack(spacing: 1) {
                            Text("\(surah.id)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Theme.gold)
                            Text("سورة")
                                .font(.system(size: 9))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(surah.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Theme.text)
                        HStack(spacing: 8) {
                            Text("صفحة \(page)")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.gold)
                            Text("•")
                                .foregroundColor(Theme.border)
                            Text("\(surah.verses) آية")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textSecondary)
                            Text("•")
                                .foregroundColor(Theme.border)
                            Text(surah.type)
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)

                    // Continue button
                    Button {
                        navigateToPage  = page
                        navigateToSurah = surah
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14))
                            Text("تابع")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(Theme.background)
                        .frame(width: 44, height: 44)
                        .background(Theme.gold)
                        .cornerRadius(12)
                    }
                }
                .padding(16)

                // Reading progress bar for this surah
                let progress = surahProgress(surah: surah, page: page)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Theme.border).frame(height: 3)
                        Rectangle()
                            .fill(Theme.gold.opacity(0.7))
                            .frame(width: g.size.width * progress, height: 3)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            } else {
                HStack(spacing: 12) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 28))
                        .foregroundColor(Theme.textSecondary.opacity(0.4))
                    Text("لم تبدأ القراءة بعد — افتح أي سورة لتبدأ")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
            }
        }
        .background(Theme.card)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Reading Stats Card

    private var readingStatsCard: some View {
        let todayPages  = stats.todayPages
        let weekPages   = stats.weeklyPages
        let totalPages  = stats.totalPages
        let streakDays  = stats.streak

        return HStack(spacing: 0) {
            statItem(value: "\(todayPages)", label: "صفحات اليوم",  icon: "sun.max.fill",    color: .orange)
            Divider().background(Theme.border).frame(height: 44)
            statItem(value: "\(weekPages)",  label: "هذا الأسبوع",  icon: "calendar.badge.clock", color: .cyan)
            Divider().background(Theme.border).frame(height: 44)
            statItem(value: "\(streakDays)", label: "أيام متتالية", icon: "flame.fill",       color: .red)
            Divider().background(Theme.border).frame(height: 44)
            statItem(value: "\(totalPages)", label: "إجمالي",       icon: "books.vertical.fill", color: Theme.gold)
        }
        .padding(.vertical, 12)
        .background(Theme.card)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Theme.text)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Mini Qibla Compass Card

    private var miniQiblaCard: some View {
        Button(action: { showQiblaFull = true }) {
            HStack(spacing: 16) {

                // ── Rotating compass disc ──────────────────────────
                // The whole disc (including N/S/E/W marks) rotates with
                // the phone heading. The Qibla arrow is at qiblaAngle on
                // the disc → arrives at top when heading == qiblaAngle.
                ZStack {
                    // Compass rose background
                    Circle()
                        .fill(Color.teal.opacity(0.12))
                        .frame(width: 62, height: 62)
                    Circle()
                        .stroke(Color.teal.opacity(0.25), lineWidth: 1)
                        .frame(width: 62, height: 62)

                    // Cardinal marks (N, S, E, W tick lines)
                    ForEach([0, 90, 180, 270], id: \.self) { deg in
                        Rectangle()
                            .fill(Color.teal.opacity(0.4))
                            .frame(width: 1, height: 5)
                            .offset(y: -26)
                            .rotationEffect(.degrees(Double(deg)))
                    }
                    // North "N" label
                    Text("N")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.teal.opacity(0.6))
                        .offset(y: -19)

                    // Qibla pin — placed at qiblaAngle on the disc
                    if qiblaCalculated {
                        Image(systemName: "location.north.line.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.teal)
                            .rotationEffect(.degrees(qiblaAngle))
                    }
                }
                .rotationEffect(
                    .degrees(qiblaCalculated ? -loc.compassHeading : 0)
                )
                .animation(.interpolatingSpring(stiffness: 130, damping: 16),
                           value: loc.compassHeading)

                // ── Labels ───────────────────────────────────────────
                VStack(alignment: .trailing, spacing: 4) {
                    Text("البوصلة")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.text)
                    Text(qiblaCalculated
                         ? "اتجاه القبلة \(Int(qiblaAngle))° — حرّك الجهاز حتى يصل السهم للأعلى"
                         : "جارٍ تحديد الموقع...")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.trailing)
                }

                Spacer()

                Image(systemName: "chevron.left")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(14)
            .background(Theme.card)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.teal.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func computeQiblaAngle(lat: Double, lon: Double) {
        let kaabaLat = 21.4225, kaabaLon = 39.8262
        let lat1 = lat * .pi / 180, lon1 = lon * .pi / 180
        let lat2 = kaabaLat * .pi / 180, lon2 = kaabaLon * .pi / 180
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        qiblaAngle = fmod(atan2(y, x) * 180 / .pi + 360, 360)
        qiblaCalculated = true
    }

    // MARK: - Quick Links

    private var quickLinksRow: some View {
        VStack(alignment: .trailing, spacing: 10) {
            Text("وصول سريع")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)

            LazyVGrid(columns: [
                GridItem(.flexible()), GridItem(.flexible()),
                GridItem(.flexible()), GridItem(.flexible()),
                GridItem(.flexible()), GridItem(.flexible())
            ], spacing: 10) {
                quickLink(icon: "location.north.line.fill", label: "القبلة",
                          color: .teal, dest: AnyView(QiblaView()))
                quickLink(icon: "square.grid.2x2.fill", label: "المزيد",
                          color: .blue, dest: AnyView(MuslimToolsView()))
                quickLink(icon: "questionmark.circle.fill", label: "الفتاوى",
                          color: .purple, dest: AnyView(FatwaListView()))
                quickLink(icon: "scalemass.fill", label: "الزكاة",
                          color: .orange, dest: AnyView(ZakatCalculatorView()))
                quickLink(icon: "text.book.closed.fill", label: "الأربعون",
                          color: .indigo, dest: AnyView(NawawiHadithView()))
                quickLink(icon: "building.columns.fill", label: "المواقيت",
                          color: .green, dest: AnyView(PrayerTimesView()))
            }
        }
    }

    @ViewBuilder
    private func quickLink(icon: String, label: String, color: Color, dest: AnyView) -> some View {
        NavigationLink(destination: dest) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.15))
                        .frame(height: 52)
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(color)
                }
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.text)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var greetingText: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 4..<12: return "صباح الخير 🌅"
        case 12..<17: return "مساء النور ☀️"
        case 17..<20: return "مساء الخير 🌇"
        default:      return "تصبح على خير 🌙"
        }
    }

    private var hijriDate: String {
        IslamicCalendarService.shared.currentHijriDate().formatted
    }

    private func prayerIcon(_ name: String) -> String {
        switch name {
        case "الفجر":  return "moon.fill"
        case "الشروق": return "sunrise.fill"
        case "الظهر":  return "sun.max.fill"
        case "العصر":  return "sun.haze.fill"
        case "المغرب": return "sunset.fill"
        case "العشاء": return "moon.stars.fill"
        default:        return "clock.fill"
        }
    }

    // ── Last Read ────────────────────────────────────────────────
    private func findLastRead() -> (Surah, Int)? {
        // Check UserDefaults for a globally-saved last surah ID
        let ud = UserDefaults.standard
        if let lastId = ud.object(forKey: "home_lastSurahId") as? Int,
           let surah  = allSurahs.first(where: { $0.id == lastId }) {
            let page = ud.integer(forKey: "lastPage_\(lastId)")
            if page > 0 { return (surah, page) }
        }
        // Fallback: scan all surahs and find one with highest lastPage
        var best: (Surah, Int)? = nil
        for s in allSurahs {
            let p = ud.integer(forKey: "lastPage_\(s.id)")
            if p > 0 {
                if best == nil || p > (best?.1 ?? 0) { best = (s, p) }
            }
        }
        return best
    }

    private func surahProgress(surah: Surah, page: Int) -> Double {
        guard let next = allSurahs.first(where: { $0.id == surah.id + 1 }) else {
            return Double(page - surah.page) / max(1, Double(604 - surah.page))
        }
        let total = Double(next.page - surah.page)
        let done  = Double(page - surah.page)
        return min(1, max(0, total > 0 ? done / total : 0))
    }

    // ── Prayer Time Helpers ──────────────────────────────────────
    private func loadPrayerTimes() {
        let ud    = UserDefaults.standard
        let order = ["الفجر","الشروق","الظهر","العصر","المغرب","العشاء"]
        let icons = ["الفجر":"moon.fill","الشروق":"sunrise.fill","الظهر":"sun.max.fill",
                     "العصر":"sun.haze.fill","المغرب":"sunset.fill","العشاء":"moon.stars.fill"]

        // Read from the same key used by PrayerTimesView (offline_prayer_times_v2)
        guard let dict = ud.dictionary(forKey: "offline_prayer_times_v2") as? [String: String],
              !dict.isEmpty else {
            // Cache is empty (first launch before PrayerTimesView visited) — fetch from server
            Task { await fetchPrayerTimesFromServer() }
            return
        }
        let times = order.compactMap { name -> PrayerTime? in
            guard let t = dict[name] else { return nil }
            return PrayerTime(name: name, time: t, icon: icons[name] ?? "clock.fill")
        }
        if !times.isEmpty {
            prayerTimes = times
            refreshNextPrayer()
        }
    }

    private func refreshNextPrayer() {
        guard let (name, date) = computeNextPrayer() else { return }
        nextPrayerName = name
        nextPrayerDate = date

        // Format time
        let fmt = DateFormatter(); fmt.dateFormat = "h:mm"
        let h = Calendar.current.component(.hour, from: date)
        nextPrayerTime = "\(fmt.string(from: date)) \(h < 12 ? "ص" : "م")"

        // prevPrayerDate = previous prayer date for progress bar
        let prayers = prayerTimes.filter { $0.name != "الشروق" }
        let fmt2 = DateFormatter(); fmt2.dateFormat = "HH:mm"
        let now = Date(), cal = Calendar.current
        if let idx = prayers.firstIndex(where: { $0.name == name }), idx > 0 {
            let prev = prayers[idx - 1]
            let clean = prev.time.components(separatedBy: " ").first ?? prev.time
            if let t = fmt2.date(from: clean) {
                var comps = cal.dateComponents([.hour,.minute], from: t)
                comps.year  = cal.component(.year,  from: now)
                comps.month = cal.component(.month, from: now)
                comps.day   = cal.component(.day,   from: now)
                prevPrayerDate = cal.date(from: comps)
            }
        }
        updateCountdown()
    }

    private func updateCountdown() {
        guard let target = nextPrayerDate else { return }
        let remaining = max(0, target.timeIntervalSinceNow)
        if remaining <= 0 { refreshNextPrayer(); return }
        let h = Int(remaining) / 3600
        let m = (Int(remaining) % 3600) / 60
        let s = Int(remaining) % 60
        countdownText = h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    private func computeNextPrayer() -> (String, Date)? {
        let now  = Date()
        let cal  = Calendar.current
        let fmt  = DateFormatter(); fmt.dateFormat = "HH:mm"
        let prayers = prayerTimes.filter { $0.name != "الشروق" }
        for p in prayers {
            let clean = p.time.components(separatedBy: " ").first ?? p.time
            guard let t = fmt.date(from: clean) else { continue }
            var comps = cal.dateComponents([.hour,.minute], from: t)
            comps.year  = cal.component(.year,  from: now)
            comps.month = cal.component(.month, from: now)
            comps.day   = cal.component(.day,   from: now)
            if let full = cal.date(from: comps), full > now { return (p.name, full) }
        }
        if let fajr = prayers.first(where: { $0.name == "الفجر" }) {
            let clean = fajr.time.components(separatedBy: " ").first ?? fajr.time
            guard let t = fmt.date(from: clean) else { return nil }
            var comps = cal.dateComponents([.hour,.minute], from: t)
            guard let tmrw = cal.date(byAdding: .day, value: 1, to: now) else { return nil }
            comps.year  = cal.component(.year,  from: tmrw)
            comps.month = cal.component(.month, from: tmrw)
            comps.day   = cal.component(.day,   from: tmrw)
            if let full = cal.date(from: comps) { return (fajr.name, full) }
        }
        return nil
    }

    // ── Prayer Times API fetch (used on first launch before PrayerTimesView is visited) ──

    private func fetchPrayerTimesFromServer() async {
        guard let lat = loc.latitude, let lon = loc.longitude else { return }

        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let today = fmt.string(from: Date())

        if let dict = Self.localPrayerTimesDict(lat: lat, lon: lon, date: Date(), tz: .current) {
            persistPrayerTimes(dict, date: today)
            saveWidgetPrayerTimes(dict)
            await MainActor.run { loadPrayerTimes() }
            return
        }

        // Try our own server first
        let ownURLStr = "https://quran.meshari.tech/api/prayer_times.php?lat=\(lat)&lng=\(lon)&date=\(today)&method=10"
        if let url = URL(string: ownURLStr),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool, success {

            let prayers: [String: Any]?
            if let d = json["data"] as? [String: Any], let p = d["prayers"] as? [String: Any] {
                prayers = p
            } else { prayers = nil }

            func pTime(_ key: String) -> String? {
                if let p = prayers, let e = p[key] as? [String: Any] { return e["time"] as? String }
                return json[key] as? String
            }

            var dict: [String: String] = [:]
            if let v = pTime("fajr")    { dict["الفجر"]  = v }
            if let v = pTime("sunrise") { dict["الشروق"] = v }
            if let v = pTime("dhuhr")   { dict["الظهر"]  = v }
            if let v = pTime("asr")     { dict["العصر"]  = v }
            if let v = pTime("maghrib") { dict["المغرب"] = v }
            if let v = pTime("isha")    { dict["العشاء"] = v }

            if !dict.isEmpty {
                persistPrayerTimes(dict, date: today)
                saveWidgetPrayerTimes(dict)
                await MainActor.run { loadPrayerTimes() }
                return
            }
        }

        // Fallback: aladhan.com
        let fallbackStr = "https://api.aladhan.com/v1/timings?latitude=\(lat)&longitude=\(lon)&method=4"
        guard let fallURL = URL(string: fallbackStr),
              let (data2, _) = try? await URLSession.shared.data(from: fallURL),
              let json2 = try? JSONSerialization.jsonObject(with: data2) as? [String: Any],
              let d2 = json2["data"] as? [String: Any],
              let timings = d2["timings"] as? [String: String] else { return }

        var dict2: [String: String] = [:]
        if let v = timings["Fajr"]    { dict2["الفجر"]  = v }
        if let v = timings["Sunrise"] { dict2["الشروق"] = v }
        if let v = timings["Dhuhr"]   { dict2["الظهر"]  = v }
        if let v = timings["Asr"]     { dict2["العصر"]  = v }
        if let v = timings["Maghrib"] { dict2["المغرب"] = v }
        if let v = timings["Isha"]    { dict2["العشاء"] = v }

        if !dict2.isEmpty {
            persistPrayerTimes(dict2, date: today)
            saveWidgetPrayerTimes(dict2)
            await MainActor.run { loadPrayerTimes() }
        }
    }

    private func persistPrayerTimes(_ dict: [String: String], date: String) {
        let ud = UserDefaults.standard
        ud.set(dict, forKey: "offline_prayer_times_v2")
        ud.set(date, forKey: "offline_prayer_date")
    }

    private func saveWidgetPrayerTimes(_ dict: [String: String]) {
        guard let ud = UserDefaults(suiteName: "group.tech.meshari.QuranApp") else { return }
        ud.set(dict, forKey: "widget_prayerTimings")
        ud.set(UserDefaults.standard.string(forKey: "offline_prayer_city") ?? "", forKey: "widget_cityName")
        ud.set(Date().timeIntervalSince1970, forKey: "widget_updatedAt")
        if let (name, date) = Self.computeNextPrayer(from: dict) {
            ud.set(name, forKey: "widget_nextPrayer")
            ud.set(date.timeIntervalSince1970, forKey: "widget_nextPrayerDate")
        } else {
            ud.removeObject(forKey: "widget_nextPrayer")
            ud.removeObject(forKey: "widget_nextPrayerDate")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func localPrayerTimesDict(
        lat: Double,
        lon: Double,
        date: Date,
        tz: TimeZone
    ) -> [String: String]? {
        let calc = PrayerTimesCalculator.fromUserDefaults()
        guard let result = calc.calculate(lat: lat, lon: lon, date: date, tz: tz) else { return nil }

        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        fmt.timeZone = tz

        return [
            "الفجر": fmt.string(from: result.fajr),
            "الشروق": fmt.string(from: result.sunrise),
            "الظهر": fmt.string(from: result.dhuhr),
            "العصر": fmt.string(from: result.asr),
            "المغرب": fmt.string(from: result.maghrib),
            "العشاء": fmt.string(from: result.isha)
        ]
    }

    private static func computeNextPrayer(from timesDict: [String: String]) -> (String, Date)? {
        let order = ["الفجر", "الظهر", "العصر", "المغرب", "العشاء"]
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        let now = Date()
        let cal = Calendar.current

        for name in order {
            guard let raw = timesDict[name] else { continue }
            let clean = raw.components(separatedBy: " ").first ?? raw
            guard let parsed = fmt.date(from: clean) else { continue }
            var comps = cal.dateComponents([.hour, .minute], from: parsed)
            comps.year = cal.component(.year, from: now)
            comps.month = cal.component(.month, from: now)
            comps.day = cal.component(.day, from: now)
            if let full = cal.date(from: comps), full > now {
                return (name, full)
            }
        }

        guard let fajr = timesDict["الفجر"],
              let parsed = fmt.date(from: fajr.components(separatedBy: " ").first ?? fajr),
              let tomorrow = cal.date(byAdding: .day, value: 1, to: now)
        else { return nil }
        var comps = cal.dateComponents([.hour, .minute], from: parsed)
        comps.year = cal.component(.year, from: tomorrow)
        comps.month = cal.component(.month, from: tomorrow)
        comps.day = cal.component(.day, from: tomorrow)
        guard let full = cal.date(from: comps) else { return nil }
        return ("الفجر", full)
    }
}
