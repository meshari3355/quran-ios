import Foundation
import UIKit

/// Handles all communication with the Quran App backend server.
final class APIService {

    static let shared = APIService()
    private init() {}

    private let baseURL = "https://quran.meshari.tech/api"

    // MARK: - Device Registration

    /// Call this once Apple delivers the push token.
    func registerDevice(pushToken: String) {
        let deviceId  = deviceIdentifier()
        let params: [String: Any] = [
            "device_id":    deviceId,
            "push_token":   pushToken,
            "platform":     "ios",
            "app_version":  appVersion(),
            "os_version":   UIDevice.current.systemVersion,
            "device_model": deviceModel(),
            "language":     Locale.current.language.languageCode?.identifier ?? "ar"
        ]
        post(endpoint: "register_device.php", body: params)
    }

    /// Call when push notifications are denied or token is unavailable.
    func registerDeviceWithoutToken() {
        let params: [String: Any] = [
            "device_id":    deviceIdentifier(),
            "platform":     "ios",
            "app_version":  appVersion(),
            "os_version":   UIDevice.current.systemVersion,
            "device_model": deviceModel(),
            "language":     Locale.current.language.languageCode?.identifier ?? "ar"
        ]
        post(endpoint: "register_device.php", body: params)
    }

    // MARK: - Analytics

    /// Track a screen view or user action.
    func trackEvent(name: String, screen: String? = nil, data: [String: Any] = [:]) {
        let params: [String: Any?] = [
            "device_id":  deviceIdentifier(),
            "event_name": name,
            "event_data": data.isEmpty ? nil : data,
            "screen":     screen,
            "session_id": sessionId()
        ]
        post(endpoint: "track_event.php", body: params.compactMapValues { $0 })
    }

    /// Call when app moves to foreground.
    func trackSessionStart() {
        trackEvent(name: "session_start")
    }

    /// Call when app moves to background.
    func trackSessionEnd() {
        trackEvent(name: "session_end")
    }

    // MARK: - Helpers

    private func post(endpoint: String, body: [String: Any]) {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else { return }
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        req.timeoutInterval = 10

        URLSession.shared.dataTask(with: req) { _, _, _ in }.resume()
    }

    private func deviceIdentifier() -> String {
        let key = "app_device_uuid"
        if let saved = UserDefaults.standard.string(forKey: key) { return saved }
        let newId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }

    private func sessionId() -> String {
        let key = "app_session_id"
        if let s = UserDefaults.standard.string(forKey: key) { return s }
        let s = UUID().uuidString
        UserDefaults.standard.set(s, forKey: key)
        return s
    }

    func resetSessionId() {
        UserDefaults.standard.removeObject(forKey: "app_session_id")
    }

    private func appVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private func deviceModel() -> String {
        var sysinfo = utsname()
        uname(&sysinfo)
        let machine = withUnsafeBytes(of: &sysinfo.machine) { buf in
            buf.bindMemory(to: CChar.self).baseAddress.map { String(cString: $0) } ?? "unknown"
        }
        return machine
    }
}
