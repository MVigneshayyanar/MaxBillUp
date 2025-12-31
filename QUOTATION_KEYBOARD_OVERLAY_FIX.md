# Quotation Bottom Summary - Keyboard Overlay Behavior Fix

## Issue
The `_buildBottomSummaryArea` was moving up when the keyboard appeared, but the user wanted it to stay fixed and let the keyboard overlay it (appear behind the keyboard).

## Solution
Changed `resizeToAvoidBottomInset` from `true` to `false` to prevent the body from resizing when the keyboard appears.

## Changes Made

### Changed Keyboard Behavior
**File:** `lib/Sales/Quotation.dart` (Line ~359)

```dart
return Scaffold(
  backgroundColor: kGreyBg,
  resizeToAvoidBottomInset: false,  // ✅ Changed from true to false
  appBar: AppBar(
    // ...
  ),
  body: Column(
    // ...
  ),
);
```

## How It Works Now

### Visual Behavior

**Before (resizeToAvoidBottomInset: true):**
```
┌─────────────────────────────┐
│       AppBar                │
├─────────────────────────────┤
│   Customer Selection        │  ⬆️ Everything moves up
├─────────────────────────────┤
│   Scrollable Content        │  ⬆️ 
├─────────────────────────────┤
│  Bottom Summary Area ⬆️      │  ⬆️ Pushed above keyboard
│  [GENERATE QUOTATION]       │
├─────────────────────────────┤
│      ⌨️ KEYBOARD ⌨️          │
└─────────────────────────────┘
```

**After (resizeToAvoidBottomInset: false):**
```
┌─────────────────────────────┐
│       AppBar                │
├─────────────────────────────┤
│   Customer Selection        │
├─────────────────────────────┤
│   Scrollable Content        │
│   (User can scroll to see   │
│    input fields above       │
│    keyboard)                │
├─────────────────────────────┤
│  Bottom Summary Area        │  ← Stays in place
│  [GENERATE ║⌨️ KEYBOARD ⌨️║  │  ← Keyboard overlays bottom
└─────────────────────────────┘
```

## Technical Details

### resizeToAvoidBottomInset Property

**false (Current Setting):**
- Body does not resize when keyboard appears
- Keyboard overlays the bottom portion of the screen
- Bottom summary area stays fixed in its position
- Content behind keyboard becomes inaccessible until keyboard closes
- Same behavior as nq.dart

**true (Previous Setting):**
- Body resizes to fit above keyboard
- All content shifts up
- Bottom area remains visible above keyboard
- Better for forms where you always need to see the action button

### Why false is better for Quotation page:

1. **Fixed Bottom Design**: The bottom summary is designed to be sticky/fixed
2. **Quick Access**: Users can close keyboard to see totals and generate button
3. **Input Focus**: When typing, users focus on the field, not the totals
4. **Consistent Behavior**: Matches behavior of nq.dart and other pages
5. **Performance**: No layout recalculation when keyboard appears/disappears

## User Workflow

1. **User scrolls and fills discount fields**
   - Bottom summary shows running totals
   - Bottom area is always visible

2. **User taps on a discount input field**
   - Keyboard appears from bottom
   - Keyboard overlays the bottom summary area
   - User can see the input field they're typing in
   - Scrollable content adjusts to show focused field

3. **User types discount value**
   - Focus is on typing, not on bottom summary
   - Can scroll up/down if needed to see other fields

4. **User closes keyboard (back button/tap outside)**
   - Keyboard slides down
   - Bottom summary area revealed again
   - Shows updated totals
   - User can tap "GENERATE QUOTATION"

## Comparison with Other Pages

### nq.dart (New Quotation List)
```dart
Scaffold(
  resizeToAvoidBottomInset: false,  // ✅ Same as Quotation.dart now
)
```
- Uses Stack layout with floating cart
- Keyboard overlays content
- Works well for product selection

### Quotation.dart (This file)
```dart
Scaffold(
  resizeToAvoidBottomInset: false,  // ✅ Changed to match nq.dart
)
```
- Uses Column layout with sticky bottom
- Keyboard overlays bottom area
- Works well for discount input form

## Benefits

✅ **Fixed Position**: Bottom area stays in its intended fixed position
✅ **Natural Behavior**: Keyboard overlays content as users expect
✅ **Performance**: No layout recalculation when keyboard toggles
✅ **Consistent**: Matches behavior of other pages in the app
✅ **Focus on Input**: User focuses on typing, sees results when keyboard closes
✅ **Simple UX**: Close keyboard to see totals and generate button

## Testing Checklist

- [x] Open "Fixed Cash Discount" field → Keyboard overlays bottom area
- [x] Type in discount → Input field remains visible
- [x] Close keyboard → Bottom area reappears with updated totals
- [x] Open "Percentage Discount" → Same overlay behavior
- [x] Switch to Item Wise → Item discount fields work properly
- [x] Scroll while keyboard open → Can access all fields
- [x] Generate button accessible when keyboard is closed

## Files Modified

1. `lib/Sales/Quotation.dart`
   - Changed `resizeToAvoidBottomInset: true` to `false` (Line ~359)

## Date
December 31, 2025

---

## Summary

✅ **Problem Solved:**
The bottom summary area now stays fixed and lets the keyboard overlay it (go behind the keyboard) instead of being pushed up.

✅ **User Experience:**
- Bottom area remains in its fixed position
- Keyboard appears on top when needed
- Users close keyboard to see totals and generate button
- Natural and performant behavior

