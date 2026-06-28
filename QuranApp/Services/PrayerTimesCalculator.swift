import Foundation

// MARK: - PrayerTimesCalculator
// Full implementation of the PrayTimes algorithm
// Reference: https://praytimes.org/calculation
// Supports all major calculation methods and Asr juristics

// MARK: - Calculation Method

enum PrayerCalculationMethod: Int, CaseIterable, Codable {
    case mwl        = 1  // Muslim World League
    case isna       = 2  // Islamic Society of North America
    case egypt      = 3  // Egyptian General Authority
    case makkah     = 4  // Umm Al-Qura, Makkah (Saudi Official)
    case karachi    = 5  // University of Islamic Sciences, Karachi
    case tehran     = 6  // Institute of Geophysics, Tehran
    case jafari     = 7  // Shia Ithna-Ashari (Leva Research)
    case kuwait     = 8  // Kuwait Ministry of Awqaf
    case qatar      = 9  // Qatar — Isha 15 min after Maghrib
    case singapore  = 10 // Majlis Ugama Islam Singapura (MUIS)
    case uoif       = 11 // Union des Organisations Islamiques de France

    var nameAr: String {
        switch self {
        case .mwl:       return "رابطة العالم الإسلامي"
        case .isna:      return "جمعية أمريكا الشمالية الإسلامية"
        case .egypt:     return "الهيئة المصرية العامة للمساحة"
        case .makkah:    return "أم القرى (مكة المكرمة)"
        case .karachi:   return "جامعة العلوم الإسلامية (كراتشي)"
        case .tehran:    return "معهد الجيوفيزياء (طهران)"
        case .jafari:    return "جعفري (لفعا)"
        case .kuwait:    return "وزارة الأوقاف (الكويت)"
        case .qatar:     return "قطر — 15 دقيقة بعد الغروب"
        case .singapore: return "مجلس الدين الإسلامي (سنغافورة)"
        case .uoif:      return "الاتحاد الإسلامي الفرنسي (UOIF)"
        }
    }

    struct Params {
        var fajrAngle:      Double   // twilight angle for Fajr
        var ishaAngle:      Double   // twilight angle for Isha (0 = use ishaMinutes)
        var ishaMinutes:    Double   // minutes after Maghrib (if ishaAngle == 0)
        var maghribAngle:   Double   // 0 = use maghribMinutes
        var maghribMinutes: Double   // minutes after sunset
    }

    var params: Params {
        switch self {
        case .mwl:       return Params(fajrAngle: 18,   ishaAngle: 17,   ishaMinutes: 0,  maghribAngle: 0,   maghribMinutes: 0)
        case .isna:      return Params(fajrAngle: 15,   ishaAngle: 15,   ishaMinutes: 0,  maghribAngle: 0,   maghribMinutes: 0)
        case .egypt:     return Params(fajrAngle: 19.5, ishaAngle: 17.5, ishaMinutes: 0,  maghribAngle: 0,   maghribMinutes: 0)
        case .makkah:    return Params(fajrAngle: 18.5, ishaAngle: 0,    ishaMinutes: 90, maghribAngle: 0,   maghribMinutes: 0)
        case .karachi:   return Params(fajrAngle: 18,   ishaAngle: 18,   ishaMinutes: 0,  maghribAngle: 0,   maghribMinutes: 0)
        case .tehran:    return Params(fajrAngle: 17.7, ishaAngle: 14,   ishaMinutes: 0,  maghribAngle: 4.5, maghribMinutes: 0)
        case .jafari:    return Params(fajrAngle: 16,   ishaAngle: 14,   ishaMinutes: 0,  maghribAngle: 4,   maghribMinutes: 0)
        case .kuwait:    return Params(fajrAngle: 18,   ishaAngle: 17.5, ishaMinutes: 0,  maghribAngle: 0,   maghribMinutes: 0)
        case .qatar:     return Params(fajrAngle: 18,   ishaAngle: 0,    ishaMinutes: 15, maghribAngle: 0,   maghribMinutes: 0)
        case .singapore: return Params(fajrAngle: 20,   ishaAngle: 18,   ishaMinutes: 0,  maghribAngle: 0,   maghribMinutes: 0)
        case .uoif:      return Params(fajrAngle: 12,   ishaAngle: 12,   ishaMinutes: 0,  maghribAngle: 0,   maghribMinutes: 0)
        }
    }
}

