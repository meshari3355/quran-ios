import SwiftUI
import AVFoundation

// MARK: - Library Reciter Model
// cdnId = everyayah.com folder → https://everyayah.com/data/{cdnId}/{SSS}{AAA}.mp3
// نفس مجلدات موقع everyayah.com المستخدمة في قارئ القرآن (مضمونة الاشتغال)

struct LibraryReciter: Identifiable {
    let id: String
    let name: String
    let style: String      // "murattal" | "mujawwad" | "haram" | "educational"
    let cdnId: String      // everyayah.com folder name
    let description: String
}

let libraryReciters: [LibraryReciter] = [
    // ── مرتّل ────────────────────────────────────────────────────────────
    LibraryReciter(id: "maher",    name: "ماهر المعيقلي",
                   style: "murattal",   cdnId: "MaherAlMuaiqly128kbps",
                   description: "إمام المسجد الحرام، تلاوة رائعة ومؤثرة"),
    LibraryReciter(id: "afasy",    name: "مشاري العفاسي",
                   style: "murattal",   cdnId: "Alafasy_128kbps",
                   description: "صوت جميل ومميز، من الكويت"),
    LibraryReciter(id: "sudais",   name: "عبدالرحمن السديس",
                   style: "murattal",   cdnId: "Abdurrahmaan_As-Sudais_192kbps",
                   description: "إمام المسجد الحرام"),
    LibraryReciter(id: "shuraim",  name: "سعود الشريم",
                   style: "murattal",   cdnId: "Saood_ash-Shuraym_128kbps",
                   description: "إمام المسجد الحرام"),
    LibraryReciter(id: "ghamdi",   name: "سعد الغامدي",
                   style: "murattal",   cdnId: "Ghamadi_40kbps",
                   description: "تلاوة هادئة ومميزة"),
    LibraryReciter(id: "ajami",    name: "أحمد العجمي",
                   style: "murattal",   cdnId: "ahmed_ibn_ali_al_ajamy_128kbps",
                   description: "تلاوة خاشعة من الكويت"),
    LibraryReciter(id: "qtami",    name: "ناصر القطامي",
                   style: "murattal",   cdnId: "Nasser_Alqatami_128kbps",
                   description: "صوت مؤثر ومخشع"),
    LibraryReciter(id: "dosary",   name: "ياسر الدوسري",
                   style: "murattal",   cdnId: "Yasser_Ad-Dussary_128kbps",
                   description: "صوت خاشع من الرياض"),
    LibraryReciter(id: "shatri",   name: "أبو بكر الشاطري",
                   style: "murattal",   cdnId: "Abu_Bakr_Ash-Shaatree_128kbps",
                   description: "تلاوة رتيلة ومجودة"),
    LibraryReciter(id: "huthaify", name: "علي الحذيفي",
                   style: "murattal",   cdnId: "Hudhaify_128kbps",
                   description: "إمام المسجد النبوي"),

    // ── مجوّد ────────────────────────────────────────────────────────────
    LibraryReciter(id: "basit",    name: "عبدالباسط عبدالصمد",
                   style: "mujawwad",   cdnId: "Abdul_Basit_Mujawwad_128kbps",
                   description: "أسطورة التلاوة المجودة"),
    LibraryReciter(id: "jabril",   name: "محمد جبريل",
                   style: "mujawwad",   cdnId: "Muhammad_Jibreel_128kbps",
                   description: "تجويد واضح ومحكم"),
    LibraryReciter(id: "ayoub",    name: "محمد أيوب",
                   style: "mujawwad",   cdnId: "Muhammad_Ayyoub_128kbps",
                   description: "تجويد خاشع ومميز"),

    // ── الحرمين ──────────────────────────────────────────────────────────
    LibraryReciter(id: "sudais2",  name: "عبدالرحمن السديس",
                   style: "haram",      cdnId: "Abdurrahmaan_As-Sudais_192kbps",
                   description: "إمام المسجد الحرام — مكة"),
    LibraryReciter(id: "maher2",   name: "ماهر المعيقلي",
                   style: "haram",      cdnId: "MaherAlMuaiqly128kbps",
                   description: "إمام المسجد الحرام — مكة"),
    LibraryReciter(id: "huthaify2",name: "علي الحذيفي",
                   style: "haram",      cdnId: "Hudhaify_128kbps",
                   description: "إمام المسجد النبوي — المدينة"),

    // ── تعليمي ───────────────────────────────────────────────────────────
    LibraryReciter(id: "faresabbad",name: "فارس عباد",
                   style: "educational", cdnId: "Fares_Abbad_64kbps",
                   description: "صوت واضح مناسب للحفظ"),
    LibraryReciter(id: "juhaynee", name: "عبدالله الجهني",
                   style: "educational", cdnId: "Abdullaah_3awwaad_Al-Juhaynee_128kbps",
                   description: "تلاوة تعليمية هادئة"),
]

