import SwiftUI

// MARK: - Models

struct MetalPriceResponse: Codable {
    let price: Double
}

struct GoldEntry: Identifiable {
    let id = UUID()
    var karat: Int = 21
    var grams: String = ""

    var purity: Double { Double(karat) / 24.0 }

    static let availableKarats = [24, 22, 21, 18, 14]
    static let karatNames: [Int: String] = [
        24: "عيار 24",
        22: "عيار 22",
        21: "عيار 21",
        18: "عيار 18",
        14: "عيار 14"
    ]
}

// MARK: - Zakat Category Tab

enum ZakatCategory: String, CaseIterable {
    case metals   = "المعادن"
    case cash     = "النقود"
    case trade    = "التجارة"
    case livestock = "الماشية"

    var icon: String {
        switch self {
        case .metals:    return "circle.fill"
        case .cash:      return "banknote"
        case .trade:     return "cart.fill"
        case .livestock: return "hare.fill"
        }
    }
}

// MARK: - ZakatCalculatorView

struct ZakatCalculatorView: View {
    // Metals
    @State private var goldEntries: [GoldEntry] = [GoldEntry()]
    @State private var silverGrams: String = ""

    // Cash & debts
    @State private var cashAmount: String = ""
    @State private var investmentAmount: String = ""
    @State private var receivableAmount: String = ""   // ديون مستحقة القبض

    // Trade goods
    @State private var tradeGoodsValue: String = ""    // قيمة البضاعة
    @State private var tradeReceivables: String = ""   // ديون التجارة المستحقة

    // Livestock — camels
    @State private var camelsCount: String = ""
    // Livestock — cattle
    @State private var cattleCount: String = ""
    // Livestock — sheep / goats
    @State private var sheepCount: String = ""

    // Prices & state
    @State private var goldPriceSAR: Double = 290.0
    @State private var silverPriceSAR: Double = 3.5
    @State private var pricesLoaded = false
    @State private var pricesLoading = false
    @State private var pricesError = false

    @State private var result: ZakatResult? = nil
    @State private var selectedTab: ZakatCategory = .metals

    let nisabGoldGrams: Double = 85.0
    let zakatRate: Double = 0.025
    let usdToSAR: Double = 3.75

    var nisabSAR: Double { nisabGoldGrams * goldPriceSAR }

    var totalGoldValue: Double {
        goldEntries.reduce(0) { sum, entry in
            let g = Double(entry.grams) ?? 0
            return sum + g * entry.purity * goldPriceSAR
        }
    }

