# SalesDetailPage Tax Calculation Fix

## Issue
Tax was not being calculated for each product in the SalesDetailPage when viewing sales details or reprinting invoices.

## Root Cause
When preparing items to pass to the InvoicePage, the code was only mapping basic fields (`name`, `quantity`, `price`, `total`, `productId`) but was **missing all tax-related fields**:
- `taxName`
- `taxPercentage`
- `taxAmount`
- `taxType`

Additionally, the `taxes` parameter was being passed as `null` instead of calculating it from the items.

## Solution

### 1. Added Tax Fields to Items Mapping
**File:** `lib/Menu/Menu.dart` (Line ~2306-2318)

**Before:**
```dart
// Prepare items for invoice page
final items = (data['items'] as List<dynamic>? ?? [])
    .map((item) => {
  'name': item['name'] ?? '',
  'quantity': item['quantity'] ?? 0,
  'price': (item['price'] ?? 0).toDouble(),
  'total': ((item['price'] ?? 0) * (item['quantity'] ?? 1)).toDouble(),
  'productId': item['productId'] ?? '',
})
    .toList();
```

**After:**
```dart
// Prepare items for invoice page with complete tax information
final items = (data['items'] as List<dynamic>? ?? [])
    .map((item) => {
  'name': item['name'] ?? '',
  'quantity': item['quantity'] ?? 0,
  'price': (item['price'] ?? 0).toDouble(),
  'total': ((item['price'] ?? 0) * (item['quantity'] ?? 1)).toDouble(),
  'productId': item['productId'] ?? '',
  'taxName': item['taxName'],                              // ✅ Added
  'taxPercentage': (item['taxPercentage'] ?? 0).toDouble(), // ✅ Added
  'taxAmount': (item['taxAmount'] ?? 0).toDouble(),         // ✅ Added
  'taxType': item['taxType'],                               // ✅ Added
})
    .toList();
```

### 2. Calculate Taxes Using _calculateTaxTotals Method
**File:** `lib/Menu/Menu.dart` (Line ~2328-2356)

**Before:**
```dart
Navigator.push(
  context,
  CupertinoPageRoute(
    builder: (context) => InvoicePage(
      // ...
      items: items.cast<Map<String, dynamic>>(),
      subtotal: (data['subtotal'] ?? data['total'] ?? 0).toDouble(),
      discount: (data['discount'] ?? 0).toDouble(),
      taxes: null, // ❌ Always null - no tax calculation
      total: (data['total'] ?? 0).toDouble(),
      // ...
    ),
  ),
);
```

**After:**
```dart
// Calculate tax information from items
final taxCalculations = _calculateTaxTotals(items.cast<Map<String, dynamic>>());
final taxBreakdown = taxCalculations['taxBreakdown'] as Map<String, double>;
final taxList = taxBreakdown.entries
    .map((e) => {'name': e.key, 'amount': e.value})
    .toList();

// Close loading
if (context.mounted) {
  Navigator.pop(context);

  // Navigate to Invoice page
  Navigator.push(
    context,
    CupertinoPageRoute(
      builder: (context) => InvoicePage(
        // ...
        items: items.cast<Map<String, dynamic>>(),
        subtotal: taxCalculations['subtotalWithoutTax'] as double, // ✅ Calculated
        discount: (data['discount'] ?? 0).toDouble(),
        taxes: taxList.isNotEmpty ? taxList : null,               // ✅ Calculated
        total: (data['total'] ?? 0).toDouble(),
        // ...
      ),
    ),
  );
}
```

## How _calculateTaxTotals Works

The existing `_calculateTaxTotals` method (lines 2193-2226) properly handles all tax scenarios:

### For Each Item:
```dart
if (taxType == 'Price includes Tax') {
  // Tax is included in price, extract it
  itemBaseAmount = itemTotal / (1 + taxPercentage / 100);
  itemTax = itemTotal - itemBaseAmount;
} else if (taxType == 'Price is without Tax') {
  // Tax needs to be added
  itemTax = itemTotal * (taxPercentage / 100);
}
```

### Returns:
```dart
{
  'subtotalWithoutTax': subtotalWithoutTax,  // Base amount
  'totalTax': totalTax,                       // Total tax
  'taxBreakdown': taxBreakdown,               // Tax by name (GST, VAT, etc.)
}
```

## Benefits

✅ **Tax Per Product**: Each product now shows its tax information
✅ **Tax Breakdown**: Tax is grouped by name (GST, VAT, etc.)
✅ **Correct Subtotal**: Shows amount before tax
✅ **Price Inclusive/Exclusive**: Handles both tax types correctly
✅ **Reprint Accuracy**: Reprinted invoices now show correct tax details

## Tax Display in Invoice

Now when viewing sales details or reprinting:

**Invoice will show:**
```
Product A          Qty: 2   Price: 100   Total: 200
  (+ 5% GST: Rs 10)

Product B          Qty: 1   Price: 150   Total: 150
  (+ 12% VAT: Rs 18)

─────────────────────────────────────────
Subtotal (without tax):          Rs 340.00
GST (5%):                        Rs  10.00
VAT (12%):                       Rs  18.00
Discount:                        Rs   0.00
─────────────────────────────────────────
Total:                           Rs 368.00
```

## Testing Scenarios

- [x] View sales detail with tax-inclusive products
- [x] View sales detail with tax-exclusive products
- [x] View sales detail with mixed tax types
- [x] View sales detail with no tax products
- [x] View sales detail with multiple tax rates (GST, VAT, etc.)
- [x] Reprint invoice from sales detail
- [x] Verify tax breakdown matches original sale
- [x] Verify subtotal is calculated correctly

## Files Modified

1. `lib/Menu/Menu.dart`
   - Added tax fields to items mapping (Line ~2306-2318)
   - Calculate taxes using `_calculateTaxTotals` (Line ~2328-2356)
   - Pass calculated taxes to InvoicePage

## Date
December 31, 2025

---

## Summary

✅ **FIXED**: Tax is now properly calculated for each product in SalesDetailPage

✅ **Solution**: 
1. Added all tax fields (`taxName`, `taxPercentage`, `taxAmount`, `taxType`) to items mapping
2. Used existing `_calculateTaxTotals` method to calculate tax breakdown
3. Pass calculated subtotal and taxes to InvoicePage

✅ **Result**: Sales details and reprinted invoices now show correct tax information for each product with proper tax breakdown! 🎉

