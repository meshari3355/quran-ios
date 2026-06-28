import SwiftUI
import CoreLocation
import AVFoundation
import MapKit

// MARK: - QiblaView — themed to match app identity (dark + gold)

struct QiblaView: View {
    @ObservedObject private var loc = SharedLocationManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var qiblaAngle:  Double = 0
    @State private var distanceKm:  Double = 0
    @State private var isCalculated = false
    @State private var cityName:    String = "جارٍ تحديد الموقع..."
    @State private var showCalibSheet = false
    @State private var showARCamera   = false
    @State private var showKaabaMap   = false

    private let kaabaLat = 21.4225
    private let kaabaLon = 39.8262

    // Net screen angle of Qibla indicator: qiblaAngle - compassHeading
    // When == 0 the pin is at 12 o'clock (user is facing Qibla)
    private var needleScreenAngle: Double {
        qiblaAngle - loc.compassHeading
    }

    private var isNearlyAligned: Bool {
        let a = fmod(abs(needleScreenAngle) + 360, 360)
        return a < 7 || a > 353
    }

    // ── Derived from Theme ──────────────────────────────────────
    private var bgColor: Color { Theme.background }
    private var cardColor: Color { Theme.card }
    private var gold: Color { Theme.gold }
    private var goldLight: Color { Theme.goldLight }

