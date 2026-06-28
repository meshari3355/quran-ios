// =============================================================
// WatchFaceView.swift — واجهة الساعة الإسلامية الإبداعية
// تعرض: الوقت الحي + التاريخ الهجري + الصلاة القادمة + رسم إسلامي
// =============================================================

import SwiftUI

// MARK: - Themes

enum WatchFaceTheme: Int, CaseIterable, Identifiable {
    case midnight = 0   // أزرق ليلي ذهبي
    case oud      = 1   // بني عود داكن
    case emerald  = 2   // أخضر زمردي
    case rose     = 3   // وردي ذهبي

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .midnight: return "منتصف الليل"
        case .oud:      return "عود"
        case .emerald:  return "زمرد"
        case .rose:     return "ورد"
        }
    }

    var bg1: Color {
        switch self {
        case .midnight: return Color(red: 0.03, green: 0.07, blue: 0.22)
        case .oud:      return Color(red: 0.13, green: 0.07, blue: 0.03)
        case .emerald:  return Color(red: 0.03, green: 0.18, blue: 0.10)
        case .rose:     return Color(red: 0.22, green: 0.07, blue: 0.10)
        }
    }

    var bg2: Color {
        switch self {
        case .midnight: return Color(red: 0.00, green: 0.02, blue: 0.10)
        case .oud:      return Color(red: 0.06, green: 0.03, blue: 0.01)
        case .emerald:  return Color(red: 0.01, green: 0.08, blue: 0.04)
        case .rose:     return Color(red: 0.10, green: 0.02, blue: 0.05)
        }
    }

    var accent: Color {
        switch self {
        case .midnight: return Color(red: 0.87, green: 0.72, blue: 0.36)
        case .oud:      return Color(red: 0.93, green: 0.78, blue: 0.45)
        case .emerald:  return Color(red: 0.55, green: 0.92, blue: 0.65)
        case .rose:     return Color(red: 0.98, green: 0.75, blue: 0.80)
        }
    }
}

// MARK: - WatchFaceView

struct WatchFaceView: View {

    @EnvironmentObject var connectivity: WatchConnectivityService

    // Live clock
    @State private var now = Date()
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var theme: WatchFaceTheme {
        WatchFaceTheme(rawValue: connectivity.watchTheme) ?? .midnight
    }

    // ── Computed ──────────────────────────────────────────────────────────────

