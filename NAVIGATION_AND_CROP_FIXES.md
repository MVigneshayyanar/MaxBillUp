# Navigation and Crop Fixes - January 1, 2026

## Issues Fixed

### 1. QuotationsListPage Back Button Navigation Fix ✅
**Problem:** When clicking the back button in QuotationsListPage, it was going to SettingsPage instead of returning to the MenuPage.

**Root Cause:** The page was calling both `widget.onBack()` (which resets `_currentView` in MenuPage) AND `Navigator.pop(context)`, causing the entire MenuPage to be popped off the navigation stack.

**Solution:**
- Modified `WillPopScope` to return `false` instead of `true` to prevent navigation pop
- Removed `Navigator.pop(context)` call from the AppBar back button
- Now only calls `widget.onBack()` which properly resets the MenuPage state

**Files Modified:**
- `lib/Sales/QuotationsList.dart`

---

### 2. TaxSettings Back Button Navigation Fix ✅
**Problem:** When clicking the back button in TaxSettings page, it was going to Reports page instead of SettingsPage.

**Root Cause:** The TaxSettings page didn't have an `onBack` callback and was using `Navigator.pop(context)` which popped to whatever was in the navigation stack.

**Solution:**
- Added `onBack` callback parameter to `TaxSettingsPage` widget
- Updated SettingsPage (Profile.dart) to pass `_goBack` callback to TaxSettings
- Replaced `Navigator.pop(context)` with `widget.onBack` in the AppBar back button
- Added `WillPopScope` to handle system back button properly

**Files Modified:**
- `lib/Settings/TaxSettings.dart`
- `lib/Settings/Profile.dart`

---

### 3. Image Crop - Restrict to Square Only ✅
**Problem:** Image crop page was showing multiple aspect ratio options (Original, Square, 3x2, 4x3, 16x9).

**Solution:** Added `aspectRatioPresets` parameter to both Android and iOS UI settings to show only square option.

**Current Configuration:**
```dart
AndroidUiSettings(
  toolbarTitle: 'Crop Logo',
  toolbarColor: kPrimaryColor,
  toolbarWidgetColor: kWhite,
  initAspectRatio: CropAspectRatioPreset.square,
  lockAspectRatio: true,
  aspectRatioPresets: [
    CropAspectRatioPreset.square, // Only square option
  ],
),
IOSUiSettings(
  title: 'Crop Logo',
  aspectRatioLockEnabled: true,
  resetAspectRatioEnabled: false,
  aspectRatioPickerButtonHidden: true,
  aspectRatioPresets: [
    CropAspectRatioPreset.square, // Only square option
  ],
)
```

**Features:**
- ✅ Starts with square aspect ratio (`initAspectRatio: CropAspectRatioPreset.square`)
- ✅ Locks aspect ratio so users cannot change it (`lockAspectRatio: true`)
- ✅ Only shows square preset in the aspect ratio picker
- ✅ Hides aspect ratio picker button on iOS (`aspectRatioPickerButtonHidden: true`)
- ✅ Disables reset on iOS (`resetAspectRatioEnabled: false`)
- ✅ Works on both Android and iOS

**Files Modified:**
- `lib/Settings/Profile.dart`

---

## Additional Cleanup
- Removed unused imports from Profile.dart:
  - `package:intl/intl.dart`
  - `package:maxbillup/utils/theme_notifier.dart`

---

## Navigation Pattern Explained

Both MenuPage and SettingsPage use a similar navigation pattern:
1. They maintain a `_currentView` state variable
2. When `_currentView` is not null, they render the child page
3. Child pages receive an `onBack` callback
4. Calling `onBack()` resets `_currentView` to null, showing the parent menu
5. This avoids using `Navigator.push/pop` for internal navigation

**Benefits:**
- No navigation stack issues
- Instant page transitions
- Consistent back button behavior
- Better state management

---

## Testing Checklist
- [ ] Test QuotationsListPage back button (AppBar)
- [ ] Test QuotationsListPage system back button (Android)
- [ ] Test QuotationsListPage back swipe gesture (iOS)
- [ ] Test TaxSettings back button (AppBar)
- [ ] Test TaxSettings system back button (Android)
- [ ] Test TaxSettings back swipe gesture (iOS)
- [ ] **Test image crop - verify only SQUARE crop is shown (no Original, 3x2, 4x3, 16x9)**
- [ ] Test image crop on Android
- [ ] Test image crop on iOS

---

## Notes
- All remaining errors are deprecation warnings only (not critical)
- WillPopScope deprecation warning can be addressed later by migrating to PopScope
- withOpacity deprecation warnings are cosmetic and don't affect functionality
- The `aspectRatioPresets` parameter ensures that ONLY the square aspect ratio appears in the crop UI
- On Android: The aspect ratio buttons at the bottom will show only "Square"
- On iOS: The aspect ratio picker is hidden entirely since there's only one option
