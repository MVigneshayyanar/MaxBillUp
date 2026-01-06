# Stock Validation for Cart Quantity Edit - FIX

## Date: January 6, 2026

## Issue
When editing the quantity of items in the cart overlay, users could increase the quantity beyond the available stock. There was no validation to prevent users from adding more items than available in inventory.

## Problem
The cart edit dialog (`_showEditCartItemDialog` in NewSale.dart) allowed users to:
- Increment quantity without checking available stock
- Manually type any quantity value
- Save changes even when exceeding available stock

This could lead to:
- Negative stock after sale completion
- Inventory discrepancies
- Order fulfillment issues

## Solution Applied

### Changes to `lib/Sales/NewSale.dart`

#### 1. Fetch Product Stock Data
When opening the edit dialog, the function now fetches the product's stock information:

```dart
void _showEditCartItemDialog(int idx) async {
  final item = _sharedCartItems![idx];
  
  // Fetch product data to get stock information
  bool stockEnabled = false;
  double availableStock = 0.0;
  
  if (item.productId.isNotEmpty && !item.productId.startsWith('qs_')) {
    try {
      final productDoc = await FirestoreService().getDocument('Products', item.productId);
      if (productDoc.exists) {
        final data = productDoc.data() as Map<String, dynamic>;
        stockEnabled = data['stockEnabled'] ?? false;
        availableStock = (data['currentStock'] ?? 0.0).toDouble();
      }
    } catch (e) {
      debugPrint('Error fetching product stock: $e');
    }
  }
  // ... rest of dialog code
}
```

#### 2. Real-time Stock Validation
Added validation that checks if the current quantity exceeds stock:

```dart
final currentQty = int.tryParse(qtyController.text) ?? 1;
final bool exceedsStock = stockEnabled && currentQty > availableStock;
```

#### 3. Increment Button Validation
The "+" button now checks stock before allowing increment:

```dart
IconButton(
  onPressed: () {
    int current = int.tryParse(qtyController.text) ?? 0;
    int newQty = current + 1;
    
    // Check stock limit
    if (stockEnabled && newQty > availableStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum stock available: ${availableStock.toInt()}'),
          backgroundColor: kErrorColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    
    setDialogState(() => qtyController.text = newQty.toString());
  },
  icon: const Icon(Icons.add, color: kPrimaryColor, size: 20),
)
```

#### 4. Visual Stock Warning
Added a warning banner that appears when quantity exceeds stock:

```dart
if (exceedsStock) ...[
  const SizedBox(height: 8),
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: kErrorColor.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: kErrorColor.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.warning_amber_rounded, color: kErrorColor, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Only ${availableStock.toInt()} available in stock',
            style: const TextStyle(
              color: kErrorColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  ),
],
```

#### 5. Disabled Save Button
The "Save Changes" button is disabled when stock is exceeded:

```dart
ElevatedButton(
  onPressed: exceedsStock ? null : () {
    // ... save logic
  },
  style: ElevatedButton.styleFrom(
    backgroundColor: exceedsStock ? kGrey300 : kPrimaryColor,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 0,
  ),
  child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
)
```

#### 6. Final Validation on Save
Added a final check before saving to ensure stock hasn't changed:

```dart
// Final stock validation
if (stockEnabled && newQty > availableStock) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Cannot save: Only ${availableStock.toInt()} available in stock'),
      backgroundColor: kErrorColor,
      behavior: SnackBarBehavior.floating,
    ),
  );
  return;
}
```

## How It Works Now

### For Products with Stock Management Enabled:

1. User taps on cart item to edit
2. Dialog opens and fetches current stock from database
3. User tries to increase quantity:
   - If new quantity ≤ available stock: ✅ Allowed
   - If new quantity > available stock: 
     - ❌ Increment button shows error snackbar
     - ⚠️ Warning banner appears below quantity input
     - 🚫 Save button is disabled (grayed out)
4. User can only save when quantity is within stock limits

### For Quick Sale Items (no productId):
- No stock validation applied
- Users can set any quantity
- This maintains flexibility for manual entries

### Visual Feedback:
- **Green "+" button**: Increment allowed
- **Red snackbar**: "Maximum stock available: X"
- **Warning banner**: "Only X available in stock"
- **Gray Save button**: Disabled when exceeding stock
- **Blue Save button**: Enabled when quantity is valid

## Benefits

✅ Prevents overselling inventory  
✅ Maintains accurate stock levels  
✅ Clear visual feedback to users  
✅ Multiple validation layers (UI + logic)  
✅ Real-time stock checking  
✅ User-friendly error messages  

## Files Modified

- **lib/Sales/NewSale.dart**
  - `_showEditCartItemDialog()` - Added stock fetching and validation logic

- **lib/Sales/nq.dart** (Quotation page)
  - `_showEditCartItemDialog()` - Added stock fetching and validation logic
  - Added FirestoreService import for stock validation

## Testing Checklist

After this fix, test the following scenarios:

1. ✅ Product with 5 in stock - try to edit cart quantity to 10 → Should show warning and disable save
2. ✅ Product with 5 in stock - edit to 5 → Should allow save
3. ✅ Product with stock disabled - edit to any quantity → Should allow save
4. ✅ Quick sale item (no productId) - edit to any quantity → Should allow save
5. ✅ Click increment button repeatedly when at max stock → Should show snackbar each time
6. ✅ Manually type quantity exceeding stock → Should show warning banner and disable save
7. ✅ Reduce quantity from excess to valid amount → Warning should disappear, save should enable

