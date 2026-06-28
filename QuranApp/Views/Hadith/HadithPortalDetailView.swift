import SwiftUI

// MARK: - HadithPortalDetailView
// Shows a single hadith in full with narrator chain, reference, sharing.

struct HadithPortalDetailView: View {

    let hadith: PortalHadith
    let book:   PortalBook

    @State private var fontSize: CGFloat = 18
    @State private var showShareSheet = false
    @State private var isBookmarked   = false

    private var bookmarkKey: String { "portal_bookmark_\(hadith.bookId)_\(hadith.id)" }

    // Split text into isnad (narrator chain) and matn (hadith body)
    // Isnad typically ends before "قال" or after narrator verbs
    private var isnad: String? {
        let text = hadith.text
        // Common isnad-ending patterns
        let separators = ["قَالَ:", "قَالَ ", "أَنَّ ", "عَنْ رَسُولِ", "قال رسول الله"]
        for sep in separators {
            if let range = text.range(of: sep) {
                let isnadPart = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if isnadPart.count > 20 { return isnadPart }
            }
        }
        return nil
    }

    private var matn: String {
        guard let isn = isnad, !isn.isEmpty else { return hadith.text }
        guard let range = hadith.text.range(of: isn, options: .literal) else { return hadith.text }
        let start = range.upperBound
        guard start <= hadith.text.endIndex else { return hadith.text }
        return String(hadith.text[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── Reference header ──────────────────────────────────
                    referenceHeader

                    // ── Isnad (narrator chain) ────────────────────────────
                    if let isn = isnad {
                        isnadSection(isn)
                    }

                    // ── Matn (hadith body) ────────────────────────────────
                    matnSection

                    // ── Font size control ─────────────────────────────────
                    fontSizeControl

                    // ── Action buttons ────────────────────────────────────
                    actionButtons

                    Spacer(minLength: 40)
                }
                .padding(.top, 8)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("الحديث \(hadith.number)")
        .onAppear {
            isBookmarked = UserDefaults.standard.bool(forKey: bookmarkKey)
        }
        .sheet(isPresented: $showShareSheet) {
            HadithShareSheet(activityItems: [shareText])
        }
    }

    // MARK: - Reference Header

    private var referenceHeader: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(book.nameAr)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.gold)
                Text("رقم الحديث: \(hadith.number)")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Theme.card)
        .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom)
    }

    // MARK: - Isnad Section

    private func isnadSection(_ text: String) -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack {
                Spacer()
                Label("سند الحديث", systemImage: "person.3.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
            }

            Text(text)
                .font(.system(size: fontSize - 2))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.trailing)
                .lineSpacing(6)
                .environment(\.layoutDirection, .rightToLeft)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .background(Theme.card.opacity(0.5))
        .overlay(
            Rectangle()
                .fill(Theme.gold.opacity(0.4))
                .frame(width: 3),
            alignment: .trailing
        )
    }

    // MARK: - Matn Section

    private var matnSection: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack {
                Spacer()
                Label("متن الحديث", systemImage: "quote.bubble.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.gold)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Text(matn)
                .font(.system(size: fontSize))
                .foregroundColor(Theme.text)
                .multilineTextAlignment(.trailing)
                .lineSpacing(8)
                .environment(\.layoutDirection, .rightToLeft)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .background(Theme.card)
        .padding(.top, 1)
    }

    // MARK: - Font Size Control

    private var fontSizeControl: some View {
        HStack(spacing: 16) {
            Spacer()
            Text("حجم الخط")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
            HStack(spacing: 0) {
                Button(action: { if fontSize > 13 { fontSize -= 1 } }) {
                    Image(systemName: "minus")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.text)
                        .frame(width: 36, height: 32)
                }
                .buttonStyle(.plain)
                Text("\(Int(fontSize))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.gold)
                    .frame(width: 28)
                Button(action: { if fontSize < 28 { fontSize += 1 } }) {
                    Image(systemName: "plus")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.text)
                        .frame(width: 36, height: 32)
                }
                .buttonStyle(.plain)
            }
            .background(Theme.card)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Bookmark
            Button(action: toggleBookmark) {
                Label(isBookmarked ? "محفوظ" : "حفظ", systemImage: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isBookmarked ? Theme.gold : Theme.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Theme.card)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                        isBookmarked ? Theme.gold.opacity(0.5) : Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            // Share
            Button(action: { showShareSheet = true }) {
                Label("مشاركة", systemImage: "square.and.arrow.up")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Theme.card)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Copy
            Button(action: copyHadith) {
                Label("نسخ", systemImage: "doc.on.doc")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Theme.card)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Helpers

    private var shareText: String {
        """
        \(hadith.text)

        📖 \(book.nameAr) | رقم: \(hadith.number)
        """
    }

    private func toggleBookmark() {
        isBookmarked.toggle()
        UserDefaults.standard.set(isBookmarked, forKey: bookmarkKey)
    }

    private func copyHadith() {
        UIPasteboard.general.string = shareText
    }
}

// MARK: - HadithShareSheet

private struct HadithShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
