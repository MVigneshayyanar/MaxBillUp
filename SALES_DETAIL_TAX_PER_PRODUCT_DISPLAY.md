# SalesDetailPage - Tax Display for Each Product in Table

## Issue
The tax calculation was working at the total level, but each individual product in the items table was not showing its tax information clearly in the TAX column.

## Solution
Enhanced the `_buildItemTableRow` method to display comprehensive tax information for each product in the TAX column, including:
- Tax name (GST, VAT, etc.)
- Tax percentage (e.g., 5%, 12%)
- Tax amount (e.g., +10.50)

## Changes Made

### Enhanced _buildItemTableRow Method
**File:** `lib/Menu/Menu.dart` (Line ~2738-2825)

**Key Improvements:**

1. **Calculate Tax Even When Fields Missing**
   ```dart
   // If tax info is missing but we have taxType, calculate it
   double calculatedTax = taxVal;
   int calculatedTaxPerc = taxPerc;
   
   if (calculatedTax == 0 && taxPerc > 0 && taxType != null) {
     if (taxType == 'Price includes Tax') {
       // Tax is included, extract it
       final baseAmount = itemSubtotal / (1 + taxPerc / 100);
       calculatedTax = itemSubtotal - baseAmount;
     } else if (taxType == 'Price is without Tax') {
       // Tax needs to be added
       calculatedTax = itemSubtotal * (taxPerc / 100);
     }
   }
   ```

2. **Display Tax as Column Widget** (Multi-line Display)
   ```dart
   Widget taxDisplay = Column(
     mainAxisSize: MainAxisSize.min,
     children: [
       // Tax Name (e.g., "GST", "VAT")
       if (taxName != null && taxName.isNotEmpty)
         Text(
           taxName,
           style: TextStyle(fontSize: 8, color: kPrimaryColor, fontWeight: w700),
         ),
       // Tax Percentage (e.g., "12%")
       Text(
         '$calculatedTaxPerc%',
         style: TextStyle(fontSize: 9, color: kBlack87, fontWeight: w700),
       ),
       // Tax Amount (e.g., "+10.50")
       Text(
         '+${calculatedTax.toStringAsFixed(2)}',
         style: TextStyle(fontSize: 8, color: kPrimaryColor, fontWeight: w600),
       ),
     ],
   );
   ```

3. **Simplified Total Column** (Removed duplicate tax display)
   ```dart
   Expanded(
     flex: 3, 
     child: Text(
       itemTotalWithTax.toStringAsFixed(2), 
       textAlign: TextAlign.right, 
       style: TextStyle(fontSize: 11, fontWeight: w800, color: kBlack87)
     )
   ),
   ```

## Visual Result

### Product Table Now Shows:

```
┌────────────────────────────────────────────────────────────────┐
│ PRODUCT          │  QTY/RATE  │    TAX       │      TOTAL      │
├────────────────────────────────────────────────────────────────┤
│ Product A        │   2 × 100  │    GST       │     224.00      │
│                  │            │     12%      │                 │
│                  │            │   +24.00     │                 │
├────────────────────────────────────────────────────────────────┤
│ Product B        │   1 × 150  │    VAT       │     157.50      │
│                  │            │     5%       │                 │
│                  │            │    +7.50     │                 │
├────────────────────────────────────────────────────────────────┤
│ Product C        │   3 × 50   │      -       │     150.00      │
│ (No tax)         │            │              │                 │
└────────────────────────────────────────────────────────────────┘
```

### Each Product Row Shows:

**TAX Column Contains:**
1. **Tax Name** (small, blue) - e.g., "GST", "VAT", "SGST"
2. **Tax Percentage** (medium, black) - e.g., "5%", "12%", "18%"
3. **Tax Amount** (small, blue) - e.g., "+10.50", "+24.00"

**TOTAL Column Contains:**
- Final total with tax included
- Single clean number

## Backward Compatibility

The code handles multiple scenarios:

### Scenario 1: New Sales (With Tax Fields)
```dart
item = {
  'name': 'Product A',
  'price': 100,
  'quantity': 2,
  'taxName': 'GST',          // ✅ Present
  'taxPercentage': 12,        // ✅ Present
  'taxAmount': 24.0,          // ✅ Present
  'taxType': 'Price is without Tax'
}
```
**Result:** Shows "GST | 12% | +24.00"

