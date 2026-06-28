import SwiftUI
import StoreKit

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - PaywallView
// ─────────────────────────────────────────────────────────────────────────────

struct PaywallView: View {

    @ObservedObject private var sub = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlan: PremiumProductID = .annual
    @State private var showPromoField: Bool = false
    @State private var showPrivacy: Bool = false
    @State private var showTerms: Bool   = false
    @State private var bounceIcon: Bool  = false

    // gradient
    private let topColor    = Color(red: 0.06, green: 0.08, blue: 0.18)
    private let bottomColor = Color(red: 0.02, green: 0.04, blue: 0.12)
    private let gold        = Color(red: 0.85, green: 0.70, blue: 0.35)

    // ─────────────────────────────────────────────────────────────────────────
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(colors: [topColor, bottomColor],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            // Stars decoration
            StarsBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    closeButton
                    headerSection
                    featuresSection
                    planSelector
                    ctaSection
                    promoSection
                    footerLinks

                }
                .padding(.bottom, 40)
            }
        }
        .task { await sub.loadProducts() }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Close
    // ─────────────────────────────────────────────────────────────────────────

    private var closeButton: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.trailing, 20)
            .padding(.top, 16)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Header
    // ─────────────────────────────────────────────────────────────────────────

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Crown icon animated
            ZStack {
                Circle()
                    .fill(gold.opacity(0.15))
                    .frame(width: 90, height: 90)
                Circle()
                    .stroke(gold.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 90, height: 90)
                Text("👑")
                    .font(.system(size: 44))
                    .scaleEffect(bounceIcon ? 1.12 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.5)
                        .repeatCount(1), value: bounceIcon)
            }
            .onAppear { bounceIcon = true }
            .padding(.top, 8)

            Text("بريميوم القرآن")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("استمتع بكامل مزايا التطبيق\nبدون قيود")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(.top, 8)
        .padding(.bottom, 28)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Features
    // ─────────────────────────────────────────────────────────────────────────

    private var featuresSection: some View {
        VStack(spacing: 0) {
            ForEach(PremiumFeature.allCases, id: \.rawValue) { feature in
                FeatureRow(feature: feature)
                if feature != PremiumFeature.allCases.last {
                    Divider()
                        .background(Color.white.opacity(0.08))
                        .padding(.leading, 56)
                }
            }
        }
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(gold.opacity(0.25), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Plan Selector
    // ─────────────────────────────────────────────────────────────────────────

    private var planSelector: some View {
        VStack(spacing: 12) {
            Text("اختر خطتك")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 22)

            HStack(spacing: 12) {
                // Annual Plan
                PlanCard(
                    title: "سنوي",
                    price: sub.annualProduct?.displayPrice ?? "35 ر.س",
                    subtitle: "فقط 2.92 ر.س / شهر",
                    badge: sub.annualSavings(),
                    isSelected: selectedPlan == .annual,
                    gold: gold
                ) { selectedPlan = .annual }

                // Monthly Plan
                PlanCard(
                    title: "شهري",
                    price: sub.monthlyProduct?.displayPrice ?? "3.99 ر.س",
                    subtitle: "يُجدَّد شهرياً",
                    badge: nil,
                    isSelected: selectedPlan == .monthly,
                    gold: gold
                ) { selectedPlan = .monthly }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 20)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: CTA
    // ─────────────────────────────────────────────────────────────────────────

    private var ctaSection: some View {
        VStack(spacing: 12) {
            // Main purchase button
            Button {
                Task {
                    let product = selectedPlan == .annual
                        ? sub.annualProduct
                        : sub.monthlyProduct
                    if let p = product { await sub.purchase(p) }
                }
            } label: {
                HStack(spacing: 10) {
                    if sub.purchaseInProgress {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 16))
                        Text("اشترك الآن")
                            .font(.system(size: 18, weight: .bold))
                    }
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(colors: [gold, Color(red: 1.0, green: 0.85, blue: 0.45)],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(16)
                .shadow(color: gold.opacity(0.5), radius: 12, x: 0, y: 4)
            }
            .disabled(sub.purchaseInProgress)
            .padding(.horizontal, 20)

            // Trial note
            Text("٣ أيام تجربة مجانية · يمكنك الإلغاء في أي وقت")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))

            // Error message
            if let err = sub.errorMessage {
                Text(err)
                    .font(.system(size: 13))
                    .foregroundColor(.red.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            // Restore button
            Button {
                Task { await sub.restorePurchases() }
            } label: {
                Text("استعادة مشترياتي")
                    .font(.system(size: 14))
                    .foregroundColor(gold.opacity(0.8))
                    .underline()
            }
        }
        .padding(.bottom, 20)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Promo Code
    // ─────────────────────────────────────────────────────────────────────────

    private var promoSection: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(.spring()) { showPromoField.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 13))
                    Text("لديك كود خصم؟")
                        .font(.system(size: 14))
                }
                .foregroundColor(gold.opacity(0.75))
            }

            if showPromoField {
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        TextField("أدخل الكود هنا", text: $sub.promoCodeInput)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15, design: .monospaced))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)

                        Button {
                            sub.applyPromoCode(sub.promoCodeInput)
                        } label: {
                            Text("تفعيل")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(gold)
                                .cornerRadius(10)
                        }
                        .disabled(sub.promoCodeInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(gold.opacity(0.3), lineWidth: 1))
                    .padding(.horizontal, 20)

                    if sub.promoCodeStatus != .idle {
                        Text(sub.promoCodeStatus.message)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(sub.promoCodeStatus.color)
                    }

                    // إذا اكتمل تفعيل الكود
                    if sub.promoCodeStatus == .success {
                        Button { dismiss() } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("تم التفعيل — تفضل!")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.green)
                            .cornerRadius(14)
                        }
                        .padding(.horizontal, 20)
                        .transition(.scale)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.bottom, 16)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Footer
    // ─────────────────────────────────────────────────────────────────────────

    private var footerLinks: some View {
        HStack(spacing: 20) {
            Button { showPrivacy = true } label: {
                Text("سياسة الخصوصية")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))
                    .underline()
            }
            Text("·").foregroundColor(.white.opacity(0.2))
            Button { showTerms = true } label: {
                Text("شروط الاستخدام")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))
                    .underline()
            }
        }
        .sheet(isPresented: $showPrivacy) {
            LegalDocumentView(document: .privacy)
        }
        .sheet(isPresented: $showTerms) {
            LegalDocumentView(document: .terms)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Feature Row
// ─────────────────────────────────────────────────────────────────────────────

private struct FeatureRow: View {
    let feature: PremiumFeature

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(feature.color.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: feature.icon)
                    .font(.system(size: 16))
                    .foregroundColor(feature.color)
            }

            Text(feature.rawValue)
                .font(.system(size: 15))
                .foregroundColor(.white)

            Spacer()

            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(red: 0.85, green: 0.70, blue: 0.35))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Plan Card
