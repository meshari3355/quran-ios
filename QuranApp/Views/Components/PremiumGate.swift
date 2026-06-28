import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - PremiumGate — كل المزايا مفتوحة مجاناً
// ─────────────────────────────────────────────────────────────────────────────

/// يعرض المحتوى مباشرة — جميع المزايا مجانية
struct PremiumGate<Content: View>: View {
    let feature: PremiumFeature
    let content: Content

    init(feature: PremiumFeature, @ViewBuilder content: () -> Content) {
        self.feature = feature
        self.content = content()
    }

    var body: some View { content }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - PremiumRow — يعمل كزر عادي
// ─────────────────────────────────────────────────────────────────────────────

struct PremiumRow<Label: View>: View {
    let label: Label
    let feature: PremiumFeature
    let action: (() -> Void)?

    init(feature: PremiumFeature,
         action: (() -> Void)? = nil,
         @ViewBuilder label: () -> Label) {
        self.feature = feature
        self.action  = action
        self.label   = label()
    }

    var body: some View {
        Button { action?() } label: {
            HStack { label; Spacer() }
        }
        .buttonStyle(.plain)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - PremiumBanner — محذوف (لا ضرورة له)
// ─────────────────────────────────────────────────────────────────────────────

/// شريط فارغ للتوافق مع الكود القديم — لا يعرض شيئاً
struct PremiumBanner: View {
    init(_ label: String = "") {}
    var body: some View { EmptyView() }
}
