import SwiftUI

// MARK: - Models

struct ZikrItem: Identifiable {
    let id = UUID()
    let text: String
    let count: Int
    let source: String
}

struct AzkarCategory: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let items: [ZikrItem]
}

// MARK: - Azkar Data

let morningAzkar: [ZikrItem] = [
    ZikrItem(text: "أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ\nاللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ... (آية الكرسي)", count: 1, source: "البخاري"),
    ZikrItem(text: "أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ", count: 1, source: "مسلم"),
    ZikrItem(text: "اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ وَإِلَيْكَ النُّشُورُ", count: 1, source: "أبو داود والترمذي"),
    ZikrItem(text: "اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ", count: 1, source: "البخاري"),
    ZikrItem(text: "رَضِيتُ بِاللَّهِ رَبًّا، وَبِالإِسْلامِ دِينًا، وَبِمُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ نَبِيًّا", count: 3, source: "أبو داود"),
    ZikrItem(text: "اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَافِيَةَ فِي الدُّنْيَا وَالآخِرَةِ، اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي دِينِي وَدُنْيَايَ وَأَهْلِي وَمَالِي", count: 1, source: "ابن ماجه"),
    ZikrItem(text: "اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعِلْمَ النَّافِعَ، وَالرِّزْقَ الطَّيِّبَ، وَالْعَمَلَ الْمُتَقَبَّلَ", count: 1, source: "ابن ماجه"),
    ZikrItem(text: "بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ", count: 3, source: "أبو داود والترمذي"),
    ZikrItem(text: "اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي، لَا إِلَهَ إِلَّا أَنْتَ", count: 3, source: "أبو داود"),
    ZikrItem(text: "حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ", count: 7, source: "أبو داود"),
    ZikrItem(text: "اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَأَعُوذُ بِكَ مِنَ الْعَجْزِ وَالْكَسَلِ، وَأَعُوذُ بِكَ مِنَ الْجُبْنِ وَالْبُخْلِ، وَأَعُوذُ بِكَ مِنْ غَلَبَةِ الدَّيْنِ وَقَهْرِ الرِّجَالِ", count: 1, source: "البخاري"),
    ZikrItem(text: "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ", count: 100, source: "مسلم"),
    ZikrItem(text: "لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ", count: 10, source: "البخاري"),
    ZikrItem(text: "اللَّهُمَّ صَلِّ وَسَلِّمْ وَبَارِكْ عَلَى نَبِيِّنَا مُحَمَّدٍ", count: 10, source: ""),
]

let eveningAzkar: [ZikrItem] = [
    ZikrItem(text: "أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ\nاللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ... (آية الكرسي)", count: 1, source: "البخاري"),
    ZikrItem(text: "أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ", count: 1, source: "مسلم"),
    ZikrItem(text: "اللَّهُمَّ بِكَ أَمْسَيْنَا، وَبِكَ أَصْبَحْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ وَإِلَيْكَ الْمَصِيرُ", count: 1, source: "أبو داود والترمذي"),
    ZikrItem(text: "اللَّهُمَّ إِنِّي أَمْسَيْتُ أُشْهِدُكَ وَأُشْهِدُ حَمَلَةَ عَرْشِكَ، وَمَلَائِكَتَكَ وَجَمِيعَ خَلْقِكَ أَنَّكَ أَنْتَ اللَّهُ لَا إِلَهَ إِلَّا أَنْتَ وَحْدَكَ لَا شَرِيكَ لَكَ وَأَنَّ مُحَمَّدًا عَبْدُكَ وَرَسُولُكَ", count: 4, source: "أبو داود"),
    ZikrItem(text: "اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ", count: 1, source: "البخاري"),
    ZikrItem(text: "اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَأَعُوذُ بِكَ مِنَ الْعَجْزِ وَالْكَسَلِ، وَأَعُوذُ بِكَ مِنَ الْجُبْنِ وَالْبُخْلِ، وَأَعُوذُ بِكَ مِنْ غَلَبَةِ الدَّيْنِ وَقَهْرِ الرِّجَالِ", count: 1, source: "البخاري"),
    ZikrItem(text: "بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ", count: 3, source: "أبو داود والترمذي"),
    ZikrItem(text: "اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي، لَا إِلَهَ إِلَّا أَنْتَ", count: 3, source: "أبو داود"),
    ZikrItem(text: "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ", count: 100, source: "مسلم"),
    ZikrItem(text: "اللَّهُمَّ صَلِّ وَسَلِّمْ وَبَارِكْ عَلَى نَبِيِّنَا مُحَمَّدٍ", count: 10, source: ""),
]