// MARK: - AudioLibraryView

struct AudioLibraryView: View {
    let filter: String

    @StateObject private var audioCache = AudioOfflineCacheManager.shared
    @State private var showOfflineSheet = false

    private var filteredReciters: [LibraryReciter] {
        libraryReciters.filter { $0.style == filter }
    }

    private var libraryTitle: String {
        switch filter {
        case "murattal":    return "تلاوات مرتّلة"
        case "mujawwad":    return "تلاوات مجوّدة"
        case "haram":       return "تلاوات الحرمين"
        case "educational": return "تلاوات تعليمية"
        default:            return "المكتبة الصوتية"
        }
    }

    private var libraryIcon: String {
        switch filter {
        case "murattal":    return "mic.fill"
        case "mujawwad":    return "waveform"
        case "haram":       return "house.fill"
        case "educational": return "graduationcap.fill"
        default:            return "music.note.list"
        }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {

                    // Info banner
                    HStack(spacing: 12) {
                        Image(systemName: libraryIcon)
                            .font(.system(size: 28))
                            .foregroundColor(Theme.gold)
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(libraryTitle)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Theme.goldLight)
                            Text("قراءة متصلة آية بآية — بدون انقطاع")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Theme.card)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.gold.opacity(0.3), lineWidth: 1))
                    .padding(.horizontal, 16)

                    // Offline download button (inline, visible always)
                    offlineStatusBanner
                        .padding(.horizontal, 16)

                    // Reciter list
                    VStack(spacing: 0) {
                        ForEach(Array(filteredReciters.enumerated()), id: \.element.id) { idx, reciter in
                            NavigationLink(destination: AudioSurahListView(reciter: reciter)) {
                                reciterRow(reciter)
                            }
                            .buttonStyle(.plain)
                            if idx < filteredReciters.count - 1 {
                                Divider().background(Theme.border).padding(.leading, 66)
                            }
                        }
                    }
                    .background(Theme.card)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
                .padding(.top, 12)
            }
        }
        .navigationTitle(libraryTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showOfflineSheet = true } label: {
                    Image(systemName: audioCache.isComplete
                          ? "arrow.down.circle.fill"
                          : (audioCache.isDownloading ? "stop.circle" : "arrow.down.circle"))
                        .foregroundColor(audioCache.isComplete ? .green : Theme.gold)
                }
            }
        }
        .sheet(isPresented: $showOfflineSheet) {
            audioOfflineSheet
        }
    }

    // MARK: - Offline banner
    private var offlineStatusBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill((audioCache.isComplete ? Color.green : Color.orange).opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: audioCache.isComplete
                      ? "wifi.slash" : (audioCache.isDownloading ? "arrow.down.circle" : "wifi.slash"))
                    .font(.system(size: 16))
                    .foregroundColor(audioCache.isComplete ? .green : .orange)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(audioCache.isComplete ? "متاح دون إنترنت" : "يعمل مع الإنترنت فقط")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.text)
                if audioCache.isDownloading {
                    Text("جارٍ التحميل... \(audioCache.downloadedFiles)/\(audioCache.totalFiles)")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                } else if audioCache.isComplete {
                    Text("ماهر المعيقلي — \(audioCache.totalFiles) آية")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                } else {
                    Text("اضغط لتحميل تلاوات ماهر المعيقلي بالكامل")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            Spacer()
            if audioCache.isDownloading {
                Button { audioCache.cancel() } label: {
                    Text("إيقاف")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            } else if !audioCache.isComplete {
                Button { audioCache.startFullDownloadIfNeeded() } label: {
                    Text("تحميل")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Theme.gold)
                        .cornerRadius(20)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Theme.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(
            (audioCache.isComplete ? Color.green : Color.orange).opacity(0.4), lineWidth: 1))
    }

    // MARK: - Offline sheet
    private var audioOfflineSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Progress bar if downloading
                if audioCache.isDownloading {
                    VStack(spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Theme.border)
                                    .frame(height: 8)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Theme.gold)
                                    .frame(width: geo.size.width * CGFloat(audioCache.progress), height: 8)
                                    .animation(.easeInOut(duration: 0.3), value: audioCache.progress)
                            }
                        }
                        .frame(height: 8)
                        HStack {
                            Text("\(Int(audioCache.progress * 100))%")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Theme.gold)
                            Spacer()
                            Text("\(audioCache.downloadedFiles) / \(audioCache.totalFiles) آية")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                OfflineDownloadButton(
                    title: "ماهر المعيقلي — القرآن كاملاً",
                    icon: "waveform",
                    color: Theme.gold,
                    isOffline: audioCache.isComplete,
                    isDownloading: audioCache.isDownloading,
                    progress: audioCache.progress,
                    cachedCount: audioCache.downloadedFiles,
                    totalCount: audioCache.totalFiles,
                    onDownload: { audioCache.startFullDownloadIfNeeded() },
                    onClear: {
                        audioCache.cancel()
                        // Clear downloaded audio files
                        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        let cacheDir = docs.appendingPathComponent("audio_cache")
                        try? FileManager.default.removeItem(at: cacheDir)
                    }
                )
                .padding(.horizontal, 16)

                Text("يتطلب حوالي 800 ميجابايت من مساحة التخزين.\nبعد التحميل تعمل التلاوات بدون إنترنت.")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("تحميل التلاوات")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("إغلاق") { showOfflineSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func reciterRow(_ r: LibraryReciter) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.gold.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "person.wave.2.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Theme.gold)
            }
            VStack(alignment: .trailing, spacing: 3) {
                Text(r.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.text)
                Text(r.description)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Text("متصلة")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.gold)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(Theme.gold.opacity(0.12))
                .cornerRadius(6)
            Image(systemName: "chevron.left")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - AudioSurahListView