    var body: some View {
        ZStack {
            // ── Background ────────────────────────────────────────
            bgColor.ignoresSafeArea()

            // Subtle radial glow behind compass
            RadialGradient(
                colors: [gold.opacity(0.08), Color.clear],
                center: .center,
                startRadius: 60,
                endRadius: 260
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Top bar ─────────────────────────────────────────
                ZStack {
                    VStack(spacing: 4) {
                        Text("القبلة")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(Theme.text)
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 11))
                                .foregroundColor(gold)
                            Text(cityName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }

                    HStack {
                        Button { dismiss() } label: {
                            ZStack {
                                Circle()
                                    .fill(cardColor)
                                    .frame(width: 38, height: 38)
                                    .overlay(
                                        Circle().stroke(gold.opacity(0.3), lineWidth: 1)
                                    )
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.leading, 20)
                }
                .padding(.top, 16)
                .padding(.bottom, 6)

                // ── Qibla angle badge ─────────────────────────────
                if isCalculated {
                    HStack(spacing: 6) {
                        Image(systemName: "safari.fill")
                            .font(.system(size: 12))
                            .foregroundColor(gold)
                        Text("اتجاه القبلة \(Int(qiblaAngle))°")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(goldLight)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(gold.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(gold.opacity(0.3), lineWidth: 1))
                    .padding(.bottom, 4)
                }

                Spacer()

                // ── Main compass ──────────────────────────────────
                ZStack {
                    // Outer alignment ring
                    Circle()
                        .stroke(
                            isNearlyAligned
                                ? Color.green.opacity(0.55)
                                : gold.opacity(0.18),
                            lineWidth: isNearlyAligned ? 3.5 : 1.5
                        )
                        .frame(width: 296, height: 296)
                        .animation(.easeInOut(duration: 0.3), value: isNearlyAligned)

                    // Compass disc background
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: colorScheme == .dark
                                    ? [Color(red: 0.18, green: 0.17, blue: 0.14),
                                       Color(red: 0.11, green: 0.10, blue: 0.09)]
                                    : [Color(red: 1.0, green: 0.98, blue: 0.94),
                                       Color(red: 0.95, green: 0.91, blue: 0.83)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 140
                            )
                        )
                        .frame(width: 280, height: 280)
                        .shadow(
                            color: colorScheme == .dark
                                ? Color.black.opacity(0.6)
                                : Color.black.opacity(0.15),
                            radius: 24, y: 8
                        )

                    // Compass disc group — rotates with the phone heading
                    // so cardinal labels track the real world.
                    // The Qibla pin is embedded at qiblaAngle on the disc,
                    // so it reaches the top (12 o'clock) when heading == qiblaAngle.
                    ZStack {
                        // Rose & tick marks
                        QiblaCompassRose(gold: gold, goldLight: goldLight,
                                         colorScheme: colorScheme)
                            .frame(width: 280, height: 280)

                        // Qibla needle — fixed at qiblaAngle on the disc
                        if isCalculated {
                            QiblaNeedleView(isAligned: isNearlyAligned, gold: gold)
                                .frame(width: 200, height: 200)
                                .rotationEffect(.degrees(qiblaAngle))
                        }
                    }
                    .rotationEffect(
                        .degrees(isCalculated ? -loc.compassHeading : 0)
                    )
                    .animation(.interpolatingSpring(stiffness: 120, damping: 15),
                               value: loc.compassHeading)

                    // No location placeholder (outside the rotating disc)
                    if !isCalculated {
                        VStack(spacing: 10) {
                            Image(systemName: "location.slash.fill")
                                .font(.system(size: 34))
                                .foregroundColor(gold.opacity(0.35))
                            Text("في انتظار الموقع...")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
                .padding(.vertical, 12)

                // ── Alignment feedback ────────────────────────────
                if isNearlyAligned && isCalculated {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 15))
                        Text("أنت متجه نحو القبلة")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.green.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.green.opacity(0.3), lineWidth: 1))
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Text(isCalculated
                         ? "حرّك الجهاز حتى تصل إبرة القبلة ذهبية لأعلى"
                         : "جارٍ تحديد الموقع...")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                // ── Heading & distance ────────────────────────────
                if isCalculated {
                    VStack(spacing: 6) {
                        Text(String(format: "%.1f°", loc.compassHeading))
                            .font(.system(size: 42, weight: .thin, design: .rounded))
                            .foregroundColor(Theme.text)

                        HStack(spacing: 5) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(gold)
                            Text("المسافة إلى مكة: \(Int(distanceKm)) كم")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }

                // ── Bottom action buttons ─────────────────────────
                VStack(spacing: 14) {
                    HStack {
                        // Re-locate button
                        Button { loc.requestLocation() } label: {
                            ZStack {
                                Circle()
                                    .fill(cardColor)
                                    .frame(width: 52, height: 52)
                                    .overlay(Circle().stroke(gold.opacity(0.3), lineWidth: 1))
                                Image(systemName: loc.headingAccuracy < 0
                                      ? "exclamationmark.triangle.fill"
                                      : "location.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(loc.headingAccuracy < 0 ? .orange : gold)
                            }
                        }

                        Spacer()

                        // AR Camera Qibla button (Premium)
                        ARQiblaButton(showARCamera: $showARCamera, gold: gold, cardColor: cardColor)

                        Spacer()

                        // Show Kaaba on map
                        Button {
                            showKaabaMap = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(cardColor)
                                    .frame(width: 52, height: 52)
                                    .overlay(Circle().stroke(gold.opacity(0.3), lineWidth: 1))
                                Image(systemName: "map.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(gold)
                            }
                        }
                    }
                    .padding(.horizontal, 48)

                    // Calibration button
                    Button { showCalibSheet = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "gyroscope")
                                .font(.system(size: 14))
                            Text("معايرة البوصلة")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(gold)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 10)
                        .background(gold.opacity(0.10))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(gold.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 16)
                .padding(.bottom, 30)
            }

            // ── Calibration overlay (Google-style centered dialog) ──
            if showCalibSheet {
                CompassCalibrationOverlay(isShowing: $showCalibSheet)
                    .transition(.opacity)
                    .zIndex(50)
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showARCamera) {
            QiblaARCameraView(qiblaAngle: qiblaAngle, distanceKm: distanceKm)
        }
        .onAppear {
            loc.startHeadingUpdates()
            if let lat = loc.latitude, let lon = loc.longitude {
                calculateQibla(lat: lat, lon: lon)
                reverseGeocode(lat: lat, lon: lon)
            }
        }
        .onDisappear { loc.stopHeadingUpdates() }
        .onChange(of: showARCamera) { isOpen in
            if !isOpen {
                // الكاميرا أُغلقت — نعطي AVFoundation 0.6ث لتحرير المغناطيسية
                // ثم نعيد تشغيل البوصلة بشكل قوي
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    loc.stopHeadingUpdates()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        loc.startHeadingUpdates()
                    }
                }
            }
        }
        .onChange(of: loc.locationReceived) { received in
            if received, let lat = loc.latitude, let lon = loc.longitude {
                calculateQibla(lat: lat, lon: lon)
                reverseGeocode(lat: lat, lon: lon)
            }
        }
        .onChange(of: isNearlyAligned) { aligned in
            if aligned {
                let gen = UIImpactFeedbackGenerator(style: .medium)
                gen.impactOccurred()
            }
        }
        .sheet(isPresented: $showKaabaMap) {
            KaabaMapSheet(
                userLat:  loc.latitude  ?? kaabaLat,
                userLon:  loc.longitude ?? kaabaLon,
                kaabaLat: kaabaLat,
                kaabaLon: kaabaLon
            )
        }
    }

    // MARK: - Qibla Calculation
    private func calculateQibla(lat: Double, lon: Double) {
        let lat1 = lat * .pi / 180,  lon1 = lon * .pi / 180
        let lat2 = kaabaLat * .pi / 180, lon2 = kaabaLon * .pi / 180
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        qiblaAngle = fmod(atan2(y, x) * 180 / .pi + 360, 360)

        let R = 6371.0, dLat = lat2 - lat1
        let a = sin(dLat/2)*sin(dLat/2) + cos(lat1)*cos(lat2)*sin(dLon/2)*sin(dLon/2)
        distanceKm = R * 2 * atan2(sqrt(a), sqrt(1-a))
        isCalculated = true
    }

    private func reverseGeocode(lat: Double, lon: Double) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(CLLocation(latitude: lat, longitude: lon)) { placemarks, _ in
            DispatchQueue.main.async {
                if let p = placemarks?.first {
                    let sub  = p.subLocality ?? p.locality ?? ""
                    let main = p.administrativeArea ?? p.country ?? ""
                    cityName = sub.isEmpty ? (main.isEmpty ? "موقعك الحالي" : main)
                                           : (main.isEmpty ? sub : "\(sub) - \(main)")
                }
            }
        }
    }
}

// MARK: - Compass Rose  (N always at top — gold themed)

struct QiblaCompassRose: View {
    let gold: Color
    let goldLight: Color
    let colorScheme: ColorScheme