let afterPrayerAzkar: [ZikrItem] = [
    ZikrItem(text: "أَسْتَغْفِرُ اللَّهَ", count: 3, source: "مسلم"),
    ZikrItem(text: "اللَّهُمَّ أَنْتَ السَّلَامُ، وَمِنْكَ السَّلَامُ، تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالإِكْرَامِ", count: 1, source: "مسلم"),
    ZikrItem(text: "لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، اللَّهُمَّ لَا مَانِعَ لِمَا أَعْطَيْتَ، وَلَا مُعْطِيَ لِمَا مَنَعْتَ، وَلَا يَنْفَعُ ذَا الْجَدِّ مِنْكَ الْجَدُّ", count: 1, source: "البخاري ومسلم"),
    ZikrItem(text: "سُبْحَانَ اللَّهِ", count: 33, source: "مسلم"),
    ZikrItem(text: "الْحَمْدُ لِلَّهِ", count: 33, source: "مسلم"),
    ZikrItem(text: "اللَّهُ أَكْبَرُ (٣٣ مرة) ثم: لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ", count: 34, source: "مسلم"),
    ZikrItem(text: "اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ... (آية الكرسي)", count: 1, source: "النسائي"),
    ZikrItem(text: "قُلْ هُوَ اللَّهُ أَحَدٌ (الإخلاص) + قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ + قُلْ أَعُوذُ بِرَبِّ النَّاسِ", count: 3, source: "أبو داود والترمذي"),
    ZikrItem(text: "لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ", count: 10, source: "الترمذي"),
    ZikrItem(text: "اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ", count: 1, source: "أبو داود"),
]

let sleepAzkar: [ZikrItem] = [
    ZikrItem(text: "بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا", count: 1, source: "البخاري"),
    ZikrItem(text: "اللَّهُمَّ قِنِي عَذَابَكَ يَوْمَ تَبْعَثُ عِبَادَكَ", count: 3, source: "أبو داود والترمذي"),
    ZikrItem(text: "بِاسْمِكَ رَبِّي وَضَعْتُ جَنْبِي، وَبِكَ أَرْفَعُهُ، فَإِنْ أَمْسَكْتَ نَفْسِي فَارْحَمْهَا، وَإِنْ أَرْسَلْتَهَا فَاحْفَظْهَا بِمَا تَحْفَظُ بِهِ عِبَادَكَ الصَّالِحِينَ", count: 1, source: "البخاري ومسلم"),
    ZikrItem(text: "اللَّهُمَّ أَسْلَمْتُ نَفْسِي إِلَيْكَ، وَفَوَّضْتُ أَمْرِي إِلَيْكَ، وَأَلْجَأْتُ ظَهْرِي إِلَيْكَ رَغْبَةً وَرَهْبَةً إِلَيْكَ، لَا مَلْجَأَ وَلَا مَنْجَا مِنْكَ إِلَّا إِلَيْكَ، آمَنْتُ بِكِتَابِكَ الَّذِي أَنْزَلْتَ وَبِنَبِيِّكَ الَّذِي أَرْسَلْتَ", count: 1, source: "البخاري ومسلم"),
    ZikrItem(text: "سُبْحَانَ اللَّهِ (٣٣)، الْحَمْدُ لِلَّهِ (٣٣)، اللَّهُ أَكْبَرُ (٣٤)", count: 1, source: "البخاري ومسلم"),
    ZikrItem(text: "قُلْ هُوَ اللَّهُ أَحَدٌ + الْمُعَوِّذَتَيْن (مرتين أو ثلاث مرات مع النفث على الجسد)", count: 3, source: "البخاري"),
    ZikrItem(text: "اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ... (آية الكرسي)", count: 1, source: "البخاري"),
]

let wakingAzkar: [ZikrItem] = [
    ZikrItem(text: "الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ", count: 1, source: "البخاري"),
    ZikrItem(text: "لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، سُبْحَانَ اللَّهِ وَالْحَمْدُ لِلَّهِ وَلَا إِلَهَ إِلَّا اللَّهُ وَاللَّهُ أَكْبَرُ وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ الْعَلِيِّ الْعَظِيمِ", count: 1, source: "البخاري"),
    ZikrItem(text: "اللَّهُمَّ إِنِّي أَسْأَلُكَ خَيْرَ هَذَا الْيَوْمِ، فَتْحَهُ وَنَصْرَهُ وَنُورَهُ وَبَرَكَتَهُ وَهُدَاهُ، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِيهِ وَشَرِّ مَا بَعْدَهُ", count: 1, source: "أبو داود"),
    ZikrItem(text: "الْحَمْدُ لِلَّهِ الَّذِي عَافَانِي فِي جَسَدِي وَرَدَّ عَلَيَّ رُوحِي وَأَذِنَ لِي بِذِكْرِهِ", count: 1, source: "الترمذي"),
]

let homeAzkar: [ZikrItem] = [
    ZikrItem(text: "بِسْمِ اللَّهِ وَلَجْنَا، وَبِسْمِ اللَّهِ خَرَجْنَا، وَعَلَى اللَّهِ رَبِّنَا تَوَكَّلْنَا", count: 1, source: "أبو داود"),
    ZikrItem(text: "اللَّهُمَّ إِنِّي أَسْأَلُكَ خَيْرَ الْمَوْلَجِ وَخَيْرَ الْمَخْرَجِ، بِسْمِ اللَّهِ وَلَجْنَا وَبِسْمِ اللَّهِ خَرَجْنَا وَعَلَى اللَّهِ رَبِّنَا تَوَكَّلْنَا", count: 1, source: "أبو داود"),
]

