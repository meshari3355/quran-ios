import StoreKit
import SwiftUI
import Combine

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Product IDs
// ─────────────────────────────────────────────────────────────────────────────

enum PremiumProductID: String, CaseIterable {
    case monthly = "tech.meshari.quranapp.premium.monthly"
    case annual  = "tech.meshari.quranapp.premium.annual"
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Premium Features
// ─────────────────────────────────────────────────────────────────────────────

enum PremiumFeature: String, CaseIterable {
    case offlineAudio       = "تنزيل التلاوات"
    case allReciters        = "جميع القراء"
    case watchSync          = "مزامنة Apple Watch الكاملة"
    case arQibla            = "القبلة بالواقع المعزز"
    case advancedStats      = "إحصائيات القراءة المتقدمة"
    case islamicLibrary     = "المكتبة الإسلامية"
    case advancedZakat      = "حاسبة الزكاة المتقدمة"
    case themeCustomization = "تخصيص الثيمات"

    var icon: String {
        switch self {
        case .offlineAudio:       return "arrow.down.circle.fill"
        case .allReciters:        return "mic.fill"
        case .watchSync:          return "applewatch"
        case .arQibla:            return "camera.fill"
        case .advancedStats:      return "chart.bar.fill"
        case .islamicLibrary:     return "books.vertical.fill"
        case .advancedZakat:      return "dollarsign.circle.fill"
        case .themeCustomization: return "paintpalette.fill"
        }
    }

