import SwiftUI

// MARK: - 40 Nawawi Hadiths Data

struct NHadith: Identifiable {
    let id: Int
    let title: String         // short title
    let narrator: String      // الراوي
    let arabic: String        // النص العربي
    let source: String        // المصدر
}

let nawawiHadiths: [NHadith] = [
    NHadith(id: 1,
            title: "إنما الأعمال بالنيات",
            narrator: "عمر بن الخطاب رضي الله عنه",
            arabic: "إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ، وَإِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى، فَمَنْ كَانَتْ هِجْرَتُهُ إِلَى اللَّهِ وَرَسُولِهِ فَهِجْرَتُهُ إِلَى اللَّهِ وَرَسُولِهِ، وَمَنْ كَانَتْ هِجْرَتُهُ لِدُنْيَا يُصِيبُهَا أَوِ امْرَأَةٍ يَتَزَوَّجُهَا فَهِجْرَتُهُ إِلَى مَا هَاجَرَ إِلَيْهِ.",
            source: "رواه البخاري ومسلم"),
    NHadith(id: 2,
            title: "الإيمان وشعبه",
            narrator: "عمر بن الخطاب رضي الله عنه",
            arabic: "بَيْنَمَا نَحْنُ جُلُوسٌ عِنْدَ رَسُولِ اللَّهِ ﷺ ذَاتَ يَوْمٍ إِذْ طَلَعَ عَلَيْنَا رَجُلٌ شَدِيدُ بَيَاضِ الثِّيَابِ، شَدِيدُ سَوَادِ الشَّعَرِ... قَالَ: فَأَخْبِرْنِي عَنِ الإِسْلَامِ. فَقَالَ رَسُولُ اللَّهِ ﷺ: «الإِسْلَامُ أَنْ تَشْهَدَ أَنْ لَا إِلَهَ إِلَّا اللَّهُ وَأَنَّ مُحَمَّداً رَسُولُ اللَّهِ، وَتُقِيمَ الصَّلَاةَ، وَتُؤْتِيَ الزَّكَاةَ، وَتَصُومَ رَمَضَانَ، وَتَحُجَّ الْبَيْتَ إِنِ اسْتَطَعْتَ إِلَيْهِ سَبِيلاً» ...وَأَنْ تُؤْمِنَ بِاللَّهِ وَمَلَائِكَتِهِ وَكُتُبِهِ وَرُسُلِهِ وَالْيَوْمِ الآخِرِ، وَتُؤْمِنَ بِالْقَدَرِ خَيْرِهِ وَشَرِّهِ.",
            source: "رواه مسلم"),
    NHadith(id: 3,
            title: "أركان الإسلام الخمسة",
            narrator: "ابن عمر رضي الله عنهما",
            arabic: "بُنِيَ الإِسْلَامُ عَلَى خَمْسٍ: شَهَادَةِ أَنْ لَا إِلَهَ إِلَّا اللَّهُ وَأَنَّ مُحَمَّداً رَسُولُ اللَّهِ، وَإِقَامِ الصَّلَاةِ، وَإِيتَاءِ الزَّكَاةِ، وَصَوْمِ رَمَضَانَ، وَحَجِّ الْبَيْتِ.",
            source: "رواه البخاري ومسلم"),
    NHadith(id: 4,
            title: "مراحل خلق الإنسان",
            narrator: "عبدالله بن مسعود رضي الله عنه",
            arabic: "إِنَّ أَحَدَكُمْ يُجْمَعُ خَلْقُهُ فِي بَطْنِ أُمِّهِ أَرْبَعِينَ يَوْماً نُطْفَةً، ثُمَّ يَكُونُ عَلَقَةً مِثْلَ ذَلِكَ، ثُمَّ يَكُونُ مُضْغَةً مِثْلَ ذَلِكَ، ثُمَّ يُرْسَلُ إِلَيْهِ الْمَلَكُ فَيَنْفُخُ فِيهِ الرُّوحَ، وَيُؤْمَرُ بِأَرْبَعِ كَلِمَاتٍ: بِكَتْبِ رِزْقِهِ، وَأَجَلِهِ، وَعَمَلِهِ، وَشَقِيٌّ أَوْ سَعِيدٌ.",
            source: "رواه البخاري ومسلم"),
    NHadith(id: 5,
            title: "نهي المحدثات",
            narrator: "أم المؤمنين عائشة رضي الله عنها",
            arabic: "مَنْ أَحْدَثَ فِي أَمْرِنَا هَذَا مَا لَيْسَ مِنْهُ فَهُوَ رَدٌّ.",
            source: "رواه البخاري ومسلم"),
    NHadith(id: 6,
            title: "الحلال بيّن والحرام بيّن",
            narrator: "النعمان بن بشير رضي الله عنهما",
            arabic: "إِنَّ الْحَلَالَ بَيِّنٌ، وَإِنَّ الْحَرَامَ بَيِّنٌ، وَبَيْنَهُمَا أُمُورٌ مُشْتَبِهَاتٌ لَا يَعْلَمُهُنَّ كَثِيرٌ مِنَ النَّاسِ، فَمَنِ اتَّقَى الشُّبُهَاتِ فَقَدِ اسْتَبْرَأَ لِدِينِهِ وَعِرْضِهِ، وَمَنْ وَقَعَ فِي الشُّبُهَاتِ وَقَعَ فِي الْحَرَامِ، كَالرَّاعِي يَرْعَى حَوْلَ الْحِمَى يُوشِكُ أَنْ يَرْتَعَ فِيهِ.",
            source: "رواه البخاري ومسلم"),
    NHadith(id: 7,
            title: "الدين النصيحة",
            narrator: "تميم بن أوس الداري رضي الله عنه",
            arabic: "الدِّينُ النَّصِيحَةُ. قُلْنَا: لِمَنْ؟ قَالَ: لِلَّهِ وَلِكِتَابِهِ وَلِرَسُولِهِ وَلِأَئِمَّةِ الْمُسْلِمِينَ وَعَامَّتِهِمْ.",
            source: "رواه مسلم"),
    NHadith(id: 8,
            title: "حرمة دم المسلم",
            narrator: "ابن عمر رضي الله عنهما",
            arabic: "أُمِرْتُ أَنْ أُقَاتِلَ النَّاسَ حَتَّى يَشْهَدُوا أَنْ لَا إِلَهَ إِلَّا اللَّهُ وَأَنَّ مُحَمَّداً رَسُولُ اللَّهِ، وَيُقِيمُوا الصَّلَاةَ، وَيُؤْتُوا الزَّكَاةَ، فَإِذَا فَعَلُوا ذَلِكَ عَصَمُوا مِنِّي دِمَاءَهُمْ وَأَمْوَالَهُمْ إِلَّا بِحَقِّ الإِسْلَامِ، وَحِسَابُهُمْ عَلَى اللَّهِ.",
            source: "رواه البخاري ومسلم"),
    NHadith(id: 9,
            title: "ما نهيت عنه فاجتنبوه",
            narrator: "أبو هريرة رضي الله عنه",
            arabic: "مَا نَهَيْتُكُمْ عَنْهُ فَاجْتَنِبُوهُ، وَمَا أَمَرْتُكُمْ بِهِ فَافْعَلُوا مِنْهُ مَا اسْتَطَعْتُمْ، فَإِنَّمَا أَهْلَكَ الَّذِينَ مِنْ قَبْلِكُمْ كَثْرَةُ مَسَائِلِهِمْ وَاخْتِلَافُهُمْ عَلَى أَنْبِيَائِهِمْ.",
            source: "رواه البخاري ومسلم"),
    NHadith(id: 10,
            title: "الطيب لا يقبل إلا طيباً",
            narrator: "أبو هريرة رضي الله عنه",
            arabic: "إِنَّ اللَّهَ طَيِّبٌ لَا يَقْبَلُ إِلَّا طَيِّباً، وَإِنَّ اللَّهَ أَمَرَ الْمُؤْمِنِينَ بِمَا أَمَرَ بِهِ الْمُرْسَلِينَ فَقَالَ: ﴿يَا أَيُّهَا الرُّسُلُ كُلُوا مِنَ الطَّيِّبَاتِ وَاعْمَلُوا صَالِحاً﴾.",
            source: "رواه مسلم"),
    NHadith(id: 11,
            title: "دع ما يريبك",
            narrator: "الحسن بن علي رضي الله عنهما",
            arabic: "دَعْ مَا يَرِيبُكَ إِلَى مَا لَا يَرِيبُكَ.",
            source: "رواه الترمذي والنسائي"),
    NHadith(id: 12,
            title: "من حسن إسلام المرء",
            narrator: "أبو هريرة رضي الله عنه",
            arabic: "مِنْ حُسْنِ إِسْلَامِ الْمَرْءِ تَرْكُهُ مَا لَا يَعْنِيهِ.",
            source: "حديث حسن — رواه الترمذي وابن ماجه"),
    NHadith(id: 13,
            title: "حب الخير للمسلمين",
            narrator: "أنس بن مالك رضي الله عنه",
            arabic: "لَا يُؤْمِنُ أَحَدُكُمْ حَتَّى يُحِبَّ لِأَخِيهِ مَا يُحِبُّ لِنَفْسِهِ.",
            source: "رواه البخاري ومسلم"),
    NHadith(id: 14,
            title: "حرمة الدماء والأعراض والأموال",
            narrator: "ابن مسعود رضي الله عنه",
            arabic: "لَا يَحِلُّ دَمُ امْرِئٍ مُسْلِمٍ يَشْهَدُ أَنْ لَا إِلَهَ إِلَّا اللَّهُ وَأَنِّي رَسُولُ اللَّهِ إِلَّا بِإِحْدَى ثَلَاثٍ: النَّفْسُ بِالنَّفْسِ، وَالثَّيِّبُ الزَّانِي، وَالتَّارِكُ لِدِينِهِ الْمُفَارِقُ لِلْجَمَاعَةِ.",
            source: "رواه البخاري ومسلم"),
    NHadith(id: 15,
            title: "من كان يؤمن بالله واليوم الآخر",
            narrator: "أبو هريرة رضي الله عنه",
            arabic: "مَنْ كَانَ يُؤْمِنُ بِاللَّهِ وَالْيَوْمِ الآخِرِ فَلْيَقُلْ خَيْراً أَوْ لِيَصْمُتْ، وَمَنْ كَانَ يُؤْمِنُ بِاللَّهِ وَالْيَوْمِ الآخِرِ فَلْيُكْرِمْ جَارَهُ، وَمَنْ كَانَ يُؤْمِنُ بِاللَّهِ وَالْيَوْمِ الآخِرِ فَلْيُكْرِمْ ضَيْفَهُ.",
            source: "رواه البخاري ومسلم"),
    NHadith(id: 16,
            title: "لا تغضب",
            narrator: "أبو هريرة رضي الله عنه",
            arabic: "أَنَّ رَجُلاً قَالَ لِلنَّبِيِّ ﷺ: أَوْصِنِي. قَالَ: لَا تَغْضَبْ. فَرَدَّدَ مِرَاراً، قَالَ: لَا تَغْضَبْ.",
            source: "رواه البخاري"),
    NHadith(id: 17,
            title: "الإحسان في كل شيء",
            narrator: "أبو يعلى شداد بن أوس رضي الله عنه",
            arabic: "إِنَّ اللَّهَ كَتَبَ الإِحْسَانَ عَلَى كُلِّ شَيْءٍ، فَإِذَا قَتَلْتُمْ فَأَحْسِنُوا الْقِتْلَةَ، وَإِذَا ذَبَحْتُمْ فَأَحْسِنُوا الذِّبْحَةَ، وَلْيُحِدَّ أَحَدُكُمْ شَفْرَتَهُ، وَلْيُرِحْ ذَبِيحَتَهُ.",
            source: "رواه مسلم"),
    NHadith(id: 18,
            title: "اتق الله حيثما كنت",
            narrator: "أبو ذر رضي الله عنه",
            arabic: "اتَّقِ اللَّهَ حَيْثُمَا كُنْتَ، وَأَتْبِعِ السَّيِّئَةَ الْحَسَنَةَ تَمْحُهَا، وَخَالِقِ النَّاسَ بِخُلُقٍ حَسَنٍ.",
            source: "حديث حسن — رواه الترمذي"),
    NHadith(id: 19,
            title: "احفظ الله يحفظك",
            narrator: "ابن عباس رضي الله عنهما",
            arabic: "احْفَظِ اللَّهَ يَحْفَظْكَ، احْفَظِ اللَّهَ تَجِدْهُ تُجَاهَكَ، إِذَا سَأَلْتَ فَاسْأَلِ اللَّهَ، وَإِذَا اسْتَعَنْتَ فَاسْتَعِنْ بِاللَّهِ، وَاعْلَمْ أَنَّ الأُمَّةَ لَوِ اجْتَمَعَتْ عَلَى أَنْ يَنْفَعُوكَ بِشَيْءٍ لَمْ يَنْفَعُوكَ إِلَّا بِشَيْءٍ قَدْ كَتَبَهُ اللَّهُ لَكَ.",
            source: "رواه الترمذي"),
    NHadith(id: 20,
            title: "الحياء من الإيمان",
            narrator: "ابن عمر رضي الله عنهما",
            arabic: "الْحَيَاءُ وَالإِيمَانُ قُرِنَا جَمِيعاً، فَإِذَا رُفِعَ أَحَدُهُمَا رُفِعَ الآخَرُ.",
            source: "رواه الحاكم في المستدرك"),
    NHadith(id: 21,
            title: "قل آمنت بالله ثم استقم",
            narrator: "سفيان بن عبدالله الثقفي رضي الله عنه",
            arabic: "قُلْ آمَنْتُ بِاللَّهِ ثُمَّ اسْتَقِمْ.",
            source: "رواه مسلم"),
    NHadith(id: 22,
            title: "المسلم من سلم الناس",
            narrator: "عبدالله بن عمرو رضي الله عنهما",
            arabic: "الْمُسْلِمُ مَنْ سَلِمَ الْمُسْلِمُونَ مِنْ لِسَانِهِ وَيَدِهِ، وَالْمُهَاجِرُ مَنْ هَجَرَ مَا نَهَى اللَّهُ عَنْهُ.",
            source: "رواه البخاري"),
    NHadith(id: 23,
            title: "الطهور شطر الإيمان",
            narrator: "أبو مالك الأشعري رضي الله عنه",
            arabic: "الطُّهُورُ شَطْرُ الإِيمَانِ، وَالْحَمْدُ لِلَّهِ تَمْلَأُ الْمِيزَانَ، وَسُبْحَانَ اللَّهِ وَالْحَمْدُ لِلَّهِ تَمْلَآنِ أَوْ تَمْلَأُ مَا بَيْنَ السَّمَاوَاتِ وَالأَرْضِ.",
            source: "رواه مسلم"),
    NHadith(id: 24,
            title: "تحريم الظلم",
            narrator: "أبو ذر الغفاري رضي الله عنه",
            arabic: "يَا عِبَادِي إِنِّي حَرَّمْتُ الظُّلْمَ عَلَى نَفْسِي وَجَعَلْتُهُ بَيْنَكُمْ مُحَرَّماً فَلَا تَظَالَمُوا.",
            source: "رواه مسلم"),
    NHadith(id: 25,
            title: "الصدقة تطفئ الخطيئة",
            narrator: "أبو ذر رضي الله عنه",
            arabic: "الصَّدَقَةُ تُطْفِئُ الْخَطِيئَةَ كَمَا يُطْفِئُ الْمَاءُ النَّارَ.",
            source: "رواه الترمذي — حديث حسن صحيح"),
    NHadith(id: 26,
            title: "كل سلامى من الناس عليه صدقة",
            narrator: "أبو هريرة رضي الله عنه",
            arabic: "كُلُّ سُلَامَى مِنَ النَّاسِ عَلَيْهِ صَدَقَةٌ، كُلَّ يَوْمٍ تَطْلُعُ فِيهِ الشَّمْسُ، تَعْدِلُ بَيْنَ الِاثْنَيْنِ صَدَقَةٌ، وَتُعِينُ الرَّجُلَ فِي دَابَّتِهِ فَتَحْمِلُهُ عَلَيْهَا صَدَقَةٌ.",
            source: "رواه البخاري ومسلم"),
    NHadith(id: 27,
            title: "البر حسن الخلق",
            narrator: "النواس بن سمعان رضي الله عنه",
            arabic: "الْبِرُّ حُسْنُ الْخُلُقِ، وَالإِثْمُ مَا حَاكَ فِي نَفْسِكَ وَكَرِهْتَ أَنْ يَطَّلِعَ عَلَيْهِ النَّاسُ.",
            source: "رواه مسلم"),
    NHadith(id: 28,
            title: "الزهد في الدنيا",
            narrator: "ابن عمر رضي الله عنهما",
            arabic: "كُنْ فِي الدُّنْيَا كَأَنَّكَ غَرِيبٌ أَوْ عَابِرُ سَبِيلٍ.",
            source: "رواه البخاري"),
    NHadith(id: 29,
            title: "لا ضرر ولا ضرار",
            narrator: "ابن عباس رضي الله عنهما",
            arabic: "لَا ضَرَرَ وَلَا ضِرَارَ.",
            source: "رواه ابن ماجه — حديث حسن"),
    NHadith(id: 30,
            title: "حدود الله",
            narrator: "أبو ثعلبة الخشني رضي الله عنه",
            arabic: "إِنَّ اللَّهَ حَدَّ حُدُوداً فَلَا تَعْتَدُوهَا، وَفَرَضَ فَرَائِضَ فَلَا تُضَيِّعُوهَا، وَحَرَّمَ أَشْيَاءَ فَلَا تَنْتَهِكُوهَا، وَسَكَتَ عَنْ أَشْيَاءَ رَحْمَةً لَكُمْ غَيْرَ نِسْيَانٍ فَلَا تَبْحَثُوا عَنْهَا.",
            source: "حديث حسن — رواه الدارقطني"),
    NHadith(id: 31,
            title: "الزهد في الدنيا يحبك الله",
            narrator: "سهل بن سعد رضي الله عنه",
            arabic: "ازْهَدْ فِي الدُّنْيَا يُحِبَّكَ اللَّهُ، وَازْهَدْ فِيمَا فِي أَيْدِي النَّاسِ يُحِبُّوكَ.",
            source: "حديث حسن — رواه ابن ماجه"),
    NHadith(id: 32,
            title: "لا ضرر ولا ضرار — النسخة الموسعة",
            narrator: "أبو سعيد الخدري رضي الله عنه",
            arabic: "لَا ضَرَرَ وَلَا ضِرَارَ، مَنْ ضَارَّ ضَارَّهُ اللَّهُ، وَمَنْ شَاقَّ شَقَّ اللَّهُ عَلَيْهِ.",
            source: "رواه الحاكم"),
    NHadith(id: 33,
            title: "القضاء بالبينة",
            narrator: "ابن عباس رضي الله عنهما",
            arabic: "لَوْ يُعْطَى النَّاسُ بِدَعْوَاهُمْ لَادَّعَى نَاسٌ دِمَاءَ رِجَالٍ وَأَمْوَالَهُمْ، وَلَكِنَّ الْبَيِّنَةَ عَلَى الْمُدَّعِي وَالْيَمِينَ عَلَى مَنْ أَنْكَرَ.",
            source: "رواه البيهقي — حديث حسن"),
    NHadith(id: 34,
            title: "تغيير المنكر",
            narrator: "أبو سعيد الخدري رضي الله عنه",
            arabic: "مَنْ رَأَى مِنْكُمْ مُنْكَراً فَلْيُغَيِّرْهُ بِيَدِهِ، فَإِنْ لَمْ يَسْتَطِعْ فَبِلِسَانِهِ، فَإِنْ لَمْ يَسْتَطِعْ فَبِقَلْبِهِ، وَذَلِكَ أَضْعَفُ الإِيمَانِ.",
            source: "رواه مسلم"),
    NHadith(id: 35,
            title: "المساواة في الحقوق",
            narrator: "أبو هريرة رضي الله عنه",
            arabic: "لَا تَحَاسَدُوا، وَلَا تَنَاجَشُوا، وَلَا تَبَاغَضُوا، وَلَا تَدَابَرُوا، وَلَا يَبِعْ بَعْضُكُمْ عَلَى بَيْعِ بَعْضٍ، وَكُونُوا عِبَادَ اللَّهِ إِخْوَاناً.",
            source: "رواه مسلم"),
    NHadith(id: 36,
            title: "من نفّس كربة",
            narrator: "أبو هريرة رضي الله عنه",
            arabic: "مَنْ نَفَّسَ عَنْ مُؤْمِنٍ كُرْبَةً مِنْ كُرَبِ الدُّنْيَا نَفَّسَ اللَّهُ عَنْهُ كُرْبَةً مِنْ كُرَبِ يَوْمِ الْقِيَامَةِ، وَمَنْ يَسَّرَ عَلَى مُعْسِرٍ يَسَّرَ اللَّهُ عَلَيْهِ فِي الدُّنْيَا وَالآخِرَةِ.",
            source: "رواه مسلم"),
    NHadith(id: 37,
            title: "الله يكتب الحسنات والسيئات",
            narrator: "ابن عباس رضي الله عنهما",
            arabic: "إِنَّ اللَّهَ كَتَبَ الْحَسَنَاتِ وَالسَّيِّئَاتِ ثُمَّ بَيَّنَ ذَلِكَ، فَمَنْ هَمَّ بِحَسَنَةٍ فَلَمْ يَعْمَلْهَا كَتَبَهَا اللَّهُ عِنْدَهُ حَسَنَةً كَامِلَةً، وَإِنْ هَمَّ بِهَا فَعَمِلَهَا كَتَبَهَا اللَّهُ عَشْرَ حَسَنَاتٍ إِلَى سَبْعِمِائَةِ ضِعْفٍ.",
            source: "رواه البخاري ومسلم"),
    NHadith(id: 38,
            title: "من عادى لي ولياً",
            narrator: "أبو هريرة رضي الله عنه",
            arabic: "إِنَّ اللَّهَ قَالَ: مَنْ عَادَى لِي وَلِيًّا فَقَدْ آذَنْتُهُ بِالْحَرْبِ، وَمَا تَقَرَّبَ إِلَيَّ عَبْدِي بِشَيْءٍ أَحَبَّ إِلَيَّ مِمَّا افْتَرَضْتُهُ عَلَيْهِ.",
            source: "رواه البخاري"),
    NHadith(id: 39,
            title: "إن الله تجاوز عن أمتي",
            narrator: "ابن عباس رضي الله عنهما",
            arabic: "إِنَّ اللَّهَ تَجَاوَزَ عَنْ أُمَّتِي الْخَطَأَ وَالنِّسْيَانَ وَمَا اسْتُكْرِهُوا عَلَيْهِ.",
            source: "رواه ابن ماجه — حديث حسن"),
    NHadith(id: 40,
            title: "كن في الدنيا غريباً",
            narrator: "ابن عمر رضي الله عنهما",
            arabic: "كُنْ فِي الدُّنْيَا كَأَنَّكَ غَرِيبٌ أَوْ عَابِرُ سَبِيلٍ، وَعُدَّ نَفْسَكَ مِنْ أَصْحَابِ الْقُبُورِ.",
            source: "رواه البخاري"),
]