// ─────────────────────────────────────────────────────────────────────────────

private struct PlanCard: View {
    let title: String
    let price: String
    let subtitle: String
    let badge: String?
    let isSelected: Bool
    let gold: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                if let badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(gold)
                        .cornerRadius(20)
                }

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                Text(price)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? gold : .white)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected
                          ? gold.opacity(0.12)
                          : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? gold : Color.white.opacity(0.12),
                            lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? gold.opacity(0.2) : .clear,
                    radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Stars Background
// ─────────────────────────────────────────────────────────────────────────────

private struct StarsBackground: View {
    private let stars: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: CGFloat)] = {
        var result: [(CGFloat, CGFloat, CGFloat, CGFloat)] = []
        srand48(42)
        for _ in 0..<60 {
            let x = CGFloat(drand48())
            let y = CGFloat(drand48())
            let s = CGFloat(drand48() * 2 + 0.5)
            let o = CGFloat(drand48() * 0.5 + 0.1)
            result.append((x, y, s, o))
        }
        return result
    }()

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<stars.count, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(stars[i].opacity))
                    .frame(width: stars[i].size, height: stars[i].size)
                    .position(x: stars[i].x * geo.size.width,
                              y: stars[i].y * geo.size.height)
            }
        }
        .allowsHitTesting(false)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - LegalDocumentView
// ─────────────────────────────────────────────────────────────────────────────

private struct LegalDocumentView: View {
    enum Document {
        case privacy
        case terms

        var title: String {
            switch self {
            case .privacy: return "سياسة الخصوصية"
            case .terms: return "شروط الاستخدام"
            }
        }

        var bodyText: String {
            switch self {
            case .privacy:
                return """
                نحن نحترم خصوصيتك ونصمم التطبيق ليعمل بأقل قدر ممكن من البيانات.

                يستخدم التطبيق موقعك فقط لتحديد أوقات الصلاة، اتجاه القبلة، والمساجد القريبة. يتم طلب إذن الموقع من النظام، ويمكنك تعطيله في أي وقت من إعدادات الجهاز.

                يستخدم التطبيق الإشعارات لتذكيرك بأوقات الصلاة، الأذكار، والتنبيهات التي تختار تفعيلها. يمكنك التحكم بهذه الإشعارات من داخل التطبيق أو من إعدادات الجهاز.

                يعتمد التطبيق على خدمات شبكة لجلب محتوى القرآن، التفسير، الحديث، الفتاوى، أوقات الصلاة، والصوتيات. قد تتلقى هذه الخدمات معلومات تقنية لازمة لإتمام الطلب مثل عنوان IP ونوع الجهاز، ولا نبيع بياناتك الشخصية.

                لا نطلب إنشاء حساب لاستخدام التطبيق. بعض البيانات مثل العلامات، الإعدادات، الكاش، وسجل القراءة تحفظ محلياً على جهازك لتحسين التجربة.

                إذا تواصلت مع المطور، قد تتم معالجة رقم الهاتف أو بيانات التواصل التي تشاركها طوعاً لغرض الرد فقط.
                """
            case .terms:
                return """
                باستخدامك للتطبيق فأنت توافق على استخدامه للأغراض الشخصية والتعليمية والعبادية.

                نسعى لتقديم محتوى صحيح وموثوق، لكن قد تختلف أوقات الصلاة أو اتجاه القبلة بسبب إعدادات الموقع، طريقة الحساب، أو ظروف الجهاز. تحقق من الجهات المحلية الموثوقة عند الحاجة.

                المحتوى الشرعي مثل الفتاوى والتفاسير والأحاديث مقدم للفائدة ولا يغني عن سؤال أهل العلم في المسائل الخاصة أو النوازل.

                لا يجوز إساءة استخدام التطبيق أو محاولة تعطيل خدماته أو نسخ محتواه لأغراض مخالفة للأنظمة أو حقوق المصادر.

                قد تتطلب بعض الميزات اتصالاً بالإنترنت أو أذونات من النظام مثل الموقع، الكاميرا، أو الإشعارات. تعطيل الأذونات قد يجعل هذه الميزات غير متاحة.

                يمكن تحديث هذه الشروط مع تطور التطبيق. استمرارك في استخدام التطبيق يعني قبول النسخة الأحدث المتاحة داخله.
                """
            }
        }
    }

    let document: Document
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(document.bodyText)
                    .font(.system(size: 15))
                    .foregroundColor(Theme.text)
                    .lineSpacing(7)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(20)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("إغلاق") { dismiss() }
                }
            }
        }
    }
}