// MARK: - Asr Juristic Method

enum AsrMethod: Int, CaseIterable, Codable {
    case shafii = 1  // Shadow = 1× height (majority)
    case hanafi = 2  // Shadow = 2× height

    var nameAr: String {
        switch self {
        case .shafii: return "الشافعي / المالكي / الحنبلي"
        case .hanafi: return "الحنفي"
        }
    }
}

// MARK: - High Latitude Rule

enum HighLatitudeRule: Int, CaseIterable, Codable {
    case none        = 0
    case nightMiddle = 1  // Middle of the night
    case oneSeventh  = 2  // 1/7 of the night
    case angleBased  = 3  // Angle/60 of the night

    var nameAr: String {
        switch self {
        case .none:        return "لا يوجد"
        case .nightMiddle: return "منتصف الليل"
        case .oneSeventh:  return "سُبع الليل"
        case .angleBased:  return "نسبة الزاوية"
        }
    }
}

// MARK: - Result

struct PrayerTimesResult {
    let fajr:    Date
    let sunrise: Date
    let dhuhr:   Date
    let asr:     Date
    let maghrib: Date
    let isha:    Date
    let midnight: Date

    /// All named prayers in order (excluding sunrise & midnight)
    var prayers: [(name: String, icon: String, date: Date)] {
        [
            ("الفجر",  "moon.fill",         fajr),
            ("الشروق", "sunrise.fill",       sunrise),
            ("الظهر",  "sun.max.fill",       dhuhr),
            ("العصر",  "sun.haze.fill",      asr),
            ("المغرب", "sunset.fill",        maghrib),
            ("العشاء", "moon.stars.fill",    isha),
        ]
    }

    /// Format a Date to "HH:mm" string
    static func format(_ date: Date, in tz: TimeZone) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = tz
        return f.string(from: date)
    }
}

// MARK: - Calculator

struct PrayerTimesCalculator {

    // MARK: - Configuration
    var method: PrayerCalculationMethod
    var asrMethod: AsrMethod
    var highLatRule: HighLatitudeRule

    init(method: PrayerCalculationMethod = .makkah,
         asrMethod: AsrMethod = .shafii,
         highLatRule: HighLatitudeRule = .nightMiddle) {
        self.method      = method
        self.asrMethod   = asrMethod
        self.highLatRule = highLatRule
    }

    // MARK: - Main entry point