    // ── Livestock zakat rules (Sharia) ─────────────────────────────────────
    // Camels: nisab = 5; per 5 camels → 1 sheep
    private func camelZakat(_ n: Int) -> String {
        guard n >= 5 else { return "لا زكاة (أقل من النصاب 5)" }
        if n < 25 { return "\(n / 5) شاة" }
        if n < 36 { return "بنت مخاض (1 ناقة سنة)" }
        if n < 46 { return "بنت لبون (1 ناقة سنتين)" }
        if n < 61 { return "حقة (1 ناقة 3 سنوات)" }
        if n < 76 { return "جذعة (1 ناقة 4 سنوات)" }
        if n < 91 { return "2 بنت لبون" }
        if n < 121 { return "2 حقة" }
        return "\(n / 40) حقة + \(n / 50) جذعة (مراجعة العالم)"
    }
    // Cattle: nisab = 30
    private func cattleZakat(_ n: Int) -> String {
        guard n >= 30 else { return "لا زكاة (أقل من النصاب 30)" }
        let t30 = n / 30; let t40 = n / 40
        return "\(t30) تبيع (عجل سنة) أو \(t40) مسنة (بقرة سنتين)"
    }
    // Sheep/Goats: nisab = 40
    private func sheepZakat(_ n: Int) -> String {
        guard n >= 40 else { return "لا زكاة (أقل من النصاب 40)" }
        if n < 121  { return "1 شاة" }
        if n < 201  { return "2 شاة" }
        if n < 400  { return "3 شياه" }
        return "\(n / 100) شاة لكل مئة زائدة عن 400"
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {

                    Text("حاسبة الزكاة")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(Theme.goldLight)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)

                    // Prices card (always visible for reference)
                    pricesCard

                    // ── Category tabs ────────────────────────────────
                    categoryTabs

                    // ── Content per tab ──────────────────────────────
                    switch selectedTab {
                    case .metals:    metalsSection
                    case .cash:      cashSection
                    case .trade:     tradeSection
                    case .livestock: livestockSection
                    }

                    // ── Calculate button ─────────────────────────────
                    Button(action: calculate) {
                        Text("احسب الزكاة")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Theme.background)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Theme.gold)
                            .cornerRadius(12)
                    }

                    if let res = result {
                        resultCard(res)
                    }

                    Text("* الأسعار من gold-api.com. زكاة الماشية تقديرية — راجع أهل العلم.")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 20)
                }
                .padding(16)
            }
        }
        .task { await fetchPrices() }
    }

    // MARK: - Category tabs

    private var categoryTabs: some View {
        HStack(spacing: 0) {
            ForEach(ZakatCategory.allCases, id: \.self) { cat in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = cat }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: cat.icon)
                            .font(.system(size: 14))
                        Text(cat.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundColor(selectedTab == cat ? Theme.gold : Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selectedTab == cat
                            ? Theme.gold.opacity(0.12)
                            : Color.clear
                    )
                    .overlay(
                        Rectangle()
                            .fill(selectedTab == cat ? Theme.gold : Color.clear)
                            .frame(height: 2),
                        alignment: .bottom
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .background(Theme.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Prices Card

    private var pricesCard: some View {
        VStack(spacing: 10) {
            HStack {
                if pricesLoading {
                    ProgressView().tint(Theme.gold).scaleEffect(0.8)
                    Text("جاري تحديث الأسعار...")
                        .font(.system(size: 12)).foregroundColor(Theme.textSecondary)
                } else if pricesError {
                    Image(systemName: "wifi.exclamationmark").font(.system(size: 13)).foregroundColor(Theme.textSecondary)
                    Text("سعر تقريبي").font(.system(size: 12)).foregroundColor(Theme.textSecondary)
                } else {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 13)).foregroundColor(.green)
                    Text("أسعار محدثة من السوق العالمي")
                        .font(.system(size: 12)).foregroundColor(.green.opacity(0.9))
                }
                Spacer()
                Button(action: { Task { await fetchPrices() } }) {
                    Image(systemName: "arrow.clockwise").font(.system(size: 13)).foregroundColor(Theme.gold)
                }
            }

            Divider().background(Theme.border)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(GoldEntry.availableKarats, id: \.self) { karat in
                    let price = goldPriceSAR * (Double(karat) / 24.0)
                    VStack(spacing: 3) {
                        Text("عيار \(karat)")
                            .font(.system(size: 11, weight: .bold)).foregroundColor(Theme.gold)
                        Text(String(format: "%.1f", price))
                            .font(.system(size: 14, weight: .bold)).foregroundColor(Theme.text)
                        Text("ريال/جرام")
                            .font(.system(size: 10)).foregroundColor(Theme.textSecondary)
                    }
                    .padding(.vertical, 8).frame(maxWidth: .infinity)
                    .background(Theme.background.opacity(0.6)).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.gold.opacity(0.2), lineWidth: 1))
                }
            }

            Divider().background(Theme.border)

            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "circle.fill").font(.system(size: 8)).foregroundColor(Theme.textSecondary)
                    Text("الفضة").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.textSecondary)
                    Text(String(format: "%.2f ريال/جرام", silverPriceSAR))
                        .font(.system(size: 12)).foregroundColor(Theme.text)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("النصاب (85 جرام عيار 24)")
                        .font(.system(size: 10)).foregroundColor(Theme.textSecondary)
                    Text(String(format: "%.0f ريال", nisabSAR))
                        .font(.system(size: 14, weight: .bold)).foregroundColor(Theme.gold)
                }
            }
        }
        .padding(14)
        .background(Theme.card).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Metals section

    private var metalsSection: some View {
        VStack(spacing: 12) {
            goldSection
            ZakatField(title: "الفضة (بالجرام)", value: $silverGrams, icon: "circle.righthalf.filled")
        }
    }

    private var goldSection: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "circle.fill").font(.system(size: 12)).foregroundColor(Theme.goldLight)
                    Text("الذهب").font(.system(size: 15, weight: .bold)).foregroundColor(Theme.gold)
                }
                Spacer()
                Button(action: addGoldEntry) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 15))
                        Text("إضافة عيار").font(.system(size: 13))
                    }
                    .foregroundColor(Theme.gold)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Theme.gold.opacity(0.12)).cornerRadius(8)
                }
            }
            .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 10)

            Divider().background(Theme.border)

            ForEach($goldEntries) { $entry in
                GoldEntryRow(entry: $entry, goldPriceSAR: goldPriceSAR,
                             canDelete: goldEntries.count > 1,
                             onDelete: { removeGoldEntry(entry) })
                if entry.id != goldEntries.last?.id {
                    Divider().background(Theme.border).padding(.horizontal, 14)
                }
            }

            if goldEntries.count > 1 {
                Divider().background(Theme.border)
                HStack {
                    Spacer()
                    Image(systemName: "sum").font(.system(size: 11)).foregroundColor(Theme.textSecondary)
                    Text(String(format: "إجمالي الذهب: %.2f ريال", totalGoldValue))
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.gold)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
            }
        }
        .background(Theme.card).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Cash section

    private var cashSection: some View {
        VStack(spacing: 12) {
            infoCard(
                icon: "banknote",
                color: .blue,
                title: "النقود والمدخرات",
                body: "تشمل: النقود الموجودة، الأرصدة البنكية، الودائع، الأسهم بقيمتها السوقية، والديون المستحقة لك."
            )
            ZakatField(title: "النقود والمدخرات (ريال)", value: $cashAmount, icon: "banknote")
            ZakatField(title: "الاستثمارات والأسهم (ريال)", value: $investmentAmount, icon: "chart.line.uptrend.xyaxis")
            ZakatField(title: "الديون المستحقة لك (ريال)", value: $receivableAmount, icon: "person.crop.circle.badge.checkmark")
        }
    }

    // MARK: - Trade section

    private var tradeSection: some View {
        VStack(spacing: 12) {
            infoCard(
                icon: "cart.fill",
                color: .green,
                title: "زكاة عروض التجارة",
                body: "تجب في كل ما أُعِدَّ للبيع والتكسب. يُقدَّر بالقيمة السوقية عند حلول الحول. المعادلة: (قيمة البضاعة + الديون المستحقة) × 2.5٪"
            )
            ZakatField(title: "قيمة البضاعة بالسوق الحالي (ريال)", value: $tradeGoodsValue, icon: "shippingbox.fill")
            ZakatField(title: "الديون التجارية المستحقة (ريال)", value: $tradeReceivables, icon: "doc.text.fill")
        }
    }

    // MARK: - Livestock section

    private var livestockSection: some View {
        VStack(spacing: 12) {
            infoCard(
                icon: "hare.fill",
                color: .brown,
                title: "زكاة الماشية",
                body: "تجب في الإبل والبقر والغنم إذا بلغت النصاب وحال عليها الحول، وكانت سائمة (ترعى المرعى الطبيعي معظم العام)."
            )

            // Camels
            ZakatField(title: "عدد الإبل", value: $camelsCount, icon: "circle.hexagonpath.fill")
            if let n = Int(camelsCount), n > 0 {
                livestockResultBadge(label: "الواجب في الإبل", value: camelZakat(n), color: .orange)
            }

            // Cattle
            ZakatField(title: "عدد البقر", value: $cattleCount, icon: "circle.dotted")
            if let n = Int(cattleCount), n > 0 {
                livestockResultBadge(label: "الواجب في البقر", value: cattleZakat(n), color: .brown)
            }

            // Sheep / Goats
            ZakatField(title: "عدد الغنم (الأغنام والمعز)", value: $sheepCount, icon: "circle.hexagongrid.fill")
            if let n = Int(sheepCount), n > 0 {
                livestockResultBadge(label: "الواجب في الغنم", value: sheepZakat(n), color: .gray)
            }

            Text("ملاحظة: للتأكد من أحكام الماشية تفصيلاً يُرجى الرجوع لأهل العلم.")
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    private func livestockResultBadge(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 14))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.text)
            }
            Spacer()
        }
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Info card

    private func infoCard(icon: String, color: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.text)
                Text(body)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                    .lineSpacing(3)
            }
        }
        .padding(12)
        .background(color.opacity(0.08))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.2), lineWidth: 1))
        .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: - Result Card

    private func resultCard(_ res: ZakatResult) -> some View {
        VStack(spacing: 12) {
            if res.isLivestockOnly {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle.fill").foregroundColor(Theme.gold)
                    Text("نتائج الماشية ظاهرة أعلاه بجانب كل نوع")
                        .font(.system(size: 15)).foregroundColor(Theme.text)
                }
            } else if res.total < nisabSAR {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle.fill").foregroundColor(Theme.gold)
                    Text("لم يبلغ المال النصاب، لا زكاة واجبة")
                        .font(.system(size: 15)).foregroundColor(Theme.text)
                }
            } else {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
                        Text("المال بلغ النصاب")
                            .font(.system(size: 14)).foregroundColor(Theme.textSecondary)
                    }
                    Text("مقدار الزكاة الواجبة")
                        .font(.system(size: 14)).foregroundColor(Theme.textSecondary)
                    Text(String(format: "%.2f ريال", res.zakat))
                        .font(.system(size: 36, weight: .bold)).foregroundColor(Theme.gold)

                    Divider().background(Theme.border)

                    VStack(spacing: 6) {
                        if res.goldValue > 0 { ResultDetailRow(label: "الذهب",        value: res.goldValue) }
                        if res.silverValue > 0 { ResultDetailRow(label: "الفضة",      value: res.silverValue) }
                        if res.cashValue > 0 { ResultDetailRow(label: "النقود",        value: res.cashValue) }
                        if res.investmentValue > 0 { ResultDetailRow(label: "الاستثمارات", value: res.investmentValue) }
                        if res.receivableValue > 0 { ResultDetailRow(label: "الديون المستحقة", value: res.receivableValue) }
                        if res.tradeValue > 0 { ResultDetailRow(label: "عروض التجارة", value: res.tradeValue) }
                        Divider().background(Theme.border)
                        HStack {
                            Text("الإجمالي").font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.text)
                            Spacer()
                            Text(String(format: "%.0f ريال", res.total))
                                .font(.system(size: 13, weight: .bold)).foregroundColor(Theme.gold)
                        }
                    }
                    Text(String(format: "(%.1f%% من الإجمالي)", zakatRate * 100))
                        .font(.system(size: 12)).foregroundColor(Theme.textSecondary)
                }
            }
        }
        .padding(20).frame(maxWidth: .infinity)
        .background(Theme.card).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.gold.opacity(0.3), lineWidth: 1.5))
    }

    // MARK: - Actions

    private func addGoldEntry() { goldEntries.append(GoldEntry()) }
    private func removeGoldEntry(_ entry: GoldEntry) {
        goldEntries.removeAll { $0.id == entry.id }
        result = nil
    }

    private func calculate() {
        // Livestock-only tab → just show the badge results
        if selectedTab == .livestock {
            result = ZakatResult(goldValue: 0, silverValue: 0, cashValue: 0,
                                 investmentValue: 0, receivableValue: 0,
                                 tradeValue: 0, total: 0, zakat: 0,
                                 isLivestockOnly: true)
            return
        }

        let silverVal       = (Double(silverGrams) ?? 0) * silverPriceSAR
        let cashVal         = Double(cashAmount) ?? 0
        let investVal       = Double(investmentAmount) ?? 0
        let receivableVal   = Double(receivableAmount) ?? 0
        let tradeGoodsVal   = Double(tradeGoodsValue) ?? 0
        let tradeReceivableVal = Double(tradeReceivables) ?? 0
        let tradeVal        = tradeGoodsVal + tradeReceivableVal

        let total = totalGoldValue + silverVal + cashVal + investVal + receivableVal + tradeVal
        let zakatAmount = total >= nisabSAR ? total * zakatRate : 0

        result = ZakatResult(
            goldValue:       totalGoldValue,
            silverValue:     silverVal,
            cashValue:       cashVal,
            investmentValue: investVal,
            receivableValue: receivableVal,
            tradeValue:      tradeVal,
            total:           total,
            zakat:           zakatAmount,
            isLivestockOnly: false
        )
    }

    private func fetchPrices() async {
        pricesLoading = true; pricesError = false
        async let goldFetch = fetchMetal("XAU")
        async let silverFetch = fetchMetal("XAG")
        let (goldUSD, silverUSD) = await (goldFetch, silverFetch)
        await MainActor.run {
            pricesLoading = false
            if let g = goldUSD, let s = silverUSD {
                goldPriceSAR = (g / 31.1035) * usdToSAR
                silverPriceSAR = (s / 31.1035) * usdToSAR
                pricesLoaded = true
            } else { pricesError = true }
        }
    }

    private func fetchMetal(_ symbol: String) async -> Double? {
        guard let url = URL(string: "https://api.gold-api.com/price/\(symbol)") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(MetalPriceResponse.self, from: data).price
        } catch { return nil }
    }
}

