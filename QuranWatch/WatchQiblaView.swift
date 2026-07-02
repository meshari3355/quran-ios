// =============================================================
// WatchQiblaView.swift — بوصلة القبلة على الساعة
// تستخدم heading الساعة + إحداثيات المستخدم لحساب اتجاه القبلة
// =============================================================

import SwiftUI
import CoreLocation

struct WatchQiblaEntryView: View {

    @State private var showCompass = false

    private let gold = WatchContentView.gold

    var body: some View {
        if showCompass {
            WatchQiblaView()
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.10, blue: 0.20),
                        Color(red: 0.01, green: 0.04, blue: 0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 10) {
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(gold)

                    Text("القبلة")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)

                    Button {
                        showCompass = true
                    } label: {
                        Text("فتح البوصلة")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(gold.opacity(0.35))
                }
            }
        }
    }
}

struct WatchQiblaView: View {

    @EnvironmentObject var connectivity: WatchConnectivityService

    private let gold     = WatchContentView.gold
    private let navyBg1  = WatchContentView.navyBg1
    private let navyBg2  = WatchContentView.navyBg2

    @StateObject private var headingManager = WatchHeadingManager()
    @State private var isCompassActive = false

    var body: some View {
        ZStack {
            // خلفية داكنة
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.10, blue: 0.20),
                    Color(red: 0.01, green: 0.04, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 4) {

                // ── العنوان ──
                HStack(spacing: 4) {
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(gold)
                    Text("القبلة")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(gold)
                }
                .padding(.top, 2)

                // ── اسم المدينة ──
                if !connectivity.cityName.isEmpty {
                    Text(connectivity.cityName)
                        .font(.system(size: 9))
                        .foregroundStyle(gold.opacity(0.7))
                }

                // ── البوصلة ──
                compassView

                // ── الزاوية ──
                let qiblaAngle = qiblaFromNorth()
                let needleAngle = signedWatchAngleDelta(from: headingManager.heading, to: qiblaAngle)
                let aligned = abs(needleAngle) < 5

                if !isCompassActive {
                    Button {
                        isCompassActive = true
                        headingManager.startUpdating()
                    } label: {
                        Label("تفعيل البوصلة", systemImage: "location.north.fill")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(gold.opacity(0.35))
                } else if aligned {
                    Text("✓ اتجاه القبلة")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.green)
                } else {
                    let dir = needleAngle > 0 ? "أدر يمينًا" : "أدر يسارًا"
                    Text(dir)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("القبلة")
        .onDisappear {
            isCompassActive = false
            headingManager.stopUpdating()
        }
    }

    // MARK: - Compass View

    private var compassView: some View {
        let qiblaAngle = qiblaFromNorth()
        let needleRotation = signedWatchAngleDelta(from: headingManager.heading, to: qiblaAngle)

        return ZStack {
            // حلقة خارجية
            Circle()
                .stroke(gold.opacity(0.3), lineWidth: 1)
                .frame(width: 90, height: 90)

            // نقاط الاتجاهات
            ForEach([(0.0, "ش"), (90.0, "ق"), (180.0, "ج"), (270.0, "غ")], id: \.0) { angle, label in
                Text(label)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .offset(y: -38)
                    .rotationEffect(.degrees(angle - headingManager.heading))
            }

            // إبرة الشمال (حمراء)
            VStack(spacing: 0) {
                Triangle()
                    .fill(Color.red.opacity(0.8))
                    .frame(width: 8, height: 18)
                Triangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 8, height: 18)
                    .rotationEffect(.degrees(180))
            }
            .rotationEffect(.degrees(-headingManager.heading))

            // إبرة القبلة (ذهبية)
            VStack(spacing: 0) {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(gold)
                    .offset(y: -8)
            }
            .rotationEffect(.degrees(needleRotation))

            // نقطة المركز
            Circle()
                .fill(gold)
                .frame(width: 6, height: 6)
        }
        .frame(width: 90, height: 90)
    }

    // MARK: - Helpers

    private func qiblaFromNorth() -> Double {
        guard connectivity.latitude != 0 || connectivity.longitude != 0 else { return 0 }
        return computeQiblaAngle(lat: connectivity.latitude, lon: connectivity.longitude)
    }
}

// MARK: - Triangle Shape

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Heading Manager

final class WatchHeadingManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published var heading: Double = 0
    @Published var headingAccuracy: Double = -1

    private var locationManager: CLLocationManager?
    private var hasUsableHeading = false

    func startUpdating() {
        let manager = locationManager ?? CLLocationManager()
        locationManager = manager
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest

        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
        if CLLocationManager.headingAvailable() {
            manager.headingFilter = 1
            manager.startUpdatingHeading()
        }
    }

    func stopUpdating() {
        locationManager?.stopUpdatingHeading()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let rawHeading = newHeading.trueHeading >= 0
            ? newHeading.trueHeading
            : newHeading.magneticHeading
        guard rawHeading >= 0 else { return }
        let normalizedHeading = normalizedWatchDegrees(rawHeading)
        let accuracy = newHeading.headingAccuracy
        DispatchQueue.main.async {
            let factor: Double
            if !self.hasUsableHeading {
                factor = 1
                self.hasUsableHeading = true
            } else if accuracy >= 0 && accuracy <= 12 {
                factor = 0.45
            } else {
                factor = 0.28
            }

            withAnimation(.linear(duration: 0.12)) {
                self.heading = smoothedWatchHeading(
                    from: self.heading,
                    to: normalizedHeading,
                    factor: factor
                )
                self.headingAccuracy = accuracy
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {}

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        true
    }
}

// MARK: - Preview

#Preview {
    WatchQiblaView()
        .environmentObject(WatchConnectivityService.shared)
}
