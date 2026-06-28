import SwiftUI
import MapKit
import CoreLocation

// MARK: - Mosque Data Model

struct MosqueItem: Identifiable, Hashable {
    let id = UUID()
    let mapItem: MKMapItem

    var name: String {
        mapItem.name ?? "مسجد"
    }
    var coordinate: CLLocationCoordinate2D {
        mapItem.placemark.coordinate
    }
    var address: String {
        let p = mapItem.placemark
        return [p.thoroughfare, p.subThoroughfare, p.locality, p.administrativeArea]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: "، ")
    }
    var phoneNumber: String? { mapItem.phoneNumber }
    var url: URL?           { mapItem.url }

    var distanceMeters: Double = 0

    var distanceText: String {
        if distanceMeters < 1000 {
            return "\(Int(distanceMeters)) م"
        }
        let km = distanceMeters / 1000
        return String(format: "%.1f كم", km)
    }

    // Hashable / Equatable by id
    static func == (l: MosqueItem, r: MosqueItem) -> Bool { l.id == r.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - View Mode

private enum ViewMode: String, CaseIterable {
    case map  = "خريطة"
    case list = "قائمة"

    var icon: String {
        switch self {
        case .map:  return "map.fill"
        case .list: return "list.bullet"
        }
    }
}

// MARK: - Search Radius

private enum SearchRadius: Double, CaseIterable {
    case r500  =  500
    case r1km  = 1000
    case r2km  = 2000
    case r5km  = 5000

    var label: String {
        switch self {
        case .r500:  return "500 م"
        case .r1km:  return "1 كم"
        case .r2km:  return "2 كم"
        case .r5km:  return "5 كم"
        }
    }
}

// MARK: - NearbyMosquesView

struct NearbyMosquesView: View {

    @ObservedObject private var loc = SharedLocationManager.shared

    @State private var mosques:         [MosqueItem]       = []
    @State private var selectedMosque:  MosqueItem?        = nil
    @State private var region:          MKCoordinateRegion = .defaultRegion
    @State private var isLoading:       Bool               = false
    @State private var errorMessage:    String?            = nil
    @State private var viewMode:        ViewMode           = .map
    @State private var searchRadius:    SearchRadius       = .r2km
    @State private var showDetail:      Bool               = false
    @State private var searchDone:      Bool               = false
    @State private var activeSearch:    MKLocalSearch?     = nil

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Controls bar ──────────────────────────────────────
                controlBar
                    .zIndex(10)

                // ── Content ───────────────────────────────────────────
                ZStack {
                    if viewMode == .map {
                        mapView
                    } else {
                        listView
                    }

                    if isLoading {
                        loadingOverlay
                    }

                    if let err = errorMessage, !isLoading {
                        errorBanner(err)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // ── Mosque detail sheet ───────────────────────────────────
            if let mosque = selectedMosque, showDetail {
                MosqueDetailCard(
                    mosque:     mosque,
                    userCoord:  userCoordinate,
                    onDismiss:  { withAnimation { showDetail = false } }
                )
                .transition(.move(edge: .bottom))
                .zIndex(20)
            }
        }
        .navigationTitle("المساجد القريبة")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: search) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13))
                        Text("تحديث")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(Theme.gold)
                }
                .disabled(isLoading)
            }
        }
        .task { await initialLoad() }
        .onChange(of: searchRadius) { _ in search() }
        .onChange(of: loc.locationReceived) { received in
            if received && mosques.isEmpty {
                search()
            }
        }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                // View mode picker
                HStack(spacing: 0) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { viewMode = mode } }) {
                            HStack(spacing: 5) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 12))
                                Text(mode.rawValue)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(viewMode == mode ? Theme.background : Theme.text)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(viewMode == mode ? Theme.gold : Color.clear)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Theme.card)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))

                Spacer()

                // Results count
                if !mosques.isEmpty {
                    Text("\(mosques.count) مسجد")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Theme.card)
                        .cornerRadius(8)
                }
            }

            // Radius selector
            HStack(spacing: 8) {
                Text("نطاق البحث:")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)

                HStack(spacing: 0) {
                    ForEach(SearchRadius.allCases, id: \.self) { r in
                        Button(action: { searchRadius = r }) {
                            Text(r.label)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(searchRadius == r ? Theme.background : Theme.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(searchRadius == r ? Theme.gold : Color.clear)
                        }
                        .buttonStyle(.plain)

                        if r != SearchRadius.allCases.last {
                            Rectangle().fill(Theme.border).frame(width: 1, height: 18)
                        }
                    }
                }
                .background(Theme.card)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.background.opacity(0.97))
    }

    // MARK: - Map View

    private var mapView: some View {
        Map(coordinateRegion: $region,
            showsUserLocation: true,
            annotationItems: mosques)
        { mosque in
            MapAnnotation(coordinate: mosque.coordinate) {
                MosqueMapPin(
                    mosque:   mosque,
                    selected: selectedMosque?.id == mosque.id
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        selectedMosque = mosque
                        showDetail     = true
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onTapGesture {
            withAnimation { showDetail = false }
        }
    }

    // MARK: - List View

    private var listView: some View {
        ScrollView(showsIndicators: false) {
            if mosques.isEmpty && searchDone && !isLoading {
                emptyState
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(mosques) { mosque in
                        MosqueListRow(
                            mosque:   mosque,
                            selected: selectedMosque?.id == mosque.id
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                selectedMosque = mosque
                                showDetail     = true
                                // Pan map to selected mosque
                                region.center = mosque.coordinate
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 120)
            }
        }
    }

    // MARK: - Empty / Loading / Error

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 60)
            Image(systemName: "building.columns")
                .font(.system(size: 48))
                .foregroundColor(Theme.textSecondary.opacity(0.4))
            Text("لا توجد مساجد في نطاق البحث")
                .font(.system(size: 15))
                .foregroundColor(Theme.textSecondary)
            Text("جرّب توسيع نطاق البحث")
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary.opacity(0.7))
            Spacer()
        }
    }

    private var loadingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Theme.gold)
                .scaleEffect(1.3)
            Text("جارٍ البحث عن المساجد...")
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(24)
        .background(Theme.card.opacity(0.95))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.15), radius: 8)
    }

    private func errorBanner(_ message: String) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.text)
                Spacer()
                Button("إعادة المحاولة") { search() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.gold)
            }
            .padding(14)
            .background(Theme.card)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
    }

    // MARK: - Helpers

    private var userCoordinate: CLLocationCoordinate2D? {
        guard let lat = loc.latitude, let lng = loc.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    private func initialLoad() async {
        // Center map on user location if available
        if let coord = userCoordinate {
            region = MKCoordinateRegion(
                center:      coord,
                latitudinalMeters:  searchRadius.rawValue * 2.5,
                longitudinalMeters: searchRadius.rawValue * 2.5
            )
        }
        search()
    }

    // MARK: - Search (Apple MKLocalSearch)

    func search() {
        guard let userCoord = userCoordinate else {
            // Request location if not available
            loc.requestLocation()
            errorMessage = "يرجى تفعيل الموقع الجغرافي للبحث عن المساجد القريبة"
            return
        }
        errorMessage = nil
        isLoading    = true

        // Cancel any in-flight search before starting a new one
        activeSearch?.cancel()

        let searchCenter = userCoord
        let searchRegion = MKCoordinateRegion(
            center:      searchCenter,
            latitudinalMeters:  searchRadius.rawValue * 2,
            longitudinalMeters: searchRadius.rawValue * 2
        )

        // Update map region to match search area
        withAnimation {
            region = MKCoordinateRegion(
                center:      searchCenter,
                latitudinalMeters:  searchRadius.rawValue * 2.5,
                longitudinalMeters: searchRadius.rawValue * 2.5
            )
        }

        let request            = MKLocalSearch.Request()
        // Search both Arabic and English to get maximum results
        request.naturalLanguageQuery = "مسجد"
        request.region         = searchRegion
        request.resultTypes    = .pointOfInterest

        let localSearch = MKLocalSearch(request: request)
        activeSearch = localSearch
        localSearch.start { response, error in
            DispatchQueue.main.async {
                isLoading   = false
                searchDone  = true

                if error != nil {
                    // Retry with English if Arabic returned nothing
                    searchEnglish(center: searchCenter, region: searchRegion)
                    return
                }

                guard let items = response?.mapItems, !items.isEmpty else {
                    searchEnglish(center: searchCenter, region: searchRegion)
                    return
                }

                processMosques(items: items, userCoord: searchCenter)
            }
        }
    }

    private func searchEnglish(center: CLLocationCoordinate2D, region: MKCoordinateRegion) {
        isLoading = true
        let request            = MKLocalSearch.Request()
        request.naturalLanguageQuery = "mosque"
        request.region         = region
        request.resultTypes    = .pointOfInterest

        MKLocalSearch(request: request).start { response, error in
            DispatchQueue.main.async {
                isLoading  = false
                searchDone = true

                if let err = error {
                    errorMessage = "تعذّر البحث: \(err.localizedDescription)"
                    return
                }
                let items = response?.mapItems ?? []
                processMosques(items: items, userCoord: center)
            }
        }
    }

    private func processMosques(items: [MKMapItem], userCoord: CLLocationCoordinate2D) {
        let userLocation = CLLocation(latitude: userCoord.latitude, longitude: userCoord.longitude)

        var result: [MosqueItem] = items.compactMap { item -> MosqueItem? in
            let coord = item.placemark.coordinate
            let dist  = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                .distance(from: userLocation)
            // Filter to search radius
            guard dist <= searchRadius.rawValue else { return nil }
            var m = MosqueItem(mapItem: item)
            m.distanceMeters = dist
            return m
        }
        .sorted { $0.distanceMeters < $1.distanceMeters }

        // Fallback: if empty allow all regardless of strict radius
        if result.isEmpty {
            result = items.map { item in
                let coord = item.placemark.coordinate
                let dist  = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                    .distance(from: userLocation)
                var m = MosqueItem(mapItem: item)
                m.distanceMeters = dist
                return m
            }
            .sorted { $0.distanceMeters < $1.distanceMeters }
        }

        mosques = result

        if result.isEmpty { errorMessage = nil }
    }
}

