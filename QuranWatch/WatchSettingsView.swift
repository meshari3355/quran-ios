// =============================================================
// WatchSettingsView.swift — إعدادات تطبيق الساعة
// تحكم في الإشعارات والأذكار والاهتزاز ومزامنة مع الايفون
// =============================================================

import SwiftUI

struct WatchSettingsView: View {

    @EnvironmentObject var connectivity: WatchConnectivityService

    private let gold     = WatchContentView.gold
    private let navyBg1  = WatchContentView.navyBg1
    private let navyBg2  = WatchContentView.navyBg2

    @State private var didSync = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [navyBg1, navyBg2],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 8) {

                    // ── العنوان ──
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(gold)
                        Text("الإعدادات")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(gold)
                    }
                    .padding(.top, 4)

                    // ── الخط الفاصل ──
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [gold.opacity(0), gold.opacity(0.4), gold.opacity(0)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(height: 0.5)
                        .padding(.horizontal, 10)

                    // ── اختيار خلفية الساعة ──
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "paintpalette.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(gold)
                            Text("خلفية الساعة")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        HStack(spacing: 6) {
                            ForEach(WatchFaceTheme.allCases) { theme in
                                Button {
                                    connectivity.watchTheme = theme.rawValue
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(LinearGradient(
                                                colors: [theme.bg1, theme.bg2],
                                                startPoint: .topLeading, endPoint: .bottomTrailing
                                            ))
                                            .frame(height: 32)
                                        if connectivity.watchTheme == theme.rawValue {
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(theme.accent, lineWidth: 1.5)
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(theme.accent)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)

                    Rectangle()
                        .fill(LinearGradient(
                            colors: [gold.opacity(0), gold.opacity(0.3), gold.opacity(0)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(height: 0.5)
                        .padding(.horizontal, 10)

                    // ── إعداد: إشعارات الصلاة ──
                    settingRow(
                        icon: "bell.fill",
                        title: "إشعارات الصلاة",
                        isOn: $connectivity.watchPrayerAlertEnabled
                    )

                    // ── إعداد: إشعارات الأذكار ──
                    settingRow(
                        icon: "hands.sparkles.fill",
                        title: "أذكار الصباح والمساء",
                        isOn: $connectivity.watchAzkarEnabled
                    )

                    // ── إعداد: الاهتزاز ──
                    settingRow(
                        icon: "waveform",
                        title: "الاهتزاز",
                        isOn: $connectivity.watchHapticEnabled
                    )

                    // ── إعداد: الإشعارات العامة ──
                    settingRow(
                        icon: "app.badge.fill",
                        title: "الإشعارات",
                        isOn: $connectivity.watchNotifEnabled
                    )

                    // ── مزامنة مع الايفون ──
                    VStack(spacing: 4) {
                        Button {
                            connectivity.syncSettingsToPhone()
                            withAnimation {
                                didSync = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { didSync = false }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: didSync ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                                    .font(.system(size: 11))
                                    .foregroundStyle(didSync ? .green : gold)
                                Text(didSync ? "تمت المزامنة" : "مزامنة مع الايفون")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(didSync ? .green : gold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(gold.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(didSync ? Color.green.opacity(0.4) : gold.opacity(0.25), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)

                        // حالة الاتصال
                        HStack(spacing: 4) {
                            Circle()
                                .fill(connectivity.isPhoneReachable ? Color.green : Color.red.opacity(0.6))
                                .frame(width: 5, height: 5)
                            Text(connectivity.isPhoneReachable ? "الايفون متصل" : "الايفون غير متصل")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    .padding(.top, 4)

                    // ── طلب تحديث من الايفون ──
                    Button {
                        connectivity.requestUpdateFromPhone()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "iphone.and.arrow.forward")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.6))
                            Text("تحديث البيانات")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(!connectivity.isPhoneReachable)
                    .opacity(connectivity.isPhoneReachable ? 1.0 : 0.4)
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
            }
        }
        .navigationTitle("الإعدادات")
    }

    // MARK: - Setting Row

    @ViewBuilder
    private func settingRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(isOn.wrappedValue ? gold : .white.opacity(0.4))
                .frame(width: 16)

            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(gold)
                .scaleEffect(0.75)
                .frame(width: 36)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isOn.wrappedValue ? gold.opacity(0.07) : Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isOn.wrappedValue ? gold.opacity(0.2) : Color.clear, lineWidth: 0.5)
        )
        .animation(.easeInOut(duration: 0.2), value: isOn.wrappedValue)
    }
}

// MARK: - Preview

#Preview {
    WatchSettingsView()
        .environmentObject(WatchConnectivityService.shared)
}
