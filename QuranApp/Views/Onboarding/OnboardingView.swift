import SwiftUI
import CoreLocation

// MARK: - OnboardingView

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @ObservedObject private var cacheManager      = QuranOfflineCacheManager.shared
    @ObservedObject private var audioCacheManager = AudioOfflineCacheManager.shared

    @State private var currentStep = 0
    @State private var locationGranted = false
    @State private var notifGranted = false
    @State private var locationRequested = false
    @State private var notifRequested = false
    @State private var downloadStarted = false

    /// Both text and audio are complete
    private var allDownloadsComplete: Bool {
        cacheManager.isComplete && audioCacheManager.isComplete
    }
    /// Either is still downloading
    private var anyDownloading: Bool {
        cacheManager.isDownloading || audioCacheManager.isDownloading
    }
    /// Combined 0–1 progress (text 40% weight, audio 60% weight)
    private var combinedProgress: Double {
        cacheManager.progress * 0.4 + audioCacheManager.progress * 0.6
    }

    // Steps: 0=Welcome, 1=FeatureQuran, 2=FeaturePrayer, 3=FeatureTools,
    //        4=DynamicIsland, 5=Location, 6=Notifications, 7=Download
    private let steps = 8

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.04, blue: 0.11),
                    Color(red: 0.08, green: 0.06, blue: 0.18),
                    Color(red: 0.05, green: 0.04, blue: 0.13)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Stars decoration
            starsBackground

            VStack(spacing: 0) {
                // Progress dots
                HStack(spacing: 6) {
                    ForEach(0..<steps, id: \.self) { i in
                        Capsule()
                            .fill(i == currentStep ? Theme.gold : Theme.gold.opacity(0.25))
                            .frame(width: i == currentStep ? 24 : 7, height: 7)
                            .animation(.spring(response: 0.4), value: currentStep)
                    }
                }
                .padding(.top, 60)

                Spacer()

                // Step content
                ZStack {
                    if currentStep == 0 { welcomeStep.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))) }
                    if currentStep == 1 { featureQuranStep.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))) }
                    if currentStep == 2 { featurePrayerStep.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))) }
                    if currentStep == 3 { featureToolsStep.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))) }
                    if currentStep == 4 { featureDynamicIslandStep.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))) }
                    if currentStep == 5 { locationStep.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))) }
                    if currentStep == 6 { notifStep.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))) }
                    if currentStep == 7 { downloadStep.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))) }
                }
                .animation(.easeInOut(duration: 0.35), value: currentStep)

                Spacer()

                // Bottom buttons
                VStack(spacing: 12) {
                    // Main action button
                    Button(action: handleMainAction) {
                        HStack(spacing: 10) {
                            if currentStep == 7 && anyDownloading && !allDownloadsComplete {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .scaleEffect(0.85)
                            }
                            Text(mainButtonLabel)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: buttonEnabled
                                    ? [Theme.goldLight, Theme.gold]
                                    : [Theme.gold.opacity(0.4), Theme.gold.opacity(0.4)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: Theme.gold.opacity(buttonEnabled ? 0.4 : 0.1), radius: 12, y: 4)
                    }
                    .disabled(!buttonEnabled)

                    // Skip / secondary action
                    if currentStep == 7 && anyDownloading && !allDownloadsComplete {
                        Button(action: finishOnboarding) {
                            Text("تخطي التحميل والدخول الآن")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.bottom, 4)
                    } else if currentStep < steps - 1 && currentStep != 5 {
                        Button(action: skipStep) {
                            Text("تخطي")
                                .font(.system(size: 15))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.bottom, 4)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 50)
            }
        }
    }

    // MARK: - Download Step

    private var downloadStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {

                // ── Icon ──────────────────────────────────────────
                ZStack {
                    Circle().fill(Theme.gold.opacity(0.10)).frame(width: 120, height: 120)
                    Circle().fill(Theme.gold.opacity(0.05)).frame(width: 148, height: 148)
                    if allDownloadsComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 54))
                            .foregroundColor(.green)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Image(systemName: "icloud.and.arrow.down.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(
                                LinearGradient(colors: [Theme.goldLight, Theme.gold],
                                               startPoint: .top, endPoint: .bottom))
                    }
                }
                .animation(.spring(response: 0.5), value: allDownloadsComplete)

                // ── Title ─────────────────────────────────────────
                VStack(spacing: 8) {
                    Text(allDownloadsComplete ? "اكتمل التحميل ✓" : "تحميل محتوى التطبيق")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(allDownloadsComplete ? .green : Theme.goldLight)
                        .animation(.easeInOut, value: allDownloadsComplete)

                    Text(allDownloadsComplete
                         ? "التطبيق يعمل الآن بالكامل بدون إنترنت"
                         : "يتم تحميل القرآن والصوتيات لتعمل بدون إنترنت")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // ── Progress bars ─────────────────────────────────
                VStack(spacing: 16) {

                    // — Quran text —
                    DownloadProgressRow(
                        icon: "doc.text.fill",
                        color: Theme.gold,
                        title: "نصوص القرآن الكريم",
                        subtitle: "\(cacheManager.downloadedPages) / \(cacheManager.totalPages) صفحة",
                        progress: cacheManager.progress,
                        isComplete: cacheManager.isComplete
                    )

                    Divider().background(Theme.border)

                    // — Audio —
                    DownloadProgressRow(
                        icon: "waveform",
                        color: .cyan,
                        title: "التلاوة الصوتية (ماهر المعيقلي)",
                        subtitle: "\(audioCacheManager.downloadedFiles) / \(audioCacheManager.totalFiles) آية",
                        progress: audioCacheManager.progress,
                        isComplete: audioCacheManager.isComplete
                    )
                }
                .padding(16)
                .background(Color.white.opacity(0.05))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))

                // ── Storage note ──────────────────────────────────
                HStack(spacing: 8) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                    Text("الحجم التقريبي: ~400 MB • يُحفظ على جهازك فقط")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 4)

                // ── Feature rows ──────────────────────────────────
                VStack(spacing: 0) {
                    DownloadInfoRow(icon: "wifi.slash",       color: .blue,   text: "القرآن والصوت بدون إنترنت")
                    Divider().background(Theme.border).padding(.horizontal, 16)
                    DownloadInfoRow(icon: "speaker.wave.2",   color: .cyan,   text: "تلاوة ماهر المعيقلي offline")
                    Divider().background(Theme.border).padding(.horizontal, 16)
                    DownloadInfoRow(icon: "moon.stars.fill",  color: Theme.gold, text: "أذكار وأوقات صلاة بدون نت")
                    Divider().background(Theme.border).padding(.horizontal, 16)
                    DownloadInfoRow(icon: "location.north.line.fill", color: .teal, text: "القبلة تعمل بالبوصلة فقط")
                }
                .background(Color.white.opacity(0.04))
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 4)
        }
        .onAppear {
            if !downloadStarted {
                downloadStarted = true
                QuranOfflineCacheManager.shared.startFullDownloadIfNeeded()
                AudioOfflineCacheManager.shared.startFullDownloadIfNeeded()
            }
        }
        .onChange(of: allDownloadsComplete) { complete in
            if complete {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    finishOnboarding()
                }
            }
        }
    }

    // MARK: - Step Views

    private var welcomeStep: some View {
        VStack(spacing: 28) {
            // App icon
            ZStack {
                Circle()
                    .fill(Theme.gold.opacity(0.12))
                    .frame(width: 140, height: 140)
                Circle()
                    .fill(Theme.gold.opacity(0.06))
                    .frame(width: 170, height: 170)
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 62))
                    .foregroundStyle(
                        LinearGradient(colors: [Theme.goldLight, Theme.gold], startPoint: .top, endPoint: .bottom)
                    )
            }

            VStack(spacing: 12) {
                Text("القرآن الكريم")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(Theme.goldLight)

                Text("رفيقك في رحلة التلاوة والتعبد")
                    .font(.system(size: 17))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Features
            VStack(spacing: 0) {
                OnboardingFeatureRow(icon: "book.fill", color: Theme.gold, text: "قراءة القرآن كاملاً بخط عثماني")
                Divider().background(Theme.border).padding(.horizontal, 16)
                OnboardingFeatureRow(icon: "clock.fill", color: .blue, text: "أوقات الصلاة بالموقع الجغرافي")
                Divider().background(Theme.border).padding(.horizontal, 16)
                OnboardingFeatureRow(icon: "bell.fill", color: .orange, text: "تنبيهات أوقات الصلاة وقراءة القرآن")
                Divider().background(Theme.border).padding(.horizontal, 16)
                OnboardingFeatureRow(icon: "location.north.line.fill", color: .teal, text: "اتجاه القبلة بالبوصلة")
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Feature Showcase Steps

    private var featureQuranStep: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle().fill(Theme.gold.opacity(0.12)).frame(width: 120, height: 120)
                Image(systemName: "book.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(LinearGradient(colors: [Theme.goldLight, Theme.gold],
                                                    startPoint: .top, endPoint: .bottom))
            }

            VStack(spacing: 8) {
                Text("القرآن الكريم")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Theme.goldLight)
                Text("تلاوة، استماع وتفسير في مكان واحد")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 0) {
                OnboardingFeatureRow(icon: "text.book.closed.fill", color: Theme.gold,
                    text: "القرآن كاملاً بالخط العثماني المجوّد")
                Divider().background(Theme.border).padding(.horizontal, 16)
                OnboardingFeatureRow(icon: "waveform", color: .cyan,
                    text: "20+ قارئاً — تلاوة متصلة آية بآية")
                Divider().background(Theme.border).padding(.horizontal, 16)
                OnboardingFeatureRow(icon: "text.magnifyingglass", color: .brown,
                    text: "تفسير ابن كثير والجلالين لكل آية")
                Divider().background(Theme.border).padding(.horizontal, 16)
                OnboardingFeatureRow(icon: "bookmark.fill", color: .orange,
                    text: "حفظ المواضع وإضافة العلامات")
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 28)
    }

    private var featurePrayerStep: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle().fill(Color.blue.opacity(0.12)).frame(width: 120, height: 120)
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 52))
                    .foregroundColor(Color.blue)
            }

            VStack(spacing: 8) {
                Text("الصلاة والقبلة")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text("أوقات دقيقة لكل مدن العالم مع بوصلة القبلة")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 0) {
                OnboardingFeatureRow(icon: "clock.fill", color: .blue,
                    text: "أوقات الصلاة الخمس مع العد التنازلي")
                Divider().background(Theme.border).padding(.horizontal, 16)
                OnboardingFeatureRow(icon: "location.north.line.fill", color: .teal,
                    text: "اتجاه القبلة بالبوصلة بدون إنترنت")
                Divider().background(Theme.border).padding(.horizontal, 16)
                OnboardingFeatureRow(icon: "bell.badge.fill", color: .orange,
                    text: "إشعارات الأذان بأصوات مؤذنين مختلفة")
                Divider().background(Theme.border).padding(.horizontal, 16)
                OnboardingFeatureRow(icon: "magnifyingglass", color: .purple,
                    text: "بحث عن أوقات الصلاة في أي مدينة بالعالم")
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 28)
    }

    private var featureToolsStep: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle().fill(Color.green.opacity(0.12)).frame(width: 120, height: 120)
                Image(systemName: "star.fill")
                    .font(.system(size: 52))
                    .foregroundColor(Color.green)
            }

            VStack(spacing: 8) {
                Text("أدوات إسلامية متكاملة")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                Text("كل ما يحتاجه المسلم في تطبيق واحد")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 0) {
                OnboardingFeatureRow(icon: "moon.stars.fill", color: .orange,
                    text: "أذكار الصباح والمساء مع العداد")
                Divider().background(Theme.border).padding(.horizontal, 16)
                OnboardingFeatureRow(icon: "questionmark.circle.fill", color: .purple,
                    text: "2565 فتوى من فتاوى الإمام ابن باز")
                Divider().background(Theme.border).padding(.horizontal, 16)
                OnboardingFeatureRow(icon: "book.closed.fill", color: .red,
                    text: "الكتب الستة الصحاح كاملة")
                Divider().background(Theme.border).padding(.horizontal, 16)
                OnboardingFeatureRow(icon: "wifi.slash", color: .green,
                    text: "يعمل بدون إنترنت بعد التحميل")
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Dynamic Island & Widget Step

    private var featureDynamicIslandStep: some View {
        VStack(spacing: 24) {

            // Icon
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.18))
                    .frame(width: 120, height: 120)
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 148, height: 148)

                VStack(spacing: 4) {
                    // Dynamic Island pill shape
                    Capsule()
                        .fill(Color.black)
                        .frame(width: 50, height: 16)
                        .overlay(
                            HStack(spacing: 4) {
                                Circle().fill(Color.orange.opacity(0.8)).frame(width: 5, height: 5)
                                Spacer()
                                Text("07:30")
                                    .font(.system(size: 5, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 5)
                        )

                    Image(systemName: "oval.tophalf.filled")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(colors: [Theme.goldLight, Theme.gold],
                                           startPoint: .top, endPoint: .bottom)
                        )
                }
            }

            VStack(spacing: 8) {
                Text("الماجيك آيلاند والويدجت")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Theme.goldLight)
                Text("تابع أوقات الصلاة في أي مكان دون فتح التطبيق")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 0) {
                OnboardingFeatureRow(
                    icon: "oval.tophalf.filled",
                    color: Theme.gold,
                    text: "الماجيك آيلاند — يعرض الصلاة القادمة وعداد تنازلي حي"
                )
                Divider().background(Theme.border).padding(.horizontal, 16)
                OnboardingFeatureRow(
                    icon: "lock.display",
                    color: .blue,
                    text: "شاشة القفل — الصلاة القادمة وتوقيتها دائماً أمامك"
                )
                Divider().background(Theme.border).padding(.horizontal, 16)
                OnboardingFeatureRow(
                    icon: "apps.iphone",
                    color: .green,
                    text: "ويدجت الشاشة الرئيسية — أضفه من قائمة التعديل"
                )
                Divider().background(Theme.border).padding(.horizontal, 16)
                OnboardingFeatureRow(
                    icon: "bell.badge.fill",
                    color: .orange,
                    text: "إشعارات أوقات الصلاة — تنبيه عند دخول وقت كل صلاة"
                )
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
            .padding(.horizontal, 4)

            // Widget preview hint
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
                Text("لإضافة الويدجت: اضغط مطوّلاً على الشاشة الرئيسية ← + ← ابحث عن \"القرآن الكريم\"")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 28)
    }

    private var locationStep: some View {
        VStack(spacing: 28) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.teal.opacity(0.12))
                    .frame(width: 130, height: 130)
                Image(systemName: "location.fill")
                    .font(.system(size: 54))
                    .foregroundColor(Color.teal)
            }

            VStack(spacing: 12) {
                Text("الموقع الجغرافي")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)

                Text("للحصول على أوقات الصلاة الدقيقة واتجاه القبلة لموقعك الحالي")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // Why we need it card
            VStack(spacing: 0) {
                OnboardingReasonRow(icon: "clock.fill", color: .blue, text: "أوقات الصلاة الدقيقة لمدينتك")
                Divider().background(Theme.border).padding(.horizontal, 16)
                OnboardingReasonRow(icon: "location.north.line.fill", color: .teal, text: "اتجاه القبلة من موقعك")
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
            .padding(.horizontal, 4)

            // Status
            if locationRequested {
                HStack(spacing: 8) {
                    Image(systemName: locationGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(locationGranted ? .green : .orange)
                    Text(locationGranted ? "تم السماح بالموقع" : "يمكن السماح لاحقاً من الإعدادات")
                        .font(.system(size: 14))
                        .foregroundColor(locationGranted ? .green : Theme.textSecondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
            }
        }
        .padding(.horizontal, 28)
    }

    private var notifStep: some View {
        VStack(spacing: 28) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 130, height: 130)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 54))
                    .foregroundColor(Color.orange)
            }

            VStack(spacing: 12) {
                Text("الإشعارات")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)

                Text("لتذكيرك بأوقات الصلاة وتلاوة القرآن الكريم")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            VStack(spacing: 0) {
                OnboardingReasonRow(icon: "moon.stars.fill", color: Theme.gold, text: "تنبيهات أوقات الصلاة الخمس يومياً")
                Divider().background(Theme.border).padding(.horizontal, 16)
                OnboardingReasonRow(icon: "book.fill", color: .green, text: "تذكير بقراءة القرآن إن انقطعت لأكثر من 3 أيام")
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
            .padding(.horizontal, 4)

            // Status
            if notifRequested {
                HStack(spacing: 8) {
                    Image(systemName: notifGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(notifGranted ? .green : .orange)
                    Text(notifGranted ? "تم تفعيل الإشعارات" : "يمكن التفعيل لاحقاً من الإعدادات")
                        .font(.system(size: 14))
                        .foregroundColor(notifGranted ? .green : Theme.textSecondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
            }
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Stars Background

    private var starsBackground: some View {
        GeometryReader { geo in
            ForEach(0..<40, id: \.self) { i in
                let x = Double(i * 137 % Int(geo.size.width))
                let y = Double(i * 97 % Int(geo.size.height))
                let size = Double((i % 3) + 1) * 1.5
                Circle()
                    .fill(Color.white.opacity(Double((i % 5) + 1) * 0.04))
                    .frame(width: size, height: size)
                    .position(x: x, y: y)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Actions

    private var mainButtonLabel: String {
        switch currentStep {
        case 0, 1, 2, 3, 4: return "التالي →"
        case 5: return locationRequested ? "متابعة" : "السماح بالموقع"
        case 6: return notifRequested ? "التالي" : "تفعيل الإشعارات"
        case 7:
            if allDownloadsComplete { return "ابدأ رحلتك  ←" }
            if anyDownloading       { return "جاري التحميل..." }
            return "بدء التحميل"
        default: return "متابعة"
        }
    }

    private var buttonEnabled: Bool {
        if currentStep == 7 { return !anyDownloading || allDownloadsComplete }
        return true
    }

    private func handleMainAction() {
        switch currentStep {
        case 0, 1, 2, 3, 4:
            withAnimation { currentStep += 1 }

        case 5:
            if locationRequested {
                withAnimation { currentStep = 6 }
            } else {
                requestLocation()
            }

        case 6:
            if notifRequested {
                withAnimation { currentStep = 7 }
            } else {
                requestNotifications()
            }

        case 7:
            if allDownloadsComplete {
                finishOnboarding()
            } else if !anyDownloading {
                QuranOfflineCacheManager.shared.startFullDownloadIfNeeded()
                AudioOfflineCacheManager.shared.startFullDownloadIfNeeded()
            }

        default:
            finishOnboarding()
        }
    }

    private func skipStep() {
        withAnimation { currentStep = min(currentStep + 1, steps - 1) }
    }

    private func requestLocation() {
        let manager = CLLocationManager()
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        // Small delay to let iOS show the permission dialog
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let newStatus = CLLocationManager().authorizationStatus
            locationGranted = (newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways)
            locationRequested = true
        }
    }

    private func requestNotifications() {
        NotificationManager.shared.requestPermission { granted in
            DispatchQueue.main.async {
                notifGranted = granted
                notifRequested = true
            }
        }
    }

    private func finishOnboarding() {
        withAnimation(.easeInOut(duration: 0.4)) {
            hasCompletedOnboarding = true
        }
        // Schedule Quran reading reminder on completion
        NotificationManager.shared.scheduleQuranReminder()
    }
}

// MARK: - Helper rows

private struct OnboardingFeatureRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.18))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(color)
            }
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(Color.white.opacity(0.85))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

private struct OnboardingReasonRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 26)
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(Color.white.opacity(0.85))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - DownloadProgressRow

private struct DownloadProgressRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let progress: Double
    let isComplete: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(color.opacity(0.18))
                        .frame(width: 30, height: 30)
                    Image(systemName: isComplete ? "checkmark" : icon)
                        .font(.system(size: 13, weight: isComplete ? .bold : .regular))
                        .foregroundColor(isComplete ? .green : color)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
                Text(String(format: "%.0f%%", progress * 100))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isComplete ? .green : color)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isComplete ? Color.green : color)
                        .frame(width: geo.size.width * CGFloat(min(progress, 1.0)), height: 6)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - DownloadInfoRow

private struct DownloadInfoRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(color)
            }
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.80))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