    private let cardinals: [(Double, String, Bool)] = [
        (0,   "ش",    true),
        (90,  "شرق",  false),
        (180, "ج",    false),
        (270, "غرب",  false),
    ]

    var body: some View {
        GeometryReader { geo in
            let size   = min(geo.size.width, geo.size.height)
            let cx     = geo.size.width / 2
            let cy     = geo.size.height / 2
            let outerR = size / 2
            let tickR  = outerR - 4
            let labelR = outerR - 26

            ZStack {
                // Decorative inner rings
                ForEach([0.92, 0.70, 0.45], id: \.self) { factor in
                    Circle()
                        .stroke(gold.opacity(factor == 0.92 ? 0.20 : 0.09),
                                lineWidth: factor == 0.92 ? 1.2 : 0.8)
                        .frame(width: outerR * 2 * factor,
                               height: outerR * 2 * factor)
                }

                // Tick marks
                Canvas { ctx, _ in
                    for i in 0..<72 {
                        let deg = Double(i) * 5
                        let rad = deg * .pi / 180
                        let isMajor = i % 18 == 0
                        let isMed   = i % 6 == 0
                        let tickLen: CGFloat = isMajor ? 18 : (isMed ? 10 : 5)
                        let startR  = CGFloat(tickR) - tickLen
                        let sx = cx + startR  * CGFloat(sin(rad))
                        let sy = cy - startR  * CGFloat(cos(rad))
                        let ex = cx + CGFloat(tickR) * CGFloat(sin(rad))
                        let ey = cy - CGFloat(tickR) * CGFloat(cos(rad))
                        var path = Path()
                        path.move(to: CGPoint(x: sx, y: sy))
                        path.addLine(to: CGPoint(x: ex, y: ey))
                        let alpha: CGFloat = isMajor ? 0.85 : (isMed ? 0.45 : 0.18)
                        ctx.stroke(path,
                                   with: .color(gold.opacity(Double(alpha))),
                                   lineWidth: isMajor ? 2.5 : 1.2)
                    }
                }
                .frame(width: size, height: size)

                // Cardinal labels
                ForEach(cardinals, id: \.0) { angle, label, isNorth in
                    let rad = angle * Double.pi / 180
                    let x = cx + CGFloat(labelR) * CGFloat(sin(rad))
                    let y = cy - CGFloat(labelR) * CGFloat(cos(rad))
                    Text(label)
                        .font(.system(size: isNorth ? 20 : 14,
                                      weight: isNorth ? .bold : .semibold))
                        .foregroundColor(isNorth ? goldLight
                                         : (colorScheme == .dark
                                            ? Color(red: 0.65, green: 0.63, blue: 0.58)
                                            : Color(red: 0.40, green: 0.33, blue: 0.22)))
                        .position(x: x, y: y)
                }

                // Center dot
                Circle()
                    .fill(gold.opacity(0.25))
                    .frame(width: 8, height: 8)
                    .position(x: cx, y: cy)
            }
        }
    }
}

// MARK: - Qibla Needle  (teardrop, gold themed)

struct QiblaNeedleView: View {
    let isAligned: Bool
    let gold: Color

    var body: some View {
        GeometryReader { geo in
            let cx   = geo.size.width / 2
            let cy   = geo.size.height / 2
            let half = geo.size.height / 2

            ZStack {
                // South tail
                Path { p in
                    p.move(to: CGPoint(x: cx, y: cy + half * 0.38))
                    p.addLine(to: CGPoint(x: cx - 7, y: cy + 4))
                    p.addLine(to: CGPoint(x: cx + 7, y: cy + 4))
                    p.closeSubpath()
                }
                .fill(Color.gray.opacity(0.25))

                // Teardrop body
                TearDropShape()
                    .fill(
                        LinearGradient(
                            colors: isAligned
                                ? [Color.green.opacity(0.9), Color.green.opacity(0.6)]
                                : [gold, gold.opacity(0.60)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 54, height: half * 1.45)
                    .position(x: cx, y: cy - half * 0.28)
                    .shadow(color: (isAligned ? Color.green : gold).opacity(0.45),
                            radius: 10, y: 3)
                    .animation(.easeInOut(duration: 0.3), value: isAligned)

                // Kaaba icon
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .position(x: cx, y: cy - half * 0.62)

                // Center jewel
                ZStack {
                    Circle()
                        .fill(isAligned ? Color.green : gold)
                        .frame(width: 20, height: 20)
                    Circle()
                        .fill(.white)
                        .frame(width: 9, height: 9)
                }
                .position(x: cx, y: cy)
                .animation(.easeInOut(duration: 0.3), value: isAligned)
            }
        }
    }
}

// MARK: - Teardrop Shape

struct TearDropShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, cx = w / 2
        var path = Path()
        path.move(to: CGPoint(x: cx, y: 0))
        path.addCurve(to: CGPoint(x: 0, y: h * 0.65),
                      control1: CGPoint(x: cx - w * 0.35, y: h * 0.15),
                      control2: CGPoint(x: 0, y: h * 0.40))
        path.addArc(center: CGPoint(x: cx, y: h * 0.65), radius: w / 2,
                    startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        path.addCurve(to: CGPoint(x: cx, y: 0),
                      control1: CGPoint(x: w, y: h * 0.40),
                      control2: CGPoint(x: cx + w * 0.35, y: h * 0.15))
        path.closeSubpath()
        return path
    }
}

// MARK: - Kaaba Icon (isometric 3D floating animated)
//
// Draws a proper isometric box with THREE visible faces:
//   • Front face  — darkest (kaabaBody) + Kiswa belt + golden door
//   • Right face  — medium shade, tilted 60° for perspective
//   • Top face    — lightest shade, foreshortened parallelogram
// The whole assembly floats and slowly rotates on the Y axis.

// MARK: - KaabaIconView (Photorealistic 3D)
// Three-face isometric box with authentic Kaaba details:
//  • Near-black Kiswa fabric (cloth texture via Canvas)
//  • Gold Hizam belt at upper third with Arabic calligraphy
//  • Golden door (Bab Al-Kaaba) with dark wood interior and arch
//  • White marble base (Shaazarwan) at bottom
//  • Gentle float animation only — no spinning

struct KaabaIconView: View {
    let size: CGFloat

