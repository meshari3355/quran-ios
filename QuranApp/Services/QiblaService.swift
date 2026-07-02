import Foundation

struct QiblaDirection {
    let bearing: Double
    let distanceKm: Double
}

final class QiblaService {
    static let shared = QiblaService()

    private let kaabaLatitude = 21.422487
    private let kaabaLongitude = 39.826206
    private let earthRadiusKm = 6371.0088

    private init() {}

    func direction(fromLatitude latitude: Double, longitude: Double) -> QiblaDirection {
        let lat1 = latitude.degreesToRadians
        let lon1 = longitude.degreesToRadians
        let lat2 = kaabaLatitude.degreesToRadians
        let lon2 = kaabaLongitude.degreesToRadians
        let deltaLongitude = lon2 - lon1

        let y = sin(deltaLongitude) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLongitude)
        let bearing = Self.normalizedDegrees(atan2(y, x).radiansToDegrees)

        let deltaLatitude = lat2 - lat1
        let a = sin(deltaLatitude / 2) * sin(deltaLatitude / 2)
            + cos(lat1) * cos(lat2) * sin(deltaLongitude / 2) * sin(deltaLongitude / 2)
        let distance = earthRadiusKm * 2 * atan2(sqrt(a), sqrt(max(0, 1 - a)))

        return QiblaDirection(bearing: bearing, distanceKm: distance)
    }

    static func normalizedDegrees(_ degrees: Double) -> Double {
        let normalized = degrees.truncatingRemainder(dividingBy: 360)
        return normalized < 0 ? normalized + 360 : normalized
    }

    static func signedDelta(from current: Double, to target: Double) -> Double {
        let delta = normalizedDegrees(target - current)
        return delta > 180 ? delta - 360 : delta
    }

    static func smoothedHeading(from current: Double, to target: Double, factor: Double) -> Double {
        let clampedFactor = min(max(factor, 0), 1)
        return normalizedDegrees(current + signedDelta(from: current, to: target) * clampedFactor)
    }
}

private extension Double {
    var degreesToRadians: Double { self * .pi / 180 }
    var radiansToDegrees: Double { self * 180 / .pi }
}