let eatAzkar: [ZikrItem] = [
    ZikrItem(text: "بِسْمِ اللَّهِ", count: 1, source: "أبو داود — قبل الأكل"),
    ZikrItem(text: "بِسْمِ اللَّهِ فِي أَوَّلِهِ وَآخِرِهِ", count: 1, source: "أبو داود — إذا نسي في البداية"),
    ZikrItem(text: "الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنِي هَذَا وَرَزَقَنِيهِ مِنْ غَيْرِ حَوْلٍ مِنِّي وَلَا قُوَّةٍ", count: 1, source: "الترمذي — بعد الأكل"),
    ZikrItem(text: "اللَّهُمَّ بَارِكْ لَنَا فِيهِ وَأَطْعِمْنَا خَيْرًا مِنْهُ", count: 1, source: "الترمذي — عند شرب اللبن"),
]

let tasbihAzkar: [ZikrItem] = [
    ZikrItem(text: "سُبْحَانَ اللَّهِ", count: 33, source: ""),
    ZikrItem(text: "الْحَمْدُ لِلَّهِ", count: 33, source: ""),
    ZikrItem(text: "اللَّهُ أَكْبَرُ", count: 34, source: ""),
    ZikrItem(text: "لَا إِلَهَ إِلَّا اللَّهُ", count: 100, source: "البخاري ومسلم"),
    ZikrItem(text: "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ سُبْحَانَ اللَّهِ الْعَظِيمِ", count: 100, source: "البخاري"),
    ZikrItem(text: "لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ", count: 100, source: ""),
    ZikrItem(text: "اللَّهُمَّ صَلِّ وَسَلِّمْ وَبَارِكْ عَلَى نَبِيِّنَا مُحَمَّدٍ", count: 100, source: ""),
    ZikrItem(text: "أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ", count: 100, source: "البخاري ومسلم"),
    ZikrItem(text: "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ", count: 100, source: "مسلم"),
]

let mosqueAzkar: [ZikrItem] = [
    ZikrItem(text: "اللَّهُمَّ افْتَحْ لِي أَبْوَابَ رَحْمَتِكَ — عند دخول المسجد", count: 1, source: "مسلم"),
    ZikrItem(text: "اللَّهُمَّ إِنِّي أَسْأَلُكَ مِنْ فَضْلِكَ — عند الخروج من المسجد", count: 1, source: "مسلم"),
    ZikrItem(text: "أَعُوذُ بِاللَّهِ الْعَظِيمِ وَبِوَجْهِهِ الْكَرِيمِ وَسُلْطَانِهِ الْقَدِيمِ مِنَ الشَّيْطَانِ الرَّجِيمِ — عند دخول المسجد", count: 1, source: "أبو داود"),
    ZikrItem(text: "بِسْمِ اللَّهِ وَالصَّلَاةُ وَالسَّلَامُ عَلَى رَسُولِ اللَّهِ — عند دخول المسجد", count: 1, source: "ابن ماجه"),
]

let travelAzkar: [ZikrItem] = [
    ZikrItem(text: "اللَّهُ أَكْبَرُ، اللَّهُ أَكْبَرُ، اللَّهُ أَكْبَرُ، سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَذَا وَمَا كُنَّا لَهُ مُقْرِنِينَ وَإِنَّا إِلَى رَبِّنَا لَمُنْقَلِبُونَ — عند ركوب المركبة", count: 1, source: "مسلم"),
    ZikrItem(text: "اللَّهُمَّ إِنَّا نَسْأَلُكَ فِي سَفَرِنَا هَذَا الْبِرَّ وَالتَّقْوَى، وَمِنَ الْعَمَلِ مَا تَرْضَى، اللَّهُمَّ هَوِّنْ عَلَيْنَا سَفَرَنَا هَذَا وَاطْوِ عَنَّا بُعْدَهُ", count: 1, source: "مسلم"),
    ZikrItem(text: "اللَّهُمَّ أَنْتَ الصَّاحِبُ فِي السَّفَرِ وَالْخَلِيفَةُ فِي الأَهْلِ — دعاء المسافر عند الوداع", count: 1, source: "مسلم"),
    ZikrItem(text: "أَسْتَوْدِعُكَ اللَّهَ الَّذِي لَا تَضِيعُ وَدَائِعُهُ — دعاء المودِّع للمسافر", count: 1, source: "ابن ماجه"),
]

let wuduAzkar: [ZikrItem] = [
    ZikrItem(text: "بِسْمِ اللَّهِ — قبل الوضوء", count: 1, source: "أبو داود"),
    ZikrItem(text: "أَشْهَدُ أَنْ لَّا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ وَأَشْهَدُ أَنَّ مُحَمَّدًا عَبْدُهُ وَرَسُولُهُ — بعد الوضوء", count: 1, source: "مسلم"),
    ZikrItem(text: "اللَّهُمَّ اجْعَلْنِي مِنَ التَّوَّابِينَ وَاجْعَلْنِي مِنَ الْمُتَطَهِّرِينَ — بعد الوضوء", count: 1, source: "الترمذي"),
    ZikrItem(text: "سُبْحَانَكَ اللَّهُمَّ وَبِحَمْدِكَ أَشْهَدُ أَنْ لَّا إِلَهَ إِلَّا أَنْتَ أَسْتَغْفِرُكَ وَأَتُوبُ إِلَيْكَ — بعد الوضوء", count: 1, source: "النسائي"),
]