    @State private var floatOffset: CGFloat = 0
    @State private var shadowScale: CGFloat = 1.0

    // ── Authentic palette ─────────────────────────────────────
    private let kiswaBase    = Color(red: 0.03, green: 0.03, blue: 0.05)   // near-black fabric
    private let kiswaMid     = Color(red: 0.08, green: 0.08, blue: 0.11)   // lit edge
    private let kiswaTop     = Color(red: 0.14, green: 0.14, blue: 0.19)   // top face (most lit)
    private let gold         = Color(red: 0.84, green: 0.69, blue: 0.31)
    private let goldBright   = Color(red: 0.97, green: 0.90, blue: 0.62)
    private let goldDeep     = Color(red: 0.58, green: 0.44, blue: 0.10)
    private let marble       = Color(red: 0.93, green: 0.91, blue: 0.87)
    private let marbleShadow = Color(red: 0.76, green: 0.74, blue: 0.70)
    private let woodDark     = Color(red: 0.21, green: 0.14, blue: 0.04)
    private let woodMid      = Color(red: 0.28, green: 0.19, blue: 0.06)

    var body: some View {
        let s  = size
        let fw = s * 0.72        // front face width
        let fh = s * 0.82        // front face height (authentic Kaaba: slightly taller than wide)
        let sw = s * 0.26        // right side face width
        let th = s * 0.18        // top face height (foreshortened)

        VStack(spacing: s * 0.05) {
            ZStack(alignment: .bottom) {

                // ── TOP FACE ──────────────────────────────────────
                TopFace(width: fw, sideW: sw, height: th)
                    .fill(LinearGradient(
                        colors: [kiswaTop, kiswaTop.opacity(0.70)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(
                        TopFace(width: fw, sideW: sw, height: th)
                            .stroke(
                                LinearGradient(colors: [gold.opacity(0.75), goldDeep.opacity(0.50)],
                                               startPoint: .leading, endPoint: .trailing),
                                lineWidth: s * 0.015))
                    .frame(width: fw + sw, height: th)
                    .offset(y: -(fh / 2 + th / 2) + s * 0.01)

                // ── RIGHT SIDE FACE ───────────────────────────────
                SideFace(width: sw, height: fh, skewTop: th)
                    .fill(LinearGradient(
                        colors: [kiswaMid, kiswaBase],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(
                        SideFace(width: sw, height: fh, skewTop: th)
                            .stroke(gold.opacity(0.30), lineWidth: s * 0.014))
                    .frame(width: sw, height: fh)
                    .offset(x: fw / 2 + sw / 2)

                // ── FRONT FACE ────────────────────────────────────
                ZStack {

                    // 1 — Kiswa body (deep black)
                    RoundedRectangle(cornerRadius: s * 0.04)
                        .fill(LinearGradient(
                            colors: [kiswaMid.opacity(0.55), kiswaBase, kiswaBase],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: fw, height: fh)

                    // 2 — Subtle cloth ribbing texture
                    KiswaClothTexture(size: s)
                        .frame(width: fw, height: fh * 0.88)
                        .offset(y: -fh * 0.06)
                        .clipShape(RoundedRectangle(cornerRadius: s * 0.04))

                    // 3 — Gold border frame
                    RoundedRectangle(cornerRadius: s * 0.04)
                        .stroke(
                            LinearGradient(
                                colors: [goldDeep.opacity(0.55), gold.opacity(0.90), goldDeep.opacity(0.55)],
                                startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: s * 0.024)
                        .frame(width: fw, height: fh)

                    // 4 — HIZAM: gold belt — upper third of face
                    ZStack {
                        // Belt body gradient (gold shimmer)
                        LinearGradient(
                            colors: [goldDeep, gold, goldBright, gold, goldDeep],
                            startPoint: .leading, endPoint: .trailing)
                        .frame(width: fw, height: fh * 0.110)

                        // Top and bottom edge highlight lines
                        VStack {
                            Rectangle().fill(goldBright.opacity(0.90)).frame(width: fw, height: s * 0.012)
                            Spacer()
                            Rectangle().fill(goldBright.opacity(0.90)).frame(width: fw, height: s * 0.012)
                        }
                        .frame(height: fh * 0.110)

                        // Calligraphy embroidery
                        Text("لا إله إلا الله محمد رسول الله")
                            .font(.system(size: s * 0.055, weight: .bold, design: .rounded))
                            .foregroundColor(kiswaBase.opacity(0.90))
                            .lineLimit(1)
                            .minimumScaleFactor(0.3)
                            .frame(width: fw * 0.88)
                    }
                    .offset(y: -fh * 0.255)   // upper 30% of face

                    // 5 — BAB AL-KAABA: golden door — center-lower area
                    ZStack {
                        // Outer gold frame
                        RoundedRectangle(cornerRadius: s * 0.030)
                            .fill(LinearGradient(
                                colors: [goldBright, gold, goldDeep, gold, goldBright],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: fw * 0.30, height: fh * 0.310)

                        // Inner door (dark carved wood)
                        RoundedRectangle(cornerRadius: s * 0.020)
                            .fill(LinearGradient(
                                colors: [woodMid, woodDark],
                                startPoint: .top, endPoint: .bottom))
                            .frame(width: fw * 0.23, height: fh * 0.255)

                        // Arch crown at top
                        Capsule()
                            .fill(LinearGradient(colors: [goldBright, gold],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(width: fw * 0.21, height: fh * 0.072)
                            .offset(y: -fh * 0.097)

                        // Vertical center divider
                        Rectangle()
                            .fill(gold.opacity(0.72))
                            .frame(width: s * 0.011, height: fh * 0.175)
                            .offset(y: fh * 0.025)

                        // Horizontal mid-rail
                        Rectangle()
                            .fill(gold.opacity(0.72))
                            .frame(width: fw * 0.21, height: s * 0.011)
                            .offset(y: fh * 0.020)
                    }
                    .offset(y: fh * 0.175)    // lower-center, above marble base

                    // 6 — White marble base (Shaazarwan)
                    LinearGradient(
                        colors: [marble, marbleShadow],
                        startPoint: .top, endPoint: .bottom)
                    .frame(width: fw, height: fh * 0.095)
                    .overlay(
                        Rectangle()
                            .stroke(marbleShadow.opacity(0.55), lineWidth: 0.6)
                    )
                    .offset(y: fh * 0.4525)   // pinned to very bottom
                    .clipShape(RoundedRectangle(cornerRadius: s * 0.04))

                    // 7 — Top edge depth shadow
                    LinearGradient(
                        colors: [Color.black.opacity(0.55), Color.clear],
                        startPoint: .top, endPoint: .bottom)
                    .frame(width: fw, height: fh * 0.09)
                    .offset(y: -fh * 0.455)
                    .clipShape(RoundedRectangle(cornerRadius: s * 0.04))
                }
                .frame(width: fw, height: fh)

            } // ZStack box
            .frame(width: fw + sw, height: fh + th)
            .shadow(color: gold.opacity(0.20), radius: s * 0.12, x: 1, y: s * 0.05)
            .offset(y: floatOffset)

            // ── Ground shadow ─────────────────────────────────────
            Ellipse()
                .fill(RadialGradient(
                    colors: [Color.black.opacity(0.32), Color.clear],
                    center: .center, startRadius: 2, endRadius: s * 0.44))
                .frame(width: s * 0.70 * shadowScale, height: s * 0.065 * shadowScale)
                .blur(radius: 3)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                floatOffset = -s * 0.07
                shadowScale = 0.80
            }
        }
    }
}

// ── Canvas-based cloth rib texture ───────────────────────────
private struct KiswaClothTexture: View {
    let size: CGFloat
    var body: some View {
        Canvas { ctx, sz in
            let spacing = max(2.0, size * 0.042)
            var y = spacing
            while y < sz.height {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: sz.width, y: y))
                ctx.stroke(p, with: .color(.white.opacity(0.040)), lineWidth: 0.55)
                y += spacing
            }
        }
    }
}

// ── Helper Shapes ─────────────────────────────────────────────

/// Parallelogram for the top face of an isometric box.
private struct TopFace: Shape {
    let width: CGFloat
    let sideW: CGFloat
    let height: CGFloat

    func path(in rect: CGRect) -> Path {
        let w = width, s = sideW, h = height
        var path = Path()
        path.move(to: CGPoint(x: s, y: h))
        path.addLine(to: CGPoint(x: s + w, y: h))
        path.addLine(to: CGPoint(x: s + w, y: 0))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.closeSubpath()
        return path
    }
}

/// Skewed quad for the right side face of an isometric box.
private struct SideFace: Shape {
    let width: CGFloat
    let height: CGFloat
    let skewTop: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: skewTop))
        path.addLine(to: CGPoint(x: width, y: 0))
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Compass Calibration Overlay (Google style)

struct CompassCalibrationOverlay: View {
    @Binding var isShowing: Bool
    @State private var animPhase: Double = 0

    private let teal = Color(red: 0.0, green: 0.55, blue: 0.55)

    private func lemPoint(phase: Double, a: Double) -> CGPoint {
        let t     = phase * 2 * Double.pi
        let sinT  = sin(t), cosT = cos(t)
        let denom = 1 + sinT * sinT
        return CGPoint(x: a * cosT / denom, y: a * sinT * cosT / denom)
    }

    var body: some View {
        ZStack {
            // Dark scrim
            Color.black.opacity(0.60)
                .ignoresSafeArea()
                .onTapGesture { withAnimation(.easeOut) { isShowing = false } }

            // White card
            VStack(spacing: 0) {

                // Title
                Text("معايرة البوصلة")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.top, 28)
                    .padding(.bottom, 6)

                Text("حرّك الجهاز على شكل رقم 8 لضبط البوصلة")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                // ── Figure-8 animation ────────────────────────────
                ZStack {
                    // Guide path
                    Canvas { ctx, size in
                        let cx = size.width / 2
                        let cy = size.height / 2
                        let a  = Double(size.width) * 0.38
                        var path = Path()
                        for i in 0...120 {
                            let p  = Double(i) / 120.0
                            let pt = CGPoint(
                                x: cx + CGFloat(lemPoint(phase: p, a: a).x),
                                y: cy - CGFloat(lemPoint(phase: p, a: a).y)
                            )
                            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                        }
                        ctx.stroke(path,
                                   with: .color(Color(red: 0.0, green: 0.55, blue: 0.55).opacity(0.22)),
                                   lineWidth: 2)
                    }
                    .frame(width: 240, height: 120)

                    // Animated hand + phone icon
                    GeometryReader { geo in
                        let cx  = geo.size.width  / 2
                        let cy  = geo.size.height / 2
                        let a   = Double(geo.size.width) * 0.38
                        let pt  = lemPoint(phase: animPhase, a: a)
                        let pt2 = lemPoint(phase: animPhase + 0.01, a: a)
                        let ang = atan2(pt2.y - pt.y, pt2.x - pt.x) * 180 / .pi

                        CalibHandPhone(teal: teal)
                            .rotationEffect(.degrees(ang - 90))
                            .position(x: cx + CGFloat(pt.x), y: cy - CGFloat(pt.y))
                    }
                    .frame(width: 240, height: 120)
                }
                .frame(height: 120)
                .padding(.bottom, 26)
                .onAppear {
                    withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                        animPhase = 1.0
                    }
                }

                // ── Steps ─────────────────────────────────────────
                VStack(alignment: .trailing, spacing: 14) {
                    CalibRow(num: "١", text: "أمسك الجهاز أفقياً مع توجيه الشاشة للأعلى",
                             teal: teal)
                    CalibRow(num: "٢", text: "حرّكه ببطء على شكل رقم 8 في الهواء عدة مرات",
                             teal: teal)
                    CalibRow(num: "٣", text: "كرّر حتى يختفي رمز التحذير البرتقالي",
                             teal: teal)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)

                // Dismiss button
                Button { withAnimation(.easeOut) { isShowing = false } } label: {
                    Text("تم")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(teal)
                }
            }
            .background(Color.white)
            .cornerRadius(20)
            .padding(.horizontal, 28)
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
}

// MARK: - Calib Helpers

private struct CalibRow: View {
    let num:  String
    let text: String
    let teal: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.black.opacity(0.75))
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
            ZStack {
                Circle()
                    .fill(teal.opacity(0.12))
                    .frame(width: 32, height: 32)
                Text(num)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(teal)
            }
        }
    }
}

private struct CalibHandPhone: View {
    let teal: Color
    var body: some View {
        ZStack {
            Circle()
                .fill(teal.opacity(0.15))
                .frame(width: 46, height: 46)
                .blur(radius: 8)
            VStack(spacing: -3) {
                Image(systemName: "iphone")
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(teal)
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 16))
                    .foregroundColor(teal.opacity(0.70))
            }
        }
    }
}

// MARK: - QiblaARCameraView (Google Qibla Finder style)

struct QiblaARCameraView: View {
    let qiblaAngle: Double
    let distanceKm: Double

