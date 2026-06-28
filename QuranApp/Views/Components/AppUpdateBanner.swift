import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - AppUpdateBanner
// يتحقق من أحدث إصدار ويعرض بانر تحديث أنيق
// ─────────────────────────────────────────────────────────────────────────────

struct AppUpdateBanner: View {

    @State private var latestVersion: String? = nil
    @State private var isDismissed = false

    private let gold  = Color(red: 0.85, green: 0.70, blue: 0.35)

    // الإصدار الحالي المثبت على جهاز المستخدم
    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    var body: some View {
        if let latest = latestVersion,
           isNewer(latest, than: currentVersion),
           !isDismissed {

            HStack(spacing: 12) {

                // أيقونة
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(gold.opacity(0.18))
                        .frame(width: 38, height: 38)
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(gold)
                }

                // النص
                VStack(alignment: .trailing, spacing: 2) {
                    Text("تحديث جديد متاح — \(latest)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.text)
                    Text("ميزات جديدة وتحسينات")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                // زر التحديث
                Button {
                    openAppStore()
                } label: {
                    Text("تحديث")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(gold)
                        .cornerRadius(20)
                }
                .buttonStyle(.plain)

                // زر الإغلاق
                Button {
                    withAnimation { isDismissed = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(gold.opacity(0.4), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
            .task { await checkForUpdate() }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - فحص أحدث إصدار من App Store
    // ─────────────────────────────────────────────────────────────────────────

    private func checkForUpdate() async {
        // تجنب الفحص أكثر من مرة في اليوم
        let lastCheckKey = "lastUpdateCheckDate"
        if let last = UserDefaults.standard.object(forKey: lastCheckKey) as? Date,
           Calendar.current.isDateInToday(last) { return }

        guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(AppMetadata.appStoreID)&country=sa") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let results = json?["results"] as? [[String: Any]],
                  let first  = results.first,
                  let version = first["version"] as? String else { return }

            UserDefaults.standard.set(Date(), forKey: lastCheckKey)

            await MainActor.run {
                withAnimation(.spring()) {
                    latestVersion = version
                }
            }
        } catch {
            // فشل الفحص — لا نعرض شيئاً
        }
    }

    // ─────────────────────────────────────────────────────────────────────────

    private func isNewer(_ latest: String, than current: String) -> Bool {
        latest.compare(current, options: .numeric) == .orderedDescending
    }

    private func openAppStore() {
        UIApplication.shared.open(AppMetadata.appStoreURL)
    }
}