struct AudioSurahListView: View {
    let reciter: LibraryReciter

    static let surahs: [(Int, String, Int)] = [
        (1,"الفاتحة",7),(2,"البقرة",286),(3,"آل عمران",200),(4,"النساء",176),
        (5,"المائدة",120),(6,"الأنعام",165),(7,"الأعراف",206),(8,"الأنفال",75),
        (9,"التوبة",129),(10,"يونس",109),(11,"هود",123),(12,"يوسف",111),
        (13,"الرعد",43),(14,"إبراهيم",52),(15,"الحجر",99),(16,"النحل",128),
        (17,"الإسراء",111),(18,"الكهف",110),(19,"مريم",98),(20,"طه",135),
        (21,"الأنبياء",112),(22,"الحج",78),(23,"المؤمنون",118),(24,"النور",64),
        (25,"الفرقان",77),(26,"الشعراء",227),(27,"النمل",93),(28,"القصص",88),
        (29,"العنكبوت",69),(30,"الروم",60),(31,"لقمان",34),(32,"السجدة",30),
        (33,"الأحزاب",73),(34,"سبأ",54),(35,"فاطر",45),(36,"يس",83),
        (37,"الصافات",182),(38,"ص",88),(39,"الزمر",75),(40,"غافر",85),
        (41,"فصلت",54),(42,"الشورى",53),(43,"الزخرف",89),(44,"الدخان",59),
        (45,"الجاثية",37),(46,"الأحقاف",35),(47,"محمد",38),(48,"الفتح",29),
        (49,"الحجرات",18),(50,"ق",45),(51,"الذاريات",60),(52,"الطور",49),
        (53,"النجم",62),(54,"القمر",55),(55,"الرحمن",78),(56,"الواقعة",96),
        (57,"الحديد",29),(58,"المجادلة",22),(59,"الحشر",24),(60,"الممتحنة",13),
        (61,"الصف",14),(62,"الجمعة",11),(63,"المنافقون",11),(64,"التغابن",18),
        (65,"الطلاق",12),(66,"التحريم",12),(67,"الملك",30),(68,"القلم",52),
        (69,"الحاقة",52),(70,"المعارج",44),(71,"نوح",28),(72,"الجن",28),
        (73,"المزمل",20),(74,"المدثر",56),(75,"القيامة",40),(76,"الإنسان",31),
        (77,"المرسلات",50),(78,"النبأ",40),(79,"النازعات",46),(80,"عبس",42),
        (81,"التكوير",29),(82,"الانفطار",19),(83,"المطففين",36),(84,"الانشقاق",25),
        (85,"البروج",22),(86,"الطارق",17),(87,"الأعلى",19),(88,"الغاشية",26),
        (89,"الفجر",30),(90,"البلد",20),(91,"الشمس",15),(92,"الليل",21),
        (93,"الضحى",11),(94,"الشرح",8),(95,"التين",8),(96,"العلق",19),
        (97,"القدر",5),(98,"البينة",8),(99,"الزلزلة",8),(100,"العاديات",11),
        (101,"القارعة",11),(102,"التكاثر",8),(103,"العصر",3),(104,"الهمزة",9),
        (105,"الفيل",5),(106,"قريش",4),(107,"الماعون",7),(108,"الكوثر",3),
        (109,"الكافرون",6),(110,"النصر",3),(111,"المسد",5),(112,"الإخلاص",4),
        (113,"الفلق",5),(114,"الناس",6)
    ]