    @ObservedObject private var loc = SharedLocationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var cameraOn      = true
    @State private var cameraGranted = false
    @State private var checkDone     = false

    private let teal = Color(red: 0.0, green: 0.50, blue: 0.50)

    /// Positive = Qibla is clockwise from current heading (turn right)
    /// Negative = Qibla is counter-clockwise (turn left)
    private var offsetAngle: Double {
        var a = qiblaAngle - loc.compassHeading
        while a >  180 { a -= 360 }
        while a < -180 { a += 360 }
        return a
    }

    private var isAligned: Bool { abs(offsetAngle) < 6 }

    /// Horizontal pixel offset for the Kaaba pin on the 320 pt track
    private var pinOffset: CGFloat {
        let maxOff: CGFloat = 148
        let raw = CGFloat(offsetAngle) * 5
        return raw < -maxOff ? -maxOff : (raw > maxOff ? maxOff : raw)
    }

    var body: some View {
        ZStack {
            // ── Background ─────────────────────────────────────────
            if cameraOn && cameraGranted && checkDone {
                CameraPreviewView()
                    .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [teal, Color(red: 0.0, green: 0.28, blue: 0.28)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            }

            // ── Overlay ────────────────────────────────────────────
            VStack(spacing: 0) {

                // Top bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.30))
                            .clipShape(Circle())
                    }

                    Spacer()

                    // Heading badge
                    VStack(spacing: 1) {
                        Text(String(format: "%.0f°", loc.compassHeading))
                            .font(.system(size: 16, weight: .thin, design: .rounded))
                            .foregroundColor(.white)
                        Text("القبلة \(Int(qiblaAngle))°")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.30))
                    .cornerRadius(10)

                    Spacer()

                    // Camera toggle (only when permission granted)
                    if checkDone && cameraGranted {
                        Button { withAnimation { cameraOn.toggle() } } label: {
                            Image(systemName: cameraOn ? "camera.fill" : "camera.slash.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.30))
                                .clipShape(Circle())
                        }
                    } else {
                        Spacer().frame(width: 44)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)

                Spacer()

                // ── Kaaba sliding track ────────────────────────────
                ZStack {
                    // Track
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 320, height: 60)
                        .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 1))

                    // Centre crosshair
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.white.opacity(0.70))
                            .frame(width: 1.5, height: 20)
                        Rectangle()
                            .fill(Color.white.opacity(0.70))
                            .frame(width: 1.5, height: 20)
                    }

