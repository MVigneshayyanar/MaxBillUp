# Image Crop - Square Only Fix ✅

## Problem
The image crop page was showing multiple aspect ratio options:
- Original
- Square
- 3x2
- 4x3
- 16x9

This allowed users to select non-square aspect ratios for the logo.

## Solution
Added `aspectRatioPresets` parameter to **both** AndroidUiSettings and IOSUiSettings with only the square preset.

## Code Changes

### Before:
```dart
final croppedFile = await ImageCropper().cropImage(
  sourcePath: pickedFile.path,
  uiSettings: [
    AndroidUiSettings(
      toolbarTitle: 'Crop Logo',
      toolbarColor: kPrimaryColor,
      toolbarWidgetColor: kWhite,
      initAspectRatio: CropAspectRatioPreset.square,
      lockAspectRatio: true
    ),
    IOSUiSettings(
      title: 'Crop Logo',
      aspectRatioLockEnabled: true
    ),
  ],
);
```

### After:
```dart
final croppedFile = await ImageCropper().cropImage(
  sourcePath: pickedFile.path,
  uiSettings: [
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
    ),
  ],
);
```

## Key Parameters Explained

### Android Settings:
- `initAspectRatio: CropAspectRatioPreset.square` - Starts with square
- `lockAspectRatio: true` - Prevents manual aspect ratio changes
- `aspectRatioPresets: [CropAspectRatioPreset.square]` - **Only shows square in the picker**

### iOS Settings:
- `aspectRatioLockEnabled: true` - Locks to one aspect ratio
- `resetAspectRatioEnabled: false` - Prevents resetting to original
- `aspectRatioPickerButtonHidden: true` - Hides the picker button entirely
- `aspectRatioPresets: [CropAspectRatioPreset.square]` - **Only square available**

## Result
Now when users crop their logo:
- ✅ Only the square aspect ratio is available
- ✅ No Original, 3x2, 4x3, or 16x9 options appear
- ✅ On Android: Bottom aspect ratio buttons show only "Square"
- ✅ On iOS: Aspect ratio picker is hidden completely
- ✅ Users can only crop in 1:1 (square) ratio

## File Modified
- `lib/Settings/Profile.dart` (line ~464)

## Testing
1. Go to Settings → Business Details
2. Tap on logo to change it
3. Select an image from gallery
4. Verify crop page shows ONLY square option
5. Verify no other aspect ratios (Original, 3x2, 4x3, 16x9) are visible