    @State private var searchText = ""
    @StateObject private var player = ContinuousSurahPlayer()

    private var filtered: [(Int, String, Int)] {
        if searchText.isEmpty { return Self.surahs }
        return Self.surahs.filter { $0.1.contains(searchText) || "\($0.0)".contains(searchText) }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Search
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(Theme.textSecondary)
                    TextField("ابحث عن سورة...", text: $searchText).foregroundColor(Theme.text)
                }
                .padding(10)
                .background(Theme.card)
                .cornerRadius(10)
                .padding(.horizontal, 16).padding(.vertical, 8)

                // Surah list
                List {
                    ForEach(filtered, id: \.0) { num, name, ayahCount in
                        let isCurrent = player.currentSurahNumber == num
                        Button {
                            player.play(surahNumber: num, surahName: name,
                                        cdnId: reciter.cdnId,
                                        allSurahs: Self.surahs)
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(isCurrent ? Theme.gold : Theme.gold.opacity(0.12))
                                        .frame(width: 36, height: 36)
                                    Text(arabicNum(num))
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(isCurrent ? Theme.background : Theme.gold)
                                }
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text(name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(isCurrent ? Theme.goldLight : Theme.text)
                                    Text("\(arabicNum(ayahCount)) آية")
                                        .font(.system(size: 11))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                Spacer()
                                if isCurrent {
                                    if player.isLoading {
                                        ProgressView().tint(Theme.gold).scaleEffect(0.75)
                                    } else {
                                        Image(systemName: player.isPlaying ? "waveform" : "pause.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(Theme.gold)
                                    }
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(isCurrent ? Theme.gold.opacity(0.07) : Theme.background)
                    }
                }
                .listStyle(.plain)
                .background(Theme.background)
                .safeAreaInset(edge: .bottom) {
                    if player.currentSurahName != nil { Color.clear.frame(height: 120) }
                }
            }

            // Mini player
            if player.currentSurahName != nil {
                ContinuousMiniPlayer(player: player,
                                     reciterName: reciter.name,
                                     allSurahs: Self.surahs,
                                     cdnId: reciter.cdnId)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.8),
                               value: player.currentSurahName)
            }
        }
        .navigationTitle(reciter.name)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { player.stop() }
    }

    private func arabicNum(_ n: Int) -> String {
        let map: [Character: Character] =
            ["0":"٠","1":"١","2":"٢","3":"٣","4":"٤",
             "5":"٥","6":"٦","7":"٧","8":"٨","9":"٩"]
        return String(String(n).map { map[$0] ?? $0 })
    }
}