// MARK: - MKCoordinateRegion default

private extension MKCoordinateRegion {
    static var defaultRegion: MKCoordinateRegion {
        // Default: Mecca
        MKCoordinateRegion(
            center:      CLLocationCoordinate2D(latitude: 21.3891, longitude: 39.8579),
            latitudinalMeters:  4000,
            longitudinalMeters: 4000
        )
    }
}

// MARK: - Mosque Map Pin

private struct MosqueMapPin: View {
    let mosque:   MosqueItem
    let selected: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(selected ? Theme.gold : Color(red: 0.04, green: 0.06, blue: 0.22))
                    .frame(width: selected ? 42 : 34, height: selected ? 42 : 34)
                    .shadow(color: .black.opacity(0.3), radius: selected ? 5 : 3)

                Image(systemName: "building.columns.fill")
                    .font(.system(size: selected ? 18 : 14))
                    .foregroundColor(selected ? Color(red: 0.04, green: 0.06, blue: 0.22) : Theme.gold)
            }

            // Callout triangle
            Triangle()
                .fill(selected ? Theme.gold : Color(red: 0.04, green: 0.06, blue: 0.22))
                .frame(width: 10, height: 6)
                .shadow(color: .black.opacity(0.2), radius: 2)

            if selected {
                Text(mosque.name)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Theme.card)
                    .cornerRadius(6)
                    .shadow(color: .black.opacity(0.15), radius: 3)
                    .padding(.top, 3)
            }
        }
        .animation(.spring(response: 0.25), value: selected)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to:    CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Mosque List Row