let adhanAzkar: [ZikrItem] = [
    ZikrItem(text: "يُرَدِّد المسلم ما يقوله المؤذن — إجابة الأذان", count: 1, source: "البخاري ومسلم"),
    ZikrItem(text: "حَيَّ عَلَى الصَّلَاةِ / حَيَّ عَلَى الْفَلَاحِ → لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ — جواب الحيعلة", count: 1, source: "البخاري"),
    ZikrItem(text: "اللَّهُمَّ رَبَّ هَذِهِ الدَّعْوَةِ التَّامَّةِ وَالصَّلَاةِ الْقَائِمَةِ آتِ مُحَمَّدًا الْوَسِيلَةَ وَالْفَضِيلَةَ وَابْعَثْهُ مَقَامًا مَحْمُودًا الَّذِي وَعَدْتَهُ — بعد الأذان", count: 1, source: "البخاري"),
]

let allAzkarCategories: [AzkarCategory] = [
    AzkarCategory(title: "أذكار الصباح",     icon: "sun.horizon.fill",       color: .orange,  items: morningAzkar),
    AzkarCategory(title: "أذكار المساء",     icon: "moon.stars.fill",        color: .indigo,  items: eveningAzkar),
    AzkarCategory(title: "أذكار بعد الصلاة", icon: "hands.and.sparkles.fill", color: .green,   items: afterPrayerAzkar),
    AzkarCategory(title: "أذكار النوم",      icon: "bed.double.fill",        color: .blue,    items: sleepAzkar),
    AzkarCategory(title: "أذكار الاستيقاظ", icon: "alarm.fill",             color: .yellow,  items: wakingAzkar),
    AzkarCategory(title: "أذكار المسجد",     icon: "building.columns.fill",  color: .purple,  items: mosqueAzkar),
    AzkarCategory(title: "أذكار السفر",      icon: "airplane",               color: .cyan,    items: travelAzkar),
    AzkarCategory(title: "أذكار الوضوء",     icon: "drop.fill",              color: .teal,    items: wuduAzkar),
    AzkarCategory(title: "أذكار الأذان",     icon: "megaphone.fill",         color: .mint,    items: adhanAzkar),
    AzkarCategory(title: "أذكار المنزل",     icon: "house.fill",             color: Color(red: 0.6, green: 0.4, blue: 0.2), items: homeAzkar),
    AzkarCategory(title: "أذكار الأكل",      icon: "fork.knife",             color: .red,     items: eatAzkar),
    AzkarCategory(title: "تسبيح وذكر",      icon: "star.fill",              color: Color(red: 0.85, green: 0.70, blue: 0.35), items: tasbihAzkar),
]

// MARK: - Dua Data

let duaQuranic: [ZikrItem] = [
    ZikrItem(text: "رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ", count: 1, source: "البقرة: 201"),
    ZikrItem(text: "رَبَّنَا لَا تُزِغْ قُلُوبَنَا بَعْدَ إِذْ هَدَيْتَنَا وَهَبْ لَنَا مِن لَّدُنكَ رَحْمَةً إِنَّكَ أَنتَ الْوَهَّابُ", count: 1, source: "آل عمران: 8"),
    ZikrItem(text: "رَبَّنَا اغْفِرْ لَنَا ذُنُوبَنَا وَإِسْرَافَنَا فِي أَمْرِنَا وَثَبِّتْ أَقْدَامَنَا وَانصُرْنَا عَلَى الْقَوْمِ الْكَافِرِينَ", count: 1, source: "آل عمران: 147"),
    ZikrItem(text: "رَبَّنَا ظَلَمْنَا أَنفُسَنَا وَإِن لَّمْ تَغْفِرْ لَنَا وَتَرْحَمْنَا لَنَكُونَنَّ مِنَ الْخَاسِرِينَ", count: 1, source: "الأعراف: 23"),
    ZikrItem(text: "رَبِّ اشْرَحْ لِي صَدْرِي وَيَسِّرْ لِي أَمْرِي وَاحْلُلْ عُقْدَةً مِّن لِّسَانِي يَفْقَهُوا قَوْلِي", count: 1, source: "طه: 25-28"),
    ZikrItem(text: "رَبِّ زِدْنِي عِلْمًا", count: 1, source: "طه: 114"),
    ZikrItem(text: "لَّا إِلَهَ إِلَّا أَنتَ سُبْحَانَكَ إِنِّي كُنتُ مِنَ الظَّالِمِينَ", count: 1, source: "الأنبياء: 87 — دعاء يونس"),
    ZikrItem(text: "رَبِّ إِنِّي لِمَا أَنزَلْتَ إِلَيَّ مِنْ خَيْرٍ فَقِيرٌ", count: 1, source: "القصص: 24"),
    ZikrItem(text: "رَبَّنَا هَبْ لَنَا مِنْ أَزْوَاجِنَا وَذُرِّيَّاتِنَا قُرَّةَ أَعْيُنٍ وَاجْعَلْنَا لِلْمُتَّقِينَ إِمَامًا", count: 1, source: "الفرقان: 74"),
    ZikrItem(text: "رَبَّنَا اغْفِرْ لِي وَلِوَالِدَيَّ وَلِلْمُؤْمِنِينَ يَوْمَ يَقُومُ الْحِسَابُ", count: 1, source: "إبراهيم: 41"),
    ZikrItem(text: "حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ", count: 1, source: "آل عمران: 173"),
    ZikrItem(text: "رَبِّ أَوْزِعْنِي أَنْ أَشْكُرَ نِعْمَتَكَ الَّتِي أَنْعَمْتَ عَلَيَّ وَعَلَى وَالِدَيَّ وَأَنْ أَعْمَلَ صَالِحًا تَرْضَاهُ وَأَدْخِلْنِي بِرَحْمَتِكَ فِي عِبَادِكَ الصَّالِحِينَ", count: 1, source: "النمل: 19"),
]

