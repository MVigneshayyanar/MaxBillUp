# Quotation Bottom Summary Area - Sticky/Fixed Position Fix

## Issue
The `_buildBottomSummaryArea` widget was scrolling with the content instead of staying fixed at the bottom of the screen.

## Solution
Restructured the layout hierarchy to make the bottom summary area sticky/fixed at the bottom.

## Changes Made

### 1. Layout Restructure
**File:** `lib/Sales/Quotation.dart` (~lines 413-456)

**Before:**
```dart
Expanded(
  child: Container(
    child: Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            // Content here
          ),
        ),
        _buildBottomSummaryArea(), // Inside Column with scroll
      ],
    ),
  ),
)
```

**After:**
```dart
Expanded(
  child: Container(
    child: SingleChildScrollView(
      // All scrollable content here
      // Added extra padding at bottom (200px) to prevent 
      // content from being hidden under sticky bottom area
    ),
  ),
),
_buildBottomSummaryArea(), // Outside scroll, directly in main Column
```

### 2. Enhanced Visual Separation
**File:** `lib/Sales/Quotation.dart` (~lines 558-580)

Added box shadow to the bottom summary area for better visual depth:
```dart
boxShadow: [
  BoxShadow(
    color: Colors.black.withValues(alpha: (0.08 * 255).toDouble()),
    blurRadius: 12,
    offset: const Offset(0, -4),
  ),
],
```

### 3. Content Padding
Added `SizedBox(height: 200)` at the bottom of scrollable content to ensure the last items are not hidden behind the fixed bottom area.

## Technical Details

### Widget Hierarchy
```
Scaffold
└── Column
    ├── Padding (Customer section)
    ├── Expanded (Scrollable content area)
    │   └── Container
    │       └── SingleChildScrollView
    │           └── Column
    │               ├── Discounting Strategy
    │               ├── Bill Wise / Item Wise content
    │               └── SizedBox(height: 200) // Bottom padding
    └── Container (_buildBottomSummaryArea) // FIXED/STICKY
        ├── _buildFinalSummary()
        └── GENERATE QUOTATION Button
```

## Benefits

✅ **Fixed Position**: Bottom summary area now stays fixed at the bottom while scrolling
✅ **Always Visible**: User can always see the total and generate button
✅ **Better UX**: No need to scroll down to see totals or generate quotation
✅ **Visual Depth**: Added shadow provides clear separation between scrollable content and fixed bottom
✅ **Content Protection**: Extra bottom padding ensures content is not hidden under the fixed area
✅ **Responsive**: Works with both Bill Wise and Item Wise discount modes

## Testing Checklist

- [x] Bottom summary area stays fixed when scrolling
- [x] All content is accessible (nothing hidden under fixed area)
- [x] Works in Bill Wise mode
- [x] Works in Item Wise mode with many items
- [x] Shadow provides good visual separation
- [x] Generate button is always accessible
- [x] Total amounts update correctly when changing discounts
- [x] Responsive on different screen sizes

## Files Modified

1. `lib/Sales/Quotation.dart`
   - Layout restructure (~lines 413-456)
   - Added box shadow to `_buildBottomSummaryArea()` (~lines 558-580)

## Date
December 31, 2025

