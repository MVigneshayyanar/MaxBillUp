Native splash setup (Android & iOS)

Overview
- This project now uses native launch screens (Android and iOS) that display your logo on a white background before the Flutter UI is ready.
- Android: `android/app/src/main/res/drawable/launch_background.xml` and `drawable-v21/launch_background.xml` reference `@drawable/launch_logo`.
- iOS: `ios/Runner/Base.lproj/LaunchScreen.storyboard` references an image named `launch_logo`.

What you must add
1) Android
- Copy your PNG logo to:
  `android/app/src/main/res/drawable/launch_logo.png`
- Optionally add density versions for better quality:
  - `drawable-mdpi/launch_logo.png`
  - `drawable-hdpi/launch_logo.png`
  - `drawable-xhdpi/launch_logo.png`
  - `drawable-xxhdpi/launch_logo.png`

2) iOS
- Open Xcode, add your image to the Asset Catalog (Images.xcassets) and name the image `launch_logo`.
  - Or directly place the PNG in the `Runner/Assets.xcassets` with the name `launch_logo`.
  - Provide 1x/2x/3x variants for different device scales.

How to build/test (Windows / macOS)
- Android (Windows/macOS):
  ```bash
  cd C:\MaxBillUp
  flutter clean
  flutter pub get
  flutter run
  # or
  flutter build apk --debug
  ```

- iOS (macOS required):
  ```bash
  cd /path/to/MaxBillUp
  flutter clean
  flutter pub get
  flutter run
  # or open ios/Runner.xcworkspace in Xcode and run
  ```

Troubleshooting
- If the old icon or background still appears on Android: uninstall the app from the device/emulator before reinstalling it to avoid cached resources.
- If iOS launch image doesn't appear: ensure `launch_logo` exists in `Assets.xcassets` and rebuild the app from Xcode.

If you want me to also:
- Add density-specific generated PNGs (I can provide commands or an image-resize script), or
- Make the native splash show only a small centered logo (I can tweak `launch_background.xml` insets),
let me know which you prefer and I will apply it automatically.