let duaAnbiya: [ZikrItem] = [
    ZikrItem(text: "رَبِّ إِنِّي ظَلَمْتُ نَفْسِي فَاغْفِرْ لِي — دعاء موسى عليه السلام", count: 1, source: "القصص: 16"),
    ZikrItem(text: "لَا إِلَهَ إِلَّا أَنتَ سُبْحَانَكَ إِنِّي كُنتُ مِنَ الظَّالِمِينَ — دعاء يونس في بطن الحوت", count: 1, source: "الأنبياء: 87"),
    ZikrItem(text: "رَبِّ أَنِّي مَسَّنِيَ الضُّرُّ وَأَنتَ أَرْحَمُ الرَّاحِمِينَ — دعاء أيوب عليه السلام", count: 1, source: "الأنبياء: 83"),
    ZikrItem(text: "رَبِّ لَا تَذَرْنِي فَرْدًا وَأَنتَ خَيْرُ الْوَارِثِينَ — دعاء زكريا عليه السلام", count: 1, source: "الأنبياء: 89"),
    ZikrItem(text: "رَبَّنَا تَقَبَّلْ مِنَّا إِنَّكَ أَنتَ السَّمِيعُ الْعَلِيمُ — دعاء إبراهيم وإسماعيل عليهما السلام", count: 1, source: "البقرة: 127"),
    ZikrItem(text: "رَبِّ هَبْ لِي مِن لَّدُنكَ ذُرِّيَّةً طَيِّبَةً إِنَّكَ سَمِيعُ الدُّعَاءِ — دعاء زكريا عليه السلام", count: 1, source: "آل عمران: 38"),
    ZikrItem(text: "رَبِّ نَجِّنِي مِنَ الْقَوْمِ الظَّالِمِينَ — دعاء موسى عليه السلام", count: 1, source: "القصص: 21"),
    ZikrItem(text: "سُبْحَانَكَ تُبْتُ إِلَيْكَ وَأَنَا أَوَّلُ الْمُؤْمِنِينَ — دعاء موسى عليه السلام", count: 1, source: "الأعراف: 143"),
]

let duaKarb: [ZikrItem] = [
    ZikrItem(text: "لَا إِلَهَ إِلَّا اللَّهُ الْعَظِيمُ الْحَلِيمُ، لَا إِلَهَ إِلَّا اللَّهُ رَبُّ الْعَرْشِ الْعَظِيمِ، لَا إِلَهَ إِلَّا اللَّهُ رَبُّ السَّمَاوَاتِ وَرَبُّ الأَرْضِ وَرَبُّ الْعَرْشِ الْكَرِيمِ", count: 1, source: "البخاري ومسلم — دعاء الكرب"),
    ZikrItem(text: "اللَّهُمَّ رَحْمَتَكَ أَرْجُو فَلَا تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ عَيْنٍ، وَأَصْلِحْ لِي شَأْنِي كُلَّهُ لَا إِلَهَ إِلَّا أَنْتَ", count: 1, source: "أبو داود — دعاء الهمّ"),
    ZikrItem(text: "اللَّهُمَّ إِنِّي عَبْدُكَ وَابْنُ عَبْدِكَ وَابْنُ أَمَتِكَ، نَاصِيَتِي بِيَدِكَ، مَاضٍ فِيَّ حُكْمُكَ، عَدْلٌ فِيَّ قَضَاؤُكَ، أَسْأَلُكَ بِكُلِّ اسْمٍ هُوَ لَكَ سَمَّيْتَ بِهِ نَفْسَكَ أَوْ أَنْزَلْتَهُ فِي كِتَابِكَ أَوْ عَلَّمْتَهُ أَحَدًا مِنْ خَلْقِكَ أَوِ اسْتَأْثَرْتَ بِهِ فِي عِلْمِ الْغَيْبِ عِنْدَكَ أَنْ تَجْعَلَ الْقُرْآنَ رَبِيعَ قَلْبِي وَنُورَ صَدْرِي وَجَلَاءَ حُزْنِي وَذَهَابَ هَمِّي", count: 1, source: "أحمد — دعاء الغمّ والحزن"),
    ZikrItem(text: "يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ", count: 1, source: "الترمذي — دعاء الكرب"),
    ZikrItem(text: "لَا إِلَهَ إِلَّا أَنتَ سُبْحَانَكَ إِنِّي كُنتُ مِنَ الظَّالِمِينَ", count: 1, source: "الترمذي — دعاء الضيق"),
    ZikrItem(text: "حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ", count: 7, source: "أبو داود"),
]

