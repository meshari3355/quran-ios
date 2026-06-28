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
    // Fires every 0.5 s; if no heading arrived in the last 1.5 s → hard restart
    private var watchdogTimer:       Timer?
    private var lastHeadingTimestamp: Date = .distantPast
    private var headingWasActive:    Bool  = false
    private let watchdogInterval:    TimeInterval = 0.5   // check every 0.5 s
    private let stallThreshold:      TimeInterval = 1.5   // restart if stalled > 1.5 s

    @Published var latitude:        Double? = nil
    @Published var longitude:       Double? = nil
    @Published var compassHeading:  Double  = 0    // true heading, degrees CW from North
    @Published var headingAccuracy: Double  = -1   // ≥ 0 valid, < 0 needs calibration
    @Published var locationError:   String? = nil
    @Published var authStatus:      CLAuthorizationStatus = .notDetermined
    @Published var locationReceived: Bool   = false

    private let latKey = "cachedLocationLat"
    private let lonKey = "cachedLocationLon"

    override init() {
        super.init()
        manager.delegate         = self
        manager.desiredAccuracy  = kCLLocationAccuracyKilometer
        if CLLocationManager.headingAvailable() {
            manager.headingFilter      = 1          // 1° sensitivity — smoothest possible
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
        lastHeadingTimestamp = Date()       // prevent instant false-stall
        hardRestartHeading()
        startWatchdog()
    }

    func stopHeadingUpdates() {
        headingWasActive = false
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
            // Stalled — hard restart without delay
            hardRestartHeading()
        }
    }

    /// Stop → start cycle clears any frozen state in CLLocationManager
    private func hardRestartHeading() {
        manager.stopUpdatingHeading()
        manager.startUpdatingHeading()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
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
        // Stamp the time so the watchdog knows we're alive
        lastHeadingTimestamp = Date()
        DispatchQueue.main.async {
            let h = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
            self.compassHeading  = h
            self.headingAccuracy = newHeading.headingAccuracy
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
}
