import Foundation
import SwiftUI

// MARK: - PortalCategory

struct PortalCategory: Identifiable {
    let id: String
    let nameAr: String
    let icon: String
    let color: Color
    let books: [PortalBook]
}

// MARK: - PortalBook

struct PortalBook: Identifiable, Codable, Hashable {
    let id: Int
    let nameAr: String
    let categoryId: String
}

// MARK: - PortalChapter

struct PortalChapter: Identifiable, Codable, Hashable {
    let id: Int
    let bookId: Int
    let nameAr: String
    let urlParams: String   // full query string e.g. "show=chapter&chapter_id=2&book=33&..."
}

// MARK: - PortalHadith

struct PortalHadith: Identifiable, Codable, Hashable {
    let id: Int             // portal sequential number
    let bookId: Int
    let chapterId: Int
    let number: String      // displayed reference number
    let text: String        // full Arabic text (isnad + matn)
    let bookName: String?
}

// MARK: - PortalNarrator

struct PortalNarrator: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let info: String?
}

// MARK: - Portal Book Catalog (hardcoded — 189 books)

extension PortalCategory {

    static let allCategories: [PortalCategory] = [

        PortalCategory(
            id: "sihah",
            nameAr: "الصحاح",
            icon: "checkmark.seal.fill",
            color: Color(red: 0.18, green: 0.55, blue: 0.34),
            books: [
                PortalBook(id: 33,  nameAr: "صحيح البخاري",                         categoryId: "sihah"),
                PortalBook(id: 31,  nameAr: "صحيح مسلم",                             categoryId: "sihah"),
                PortalBook(id: 30,  nameAr: "موطأ مالك",                             categoryId: "sihah"),
                PortalBook(id: 42,  nameAr: "صحيح ابن خزيمة",                       categoryId: "sihah"),
                PortalBook(id: 34,  nameAr: "صحيح ابن حبان",                        categoryId: "sihah"),
                PortalBook(id: 56,  nameAr: "المنتقى لابن جارود",                   categoryId: "sihah"),
                PortalBook(id: 37,  nameAr: "المستدرك على الصحيحين",                categoryId: "sihah"),
            ]
        ),

        PortalCategory(
            id: "sunan",
            nameAr: "السنن",
            icon: "books.vertical.fill",
            color: Color(red: 0.20, green: 0.40, blue: 0.70),
            books: [
                PortalBook(id: 25,  nameAr: "السنن الصغرى للنسائي",                 categoryId: "sunan"),
                PortalBook(id: 48,  nameAr: "السنن الكبرى للنسائي",                 categoryId: "sunan"),
                PortalBook(id: 26,  nameAr: "سنن أبي داوود",                        categoryId: "sunan"),
                PortalBook(id: 38,  nameAr: "جامع الترمذي",                         categoryId: "sunan"),
                PortalBook(id: 27,  nameAr: "سنن ابن ماجة",                         categoryId: "sunan"),
                PortalBook(id: 32,  nameAr: "سنن الدارمي",                          categoryId: "sunan"),
                PortalBook(id: 102, nameAr: "السنن المأثورة للشافعي",               categoryId: "sunan"),
                PortalBook(id: 129, nameAr: "مراسيل أبي داود",                       categoryId: "sunan"),
            ]
        ),

        PortalCategory(
            id: "masanid",
            nameAr: "المسانيد والمعاجم",
            icon: "archivebox.fill",
            color: Color(red: 0.55, green: 0.27, blue: 0.07),
            books: [
                PortalBook(id: 1,   nameAr: "مسند أحمد بن حنبل",                    categoryId: "masanid"),
                PortalBook(id: 57,  nameAr: "مسند أبي حنيفة",                       categoryId: "masanid"),
                PortalBook(id: 95,  nameAr: "مسند ابن المبارك",                     categoryId: "masanid"),
                PortalBook(id: 41,  nameAr: "مسند الطيالسي",                        categoryId: "masanid"),
                PortalBook(id: 60,  nameAr: "مسند الشافعي",                         categoryId: "masanid"),
                PortalBook(id: 28,  nameAr: "مسند الحميدي",                         categoryId: "masanid"),
                PortalBook(id: 54,  nameAr: "مسند ابن أبي شيبة",                    categoryId: "masanid"),
                PortalBook(id: 50,  nameAr: "مسند إسحاق بن راهويه",                 categoryId: "masanid"),
                PortalBook(id: 40,  nameAr: "المعجم الكبير للطبراني",               categoryId: "masanid"),
                PortalBook(id: 39,  nameAr: "المعجم الأوسط للطبراني",               categoryId: "masanid"),
                PortalBook(id: 36,  nameAr: "المعجم الصغير للطبراني",               categoryId: "masanid"),
                PortalBook(id: 141, nameAr: "معجم أبي يعلى الموصلي",                categoryId: "masanid"),
                PortalBook(id: 59,  nameAr: "معجم ابن الأعرابي",                    categoryId: "masanid"),
                PortalBook(id: 58,  nameAr: "معجم ابن المقرئ",                      categoryId: "masanid"),
                PortalBook(id: 115, nameAr: "مسند سعد بن أبي وقاص",                 categoryId: "masanid"),
                PortalBook(id: 120, nameAr: "مسند بلال بن رباح",                    categoryId: "masanid"),
                PortalBook(id: 132, nameAr: "مسند عبد الرحمن بن عوف للبرتي",        categoryId: "masanid"),
                PortalBook(id: 133, nameAr: "بغية الباحث عن زوائد مسند الحارث",     categoryId: "masanid"),
                PortalBook(id: 136, nameAr: "مسند أبي بكر الصديق",                  categoryId: "masanid"),
                PortalBook(id: 139, nameAr: "المفاريد لأبي يعلى الموصلي",           categoryId: "masanid"),
                PortalBook(id: 142, nameAr: "مسند الروياني",                        categoryId: "masanid"),
                PortalBook(id: 147, nameAr: "مسند عمر بن عبد العزيز",               categoryId: "masanid"),
                PortalBook(id: 150, nameAr: "مسند عائشة",                           categoryId: "masanid"),
                PortalBook(id: 158, nameAr: "مسند ابن أبي أوفى",                    categoryId: "masanid"),
                PortalBook(id: 167, nameAr: "المسند للشاشي",                        categoryId: "masanid"),
            ]
        ),

        PortalCategory(
            id: "musannafat",
            nameAr: "المصنفات",
            icon: "doc.fill",
            color: Color(red: 0.55, green: 0.20, blue: 0.55),
            books: [
                PortalBook(id: 61,  nameAr: "مصنّف عبد الرزاق",                     categoryId: "musannafat"),
                PortalBook(id: 62,  nameAr: "مصنّف ابن أبي شيبة",                   categoryId: "musannafat"),
                PortalBook(id: 143, nameAr: "تهذيب الآثار للطبري",                  categoryId: "musannafat"),
                PortalBook(id: 157, nameAr: "الأوسط لابن المنذر",                   categoryId: "musannafat"),
                PortalBook(id: 159, nameAr: "شرح معاني الآثار للطحاوي",             categoryId: "musannafat"),
                PortalBook(id: 63,  nameAr: "الجامع لمعمّر بن راشد",               categoryId: "musannafat"),
                PortalBook(id: 64,  nameAr: "الجامع لابن وهب",                      categoryId: "musannafat"),
                PortalBook(id: 43,  nameAr: "مستخرج أبي عوانة",                     categoryId: "musannafat"),
                PortalBook(id: 97,  nameAr: "الآثار لأبي يوسف القاضي",              categoryId: "musannafat"),
                PortalBook(id: 98,  nameAr: "الآثار لمحمد بن الحسن الشيباني",       categoryId: "musannafat"),
                PortalBook(id: 800, nameAr: "السير لأبي إسحاق الفزاري",             categoryId: "musannafat"),
            ]
        ),

        PortalCategory(
            id: "ajza",
            nameAr: "الأجزاء الحديثية",
            icon: "scroll.fill",
            color: .teal,
            books: [
                PortalBook(id: 91,  nameAr: "صحيفة همام بن منبه",                   categoryId: "ajza"),
                PortalBook(id: 93,  nameAr: "مشيخة ابن طهمان",                      categoryId: "ajza"),
                PortalBook(id: 96,  nameAr: "أحاديث إسماعيل بن جعفر",              categoryId: "ajza"),
                PortalBook(id: 100, nameAr: "نسخة وكيع عن الأعمش",                  categoryId: "ajza"),
                PortalBook(id: 101, nameAr: "جزء حديث سفيان بن عيينة",              categoryId: "ajza"),
                PortalBook(id: 103, nameAr: "جزء أشيب",                              categoryId: "ajza"),
                PortalBook(id: 105, nameAr: "حديث محمد بن عبدالله الأنصاري",        categoryId: "ajza"),
                PortalBook(id: 94,  nameAr: "مجلس من فوائد الليث بن سعد",           categoryId: "ajza"),
                PortalBook(id: 140, nameAr: "الفوائد للفريابي",                      categoryId: "ajza"),
                PortalBook(id: 165, nameAr: "فوائد محمد بن مخلد",                   categoryId: "ajza"),
                PortalBook(id: 104, nameAr: "الأمالي في آثار الصحابة",              categoryId: "ajza"),
                PortalBook(id: 125, nameAr: "الأمالي و القراءة",                     categoryId: "ajza"),
                PortalBook(id: 146, nameAr: "أمالي الباغندي",                        categoryId: "ajza"),
                PortalBook(id: 162, nameAr: "أمالي أبي إسحاق الأول",               categoryId: "ajza"),
                PortalBook(id: 163, nameAr: "أمالي المحاملي",                        categoryId: "ajza"),
                PortalBook(id: 89,  nameAr: "مسانيد فراس المكتب",                   categoryId: "ajza"),
                PortalBook(id: 90,  nameAr: "أحاديث أيوب السختياني",                categoryId: "ajza"),
                PortalBook(id: 92,  nameAr: "جزء ابن جريج",                         categoryId: "ajza"),
                PortalBook(id: 99,  nameAr: "جامع السنة وشروحها",                   categoryId: "ajza"),
                PortalBook(id: 108, nameAr: "جزء أبي الجهم الباهلي",                categoryId: "ajza"),
                PortalBook(id: 110, nameAr: "جزء يحيى بن معين",                     categoryId: "ajza"),
                PortalBook(id: 113, nameAr: "جزء من حديث لوين",                     categoryId: "ajza"),
                PortalBook(id: 116, nameAr: "جزء قراءات النبي لحفص بن عمر",         categoryId: "ajza"),
                PortalBook(id: 117, nameAr: "المنتخب من مسند عبد بن حميد",          categoryId: "ajza"),
                PortalBook(id: 118, nameAr: "جزء المؤمل",                            categoryId: "ajza"),
                PortalBook(id: 119, nameAr: "جزء الحسن بن عرفة",                    categoryId: "ajza"),
                PortalBook(id: 121, nameAr: "جزء محمد بن عاصم الثقفي",              categoryId: "ajza"),
                PortalBook(id: 126, nameAr: "جزء أحمد بن عاصم الثقفي",              categoryId: "ajza"),
                PortalBook(id: 128, nameAr: "جزء حنبل بن إسحاق",                    categoryId: "ajza"),
                PortalBook(id: 130, nameAr: "حديث أبي محمد الفاكهي",                categoryId: "ajza"),
                PortalBook(id: 148, nameAr: "البيتوتة لمحمد بن إسحاق",              categoryId: "ajza"),
                PortalBook(id: 152, nameAr: "جزء أبي عروبة الحراني برواية الحاكم",  categoryId: "ajza"),
                PortalBook(id: 153, nameAr: "جزء البغوي",                            categoryId: "ajza"),
                PortalBook(id: 164, nameAr: "ما رواه الأكابر عن مالك",              categoryId: "ajza"),
                PortalBook(id: 166, nameAr: "فوائد حديث أبي عمير لابن القاص",       categoryId: "ajza"),
                PortalBook(id: 168, nameAr: "جزء القاضي الأشناني",                  categoryId: "ajza"),
            ]
        ),

        PortalCategory(
            id: "arbaoon",
            nameAr: "الأربعينيات",
            icon: "text.badge.star",
            color: .indigo,
            books: [
                PortalBook(id: 68,  nameAr: "الأربعون للطوسي",                       categoryId: "arbaoon"),
                PortalBook(id: 69,  nameAr: "الأربعون للنسوي",                       categoryId: "arbaoon"),
                PortalBook(id: 70,  nameAr: "الأربعون حديثاً للآجري",               categoryId: "arbaoon"),
                PortalBook(id: 71,  nameAr: "الأربعون في شيوخ الصوفية للماليني",    categoryId: "arbaoon"),
                PortalBook(id: 72,  nameAr: "الأربعون على مذهب المتحققين",          categoryId: "arbaoon"),
                PortalBook(id: 73,  nameAr: "الأربعون الصغرى للبيهقي",              categoryId: "arbaoon"),
                PortalBook(id: 76,  nameAr: "الأربعين النووية",                      categoryId: "arbaoon"),
            ]
        ),

        PortalCategory(
            id: "aqaed",
            nameAr: "العقائد والزهد",
            icon: "heart.fill",
            color: .orange,
            books: [
                PortalBook(id: 79,  nameAr: "القدر لابن وهب",                        categoryId: "aqaed"),
                PortalBook(id: 88,  nameAr: "البدع لابن وضاح",                       categoryId: "aqaed"),
                PortalBook(id: 87,  nameAr: "السنة لعبد الله بن أحمد",              categoryId: "aqaed"),
                PortalBook(id: 169, nameAr: "القدر للفريابي",                        categoryId: "aqaed"),
                PortalBook(id: 144, nameAr: "صريح السنة للطبري",                     categoryId: "aqaed"),
                PortalBook(id: 86,  nameAr: "الشريعة للآجري",                        categoryId: "aqaed"),
                PortalBook(id: 903, nameAr: "شعار أصحاب الحديث للحاكم",             categoryId: "aqaed"),
                PortalBook(id: 700, nameAr: "الزهد لابن المبارك",                    categoryId: "aqaed"),
                PortalBook(id: 701, nameAr: "الزهد للمعافى بن عمران",               categoryId: "aqaed"),
                PortalBook(id: 702, nameAr: "الزهد لوكيع بن الجراح",                categoryId: "aqaed"),
                PortalBook(id: 703, nameAr: "الزهد لأسد بن موسى",                   categoryId: "aqaed"),
                PortalBook(id: 705, nameAr: "الزهد لأحمد بن حنبل",                  categoryId: "aqaed"),
                PortalBook(id: 706, nameAr: "الزهد لهناد بن السري",                 categoryId: "aqaed"),
                PortalBook(id: 709, nameAr: "الزهد لأبي حاتم الرازي",               categoryId: "aqaed"),
                PortalBook(id: 751, nameAr: "المُذكَّر و التِّذكير لابن أبي عاصم",  categoryId: "aqaed"),
                PortalBook(id: 752, nameAr: "اعتلال القلوب للخرائطي",               categoryId: "aqaed"),
                PortalBook(id: 753, nameAr: "فضيلة الشكر لله للخرائطي",             categoryId: "aqaed"),
                PortalBook(id: 754, nameAr: "مكارم الأخلاق للخرائطي",               categoryId: "aqaed"),
                PortalBook(id: 748, nameAr: "إكرام الضيف لإبراهيم الحربي",          categoryId: "aqaed"),
                PortalBook(id: 53,  nameAr: "الأدب لابن أبي شيبة",                  categoryId: "aqaed"),
                PortalBook(id: 55,  nameAr: "الأدب المفرد للبخاري",                  categoryId: "aqaed"),
                PortalBook(id: 74,  nameAr: "الترغيب في فضائل الأعمال لابن شاهين",  categoryId: "aqaed"),
                PortalBook(id: 75,  nameAr: "رياضة الأبدان لأبي نعيم",               categoryId: "aqaed"),
                PortalBook(id: 78,  nameAr: "شرح أصول اعتقاد أهل السنة للالكائي",   categoryId: "aqaed"),
                PortalBook(id: 80,  nameAr: "كرامات الأولياء للالكائي",              categoryId: "aqaed"),
                PortalBook(id: 83,  nameAr: "القضاء والقدر للبيهقي",                 categoryId: "aqaed"),
                PortalBook(id: 135, nameAr: "فضائل عثمان بن عفان",                   categoryId: "aqaed"),
                PortalBook(id: 755, nameAr: "مساوئ الأخلاق للخرائطي",               categoryId: "aqaed"),
            ]
        ),

        PortalCategory(
            id: "ibnabidunya",
            nameAr: "كتب ابن أبي الدنيا",
            icon: "book.closed.fill",
            color: Color(red: 0.40, green: 0.25, blue: 0.60),
            books: [
                PortalBook(id: 710, nameAr: "الأولياء لابن أبي الدنيا",             categoryId: "ibnabidunya"),
                PortalBook(id: 711, nameAr: "الإخوان لابن أبي الدنيا",              categoryId: "ibnabidunya"),
                PortalBook(id: 712, nameAr: "الإشراف في منازل الأشراف",             categoryId: "ibnabidunya"),
                PortalBook(id: 713, nameAr: "التواضع و الخمول لابن أبي الدنيا",     categoryId: "ibnabidunya"),
                PortalBook(id: 714, nameAr: "الجوع لابن أبي الدنيا",                categoryId: "ibnabidunya"),
                PortalBook(id: 715, nameAr: "الحلم لابن أبي الدنيا",                categoryId: "ibnabidunya"),
                PortalBook(id: 716, nameAr: "الرقة و البكاء لابن أبي الدنيا",       categoryId: "ibnabidunya"),
                PortalBook(id: 704, nameAr: "الكرم والجود للبرجلاني",               categoryId: "ibnabidunya"),
                PortalBook(id: 707, nameAr: "البر والصلة للحسين بن حرب",            categoryId: "ibnabidunya"),
                PortalBook(id: 111, nameAr: "العلم لزهير بن حرب",                   categoryId: "ibnabidunya"),
                PortalBook(id: 717, nameAr: "الزهد لابن أبي الدنيا",                 categoryId: "ibnabidunya"),
                PortalBook(id: 718, nameAr: "الشكر لابن أبي الدنيا",                 categoryId: "ibnabidunya"),
                PortalBook(id: 719, nameAr: "الصبر والثواب عليه لابن أبي الدنيا",   categoryId: "ibnabidunya"),
            ]
        ),

        PortalCategory(
            id: "ulumhadith",
            nameAr: "علوم الحديث",
            icon: "magnifyingglass",
            color: Color(red: 0.20, green: 0.60, blue: 0.60),
            books: [
                PortalBook(id: 901, nameAr: "المحدث الفاصل للرامهرمزي",             categoryId: "ulumhadith"),
                PortalBook(id: 605, nameAr: "معرفة علوم الحديث للحاكم",             categoryId: "ulumhadith"),
                PortalBook(id: 606, nameAr: "الأوهام للأزدي",                        categoryId: "ulumhadith"),
                PortalBook(id: 612, nameAr: "الكفاية في علم الرواية للخطيب",        categoryId: "ulumhadith"),
                PortalBook(id: 614, nameAr: "نصب الراية للزيلعي",                   categoryId: "ulumhadith"),
                PortalBook(id: 615, nameAr: "التلخيص الحبير لابن حجر",              categoryId: "ulumhadith"),
                PortalBook(id: 400, nameAr: "ناسخ الحديث ومنسوخه لابن شاهين",       categoryId: "ulumhadith"),
                PortalBook(id: 602, nameAr: "العلل الكبير للترمذي",                  categoryId: "ulumhadith"),
                PortalBook(id: 604, nameAr: "غرائب مالك لابن المظفر",               categoryId: "ulumhadith"),
                PortalBook(id: 608, nameAr: "بيان خطأ من أخطأ على الشافعي",         categoryId: "ulumhadith"),
                PortalBook(id: 601, nameAr: "اختلاف الحديث للشافعي",                categoryId: "ulumhadith"),
                PortalBook(id: 160, nameAr: "مُشكِل الآثار للطحاوي",                categoryId: "ulumhadith"),
                PortalBook(id: 65,  nameAr: "الجامع لأخلاق الراوي للخطيب",          categoryId: "ulumhadith"),
                PortalBook(id: 67,  nameAr: "الجامع في بيان العلم لابن عبد البر",   categoryId: "ulumhadith"),
                PortalBook(id: 610, nameAr: "الرحلة في طلب الحديث للخطيب",          categoryId: "ulumhadith"),
                PortalBook(id: 609, nameAr: "الأمثال للرامهرمزي",                    categoryId: "ulumhadith"),
                PortalBook(id: 613, nameAr: "أمثال الحديث لأبي الشيخ",              categoryId: "ulumhadith"),
                PortalBook(id: 450, nameAr: "غريب الحديث لإبراهيم الحربي",          categoryId: "ulumhadith"),
                PortalBook(id: 600, nameAr: "مصطلح الحديث",                          categoryId: "ulumhadith"),
                PortalBook(id: 603, nameAr: "حديث نضر الله امرأ لابن حكيم المديني", categoryId: "ulumhadith"),
                PortalBook(id: 607, nameAr: "الإرشاد في معرفة علماء الحديث للخليلي", categoryId: "ulumhadith"),
                PortalBook(id: 902, nameAr: "المخزون في علم الحديث",                 categoryId: "ulumhadith"),
            ]
        ),

        PortalCategory(
            id: "rijal",
            nameAr: "كتب الرجال والسير",
            icon: "person.3.fill",
            color: .cyan,
            books: [
                PortalBook(id: 802, nameAr: "الطبقات الكبير لابن سعد",              categoryId: "rijal"),
                PortalBook(id: 81,  nameAr: "الآحاد والمثاني لابن أبي عاصم",        categoryId: "rijal"),
                PortalBook(id: 817, nameAr: "الكنى والأسماء للدولابي",               categoryId: "rijal"),
                PortalBook(id: 156, nameAr: "المنتقى من الطبقات لأبي عروبة",        categoryId: "rijal"),
                PortalBook(id: 807, nameAr: "الضعفاء للعقيلي",                       categoryId: "rijal"),
                PortalBook(id: 810, nameAr: "من وافقت كنيته كنية زوجه",             categoryId: "rijal"),
                PortalBook(id: 112, nameAr: "فضائل الصحابة لابن حنبل",              categoryId: "rijal"),
                PortalBook(id: 85,  nameAr: "حلية الأولياء لأبي نعيم",              categoryId: "rijal"),
                PortalBook(id: 611, nameAr: "شرف أصحاب الحديث للخطيب",             categoryId: "rijal"),
                PortalBook(id: 500, nameAr: "صفة الصفوة لابن الجوزي",              categoryId: "rijal"),
                PortalBook(id: 131, nameAr: "الشمائل المحمدية للترمذي",             categoryId: "rijal"),
                PortalBook(id: 84,  nameAr: "دلائل النبوة للفريابي",                categoryId: "rijal"),
                PortalBook(id: 82,  nameAr: "دلائل النبوة لأبي نعيم",               categoryId: "rijal"),
                PortalBook(id: 806, nameAr: "فضائل المدينة للجندي",                  categoryId: "rijal"),
                PortalBook(id: 801, nameAr: "أخبار مكة للأزرقي",                    categoryId: "rijal"),
                PortalBook(id: 805, nameAr: "تاريخ المدينة لابن شبة",               categoryId: "rijal"),
                PortalBook(id: 816, nameAr: "أخبار مكة للفاكهي",                    categoryId: "rijal"),
                PortalBook(id: 809, nameAr: "تاريخ داريا للخولاني",                 categoryId: "rijal"),
                PortalBook(id: 812, nameAr: "أخبار أصبهان لأبي نعيم",              categoryId: "rijal"),
                PortalBook(id: 804, nameAr: "الأحاديث المرفوعة من التاريخ الكبير للبخاري", categoryId: "rijal"),
                PortalBook(id: 814, nameAr: "كتاب الإمامة والرد على الرافضة للأصبهاني",   categoryId: "rijal"),
            ]
        ),

        PortalCategory(
            id: "ahkam",
            nameAr: "الأحكام والفقه",
            icon: "scale.3d",
            color: Color(red: 0.70, green: 0.50, blue: 0.10),
            books: [
                PortalBook(id: 201, nameAr: "عمدة الأحكام",                          categoryId: "ahkam"),
                PortalBook(id: 200, nameAr: "بلوغ المرام",                           categoryId: "ahkam"),
                PortalBook(id: 2000, nameAr: "المقاصد الحسنة للسخاوي",              categoryId: "ahkam"),
                PortalBook(id: 350, nameAr: "تذكرة الحفاظ لابن القيسراني",          categoryId: "ahkam"),
                PortalBook(id: 1500, nameAr: "السنة ومكانتها للسباعي",              categoryId: "ahkam"),
                PortalBook(id: 749, nameAr: "الأوائل لابن أبي عاصم",                categoryId: "ahkam"),
                PortalBook(id: 808, nameAr: "الأوائل للطبراني",                      categoryId: "ahkam"),
                PortalBook(id: 123, nameAr: "تركة النبي",                            categoryId: "ahkam"),
                PortalBook(id: 145, nameAr: "الذرية الطاهرة للدولابي",              categoryId: "ahkam"),
                PortalBook(id: 138, nameAr: "المطالب العالية للحافظ ابن حجر",        categoryId: "ahkam"),
                PortalBook(id: 756, nameAr: "رياض الصالحين للنووي",                  categoryId: "ahkam"),
            ]
        ),

    ]

    // All books flat list
    static let allBooks: [PortalBook] = allCategories.flatMap(\.books)

    // Lookup by ID
    static func book(id: Int) -> PortalBook? { allBooks.first { $0.id == id } }
    static func category(id: String) -> PortalCategory? { allCategories.first { $0.id == id } }
}

// MARK: - Cached Chapter List (per book)

struct PortalChapterList: Codable {
    let bookId: Int
    let chapters: [PortalChapter]
    let fetchedAt: Date
}

// MARK: - Cached Hadith List (per chapter)

struct PortalHadithList: Codable {
    let bookId: Int
    let chapterId: Int
    let hadiths: [PortalHadith]
    let fetchedAt: Date
}