let duaIstikhara: [ZikrItem] = [
    ZikrItem(text: "اللَّهُمَّ إِنِّي أَسْتَخِيرُكَ بِعِلْمِكَ وَأَسْتَقْدِرُكَ بِقُدْرَتِكَ وَأَسْأَلُكَ مِنْ فَضْلِكَ الْعَظِيمِ، فَإِنَّكَ تَقْدِرُ وَلَا أَقْدِرُ وَتَعْلَمُ وَلَا أَعْلَمُ وَأَنْتَ عَلَّامُ الْغُيُوبِ، اللَّهُمَّ إِنْ كُنْتَ تَعْلَمُ أَنَّ هَذَا الأَمْرَ خَيْرٌ لِي فِي دِينِي وَمَعَاشِي وَعَاقِبَةِ أَمْرِي فَاقْدُرْهُ لِي وَيَسِّرْهُ لِي ثُمَّ بَارِكْ لِي فِيهِ، وَإِنْ كُنْتَ تَعْلَمُ أَنَّ هَذَا الأَمْرَ شَرٌّ لِي فِي دِينِي وَمَعَاشِي وَعَاقِبَةِ أَمْرِي فَاصْرِفْهُ عَنِّي وَاصْرِفْنِي عَنْهُ وَاقْدُرْ لِي الْخَيْرَ حَيْثُ كَانَ ثُمَّ أَرْضِنِي بِهِ", count: 1, source: "البخاري — صلاة ودعاء الاستخارة"),
]

let duaRizq: [ZikrItem] = [
    ZikrItem(text: "اللَّهُمَّ اكْفِنِي بِحَلَالِكَ عَنْ حَرَامِكَ وَأَغْنِنِي بِفَضْلِكَ عَمَّنْ سِوَاكَ", count: 1, source: "الترمذي"),
    ZikrItem(text: "اللَّهُمَّ إِنِّي أَسْأَلُكَ الْهُدَى وَالتُّقَى وَالْعَفَافَ وَالْغِنَى", count: 1, source: "مسلم"),
    ZikrItem(text: "اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْمًا نَافِعًا وَرِزْقًا طَيِّبًا وَعَمَلًا مُتَقَبَّلًا", count: 1, source: "ابن ماجه"),
    ZikrItem(text: "اللَّهُمَّ بَارِكْ لَنَا فِيمَا رَزَقْتَنَا وَقِنَا عَذَابَ النَّارِ", count: 1, source: ""),
    ZikrItem(text: "رَبِّ إِنِّي لِمَا أَنزَلْتَ إِلَيَّ مِنْ خَيْرٍ فَقِيرٌ", count: 1, source: "القصص: 24"),
    ZikrItem(text: "اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْفَقْرِ وَالْقِلَّةِ وَالذِّلَّةِ وَأَعُوذُ بِكَ مِنْ أَنْ أَظْلِمَ أَوْ أُظْلَمَ", count: 1, source: "أبو داود والنسائي"),
]

let duaGhufran: [ZikrItem] = [
    ZikrItem(text: "أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ الَّذِي لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ وَأَتُوبُ إِلَيْهِ", count: 3, source: "الترمذي — سيد الاستغفار"),
    ZikrItem(text: "اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ وَأَبُوءُ لَكَ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ", count: 1, source: "البخاري — سيد الاستغفار"),
    ZikrItem(text: "اللَّهُمَّ اغْفِرْ لِي مَا قَدَّمْتُ وَمَا أَخَّرْتُ وَمَا أَسْرَرْتُ وَمَا أَعْلَنْتُ وَمَا أَسْرَفْتُ وَمَا أَنْتَ أَعْلَمُ بِهِ مِنِّي، أَنْتَ الْمُقَدِّمُ وَأَنْتَ الْمُؤَخِّرُ لَا إِلَهَ إِلَّا أَنْتَ", count: 1, source: "مسلم"),
    ZikrItem(text: "اللَّهُمَّ إِنَّكَ عَفُوٌّ تُحِبُّ الْعَفْوَ فَاعْفُ عَنِّي", count: 1, source: "الترمذي — دعاء ليلة القدر"),
    ZikrItem(text: "رَبَّنَا اغْفِرْ لَنَا وَلِإِخْوَانِنَا الَّذِينَ سَبَقُونَا بِالْإِيمَانِ وَلَا تَجْعَلْ فِي قُلُوبِنَا غِلًّا لِّلَّذِينَ آمَنُوا رَبَّنَا إِنَّكَ رَءُوفٌ رَّحِيمٌ", count: 1, source: "الحشر: 10"),
]

let duaWalidain: [ZikrItem] = [
    ZikrItem(text: "رَّبِّ ارْحَمْهُمَا كَمَا رَبَّيَانِي صَغِيرًا", count: 1, source: "الإسراء: 24"),
    ZikrItem(text: "رَبَّنَا اغْفِرْ لِي وَلِوَالِدَيَّ وَلِلْمُؤْمِنِينَ يَوْمَ يَقُومُ الْحِسَابُ", count: 1, source: "إبراهيم: 41"),
    ZikrItem(text: "اللَّهُمَّ اغْفِرْ لِي وَلِوَالِدَيَّ وَارْحَمْهُمَا كَمَا رَبَّيَانِي صَغِيرًا", count: 1, source: ""),
    ZikrItem(text: "رَبِّ اغْفِرْ لِي وَلِوَالِدَيَّ وَلِمَن دَخَلَ بَيْتِيَ مُؤْمِنًا وَلِلْمُؤْمِنِينَ وَالْمُؤْمِنَاتِ", count: 1, source: "نوح: 28"),
]