    /// Calculate prayer times for a given location and date.
    /// - Parameters:
    ///   - lat:  latitude in decimal degrees
    ///   - lon:  longitude in decimal degrees
    ///   - date: the calendar date
    ///   - tz:   the local timezone (used for returning Date objects at correct local time)
    func calculate(lat: Double, lon: Double, date: Date, tz: TimeZone) -> PrayerTimesResult? {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents(in: tz, from: date)
        guard let year  = comps.year,
              let month = comps.month,
              let day   = comps.day else { return nil }

        // ── 1. Julian Date ───────────────────────────────────────────
        let jd = julianDate(year: year, month: month, day: day)

        // ── 2. Sun coordinates at Dhuhr ──────────────────────────────
        let d    = jd - 2451545.0
        let eqt  = equationOfTime(d: d)
        let decl = sunDeclination(d: d)

        // ── 3. Timezone offset (hours) ───────────────────────────────
        let tzOffset = Double(tz.secondsFromGMT(for: date)) / 3600.0

        // ── 4. Dhuhr time (fractional hours UTC+local) ───────────────
        let dhuhrH = 12.0 + tzOffset - lon / 15.0 - eqt

        // ── 5. Sunrise / Sunset ──────────────────────────────────────
        let sunriseH = dhuhrH - timeDiff(angle: 0.833, decl: decl, lat: lat)
        let sunsetH  = dhuhrH + timeDiff(angle: 0.833, decl: decl, lat: lat)

        // ── 6. Fajr ──────────────────────────────────────────────────
        let p = method.params
        var fajrH = dhuhrH - timeDiff(angle: p.fajrAngle, decl: decl, lat: lat)

        // ── 7. Isha ──────────────────────────────────────────────────
        var ishaH: Double
        if p.ishaAngle > 0 {
            ishaH = dhuhrH + timeDiff(angle: p.ishaAngle, decl: decl, lat: lat)
        } else {
            ishaH = sunsetH + p.ishaMinutes / 60.0
        }

        // ── 8. Maghrib ───────────────────────────────────────────────
        var maghribH: Double
        if p.maghribAngle > 0 {
            maghribH = dhuhrH + timeDiff(angle: p.maghribAngle, decl: decl, lat: lat)
        } else {
            maghribH = sunsetH + p.maghribMinutes / 60.0
        }

        // ── 9. Asr ───────────────────────────────────────────────────
        let asrH = dhuhrH + asrTime(decl: decl, lat: lat, shadow: Double(asrMethod.rawValue))

        // ── 10. High Latitude Adjustments ────────────────────────────
        // صحيح: من الغروب إلى الشروق الغد = طول الليل الفعلي
        let nightDuration = sunriseH + 24.0 - sunsetH   // night = sunset → next sunrise
        if highLatRule != .none && (fajrH.isNaN || ishaH.isNaN) {
            (fajrH, ishaH) = adjustHighLatitude(
                fajrH: fajrH, ishaH: ishaH,
                sunriseH: sunriseH, sunsetH: sunsetH,
                nightDuration: nightDuration, p: p
            )
        }

        // ── 11. Midnight ─────────────────────────────────────────────
        let midnightH: Double
        if method == .jafari {
            midnightH = sunsetH + (fajrH + 24 - sunsetH) / 2
        } else {
            midnightH = sunsetH + (sunriseH + 24 - sunsetH) / 2
        }

        // ── 12. Convert fractional hours → Dates ────────────────────
        func toDate(_ h: Double) -> Date? {
            let hSafe = h.isNaN ? Double.nan : h
            if hSafe.isNaN { return nil }
            let hRemainder = hSafe.truncatingRemainder(dividingBy: 24.0)
            let hNorm = hRemainder < 0 ? hRemainder + 24.0 : hRemainder
            let hour = Int(hNorm)
            let minute = Int(((hNorm - Double(hour)) * 60).rounded())
            var dc = DateComponents()
            dc.year   = year
            dc.month  = month
            dc.day    = day
            dc.hour   = minute == 60 ? hour + 1 : hour
            dc.minute = minute == 60 ? 0 : minute
            dc.second = 0
            dc.timeZone = tz
            return Calendar(identifier: .gregorian).date(from: dc)
        }

        guard let fajrDate    = toDate(fajrH),
              let sunriseDate = toDate(sunriseH),
              let dhuhrDate   = toDate(dhuhrH),
              let asrDate     = toDate(asrH),
              let maghribDate = toDate(maghribH),
              let ishaDate    = toDate(ishaH),
              let midnightDate = toDate(midnightH)
        else { return nil }

        return PrayerTimesResult(
            fajr:     fajrDate,
            sunrise:  sunriseDate,
            dhuhr:    dhuhrDate,
            asr:      asrDate,
            maghrib:  maghribDate,
            isha:     ishaDate,
            midnight: midnightDate
        )
    }

    // MARK: - Julian Date

    private func julianDate(year: Int, month: Int, day: Int) -> Double {
        var y = year, m = month
        if m <= 2 { y -= 1; m += 12 }
        let a = Int(Double(y) / 100)
        let b = 2 - a + Int(Double(a) / 4)
        return Double(Int(365.25 * Double(y + 4716)))
             + Double(Int(30.6001 * Double(m + 1)))
             + Double(day) + Double(b) - 1524.5
    }

    // MARK: - Sun Coordinates (U.S. Naval Observatory)

    private func sunDeclination(d: Double) -> Double {
        let g = (357.529 + 0.98560028 * d).toRad
        let q = (280.459 + 0.98564736 * d)
        let L = (q + 1.915 * sin(g) + 0.020 * sin(2 * g)).toRad
        let e = (23.439 - 0.00000036 * d).toRad
        return asin(sin(e) * sin(L)).toDeg
    }

    private func equationOfTime(d: Double) -> Double {
        let g  = (357.529 + 0.98560028 * d).toRad
        let q  = 280.459 + 0.98564736 * d
        let L  = (q + 1.915 * sin(g) + 0.020 * sin(2 * g)).toRad
        let e  = (23.439 - 0.00000036 * d).toRad
        let RA = atan2(cos(e) * sin(L), cos(L)).toDeg / 15.0
        return q / 15.0 - fixHour(RA)
    }

