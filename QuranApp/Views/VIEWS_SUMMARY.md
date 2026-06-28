# Quran iOS App - SwiftUI Views

## Created Files

### 1. Prayer Times View
**Path:** `Views/Prayer/PrayerTimesView.swift`
- Title: "🕌 أوقات الصلاة"
- Location bar with city search field and GPS button
- Displays 6 prayer times with icons (الفجر 🌅, الشروق ☀️, الظهر 🌤️, العصر 🌇, المغرب 🌆, العشاء 🌙)
- Highlights next prayer with gold border
- Empty state message when no location selected
- Bottom dua quote
- Uses PrayerService and LocationService

### 2. Qibla Direction View
**Path:** `Views/Qibla/QiblaView.swift`
- Title: "🧭 اتجاه القبلة" with subtitle
- "📍 تحديد موقعي" button with gold outline
- Compass visualization with:
  - Rotating compass ring with N/S/E/W markers
  - Gold arrow pointing to Qibla direction
  - Compass rotates based on device heading
- Displays:
  - Distance to Kaaba in kilometers
  - Qibla angle in degrees
- Bottom dua quote
- Uses QiblaService and LocationService

### 3. Bookmarks View
**Path:** `Views/Bookmarks/BookmarksView.swift`
- Title: "🔖 المحفوظات"
- Empty state with message "لا توجد محفوظات"
- List of bookmarked pages showing:
  - Page number
  - Surah name
  - Date added
- Swipe to delete functionality
- Tap to navigate to QuranPageDetailView
- Persists bookmarks using UserDefaults
- Includes BookmarkItem model and QuranPageDetailView
- Bottom dua quote

## Theme Integration

All views use the Theme struct with the following colors:
- **Background:** #0a1628 (dark navy)
- **Card:** #162b4a
- **Gold:** #c8a84e
- **Gold Light:** #e8d49a
- **Text:** #f0e8d8
- **Text Secondary:** #8ba0b8
- **Border:** #1e3a5f
- **Corner Radius:** 14

## Features

✓ Full Arabic RTL layout support
✓ All text in Arabic
✓ Beautiful dark theme matching specifications
✓ Proper error handling
✓ Loading states
✓ Environment objects for services
✓ Empty states with helpful messages
✓ Bottom dua quotes for spiritual context
✓ Swipe gestures for deletion (Bookmarks)
✓ Navigation between views

## Dependencies

- SwiftUI
- CoreLocation
- PrayerService (custom)
- QiblaService (custom)
- LocationService (custom)
- UserDefaults for persistence
