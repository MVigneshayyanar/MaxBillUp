# Quick Setup Guide: Profile Image & Receipt Customization

## Installation Steps

### 1. Add Dependencies to pubspec.yaml

Add these packages if not already present:

```yaml
dependencies:
  image_picker: ^1.0.4
  firebase_storage: ^11.5.0
```

Then run:
```bash
flutter pub get
```

---

### 2. Firebase Storage Setup

#### Enable Firebase Storage:
1. Go to Firebase Console
2. Select your project
3. Click "Storage" in left menu
4. Click "Get Started"
5. Choose "Start in test mode" (or production mode with rules)

#### Set Storage Rules (Important!):
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /store_logos/{storeId} {
      // Allow authenticated users to read their store logo
      allow read: if request.auth != null;
      
      // Allow authenticated users to write their store logo
      allow write: if request.auth != null
                   && request.resource.size < 5 * 1024 * 1024  // Max 5MB
                   && request.resource.contentType.matches('image/.*');
    }
  }
}
```

---

### 3. Android Permissions

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Already present, just verify -->
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
```

---

### 4. iOS Permissions

Add to `ios/Runner/Info.plist`:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to upload your business logo</string>
<key>NSCameraUsageDescription</key>
<string>We need access to your camera to take photos for your business logo</string>
```

---

## Testing Instructions

### Test Profile Image Upload:

1. **Launch the app**
   ```bash
   flutter run
   ```

2. **Navigate to Business Details**
   - Tap Settings (bottom navigation)
   - Tap "Business Details"

3. **Upload Logo**
   - Tap camera icon on profile circle
   - Select an image
   - Wait for upload
   - Verify logo appears

4. **Generate Invoice**
   - Go to Sales > New Sale
   - Add items and create invoice
   - Verify logo appears in invoice header

---

### Test Receipt Customization:

1. **Open Receipt Settings**
   - Settings > Receipt Customization

2. **Toggle Options**
   - Turn off "Show Email"
   - Turn off "Show GSTIN"
   - Tap "Save Preferences"

3. **Generate Invoice**
   - Create a new sale
   - Open invoice
   - Verify email and GSTIN are hidden

4. **Test Printing**
   - Settings > Printer Setup
   - Connect Bluetooth printer
   - Generate invoice
   - Tap "PRINT"
   - Verify receipt respects settings

---

## Troubleshooting

### Image Upload Fails:

**Problem**: "Upload failed" error

**Solutions**:
1. Check internet connection
2. Verify Firebase Storage is enabled
3. Check storage rules allow write access
4. Verify user is authenticated
5. Check Firebase Console for errors

---

### Logo Not Showing in Invoice:

**Problem**: Logo doesn't appear even after upload

**Solutions**:
1. Check if "Show Logo" is enabled in Receipt Customization
2. Verify logoUrl is saved in Firestore `stores` collection
3. Check internet connection (for image download)
4. Try uploading logo again
5. Check plan permission (Logo on Bill feature)

---

### Thermal Printer Not Printing:

**Problem**: Print button doesn't work

**Solutions**:
1. Check Bluetooth is enabled
2. Verify printer is paired in Settings > Printer Setup
3. Check printer has paper
4. Verify printer is ESC/POS compatible
5. Try reconnecting printer

---

### Settings Not Saving:

**Problem**: Receipt customization doesn't persist

**Solutions**:
1. Make sure to tap "Save Preferences"
2. Check SharedPreferences is working
3. Restart app to verify persistence
4. Check for errors in debug console

---

## Quick Command Reference

```bash
# Get dependencies
flutter pub get

# Clean build
flutter clean
flutter pub get

# Run app
flutter run

# Build release APK
flutter build apk --release

# Check for issues
flutter doctor

# View logs
flutter logs
```

---

## File Locations

**Modified Files**:
- `lib/Settings/Profile.dart` - Profile image & settings
- `lib/Sales/Invoice.dart` - Invoice display & printing

**New Files**:
- `IMPLEMENTATION_SUMMARY.md` - Full documentation
- `QUICK_SETUP_GUIDE.md` - This file

---

## Default Settings

When user first opens app:
- Show Logo: ON (if premium plan)
- Show Email: OFF
- Show Phone: ON
- Show GSTIN: ON

---

## API Keys & Credentials

Make sure these are configured:
- ✅ Firebase Project
- ✅ Google Services JSON (Android)
- ✅ GoogleService-Info.plist (iOS)
- ✅ Firebase Storage enabled
- ✅ Firestore database enabled

---

## Support Contacts

**Firebase Issues**: 
- Check Firebase Console Logs
- Visit: https://firebase.google.com/support

**Flutter Issues**:
- Check: https://flutter.dev/docs
- Run: `flutter doctor`

**App Issues**:
- Check Settings > Help in the app
- Review debug logs

---

## Version Information

- **Flutter**: 3.0+
- **Dart**: 2.19+
- **Firebase Core**: 2.0+
- **Image Picker**: 1.0.4+
- **Firebase Storage**: 11.5.0+

---

## Quick Test Checklist

After setup, test these:

- [ ] App builds successfully
- [ ] Settings page opens
- [ ] Business Details page loads
- [ ] Camera icon is visible
- [ ] Image picker opens
- [ ] Image uploads to Firebase
- [ ] Logo appears in Business Details
- [ ] Receipt Customization page opens
- [ ] Toggle switches work
- [ ] Save button works
- [ ] Create test invoice
- [ ] Logo appears in invoice
- [ ] Conditional fields work
- [ ] Print button works (if printer available)
- [ ] Receipt customization persists after restart

---

*Last Updated: December 28, 2025*
*Version: 1.0*