                    // Kaaba pin
                    ARKaabaPin(isAligned: isAligned, teal: teal)
                        .offset(x: pinOffset)
                        .animation(.interactiveSpring(response: 0.30, dampingFraction: 0.75),
                                   value: pinOffset)

                    // Chevron arrows when pin is off-screen
                    if abs(pinOffset) > 130 {
                        ARTurnArrows(goRight: offsetAngle > 0)
                            .frame(width: 320, height: 60)
                    }
                }
                .frame(width: 320, height: 60)
                .clipped()
                .padding(.bottom, 16)

                // Alignment / direction label
                Group {
                    if isAligned {
                        Label("أنت متجه نحو القبلة", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(Color.green.opacity(0.35))
                            .cornerRadius(12)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text(offsetAngle > 0 ? "دوّر يميناً" : "دوّر يساراً")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.90))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(Color.black.opacity(0.30))
                            .cornerRadius(12)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: isAligned)

                // ── Bottom bar: mini compass + distance ────────────
                HStack(alignment: .center) {
                    ARMiniCompass(heading: loc.compassHeading, teal: teal)

                    Spacer()

                    VStack(spacing: 2) {
                        Text(String(format: "%.0f كم", distanceKm))
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("المسافة إلى مكة")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.60))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.28))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 26)
                .padding(.top, 22)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            loc.startHeadingUpdates()
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraGranted = granted
                    checkDone     = true
                }
            }
        }
        .onDisappear { loc.stopHeadingUpdates() }
        .onChange(of: isAligned) { aligned in
            if aligned { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
        }
        .ignoresSafeArea()
    }
}