// MARK: - NawawiHadithView

struct NawawiHadithView: View {
    @State private var searchText = ""
    @State private var selectedHadith: NHadith?

    var filtered: [NHadith] {
        if searchText.isEmpty { return nawawiHadiths }
        return nawawiHadiths.filter {
            $0.title.contains(searchText) || $0.arabic.contains(searchText) || $0.narrator.contains(searchText)
        }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {

                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.textSecondary).font(.system(size: 14))
                    TextField("ابحث في الأحاديث...", text: $searchText)
                        .font(.system(size: 14))
                        .foregroundColor(Theme.text)
                }
                .padding(12)
                .background(Theme.card)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                .padding(.horizontal, 16).padding(.vertical, 10)

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filtered) { hadith in
                            Button(action: {
                                selectedHadith = hadith
                            }) {
                                HadithRow(hadith: hadith)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("الأربعون النووية")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedHadith) { h in
            HadithDetailSheet(hadith: h)
        }
    }
}

// MARK: - HadithRow

private struct HadithRow: View {
    let hadith: NHadith
    var body: some View {
        HStack(spacing: 14) {
            // Number badge
            ZStack {
                Circle().fill(Theme.gold.opacity(0.15)).frame(width: 40, height: 40)
                Text("\(hadith.id)").font(.system(size: 14, weight: .bold)).foregroundColor(Theme.gold)
            }
            VStack(alignment: .trailing, spacing: 4) {
                Text(hadith.title)
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.text)
                Text(hadith.narrator)
                    .font(.system(size: 11)).foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.left")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Theme.card).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }
}

// MARK: - HadithDetailSheet

struct HadithDetailSheet: View {
    let hadith: NHadith
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("الحديث \(hadith.id)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Theme.goldLight)
                    Spacer()
                    Button("إغلاق") { dismiss() }
                        .font(.system(size: 15)).foregroundColor(Theme.gold)
                }
                .padding(16)
                Divider().background(Theme.border)

                ScrollView {
                    VStack(alignment: .trailing, spacing: 20) {

                        // Title
                        Text(hadith.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Theme.goldLight)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        // Narrator
                        HStack(spacing: 6) {
                            Text(hadith.narrator)
                                .font(.system(size: 13)).foregroundColor(Theme.textSecondary)
                            Image(systemName: "person.fill")
                                .font(.system(size: 12)).foregroundColor(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)

                        // Arabic text
                        Text(hadith.arabic)
                            .font(.system(size: 18))
                            .foregroundColor(Theme.text)
                            .lineSpacing(10)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(16)
                            .background(Theme.card)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.gold.opacity(0.3), lineWidth: 1))

                        // Source
                        HStack(spacing: 6) {
                            Text(hadith.source)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Theme.gold)
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 13)).foregroundColor(Theme.gold)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(16).padding(.bottom, 30)
                }
            }
        }
    }
}