// MARK: - ContinuousMiniPlayer

struct ContinuousMiniPlayer: View {
    @ObservedObject var player: ContinuousSurahPlayer
    let reciterName: String
    let allSurahs: [(Int, String, Int)]
    let cdnId: String

    var body: some View {
        VStack(spacing: 0) {
            Divider().background(Theme.border)
            VStack(spacing: 10) {

                // ── Title row ──────────────────────────────────────
                HStack {
                    Button { player.stop() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text(player.currentSurahName ?? "")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.text)
                        Text(reciterName)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    Color.clear.frame(width: 22, height: 22)
                }

                // ── Ayah progress ──────────────────────────────────
                VStack(spacing: 4) {
                    // Step-based progress bar (read-only — reflects ayah index)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Theme.gold.opacity(0.18))
                                .frame(height: 4)
                            Capsule()
                                .fill(Theme.gold)
                                .frame(width: max(8, geo.size.width * player.progress), height: 4)
                                .animation(.easeInOut(duration: 0.3), value: player.progress)
                        }
                    }
                    .frame(height: 4)

                    // Ayah counter
                    HStack {
                        Text(player.isLoading ? "جاري التحميل..." :
                             (player.totalAyahs > 0 ?
                              "الآية \(player.currentAyah) من \(player.totalAyahs)" : ""))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text(player.currentSurahName ?? "")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textSecondary)
                    }
                }

                // ── Controls ───────────────────────────────────────
                HStack(spacing: 24) {
                    // Repeat playlist toggle
                    Button { player.repeatPlaylist.toggle() } label: {
                        Image(systemName: "repeat")
                            .font(.system(size: 18))
                            .foregroundColor(player.repeatPlaylist ? Theme.gold : Theme.textSecondary)
                            .overlay(
                                player.repeatPlaylist ?
                                Circle()
                                    .fill(Theme.gold)
                                    .frame(width: 5, height: 5)
                                    .offset(y: 11)
                                : nil
                            )
                    }

                    // Previous surah
                    Button { skipSurah(by: -1) } label: {
                        Image(systemName: "backward.end.fill")
                            .font(.system(size: 20))
                            .foregroundColor(canSkip(by: -1) ? Theme.gold : Theme.textSecondary)
                    }
                    .disabled(!canSkip(by: -1))

                    // Play / Pause
                    Button { player.togglePlay() } label: {
                        ZStack {
                            Circle()
                                .fill(Theme.gold)
                                .frame(width: 52, height: 52)
                            if player.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                    }

                    // Next surah
                    Button { skipSurah(by: +1) } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 20))
                            .foregroundColor(canSkip(by: 1) ? Theme.gold : Theme.textSecondary)
                    }
                    .disabled(!canSkip(by: 1))

                    // Next ayah shortcut
                    Button { player.nextAyah() } label: {
                        Image(systemName: "chevron.forward.2")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(
                                player.currentAyah < player.totalAyahs ? Theme.gold : Theme.textSecondary)
                    }
                    .disabled(player.currentAyah >= player.totalAyahs)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Theme.card.shadow(color: .black.opacity(0.18), radius: 12, y: -4))
        }
    }

    private func currentIndex() -> Int? {
        allSurahs.firstIndex { $0.0 == player.currentSurahNumber }
    }
    private func canSkip(by delta: Int) -> Bool {
        guard let idx = currentIndex() else { return false }
        let n = idx + delta
        return n >= 0 && n < allSurahs.count
    }
    private func skipSurah(by delta: Int) {
        guard let idx = currentIndex() else { return }
        let n = idx + delta
        guard n >= 0 && n < allSurahs.count else { return }
        let s = allSurahs[n]
        player.play(surahNumber: s.0, surahName: s.1,
                    cdnId: cdnId, allSurahs: allSurahs)
    }
}

