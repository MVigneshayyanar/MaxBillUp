# Quotation Tax Calculation & Store Details Fix

## Issue
Tax was not being calculated when creating a quotation, and store details were not being fetched properly like in bill.dart.

## Changes Made

### 1. Updated `_fetchBusinessDetails()` method
**File:** `lib/Sales/Quotation.dart`

- Changed from using `FirebaseFirestore.instance` directly to using `FirestoreService()` 
- This ensures proper store-scoped data fetching consistent with bill.dart
- Now properly fetches:
  - Business Name
  - Business Location/Address
  - Business Phone
  - GSTIN

### 2. Enhanced `_generateQuotation()` method
**File:** `lib/Sales/Quotation.dart`

Added comprehensive tax calculation logic:

#### Tax Information Calculation
```dart
// Calculate tax information from cart items
final Map<String, double> taxMap = {};
for (var item in widget.cartItems) {
  if (item.taxAmount > 0 && item.taxName != null) {
    taxMap[item.taxName!] = (taxMap[item.taxName!] ?? 0.0) + item.taxAmount;
  }
}
final taxList = taxMap.entries.map((e) => {'name': e.key, 'amount': e.value}).toList();
final totalTax = taxMap.values.fold(0.0, (a, b) => a + b);
```

#### Proper Subtotal & Total Calculation
```dart
// Calculate subtotal (without tax)
final subtotalAmount = widget.cartItems.fold(0.0, (sum, item) {
  if (item.taxType == 'Price includes Tax') {
    return sum + (item.basePrice * item.quantity);
  } else {
    return sum + item.total;
  }
});

// Calculate total with tax
final totalWithTax = widget.cartItems.fold(0.0, (sum, item) => sum + item.totalWithTax);
```

#### Enhanced Item Data Storage
Now saves complete tax information for each item:
- `taxName`: Name of the tax (e.g., "GST", "VAT")
- `taxPercentage`: Tax percentage
- `taxAmount`: Calculated tax amount
- `taxType`: Type of tax application
- `totalWithTax`: Item total including tax

#### Enhanced Quotation Data
Added to quotation document:
- `taxes`: Array of tax breakdowns by name
- `totalTax`: Total tax amount
- Proper `subtotal` (without tax)
- Proper `total` (with tax minus discount)

### 3. Updated Invoice Navigation
**File:** `lib/Sales/Quotation.dart`

Now passes complete tax information to InvoicePage:
```dart
InvoicePage(
  // ... other parameters
  items: widget.cartItems.map((e) => {
    'name': e.name,
    'quantity': e.quantity,
    'price': e.price,
    'total': e.totalWithTax,        // ✓ Total with tax
    'taxPercentage': e.taxPercentage ?? 0,  // ✓ Tax percentage
    'taxAmount': e.taxAmount,        // ✓ Tax amount
  }).toList(),
  subtotal: subtotalAmount,          // ✓ Subtotal without tax
  taxes: taxList,                    // ✓ Tax breakdown
  total: totalWithTax - _discountAmount,  // ✓ Final total
)
```

### 4. Enhanced Bottom Summary Display
**File:** `lib/Sales/Quotation.dart`

Updated `_buildFinalSummary()` to show:
1. **Subtotal** (base amount without tax)
2. **Tax** (total tax amount, if applicable)
3. **Discount** (discount amount with percentage)
4. **Net Total** (final amount with tax minus discount)

This matches the display format used in bill.dart for consistency.

## Benefits

1. ✅ **Tax Calculation**: Quotations now properly calculate and display tax amounts
2. ✅ **Store Details**: Business information is fetched correctly using FirestoreService
3. ✅ **Data Consistency**: Quotation data saved to Firestore includes complete tax information
4. ✅ **Invoice Display**: Tax information is properly passed to InvoicePage for accurate quotation display
5. ✅ **UI Clarity**: Bottom summary now shows tax breakdown clearly
6. ✅ **Compatibility**: Works with all tax types:
   - Price includes Tax
   - Price is without Tax
   - Zero Rated Tax
   - Exempt Tax

## Testing Checklist

- [ ] Create a quotation with tax-inclusive products
- [ ] Create a quotation with tax-exclusive products
- [ ] Verify tax is shown in bottom summary
- [ ] Verify business details are displayed correctly in quotation preview
- [ ] Verify tax breakdown is saved in Firestore
- [ ] Verify quotation can be converted to invoice with correct tax
- [ ] Test with different tax rates and types
- [ ] Test with discounts applied (tax should still calculate correctly)

## Files Modified

1. `lib/Sales/Quotation.dart`
   - `_fetchBusinessDetails()` - Line ~169
   - `_generateQuotation()` - Line ~207
   - `_buildFinalSummary()` - Line ~634

## Date
December 31, 2025