// MARK: - AR Kaaba Pin

private struct ARKaabaPin: View {
    let isAligned: Bool
    let teal: Color

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(isAligned ? Color.green : teal)
                    .frame(width: 46, height: 46)
                    .shadow(color: (isAligned ? Color.green : teal).opacity(0.55), radius: 10)
                KaabaIconView(size: 22)
            }
            ARPinTip()
                .fill(isAligned ? Color.green : teal)
                .frame(width: 14, height: 10)
        }
        .animation(.easeInOut(duration: 0.25), value: isAligned)
    }
}

private struct ARPinTip: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - AR Turn Arrows

private struct ARTurnArrows: View {
    let goRight: Bool

    var body: some View {
        HStack(spacing: 0) {
            if goRight {
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.40))
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.65))
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.90))
                }
                .font(.system(size: 13, weight: .bold))
                .padding(.trailing, 10)
            } else {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white.opacity(0.90))
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white.opacity(0.65))
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white.opacity(0.40))
                }
                .font(.system(size: 13, weight: .bold))
                .padding(.leading, 10)
                Spacer()
            }
        }
    }
}

// MARK: - AR Mini Compass

private struct ARMiniCompass: View {
    let heading: Double
    let teal: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.28))
                .frame(width: 56, height: 56)
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                .frame(width: 56, height: 56)

            // Cardinal letters (fixed)
            Text("N").font(.system(size: 8, weight: .bold)).foregroundColor(.red)
                .offset(y: -18)
            Text("S").font(.system(size: 8, weight: .medium)).foregroundColor(.white.opacity(0.5))
                .offset(y: 18)

            // Rotating needle
            ZStack {
                // North half (red)
                Capsule()
                    .fill(Color.red)
                    .frame(width: 3, height: 14)
                    .offset(y: -7)
                // South half (white)
                Capsule()
                    .fill(Color.white.opacity(0.50))
                    .frame(width: 3, height: 14)
                    .offset(y: 7)
            }
            .rotationEffect(.degrees(-heading))
            .animation(.linear(duration: 0.10), value: heading)

            Circle()
                .fill(.white)
                .frame(width: 5, height: 5)
        }
        .frame(width: 56, height: 56)
    }
}