struct MosqueListRow: View {
    let mosque:   MosqueItem
    let selected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(selected ? Theme.gold.opacity(0.25) : Theme.gold.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Theme.gold)
            }

            // Info
            VStack(alignment: .trailing, spacing: 4) {
                Text(mosque.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)

                if !mosque.address.isEmpty {
                    Text(mosque.address)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Distance badge
            VStack(spacing: 4) {
                Text(mosque.distanceText)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(selected ? Theme.background : Theme.gold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(selected ? Theme.gold : Theme.gold.opacity(0.12))
                    .cornerRadius(8)

                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(12)
        .background(selected ? Theme.card.opacity(1) : Theme.card)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(selected ? Theme.gold.opacity(0.5) : Theme.border, lineWidth: selected ? 1.5 : 1)
        )
    }
}

// MARK: - Mosque Detail Card

struct MosqueDetailCard: View {
    let mosque:    MosqueItem
    let userCoord: CLLocationCoordinate2D?
    let onDismiss: () -> Void

    @State private var showCopied = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(Theme.border)
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)
                    .frame(maxWidth: .infinity)

                // Content
                VStack(alignment: .trailing, spacing: 14) {
                    // Header
                    HStack {
                        Button(action: onDismiss) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 3) {
                            Text(mosque.name)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(Theme.text)
                                .multilineTextAlignment(.trailing)

                            HStack(spacing: 6) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.gold)
                                Text(mosque.distanceText)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Theme.gold)
                            }
                        }
                    }

                    Divider().background(Theme.border)

                    // Address
                    if !mosque.address.isEmpty {
                        HStack(spacing: 10) {
                            Button(action: {
                                UIPasteboard.general.string = mosque.address
                                showCopied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showCopied = false }
                            }) {
                                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            VStack(alignment: .trailing, spacing: 3) {
                                Text("العنوان")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textSecondary)
                                Text(mosque.address)
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.text)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }

                    // Phone
                    if let phone = mosque.phoneNumber, !phone.isEmpty {
                        HStack(spacing: 10) {
                            Button(action: {
                                guard let url = URL(string: "tel://\(phone.filter { $0.isNumber || $0 == "+" })") else { return }
                                UIApplication.shared.open(url)
                            }) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.green)
                                    .frame(width: 36, height: 36)
                                    .background(Color.green.opacity(0.12))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            VStack(alignment: .trailing, spacing: 3) {
                                Text("الهاتف")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textSecondary)
                                Text(phone)
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.text)
                            }
                        }
                    }

                    // Action buttons
                    HStack(spacing: 10) {
                        // Apple Maps directions
                        Button(action: { openInAppleMaps() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "map.fill")
                                    .font(.system(size: 14))
                                Text("خرائط Apple")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(Theme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.card)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
                        }
                        .buttonStyle(.plain)

                        // Google Maps
                        Button(action: { openInGoogleMaps() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 14))
                                Text("خرائط Google")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(Theme.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.gold)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Theme.background)
            .cornerRadius(22, corners: [.topLeft, .topRight])
            .shadow(color: .black.opacity(0.2), radius: 20, y: -4)
            // Fill the home-indicator area below the card with background colour,
            // but keep the VStack itself bounded by the tab-bar safe area so the
            // action buttons are never hidden behind the tab bar.
            .background(Theme.background.ignoresSafeArea(edges: .bottom))
        }
    }

    // MARK: - Map opening

    private func openInAppleMaps() {
        let mapItem = mosque.mapItem
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }

    private func openInGoogleMaps() {
        let lat  = mosque.coordinate.latitude
        let lng  = mosque.coordinate.longitude
        let name = mosque.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        // Try Google Maps app first
        let appURL = URL(string: "comgooglemaps://?daddr=\(lat),\(lng)&directionsmode=walking&q=\(name)")
        if let url = appURL, UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            var comps = URLComponents(string: "https://www.google.com/maps/dir/")
            comps?.queryItems = [
                URLQueryItem(name: "api", value: "1"),
                URLQueryItem(name: "destination", value: "\(lat),\(lng)"),
                URLQueryItem(name: "travelmode", value: "walking")
            ]
            if let webURL = comps?.url {
                UIApplication.shared.open(webURL)
            }
        }
    }
}

// MARK: - Corner radius helper

private extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}

private struct RoundedCornerShape: Shape {
    let radius:  CGFloat
    let corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