    var color: Color {
        switch self {
        case .offlineAudio:       return .blue
        case .allReciters:        return .purple
        case .watchSync:          return .primary
        case .arQibla:            return .orange
        case .advancedStats:      return .green
        case .islamicLibrary:     return .brown
        case .advancedZakat:      return Color(red: 0.85, green: 0.70, blue: 0.35)
        case .themeCustomization: return .pink
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - SubscriptionManager
// ─────────────────────────────────────────────────────────────────────────────

@MainActor
final class SubscriptionManager: ObservableObject {

    static let shared = SubscriptionManager()

    // ── Published state ──────────────────────────────────────────────────────
    @Published private(set) var isPremium: Bool = false
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseInProgress: Bool = false
    @Published private(set) var activePlanLabel: String = ""
    @Published var errorMessage: String? = nil
    @Published var promoCodeInput: String = ""
    @Published var promoCodeStatus: PromoStatus = .idle

    // ── Storage keys ─────────────────────────────────────────────────────────
    private let kPremiumUnlocked = "premium_unlocked"
    private let kPremiumSource   = "premium_source"       // "purchase" | "promo"
    private let kPromoCodeUsed   = "promo_code_used"
    private let kPremiumExpiry   = "premium_expiry"       // for promo (unlimited = nil)

    // ── Valid promo codes ────────────────────────────────────────────────────
    // كود الخصم الخاص بك — تقدر تضيف أكواد زيادة هنا
    private let validPromoCodes: Set<String> = [
        "MESHARI2025",      // كود المطور الرئيسي
        "QURAN_BETA",       // للتجربة
        "DEV_UNLOCK",       // للتطوير
    ]

    private var updateListenerTask: Task<Void, Never>? = nil

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Init
    // ─────────────────────────────────────────────────────────────────────────

    private init() {
        // ── جميع المزايا مجانية — مفتوح للجميع ──────────────────
        isPremium       = true
        activePlanLabel = "مجاني — كل المزايا متاحة"
        UserDefaults.standard.set(true,    forKey: kPremiumUnlocked)
        UserDefaults.standard.set("free",  forKey: kPremiumSource)

        // نبدأ المستمع لأي مشتريات مستقبلية
        updateListenerTask = listenForTransactions()
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Load Products
    // ─────────────────────────────────────────────────────────────────────────

    func loadProducts() async {
        do {
            let ids = PremiumProductID.allCases.map { $0.rawValue }
            products = try await Product.products(for: ids)
            // رتب: شهري أولاً ثم سنوي
            products.sort { a, _ in
                a.id == PremiumProductID.monthly.rawValue
            }
        } catch {
            errorMessage = "لم نستطع تحميل خيارات الاشتراك. تحقق من الاتصال."
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Purchase
    // ─────────────────────────────────────────────────────────────────────────

    func purchase(_ product: Product) async {
        purchaseInProgress = true
        errorMessage = nil
        defer { purchaseInProgress = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await unlockPremium(source: "purchase", label: product.displayName)
                await transaction.finish()

            case .userCancelled:
                break

            case .pending:
                errorMessage = "الطلب قيد المراجعة. ستُفعَّل المزايا بعد الموافقة."

            @unknown default:
                break
            }
        } catch {
            errorMessage = "فشلت عملية الشراء: \(error.localizedDescription)"
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Restore Purchases
    // ─────────────────────────────────────────────────────────────────────────

    func restorePurchases() async {
        purchaseInProgress = true
        defer { purchaseInProgress = false }

        do {
            try await AppStore.sync()
            await refreshPurchaseStatus()
            if !isPremium {
                errorMessage = "لم يتم العثور على اشتراك نشط مرتبط بحسابك."
            }
        } catch {
            errorMessage = "فشل استعادة المشتريات: \(error.localizedDescription)"
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Promo Code
    // ─────────────────────────────────────────────────────────────────────────

    enum PromoStatus {
        case idle, validating, success, invalid
        var message: String {
            switch self {
            case .idle:       return ""
            case .validating: return "جاري التحقق..."
            case .success:    return "✓ تم تفعيل البريميوم بنجاح"
            case .invalid:    return "✗ الكود غير صحيح أو مستخدم مسبقاً"
            }
        }
        var color: Color {
            switch self {
            case .success: return .green
            case .invalid: return .red
            default:       return .secondary
            }
        }
    }

    func applyPromoCode(_ code: String) {
        let clean = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        promoCodeStatus = .validating

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)

            if self.validPromoCodes.contains(clean) {
                UserDefaults.standard.set(clean, forKey: self.kPromoCodeUsed)
                await self.unlockPremium(source: "promo", label: "كود خصم: \(clean)")
                self.promoCodeStatus = .success
                self.promoCodeInput = ""
            } else {
                self.promoCodeStatus = .invalid
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                self.promoCodeStatus = .idle
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Revoke (للمطور فقط)
    // ─────────────────────────────────────────────────────────────────────────

    func revokePremium() {
        UserDefaults.standard.set(false, forKey: kPremiumUnlocked)
        UserDefaults.standard.removeObject(forKey: kPremiumSource)
        UserDefaults.standard.removeObject(forKey: kPromoCodeUsed)
        isPremium = false
        activePlanLabel = ""
        promoCodeStatus = .idle
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Private Helpers
    // ─────────────────────────────────────────────────────────────────────────

    private func unlockPremium(source: String, label: String) async {
        UserDefaults.standard.set(true,   forKey: kPremiumUnlocked)
        UserDefaults.standard.set(source, forKey: kPremiumSource)
        isPremium      = true
        activePlanLabel = source == "promo" ? "بريميوم (كود خصم)" : label
    }

    private func refreshPurchaseStatus() async {
        // إذا كان مفعّلاً بكود خصم، لا تغيّر الحالة
        let source = UserDefaults.standard.string(forKey: kPremiumSource)
        if source == "promo" { return }

        var hasActive = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               PremiumProductID(rawValue: tx.productID) != nil,
               tx.revocationDate == nil {
                hasActive = true
                activePlanLabel = tx.productID == PremiumProductID.monthly.rawValue
                    ? "اشتراك شهري"
                    : "اشتراك سنوي"
                break
            }
        }
        if hasActive {
            UserDefaults.standard.set(true,       forKey: kPremiumUnlocked)
            UserDefaults.standard.set("purchase", forKey: kPremiumSource)
        } else if source == "purchase" {
            // انتهى الاشتراك
            UserDefaults.standard.set(false, forKey: kPremiumUnlocked)
            isPremium = false
            activePlanLabel = ""
        }
        isPremium = UserDefaults.standard.bool(forKey: kPremiumUnlocked)
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let tx) = result {
                    if tx.revocationDate != nil {
                        await self.revokePremiumIfNeeded()
                    } else {
                        await self.unlockPremium(source: "purchase", label: "")
                    }
                    await tx.finish()
                }
            }
        }
    }

    @MainActor
    private func revokePremiumIfNeeded() {
        let source = UserDefaults.standard.string(forKey: kPremiumSource)
        guard source == "purchase" else { return }
        revokePremium()
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw SubscriptionError.failedVerification
        case .verified(let value): return value
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Price Helpers
    // ─────────────────────────────────────────────────────────────────────────

    var monthlyProduct: Product? {
        products.first { $0.id == PremiumProductID.monthly.rawValue }
    }

    var annualProduct: Product? {
        products.first { $0.id == PremiumProductID.annual.rawValue }
    }

    func annualSavings() -> String {
        guard let monthly = monthlyProduct,
              let annual  = annualProduct else { return "وفّر 27%" }
        let monthlyCostDouble = NSDecimalNumber(decimal: monthly.price).doubleValue * 12.0
        let annualDouble      = NSDecimalNumber(decimal: annual.price).doubleValue
        guard monthlyCostDouble > 0 else { return "وفّر 27%" }
        let pct = Int(((monthlyCostDouble - annualDouble) / monthlyCostDouble * 100).rounded())
        return "وفّر \(pct)%"
    }
}

enum SubscriptionError: Error {
    case failedVerification
}
