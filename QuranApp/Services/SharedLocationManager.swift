import Foundation
import CoreLocation
import UIKit

/// Singleton location manager shared by QiblaView and PrayerTimesView.
/// Caches last known coordinates in UserDefaults so the user is never asked
/// for permission more than once, and the location is available immediately
/// on subsequent launches.
final class SharedLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = SharedLocationManager()

    private let manager = CLLocationManager()

    // ── Watchdog ──────────────────────────────────────────────────────────────
    // Restarts only after a real stall. A short threshold causes repeated
    // stop/start cycles and makes the compass feel frozen on some devices.
    private var watchdogTimer:       Timer?
    private var lastHeadingTimestamp: Date = .distantPast
    private var lastHeadingRestart:   Date = .distantPast
    private var headingWasActive:    Bool  = false
    private var isHeadingUpdating:    Bool  = false
    private var hasUsableHeading:     Bool  = false
    private let watchdogInterval:    TimeInterval = 1.0
    private let stallThreshold:      TimeInterval = 6.0
    private let restartCooldown:     TimeInterval = 4.0

    @Published var latitude:        Double? = nil
    @Published var longitude:       Double? = nil
    @Published var compassHeading:  Double  = 0    // true heading, degrees CW from North
    @Published var headingAccuracy: Double  = -1   // ≥ 0 valid, < 0 needs calibration
    @Published var isPreciseLocationEnabled: Bool = true
    @Published var locationError:   String? = nil
    @Published var authStatus:      CLAuthorizationStatus = .notDetermined
    @Published var locationReceived: Bool   = false

    private let latKey = "cachedLocationLat"
    private let lonKey = "cachedLocationLon"

    override init() {
        super.init()
        manager.delegate         = self
        manager.desiredAccuracy  = kCLLocationAccuracyBest
        manager.distanceFilter   = 10
        manager.pausesLocationUpdatesAutomatically = true
        if CLLocationManager.headingAvailable() {
            manager.headingFilter      = 1
            manager.headingOrientation = .portrait
        }

        // Load cached coordinates immediately
        if let lat = UserDefaults.standard.object(forKey: latKey) as? Double,
           let lon = UserDefaults.standard.object(forKey: lonKey) as? Double {
            latitude        = lat
            longitude       = lon
            locationReceived = true
        }

        // If already authorized, start everything
        let status = manager.authorizationStatus
        authStatus = status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
            startHeadingUpdates()
        }

        // Restart after returning from Camera / other apps / Control Center
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    // MARK: - App lifecycle

    @objc private func appDidBecomeActive() {
        guard headingWasActive else { return }
        // Give the system 0.3 s to release AVFoundation / magnetometer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.hardRestartHeading()
        }
    }

    // MARK: - Public API

    func requestLocation() {
        locationError = nil
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            refreshAccuracyAuthorization()
            manager.requestLocation()
            startHeadingUpdates()
        case .denied, .restricted:
            locationError = "الرجاء السماح بالوصول للموقع من إعدادات الجهاز"
        @unknown default:
            break
        }
    }

    func startHeadingUpdates() {
        guard CLLocationManager.headingAvailable() else { return }
        headingWasActive     = true
        lastHeadingTimestamp = Date()
        if !isHeadingUpdating {
            isHeadingUpdating = true
            manager.startUpdatingHeading()
        }
        startWatchdog()
    }

    func stopHeadingUpdates() {
        headingWasActive = false
        isHeadingUpdating = false
        stopWatchdog()
        manager.stopUpdatingHeading()
    }

    // MARK: - Watchdog

    private func startWatchdog() {
        stopWatchdog()
        watchdogTimer = Timer.scheduledTimer(
            withTimeInterval: watchdogInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkHeadingHealth()
        }
        if let watchdogTimer {
            RunLoop.main.add(watchdogTimer, forMode: .common) // fires during scroll/animation too
        }
    }

    private func stopWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
    }

    private func checkHeadingHealth() {
        guard headingWasActive else { return }
        let staleDuration = Date().timeIntervalSince(lastHeadingTimestamp)
        if staleDuration > stallThreshold {
            hardRestartHeading()
        }
    }

    /// Stop → start clears a frozen CLLocationManager, with cooldown to avoid loops.
    private func hardRestartHeading() {
        guard Date().timeIntervalSince(lastHeadingRestart) >= restartCooldown else { return }
        lastHeadingRestart = Date()
        manager.stopUpdatingHeading()
        isHeadingUpdating = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard self.headingWasActive else { return }
            self.lastHeadingTimestamp = Date()
            self.isHeadingUpdating = true
            self.manager.startUpdatingHeading()
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last, loc.horizontalAccuracy >= 0 else { return }
        refreshAccuracyAuthorization()
        DispatchQueue.main.async {
            self.latitude        = loc.coordinate.latitude
            self.longitude       = loc.coordinate.longitude
            self.locationReceived = true
            self.locationError   = nil
            UserDefaults.standard.set(loc.coordinate.latitude,  forKey: self.latKey)
            UserDefaults.standard.set(loc.coordinate.longitude, forKey: self.lonKey)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        lastHeadingTimestamp = Date()
        let rawHeading = newHeading.trueHeading >= 0
            ? newHeading.trueHeading
            : newHeading.magneticHeading
        guard rawHeading >= 0 else { return }
        let normalizedHeading = QiblaService.normalizedDegrees(rawHeading)
        let accuracy = newHeading.headingAccuracy
        DispatchQueue.main.async {
            let smoothingFactor: Double
            if !self.hasUsableHeading {
                smoothingFactor = 1
                self.hasUsableHeading = true
            } else if accuracy >= 0 && accuracy <= 12 {
                smoothingFactor = 0.42
            } else {
                smoothingFactor = 0.25
            }

            let smoothed = QiblaService.smoothedHeading(
                from: self.compassHeading,
                to: normalizedHeading,
                factor: smoothingFactor
            )
            let delta = abs(QiblaService.signedDelta(from: self.compassHeading, to: smoothed))
            if delta >= 0.15 || self.headingAccuracy != accuracy {
                self.compassHeading = smoothed
                self.headingAccuracy = accuracy
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let clErr = error as? CLError
        DispatchQueue.main.async {
            switch clErr?.code {
            case .denied:
                self.locationError = "الرجاء السماح بالوصول للموقع من الإعدادات"
            case .locationUnknown:
                break   // transient — iOS retries automatically
            default:
                self.locationError = "تعذر تحديد الموقع، حاول مرة أخرى"
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        DispatchQueue.main.async { self.authStatus = status }
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationError = nil
            refreshAccuracyAuthorization()
            manager.requestLocation()
            startHeadingUpdates()
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.locationError = "الرجاء السماح بالوصول للموقع من الإعدادات"
            }
        default:
            break
        }
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        headingWasActive
    }

    private func refreshAccuracyAuthorization() {
        if #available(iOS 14.0, *) {
            let precise = manager.accuracyAuthorization == .fullAccuracy
            DispatchQueue.main.async {
                self.isPreciseLocationEnabled = precise
                if !precise {
                    self.locationError = "لأفضل دقة للقبلة فعّل الموقع الدقيق من إعدادات التطبيق"
                }
            }
        }
    }
}