let duaHifz: [ZikrItem] = [
    ZikrItem(text: "اللَّهُمَّ احْفَظْنِي مِنْ بَيْنِ يَدَيَّ وَمِنْ خَلْفِي وَعَنْ يَمِينِي وَعَنْ شِمَالِي وَمِنْ فَوْقِي وَأَعُوذُ بِعَظَمَتِكَ أَنْ أُغْتَالَ مِنْ تَحْتِي", count: 1, source: "أبو داود — دعاء الحفظ"),
    ZikrItem(text: "بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ", count: 3, source: "أبو داود والترمذي"),
    ZikrItem(text: "أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ", count: 3, source: "مسلم — الحفظ من الشر"),
    ZikrItem(text: "أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّةِ مِنْ كُلِّ شَيْطَانٍ وَهَامَّةٍ وَمِنْ كُلِّ عَيْنٍ لَامَّةٍ", count: 1, source: "البخاري — دعاء للأطفال"),
    ZikrItem(text: "اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ وَالْعَجْزِ وَالْكَسَلِ وَالْبُخْلِ وَالْجُبْنِ وَضَلَعِ الدَّيْنِ وَغَلَبَةِ الرِّجَالِ", count: 1, source: "البخاري"),
]

let duaMizan: [ZikrItem] = [
    ZikrItem(text: "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ — ثقيلتان في الميزان", count: 1, source: "البخاري ومسلم"),
    ZikrItem(text: "سُبْحَانَ اللَّهِ وَالْحَمْدُ لِلَّهِ وَلَا إِلَهَ إِلَّا اللَّهُ وَاللَّهُ أَكْبَرُ — أحب الكلام إلى الله", count: 1, source: "مسلم"),
    ZikrItem(text: "لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ — تعدل عتق رقبة", count: 100, source: "البخاري ومسلم"),
    ZikrItem(text: "لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ — كنز من كنوز الجنة", count: 1, source: "البخاري ومسلم"),
    ZikrItem(text: "سُبْحَانَ اللَّهِ الْعَظِيمِ وَبِحَمْدِهِ — تُغْرَسُ نخلةٌ في الجنة", count: 1, source: "الترمذي"),
]

let allDuaCategories: [AzkarCategory] = [
    AzkarCategory(title: "أدعية قرآنية",    icon: "book.fill",               color: Color(red: 0.4, green: 0.6, blue: 0.3),  items: duaQuranic),
    AzkarCategory(title: "أدعية الأنبياء",  icon: "person.3.fill",           color: Color(red: 0.7, green: 0.4, blue: 0.1),  items: duaAnbiya),
    AzkarCategory(title: "دعاء الكرب",      icon: "heart.slash.fill",        color: .pink,                                   items: duaKarb),
    AzkarCategory(title: "دعاء الاستخارة",  icon: "questionmark.circle.fill", color: .purple,                                items: duaIstikhara),
    AzkarCategory(title: "دعاء الرزق",      icon: "banknote.fill",           color: .green,                                  items: duaRizq),
    AzkarCategory(title: "دعاء المغفرة",    icon: "hands.sparkles.fill",     color: Color(red: 0.2, green: 0.5, blue: 0.8),  items: duaGhufran),
    AzkarCategory(title: "دعاء الوالدين",   icon: "figure.2.and.child.holdinghands", color: .orange,                         items: duaWalidain),
    AzkarCategory(title: "دعاء الحفظ",      icon: "shield.fill",             color: .indigo,                                 items: duaHifz),
    AzkarCategory(title: "أذكار الميزان",   icon: "scalemass.fill",          color: Color(red: 0.85, green: 0.70, blue: 0.35), items: duaMizan),
]

// MARK: - Persistence Key Helper
// Uses "categoryTitle_itemIndex" so it survives UUID regeneration on re-launch

func azkarCountKey(category: String, index: Int) -> String {
    "azkar_count_\(category)_\(index)"
}
private let lastAzkarCategoryKey = "azkar_last_category"

// MARK: - AzkarView

struct AzkarView: View {
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    @EnvironmentObject private var lang: LanguageManager
    // يتغير كل ما تظهر الصفحة → يجبر كل الكروت على إعادة القراءة من UserDefaults
    @State private var refreshKey = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .trailing, spacing: 0) {

                        // ── Page Title ─────────────────────────────────────
                        Text(lang.t("الأذكار والأدعية", "Adhkar & Du'a"))
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(Theme.goldLight)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)

                        // ── Section: أذكار ─────────────────────────────────
                        SectionHeader(title: "الأذكار", subtitle: "أذكار السنة اليومية")

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(allAzkarCategories) { cat in
                                NavigationLink(destination: AzkarListView(category: cat)) {
                                    AzkarCategoryCard(category: cat, refreshKey: refreshKey)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)

                        // ── Divider ────────────────────────────────────────
                        HStack {
                            Rectangle().fill(Theme.gold.opacity(0.3)).frame(height: 1)
                            Image(systemName: "hands.sparkles.fill")
                                .foregroundColor(Theme.gold.opacity(0.6))
                                .font(.system(size: 14))
                            Rectangle().fill(Theme.gold.opacity(0.3)).frame(height: 1)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 4)

                        // ── Section: أدعية ─────────────────────────────────
                        SectionHeader(title: "الأدعية", subtitle: "أدعية مأثورة ومختارة")

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(allDuaCategories) { cat in
                                NavigationLink(destination: AzkarListView(category: cat)) {
                                    AzkarCategoryCard(category: cat, refreshKey: refreshKey)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            // كل ما يرجع المستخدم لهذه الصفحة → أعد رسم الكروت
            .onAppear { refreshKey += 1 }
        }
    }
}