    private var timeString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar")
        f.dateFormat = "hh:mm"
        return f.string(from: now)
    }

    private var secondsString: String {
        let f = DateFormatter()
        f.dateFormat = "ss"
        return f.string(from: now)
    }

    private var amPm: String {
        Calendar.current.component(.hour, from: now) < 12 ? "ص" : "م"
    }

    private var hijriString: String {
        guard !connectivity.hijriDate.isEmpty else {
            let cal = Calendar(identifier: .islamicUmmAlQura)
            let f = DateFormatter()
            f.locale = Locale(identifier: "ar")
            f.calendar = cal
            f.dateFormat = "d MMMM"
            return f.string(from: now)
        }
        return connectivity.hijriDate
    }

    private var dayNameString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar")
        f.dateFormat = "EEEE"
        return f.string(from: now)
    }

    private var nextPrayer: (name: String, time: String)? {
        let order = ["الفجر","الظهر","العصر","المغرب","العشاء"]
        let fmt = DateFormatter(); fmt.dateFormat = "HH:mm"
        let cal = Calendar.current
        for name in order {
            guard let raw  = connectivity.prayerTimes[name],
                  let t    = fmt.date(from: raw.components(separatedBy: " ").first ?? raw) else { continue }
            var c = cal.dateComponents([.year,.month,.day], from: now)
            let tc = cal.dateComponents([.hour,.minute], from: t)
            c.hour = tc.hour; c.minute = tc.minute; c.second = 0
            if let d = cal.date(from: c), d > now {
                let h = Calendar.current.component(.hour, from: t)
                let disp = DateFormatter()
                disp.dateFormat = "h:mm"
                return (name, "\(disp.string(from: t)) \(h < 12 ? "ص" : "م")")
            }
        }
        return nil
    }

    private var qiblaAngle: Double? {
        guard connectivity.latitude != 0 || connectivity.longitude != 0 else { return nil }
        return computeQiblaAngle(lat: connectivity.latitude, lon: connectivity.longitude)
    }

    private var qiblaNeedleAngle: Double {
        qiblaAngle ?? 0
    }

    private var qiblaStatusText: String {
        guard qiblaAngle != nil else { return "افتح التطبيق للمزامنة" }
        return "اتجاه القبلة"
    }

    private var qiblaDegreeText: String {
        guard let qiblaAngle else { return "" }
        return "\(Int(qiblaAngle.rounded()))°"
    }

    // ── Body ──────────────────────────────────────────────────────────────────

    var body: some View {
        ZStack {
            // ── خلفية التدرج ──
            LinearGradient(
                colors: [theme.bg1, theme.bg2],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // ── الزخارف الهندسية الإسلامية ──
            GeometricOrnament(accent: theme.accent)

            // ── المحتوى ──
            VStack(spacing: 0) {

                // اسم اليوم + التاريخ الهجري
                VStack(spacing: 1) {
                    Text(dayNameString)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(theme.accent.opacity(0.8))
                    Text(hijriString)
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.top, 6)

                Spacer()

                // ── الساعة الرئيسية ──
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(timeString)
                        .font(.system(size: 36, weight: .thin, design: .default))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.7)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(amPm)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(theme.accent)
                        Text(secondsString)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .offset(y: -4)
                }

                // ── فاصل ذهبي ──
                HStack(spacing: 4) {
                    ornamentLine(theme.accent)
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(theme.accent)
                    ornamentLine(theme.accent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 5)

                // ── الصلاة القادمة ──
                if let prayer = nextPrayer {
                    HStack(spacing: 5) {
                        Image(systemName: prayerIcon(prayer.name))
                            .font(.system(size: 9))
                            .foregroundStyle(theme.accent)
                        Text(prayer.name)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                        Text(prayer.time)
                            .font(.system(size: 9))
                            .foregroundStyle(theme.accent.opacity(0.8))
                    }
                } else {
                    Text("لا توجد بيانات")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.3))
                }

                // ── القبلة داخل واجهة الساعة ──
                qiblaMiniCompass
                    .padding(.top, 5)

                Spacer()

                // ── اسم التطبيق ──
                Text("القرآن الكريم")
                    .font(.system(size: 8, weight: .light))
                    .foregroundStyle(.white.opacity(0.2))
                    .padding(.bottom, 4)
            }
        }
        .onReceive(ticker) { now = $0 }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private func ornamentLine(_ color: Color) -> some View {
        Rectangle()
            .fill(LinearGradient(
                colors: [color.opacity(0), color.opacity(0.5), color.opacity(0)],
                startPoint: .leading, endPoint: .trailing
            ))
            .frame(height: 0.5)
    }

    private func prayerIcon(_ name: String) -> String {
        switch name {
        case "الفجر":   return "moon.fill"
        case "الشروق":  return "sunrise.fill"
        case "الظهر":   return "sun.max.fill"
        case "العصر":   return "sun.haze.fill"
        case "المغرب":  return "sunset.fill"
        case "العشاء":  return "moon.stars.fill"
        default:        return "clock.fill"
        }
    }

    private var qiblaMiniCompass: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(theme.accent.opacity(0.35), lineWidth: 0.8)
                    .frame(width: 26, height: 26)
                Image(systemName: "location.north.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.accent)
                    .rotationEffect(.degrees(qiblaNeedleAngle))
            }

            VStack(alignment: .trailing, spacing: 1) {
                Text("القبلة")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                Text(qiblaStatusText)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(theme.accent.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !qiblaDegreeText.isEmpty {
                    Text(qiblaDegreeText)
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(theme.accent.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Islamic Geometric Ornament (Canvas)

private struct GeometricOrnament: View {
    let accent: Color

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width  / 2
            let cy = size.height / 2
            let r  = min(cx, cy) * 0.88

            // ── رسم النجمة الثمانية ──
            let pts = starPoints(cx: cx, cy: cy, r: r, r2: r * 0.42, n: 8)
            var path = Path()
            for (i, pt) in pts.enumerated() {
                i == 0 ? path.move(to: pt) : path.addLine(to: pt)
            }
            path.closeSubpath()

            ctx.stroke(path,
                       with: .color(accent.opacity(0.07)),
                       lineWidth: 0.6)

            // ── دائرة خارجية ──
            let circle = Path(ellipseIn: CGRect(x: cx-r, y: cy-r, width: r*2, height: r*2))
            ctx.stroke(circle,
                       with: .color(accent.opacity(0.05)),
                       lineWidth: 0.5)

            // ── نقاط الزوايا ──
            for pt in pts {
                let dot = Path(ellipseIn: CGRect(x: pt.x-1.2, y: pt.y-1.2, width: 2.4, height: 2.4))
                ctx.fill(dot, with: .color(accent.opacity(0.12)))
            }
        }
        .allowsHitTesting(false)
    }

    private func starPoints(cx: CGFloat, cy: CGFloat, r: CGFloat, r2: CGFloat, n: Int) -> [CGPoint] {
        var pts: [CGPoint] = []
        for i in 0..<(n*2) {
            let angle = (Double(i) * .pi / Double(n)) - (.pi / 2)
            let radius = i.isMultiple(of: 2) ? r : r2
            pts.append(CGPoint(x: cx + radius * cos(angle),
                               y: cy + radius * sin(angle)))
        }
        return pts
    }
}

// MARK: - Preview

#Preview {
    WatchFaceView()
        .environmentObject(WatchConnectivityService.shared)
}