// MARK: - ContinuousSurahPlayer
// يستخدم AVQueuePlayer مع ملفات everyayah.com الآية بالآية
// نفس مصدر قارئ القرآن → مضمون الاشتغال

class ContinuousSurahPlayer: NSObject, ObservableObject {
    @Published var isPlaying    = false
    @Published var isLoading    = false
    @Published var currentSurahNumber: Int?    = nil
    @Published var currentSurahName:   String? = nil
    @Published var currentAyah:        Int     = 0
    @Published var totalAyahs:         Int     = 0
    @Published var progress:           Double  = 0   // 0...1 — step by ayah
    @Published var repeatPlaylist:     Bool    = false  // إعادة تشغيل القائمة

    private var queuePlayer:    AVQueuePlayer?
    private var ayahURLs:       [URL]          = []    // store URLs for rebuild
    private var allItems:       [AVPlayerItem] = []    // current queue items
    private var currentItemObs: NSKeyValueObservation?
    private var statusObs:      NSKeyValueObservation?
    private var endObs:         Any?                   // for last ayah
    private var timeObs:        Any?

    private var allSurahs:  [(Int, String, Int)] = []
    private var activeCdnId = ""

    // MARK: - Play

    func play(surahNumber: Int, surahName: String,
              cdnId: String, allSurahs: [(Int, String, Int)]) {
        cleanup()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        self.allSurahs   = allSurahs
        self.activeCdnId = cdnId
        currentSurahNumber = surahNumber
        currentSurahName   = surahName

        guard let info = allSurahs.first(where: { $0.0 == surahNumber }) else { return }
        totalAyahs  = info.2
        currentAyah = 1
        progress    = 0
        isLoading   = true
        isPlaying   = true

        // Build URLs for every ayah in the surah — prefer cached files
        let cache = AudioOfflineCacheManager.shared
        ayahURLs = (1...totalAyahs).compactMap { ayah in
            // Use local file if cached, otherwise stream from network
            if let local = cache.cachedURL(surah: surahNumber, ayah: ayah, folder: cdnId) {
                return local
            }
            let s = String(format: "%03d", surahNumber)
            let a = String(format: "%03d", ayah)
            return URL(string: "https://everyayah.com/data/\(cdnId)/\(s)\(a).mp3")
        }

        buildQueueFrom(ayahIndex: 0)
    }

    // MARK: - Controls

    func togglePlay() {
        guard queuePlayer != nil else { return }
        if isPlaying { queuePlayer?.pause(); isPlaying = false }
        else         { queuePlayer?.play();  isPlaying = true  }
    }

    func nextAyah() {
        guard currentAyah < totalAyahs else { return }
        buildQueueFrom(ayahIndex: currentAyah)   // currentAyah is 1-based → index = currentAyah
    }

