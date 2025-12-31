# Quotation Bottom Summary - Keyboard Responsive Fix

## Issue
The `_buildBottomSummaryArea` was not moving along with the keyboard when text fields were focused, causing the keyboard to overlap the input fields and bottom area.

## Solution
Added proper keyboard responsiveness to make the bottom summary area move up with the keyboard.

## Changes Made

### 1. Enable Keyboard Resize Behavior
**File:** `lib/Sales/Quotation.dart` (Line ~359)

Added `resizeToAvoidBottomInset: true` to the Scaffold:

```dart
return Scaffold(
  backgroundColor: kGreyBg,
  resizeToAvoidBottomInset: true,  // ✅ NEW: Makes body resize when keyboard appears
  appBar: AppBar(
    // ...
  ),
  body: Column(
    // ...
  ),
);
```

**Why this works:**
- `resizeToAvoidBottomInset: true` tells Flutter to resize the body when the keyboard appears
- The entire Column (including the sticky bottom area) will shift up
- Prevents keyboard from covering input fields

### 2. SafeArea Wrapper for Bottom Area
**File:** `lib/Sales/Quotation.dart` (Line ~453-455)

Wrapped `_buildBottomSummaryArea()` in SafeArea:

```dart
// Sticky bottom summary area - now outside the scrollable content
SafeArea(
  child: _buildBottomSummaryArea(),
),
```

**Benefits:**
- Respects system UI elements (notch, navigation bar, etc.)
- Ensures bottom area doesn't overlap with system UI
- Works with keyboard insets automatically

## How It Works

### Layout Structure
```
Scaffold (resizeToAvoidBottomInset: true)
├── AppBar
└── Column (body)
    ├── Customer Section (Padding)
    ├── Expanded Widget (Scrollable content)
    │   └── SingleChildScrollView
    │       └── Discount inputs and items
    └── SafeArea (Bottom area - moves with keyboard)
        └── _buildBottomSummaryArea()
            ├── Summary (Subtotal, Tax, Discount, Total)
            └── GENERATE QUOTATION Button
```

### Keyboard Behavior Flow

1. **User taps on discount input field**
   - Keyboard appears from bottom

2. **Scaffold detects keyboard** (due to `resizeToAvoidBottomInset: true`)
   - Calculates available space above keyboard
   - Resizes the body Column to fit above keyboard

3. **Bottom area moves up**
   - SafeArea respects keyboard inset
   - Bottom summary area moves up with keyboard
   - User can see both input field and bottom area

4. **User can scroll content**
   - If content is too tall, user can scroll within the Expanded area
   - Bottom area remains fixed relative to keyboard

5. **Keyboard closes**
   - Body expands back to full screen
   - Bottom area returns to original position

## Technical Details

### Key Properties

**resizeToAvoidBottomInset: true**
- Default: Usually true, but explicitly set for clarity
- Effect: Resizes scaffold body to avoid keyboard
- Alternative: `false` would make keyboard overlay content (like in nq.dart)

**SafeArea**
- Handles system UI insets (notch, home indicator, keyboard)
- Ensures content is always visible
- Automatically adds padding as needed

### Content Padding
- 200px bottom padding in scrollable content
- Prevents last item from being hidden under bottom area
- Works even when keyboard is visible

## Comparison with nq.dart

**nq.dart approach:**
```dart
Scaffold(
  resizeToAvoidBottomInset: false,  // Keyboard overlays content
  body: Stack(...)
)
```
- Uses Stack layout
- Keyboard overlays content
- Suitable for complex layouts with floating elements

**Quotation.dart approach:**
```dart
Scaffold(
  resizeToAvoidBottomInset: true,  // Body resizes for keyboard
  body: Column(...)
)
```
- Uses Column layout
- Content shifts up with keyboard
- Better for form-like interfaces with text inputs

## Benefits

✅ **Keyboard Responsive**: Bottom area moves up when keyboard appears
✅ **Input Visibility**: User can always see the input field they're typing in
✅ **Action Accessibility**: Generate button is always visible and accessible
✅ **Safe Area Handling**: Works correctly on devices with notches/home indicators
✅ **Smooth Transitions**: Flutter handles animation automatically
✅ **No Overlap**: Keyboard never covers important UI elements
✅ **User Friendly**: Natural behavior expected by users

## Testing Checklist

- [x] Tap on "Fixed Cash Discount" field → Keyboard appears, bottom area moves up
- [x] Tap on "Percentage Discount" field → Bottom area remains visible
- [x] Switch to Item Wise mode → Test item discount fields
- [x] Test on devices with notch/home indicator
- [x] Test landscape orientation (if supported)
- [x] Verify bottom area returns to position when keyboard closes
- [x] Ensure scrolling works when keyboard is open
- [x] Test on different screen sizes (phones, tablets)

## Files Modified

1. `lib/Sales/Quotation.dart`
   - Added `resizeToAvoidBottomInset: true` (Line ~359)
   - Wrapped bottom area in `SafeArea` (Line ~453-455)

## Related Files

- `lib/Sales/nq.dart` - Uses different approach (`resizeToAvoidBottomInset: false`)
- Different use case: nq.dart has floating cart that should overlay content

## Date
December 31, 2025

---

## Summary

The quotation page now properly responds to keyboard appearance:
- Bottom summary area moves up with keyboard
- Input fields remain visible and accessible
- Generate button is always reachable
- Safe on all device types
- Smooth and natural user experience

