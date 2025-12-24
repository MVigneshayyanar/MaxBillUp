# Cart Item Name Edit Sync Fix

## Issue
When editing an item name in the Quick Sale page through the cart editor and clicking the Bill option, the name change was not reflected in the next page (Bill page).

## Root Cause
1. **NewSale.dart** was not preserving tax information when editing cart items
2. **QuickSale.dart** was not syncing changes from the parent component (`initialCartItems`) after the initial load in `initState()`

## Solution

### 1. Fixed NewSale.dart - Preserve Tax Information
**File:** `lib/Sales/NewSale.dart`

**Problem:** When editing cart items, the tax information (taxName, taxPercentage, taxType) was being lost.

**Fix:** Updated the `_showEditCartItemDialog` method to preserve all tax-related fields when creating the updated CartItem:

```dart
_sharedCartItems![idx] = CartItem(
  productId: item.productId,
  name: newName,
  price: newPrice,
  quantity: newQty,
  taxName: item.taxName,           // ✅ Now preserved
  taxPercentage: item.taxPercentage, // ✅ Now preserved
  taxType: item.taxType,            // ✅ Now preserved
);
```

### 2. Added Widget Update Sync to QuickSale.dart
**File:** `lib/Sales/QuickSale.dart`

**Problem:** QuickSale only loaded `initialCartItems` once in `initState()`. When the parent (NewSale) updated the cart items, QuickSale didn't receive those updates.

**Fix:** Added `didUpdateWidget` lifecycle method to sync changes from parent:

```dart
@override
void didUpdateWidget(QuickSalePage oldWidget) {
  super.didUpdateWidget(oldWidget);
  // Sync changes from parent when initialCartItems changes
  if (widget.initialCartItems != oldWidget.initialCartItems) {
    if (widget.initialCartItems != null) {
      setState(() {
        _items.clear();
        for (var item in widget.initialCartItems!) {
          _items.add(QuickSaleItem(
            name: item.name,
            price: item.price,
            quantity: item.quantity,
          ));
        }
        // Update counter to continue from the highest item number
        _counter = _items.length + 1;
      });
    }
  }
}
```

## How It Works Now

1. User edits item name in the cart (via edit icon in NewSale.dart)
2. NewSale updates `_sharedCartItems` with the new name (and preserves tax info)
3. NewSale calls `_updateCartItems()` which triggers QuickSale's `onCartChanged` callback
4. QuickSale receives updated `initialCartItems` through widget update
5. `didUpdateWidget` detects the change and syncs the internal `_items` list
6. When user clicks "Bill", QuickSale passes the updated cart items with correct names
7. Bill page receives and displays the correct item names

## Testing Checklist

- [x] Edit item name in Quick Sale cart
- [x] Click Bill option
- [x] Verify name appears correctly in Bill page
- [x] Verify tax information is preserved
- [x] Verify price and quantity are preserved
- [x] Test with multiple items
- [x] Test editing multiple times

## Technical Details

### Data Flow
```
User Edit (NewSale cart)
  ↓
_sharedCartItems updated (with all fields preserved)
  ↓
_updateCartItems() called
  ↓
QuickSale.onCartChanged() triggered
  ↓
QuickSale receives new initialCartItems via widget rebuild
  ↓
didUpdateWidget() detects change
  ↓
Internal _items list synced
  ↓
Navigate to Bill with correct _cartItems
```

### Files Modified
1. `lib/Sales/NewSale.dart` - Added tax field preservation
2. `lib/Sales/QuickSale.dart` - Added didUpdateWidget sync method

## Date
Fixed: December 25, 2025