    func previousAyah() {
        guard currentAyah > 1 else { return }
        buildQueueFrom(ayahIndex: currentAyah - 2)  // go back one
    }

    func stop() {
        cleanup()
        isPlaying = false; isLoading = false
        currentSurahNumber = nil; currentSurahName = nil
        currentAyah = 0; totalAyahs = 0; progress = 0
    }

    // MARK: - Internal: build AVQueuePlayer from ayah index (0-based)

    private func buildQueueFrom(ayahIndex: Int) {
        cleanup()

        let startIdx = max(0, min(ayahIndex, ayahURLs.count - 1))
        allItems = ayahURLs[startIdx...].map { AVPlayerItem(url: $0) }
        queuePlayer = AVQueuePlayer(items: allItems)

        currentAyah = startIdx + 1
        progress    = totalAyahs > 0 ? Double(startIdx) / Double(totalAyahs) : 0

        // Observe current item changes → update ayah counter
        currentItemObs = queuePlayer?.observe(\.currentItem, options: [.new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let current = player.currentItem,
                   let pos = self.allItems.firstIndex(of: current) {
                    let globalIdx = startIdx + pos
                    self.currentAyah = globalIdx + 1
                    self.progress    = self.totalAyahs > 0
                        ? Double(globalIdx) / Double(self.totalAyahs) : 0
                    self.isLoading   = false
                }
            }
        }

        // Observe first item ready → hide spinner
        if let first = allItems.first {
            statusObs = first.observe(\.status, options: [.new]) { [weak self] item, _ in
                DispatchQueue.main.async {
                    if item.status == .readyToPlay { self?.isLoading = false }
                    else if item.status == .failed  { self?.isLoading = false }
                }
            }
        }

        // Observe end of last ayah → auto-advance to next surah
        if let last = allItems.last {
            endObs = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime, object: last, queue: .main
            ) { [weak self] _ in self?.onSurahComplete() }
        }

        // Smooth progress update within each ayah
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObs = queuePlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
            [weak self] time in
            guard let self = self,
                  let current = self.queuePlayer?.currentItem,
                  let pos = self.allItems.firstIndex(of: current) else { return }
            let globalIdx  = startIdx + pos
            let ayahFrac   = self.totalAyahs > 0 ? 1.0 / Double(self.totalAyahs) : 0
            let dur        = current.duration.seconds
            let withinFrac = (dur.isFinite && dur > 0) ? time.seconds / dur * ayahFrac : 0
            self.progress  = Double(globalIdx) / Double(max(1, self.totalAyahs)) + withinFrac
        }

        queuePlayer?.play()
    }

    // MARK: - Auto-advance to next surah (or repeat playlist)

    private func onSurahComplete() {
        guard let current = currentSurahNumber,
              let idx = allSurahs.firstIndex(where: { $0.0 == current })
        else { stop(); return }

        if idx + 1 < allSurahs.count {
            // Advance to next surah
            let next = allSurahs[idx + 1]
            play(surahNumber: next.0, surahName: next.1,
                 cdnId: activeCdnId, allSurahs: allSurahs)
        } else if repeatPlaylist, let first = allSurahs.first {
            // End of list + repeat enabled → restart from first surah
            play(surahNumber: first.0, surahName: first.1,
                 cdnId: activeCdnId, allSurahs: allSurahs)
        } else {
            stop()
        }
    }

    // MARK: - Cleanup

    private func cleanup() {
        if let obs = timeObs { queuePlayer?.removeTimeObserver(obs) }
        timeObs = nil
        endObs.map { NotificationCenter.default.removeObserver($0) }
        endObs = nil
        currentItemObs?.invalidate(); currentItemObs = nil
        statusObs?.invalidate();      statusObs      = nil
        queuePlayer?.pause();         queuePlayer    = nil
        allItems = []
    }

    deinit { cleanup() }
}