// MARK: - Camera Preview (AVFoundation)

struct CameraPreviewView: UIViewRepresentable {

    /// Custom UIView that auto-updates the preview layer frame on every layout pass.
    /// This fixes the black-camera bug caused by previewLayer having .zero frame at makeUIView time.
    class CameraHostView: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer?
        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
    }

    class Coordinator: NSObject {
        let session = AVCaptureSession()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> CameraHostView {
        let view  = CameraHostView()
        let coord = context.coordinator

        coord.session.sessionPreset = .high

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                 for: .video, position: .back),
            let input  = try? AVCaptureDeviceInput(device: device),
            coord.session.canAddInput(input)
        else { return view }

        coord.session.addInput(input)

        let previewLayer            = AVCaptureVideoPreviewLayer(session: coord.session)
        previewLayer.videoGravity   = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        view.previewLayer = previewLayer   // layoutSubviews() will set frame correctly

        DispatchQueue.global(qos: .userInitiated).async {
            coord.session.startRunning()
        }

        return view
    }

    func updateUIView(_ uiView: CameraHostView, context: Context) {
        // Frame is handled automatically by CameraHostView.layoutSubviews()
    }
}

// MARK: - Kaaba Map Sheet

struct KaabaMapSheet: View {
    let userLat:  Double
    let userLon:  Double
    let kaabaLat: Double
    let kaabaLon: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            KaabaMapUIView(
                userLat:  userLat,
                userLon:  userLon,
                kaabaLat: kaabaLat,
                kaabaLon: kaabaLon
            )
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("الكعبة على الخريطة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("إغلاق") { dismiss() }
                        .foregroundColor(Theme.gold)
                }
            }
        }
    }
}

// MARK: - MKMapView wrapper — shows user → Kaaba polyline

struct KaabaMapUIView: UIViewRepresentable {
    let userLat:  Double
    let userLon:  Double
    let kaabaLat: Double
    let kaabaLon: Double

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.mapType = .standard

        // Kaaba annotation
        let pin = MKPointAnnotation()
        pin.coordinate = CLLocationCoordinate2D(latitude: kaabaLat, longitude: kaabaLon)
        pin.title = "الكعبة المشرفة"
        map.addAnnotation(pin)

        // Polyline from user to Kaaba
        var coords = [
            CLLocationCoordinate2D(latitude: userLat, longitude: userLon),
            CLLocationCoordinate2D(latitude: kaabaLat, longitude: kaabaLon)
        ]
        let polyline = MKPolyline(coordinates: &coords, count: 2)
        map.addOverlay(polyline)

        // Fit region to show both endpoints with padding
        let minLat = min(userLat, kaabaLat)
        let maxLat = max(userLat, kaabaLat)
        let minLon = min(userLon, kaabaLon)
        let maxLon = max(userLon, kaabaLon)
        let center = CLLocationCoordinate2D(
            latitude:  (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta:  max(abs(maxLat - minLat) * 1.5, 3),
            longitudeDelta: max(abs(maxLon - minLon) * 1.5, 3)
        )
        map.setRegion(MKCoordinateRegion(center: center, span: span), animated: false)
        return map
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {}

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor(red: 0.85, green: 0.65, blue: 0.13, alpha: 1) // gold
            renderer.lineWidth   = 3
            renderer.lineDashPattern = [8, 4]
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            let id  = "kaaba"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                        ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
            if let marker = view as? MKMarkerAnnotationView {
                marker.glyphImage   = UIImage(systemName: "building.fill")
                marker.markerTintColor = UIColor(red: 0.85, green: 0.65, blue: 0.13, alpha: 1)
                marker.canShowCallout  = true
            }
            view.annotation = annotation
            return view
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ARQiblaButton — مفتوح للجميع
// ─────────────────────────────────────────────────────────────────────────────

private struct ARQiblaButton: View {
    @Binding var showARCamera: Bool
    let gold: Color
    let cardColor: Color

    var body: some View {
        Button { showARCamera = true } label: {
            ZStack {
                Circle()
                    .fill(cardColor)
                    .frame(width: 52, height: 52)
                    .overlay(Circle().stroke(gold.opacity(0.3), lineWidth: 1))
                Image(systemName: "camera.fill")
                    .font(.system(size: 20))
                    .foregroundColor(gold)
            }
        }
    }
}