### Scenario 2: Sales with Percentage but Missing Amount
```dart
item = {
  'name': 'Product B',
  'price': 100,
  'quantity': 1,
  'taxPercentage': 5,         // ✅ Present
  'taxType': 'Price includes Tax',
  'taxAmount': 0              // ❌ Missing/Zero
}
```
**Result:** Calculates tax = 100 / 1.05 = 95.24, tax = 4.76, Shows "5% | +4.76"

### Scenario 3: Old Sales (No Tax Fields)
```dart
item = {
  'name': 'Product C',
  'price': 150,
  'quantity': 1
  // No tax fields at all
}
```
**Result:** Shows "-"

## Benefits

✅ **Clear Tax Visibility**: Each product clearly shows its tax contribution
✅ **Tax Name**: Users can see which tax applies (GST, VAT, etc.)
✅ **Tax Percentage**: Quick reference for tax rate
✅ **Tax Amount**: Exact tax amount for the item
✅ **Calculation Support**: Auto-calculates when only percentage is available
✅ **Clean Layout**: Multi-line display fits well in table cell
✅ **Color Coding**: Blue for tax info makes it stand out
✅ **Backward Compatible**: Works with old and new sales data

## Table Structure

### Header Row:
```
| PRODUCT (flex 3) | QTY/RATE (flex 2) | TAX (flex 2) | TOTAL (flex 3) |
```

### Data Row:
```
| Product Name     | Qty × Price       | TaxName      | Total Amount   |
|                  |                   | TaxPerc%     |                |
|                  |                   | +TaxAmt      |                |
```

## Tax Column Display Logic

```dart
if (tax > 0 && taxPerc > 0) {
  // Show tax info
  Column(
    taxName,      // Optional, shown if present
    taxPerc%,     // Always shown
    +taxAmount    // Always shown
  )
} else {
  // No tax
  "-"
}
```

## Previous Issues vs Fixed

| Issue | Before | After |
|-------|--------|-------|
| **Tax not shown per product** | Only total tax shown | Each product shows tax |
| **Tax amount hidden** | Only percentage | Shows both % and amount |
| **Tax name missing** | Not displayed | Shows tax name (GST/VAT) |
| **Total column cluttered** | Had extra tax info | Clean total only |
| **Missing tax fields** | Showed "-" or "0%" | Calculates from available data |

## Testing Scenarios

- [x] Product with GST (12%) → Shows "GST | 12% | +XX.XX"
- [x] Product with VAT (5%) → Shows "VAT | 5% | +XX.XX"
- [x] Product without tax → Shows "-"
- [x] Product with inclusive tax → Calculates and shows correctly
- [x] Product with exclusive tax → Calculates and shows correctly
- [x] Multiple products with different taxes → Each shows its own
- [x] Old sales without tax fields → Gracefully shows "-"

## Files Modified

1. `lib/Menu/Menu.dart`
   - Enhanced `_buildItemTableRow()` method (Line ~2738-2825)
   - Added tax calculation logic for missing fields
   - Changed tax display from simple text to Column widget
   - Simplified total column display
   - Better color coding (kPrimaryColor for tax info)

## Example Output

**Real Data Display:**

```
Product: Laptop
Qty/Rate: 2 × 500
Tax:      GST
          18%
          +180.00
Total:    1180.00

Product: Mouse  
Qty/Rate: 3 × 25
Tax:      VAT
          5%
          +3.75
Total:    78.75

Product: Cable
Qty/Rate: 5 × 10
Tax:      -
Total:    50.00
```

## Date
December 31, 2025

---

## Summary

✅ **FIXED**: Tax is now displayed clearly for each individual product in the table

✅ **TAX Column Shows**:
- Tax name (GST, VAT, etc.)
- Tax percentage (12%, 5%, etc.)
- Tax amount (+24.00, +7.50, etc.)

✅ **Features**:
- Multi-line display in TAX column
- Color-coded for visibility
- Auto-calculates missing tax amounts
- Works with old and new sales data
- Clean and professional appearance

Each product in the sales detail page now shows complete tax information in the TAX column! 🎉