// MARK: - ZakatResult

struct ZakatResult {
    let goldValue: Double
    let silverValue: Double
    let cashValue: Double
    let investmentValue: Double
    let receivableValue: Double
    let tradeValue: Double
    let total: Double
    let zakat: Double
    var isLivestockOnly: Bool = false
}

// MARK: - GoldEntryRow

struct GoldEntryRow: View {
    @Binding var entry: GoldEntry
    let goldPriceSAR: Double
    let canDelete: Bool
    let onDelete: () -> Void

    private var entryValue: Double { (Double(entry.grams) ?? 0) * entry.purity * goldPriceSAR }
    private var pureGoldGrams: Double { (Double(entry.grams) ?? 0) * entry.purity }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Menu {
                    ForEach(GoldEntry.availableKarats, id: \.self) { k in
                        Button {
                            entry.karat = k
                        } label: {
                            HStack {
                                Text(GoldEntry.karatNames[k] ?? "عيار \(k)")
                                Text(String(format: "  (%.1f ريال/جرام)", goldPriceSAR * Double(k) / 24.0))
                                    .font(.system(size: 12)).foregroundColor(.secondary)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(GoldEntry.karatNames[entry.karat] ?? "عيار \(entry.karat)")
                            .font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.gold)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9)).foregroundColor(Theme.gold.opacity(0.7))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(Theme.gold.opacity(0.13)).cornerRadius(8)
                }