// MARK: - Section Header

private struct SectionHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(Theme.goldLight)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }
}

struct AzkarCategoryCard: View {
    let category: AzkarCategory
    let refreshKey: Int          // تغييره يُعيد حساب completedCount
    @EnvironmentObject private var lang: LanguageManager

    // يُحسب من UserDefaults في كل render — refreshKey يضمن تحديثه عند العودة
    private var completedCount: Int {
        let _ = refreshKey       // اقرأ القيمة لإجبار SwiftUI على إعادة الحساب
        return category.items.indices.filter { i in
            let key = azkarCountKey(category: category.title, index: i)
            return UserDefaults.standard.integer(forKey: key) >= category.items[i].count
        }.count
    }

    var body: some View {
        let done  = completedCount
        let total = category.items.count
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(category.color.opacity(0.18)).frame(width: 56, height: 56)
                Image(systemName: category.icon).font(.system(size: 24)).foregroundColor(category.color)
            }
            Text(category.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.text)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            // Progress indicator
            Text(done == total ? "✓ مكتمل" : "\(done)/\(total)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(done == total ? .green : Theme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16)
        .background(Theme.card).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(
            done == total ? Color.green.opacity(0.5) : Theme.border,
            lineWidth: 1))
    }
}

// MARK: - AzkarListView

struct AzkarListView: View {
    let category: AzkarCategory

    // Counts loaded from/saved to UserDefaults — keyed by category+index (not UUID)
    @State private var counts: [Int: Int] = [:]
    @State private var showResetConfirm = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(category.items.enumerated()), id: \.element.id) { index, item in
                            let cur = counts[index] ?? 0
                            ZikrCard(
                                item: item,
                                currentCount: cur,
                                onTap: {
                                    let newVal = cur >= item.count ? 0 : cur + 1
                                    counts[index] = newVal
                                    // Persist immediately
                                    UserDefaults.standard.set(
                                        newVal,
                                        forKey: azkarCountKey(category: category.title, index: index)
                                    )
                                }
                            )
                            .id(index)
                        }
                    }
                    .padding(16)
                }
                .onAppear {
                    loadCounts()
                    // Scroll to first incomplete item
                    if let firstIncomplete = category.items.indices.first(where: {
                        (counts[$0] ?? 0) < category.items[$0].count
                    }) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation { proxy.scrollTo(firstIncomplete, anchor: .top) }
                        }
                    }
                    // Save last visited category
                    UserDefaults.standard.set(category.title, forKey: lastAzkarCategoryKey)
                }
            }
        }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showResetConfirm = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("إعادة")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(Theme.gold.opacity(0.8))
                }
            }
        }
        .confirmationDialog("إعادة ضبط الأذكار", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("إعادة الضبط", role: .destructive) { resetAll() }
            Button("إلغاء", role: .cancel) { }
        } message: {
            Text("سيتم إعادة جميع الأذكار إلى الصفر")
        }
    }

    private func loadCounts() {
        var loaded: [Int: Int] = [:]
        for i in category.items.indices {
            let key = azkarCountKey(category: category.title, index: i)
            loaded[i] = UserDefaults.standard.integer(forKey: key)
        }
        counts = loaded
    }

    private func resetAll() {
        for i in category.items.indices {
            counts[i] = 0
            UserDefaults.standard.set(0, forKey: azkarCountKey(category: category.title, index: i))
        }
    }
}

// MARK: - ZikrCard

struct ZikrCard: View {
    let item: ZikrItem
    let currentCount: Int
    let onTap: () -> Void

    var isComplete: Bool { currentCount >= item.count }
    var progress: Double { item.count > 1 ? Double(min(currentCount, item.count)) / Double(item.count) : (isComplete ? 1.0 : 0.0) }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .trailing, spacing: 12) {
                Text(item.text)
                    .font(.system(size: 17))
                    .foregroundColor(isComplete ? Theme.textSecondary : Theme.text)
                    .lineSpacing(8)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                HStack {
                    HStack(spacing: 5) {
                        if isComplete {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green).font(.system(size: 14))
                        }
                        Text(isComplete ? "تم ✓" : "\(currentCount)/\(item.count)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(isComplete ? .green : Theme.gold)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background((isComplete ? Color.green : Theme.gold).opacity(0.15))
                    .cornerRadius(20)

                    if !item.source.isEmpty {
                        Spacer()
                        Text(item.source)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                    } else {
                        Spacer()
                    }
                }

                if item.count > 1 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(Theme.border).frame(height: 4)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(isComplete ? Color.green : Theme.gold)
                                .frame(width: geo.size.width * progress, height: 4)
                                .animation(.easeInOut(duration: 0.15), value: progress)
                        }
                    }
                    .frame(height: 4)
                }
            }
            .padding(16)
            .background(isComplete ? Theme.card.opacity(0.6) : Theme.card)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                isComplete ? Color.green.opacity(0.4) : Theme.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