    // MARK: - Time difference for a twilight angle

    /// Returns hours difference from Dhuhr for a given twilight angle
    private func timeDiff(angle: Double, decl: Double, lat: Double) -> Double {
        let d   = decl.toRad
        let l   = lat.toRad
        let a   = (-angle).toRad
        let cos_t = (sin(a) - sin(d) * sin(l)) / (cos(d) * cos(l))
        if cos_t < -1 { return Double.nan }  // polar night
        if cos_t >  1 { return Double.nan }  // polar day
        return acos(cos_t).toDeg / 15.0
    }

    // MARK: - Asr time

    /// Returns hours difference from Dhuhr for Asr
    private func asrTime(decl: Double, lat: Double, shadow: Double) -> Double {
        let d    = decl.toRad
        let l    = lat.toRad
        let x    = shadow + tan(abs(l - d))
        let a    = atan(1.0 / x)
        let cos_t = (sin(a) - sin(d) * sin(l)) / (cos(d) * cos(l))
        if abs(cos_t) > 1 { return Double.nan }
        return acos(cos_t).toDeg / 15.0
    }

    // MARK: - High Latitude Adjustment

    private func adjustHighLatitude(
        fajrH: Double, ishaH: Double,
        sunriseH: Double, sunsetH: Double,
        nightDuration: Double, p: PrayerCalculationMethod.Params
    ) -> (Double, Double) {
        var fajr = fajrH, isha = ishaH

        switch highLatRule {
        case .none:
            break

        case .nightMiddle:
            let mid = sunsetH + nightDuration / 2.0
            if fajr.isNaN || fajr < sunriseH - nightDuration / 2 {
                fajr = mid
            }
            if isha.isNaN || isha > sunriseH + nightDuration / 2 {
                isha = mid
            }

        case .oneSeventh:
            if fajr.isNaN { fajr = sunriseH - nightDuration / 7.0 }
            if isha.isNaN { isha = sunsetH  + nightDuration / 7.0 }

        case .angleBased:
            let fajrAdjusted = sunriseH - (p.fajrAngle / 60.0) * nightDuration
            let ishaAdjusted = sunsetH  + (p.ishaAngle / 60.0) * nightDuration
            if fajr.isNaN { fajr = fajrAdjusted }
            if isha.isNaN { isha = ishaAdjusted }
        }
        return (fajr, isha)
    }

    // MARK: - Helpers

    private func fixHour(_ h: Double) -> Double {
        var v = h.truncatingRemainder(dividingBy: 24)
        if v < 0 { v += 24 }
        return v
    }
}

// MARK: - Angle Conversion Helpers

private extension Double {
    var toRad: Double { self * .pi / 180.0 }
    var toDeg: Double { self * 180.0 / .pi }
}

// MARK: - PrayerTimesCalculator + UserDefaults Settings

extension PrayerTimesCalculator {
    static let methodKey      = "prayerCalcMethod"
    static let asrKey         = "prayerAsrMethod"
    static let highLatKey     = "prayerHighLatRule"

    static func fromUserDefaults() -> PrayerTimesCalculator {
        let methodRaw   = UserDefaults.standard.integer(forKey: methodKey)
        let asrRaw      = UserDefaults.standard.integer(forKey: asrKey)
        let highLatRaw  = UserDefaults.standard.integer(forKey: highLatKey)
        let method      = PrayerCalculationMethod(rawValue: methodRaw) ?? .makkah
        let asr         = AsrMethod(rawValue: asrRaw) ?? .shafii
        let highLat     = HighLatitudeRule(rawValue: highLatRaw) ?? .nightMiddle
        return PrayerTimesCalculator(method: method, asrMethod: asr, highLatRule: highLat)
    }

    func saveToUserDefaults() {
        UserDefaults.standard.set(method.rawValue,      forKey: Self.methodKey)
        UserDefaults.standard.set(asrMethod.rawValue,   forKey: Self.asrKey)
        UserDefaults.standard.set(highLatRule.rawValue, forKey: Self.highLatKey)
    }
}