                TextField("الوزن بالجرام", text: $entry.grams)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 15)).foregroundColor(Theme.text)
                    .multilineTextAlignment(.trailing)

                if canDelete {
                    Button(action: onDelete) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 22)).foregroundColor(.red.opacity(0.75))
                    }
                }
            }

            if let gramsVal = Double(entry.grams), gramsVal > 0 {
                HStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Text(String(format: "%.2f جرام خالص", pureGoldGrams))
                            .font(.system(size: 11)).foregroundColor(Theme.textSecondary)
                        Text("•").foregroundColor(Theme.textSecondary).font(.system(size: 11))
                        Text(String(format: "%.2f ريال", entryValue))
                            .font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.goldLight)
                    }
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}

// MARK: - ResultDetailRow

struct ResultDetailRow: View {
    let label: String
    let value: Double

    var body: some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundColor(Theme.textSecondary)
            Spacer()
            Text(String(format: "%.2f ريال", value)).font(.system(size: 13)).foregroundColor(Theme.text)
        }
    }
}

// MARK: - ZakatField

struct ZakatField: View {
    let title: String
    @Binding var value: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            TextField(title, text: $value)
                .keyboardType(.decimalPad)
                .font(.system(size: 15)).foregroundColor(Theme.text)
                .multilineTextAlignment(.trailing)
            Image(systemName: icon)
                .font(.system(size: 20)).foregroundColor(Theme.gold).frame(width: 28)
        }
        .padding(14)
        .background(Theme.card).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
    }
}
