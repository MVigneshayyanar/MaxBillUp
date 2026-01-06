# Credit Due & Ledger Balance Fix

## Date: January 6, 2026

## Issues Fixed

### 1. Credit Due Not Reflected in Ledger Balance
**Problem:** When a credit sale was made, the customer's "Credit due" was updated but the ledger account didn't show the proper balance because credit sale entries weren't being added to the `credits` collection.

**Solution:** Updated `_updateCustomerCredit` functions in:
- `lib/Sales/Bill.dart` (PaymentPage and SplitPaymentPage)
- `lib/services/sale_sync_service.dart`

Now when a credit sale is made, an entry is added to the `credits` collection with:
- `type: 'credit_sale'`
- `invoiceNumber`: linked to the sale
- `customerId`: customer phone/ID
- Proper timestamp and amount

### 2. Payment Log Not Available / Normal Sales Not Reflected
**Problem:** The Payment History page (`CustomerCreditsPage`) only showed `payment_received` and `add_credit` type entries, missing credit sale entries AND normal sales (Cash, Online, Split).

**Solution:** 
- Added `_addPaymentLogEntry` method in PaymentPage for Cash/Online payments
- Added `_addSplitPaymentLogEntry` method in SplitPaymentPage for split payments
- Updated `CustomerCreditsPage` to display:
  - `payment_received` - green with down arrow (credit received)
  - `sale_payment` - green with shopping bag (Cash/Online/Split payments)
  - `credit_sale` - orange with receipt (credit due added)
  - `add_credit` - red with up arrow (manual credit added)

### 3. Total Sales Not Updated for All Payment Types
**Problem:** The `totalSales` field in customer document was only updated for Credit sales, not for Cash/Online/Split payments. This caused mismatch between:
- Customer Detail page (reads from `totalSales` field)
- Customer Menu page (calculates from `sales` collection)

**Solution:**
- Added `_updateCustomerTotalSales` function in PaymentPage, SplitPaymentPage, and sale_sync_service
- Called for ALL payment types (Cash, Online, Credit, Split)
- Separated `totalSales` update from `balance` update (balance only for Credit)

### 4. App Icon Zoomed In (FIXED)
**Problem:** The app icon (1024x1024) appears zoomed in on Android devices due to adaptive icon safe zone requirements. Adaptive icons require the foreground to fit within the center 66% circle, but the icon was being displayed at full size.

**Solution:** 
- Created custom XML drawable `ic_launcher_foreground_scaled.xml` with proper padding
- Added 22dp insets on all sides to scale the icon within the safe zone
- Updated `mipmap-anydpi-v26/ic_launcher.xml` to use the scaled foreground
- App now displays the full icon without zooming

**Technical Details:**
- Android adaptive icons use a 108dp canvas
- Only the center 66dp circle is guaranteed to be visible
- Added 20% padding (22dp on each side) to ensure the icon fits properly
- The XML layer-list approach scales the icon dynamically without modifying the source image

## Files Modified

1. **lib/Sales/Bill.dart**
   - `_updateCustomerCredit` in `_PaymentPageState` - only updates balance now
   - `_updateCustomerTotalSales` in `_PaymentPageState` - NEW: updates totalSales for all types
   - `_addPaymentLogEntry` in `_PaymentPageState` - adds sale_payment for Cash/Online
   - `_updateCustomerCredit` in `_SplitPaymentPageState` - only updates balance now
   - `_updateCustomerTotalSales` in `_SplitPaymentPageState` - NEW: updates totalSales
   - `_addSplitPaymentLogEntry` in `_SplitPaymentPageState` - adds sale_payment for splits

2. **lib/services/sale_sync_service.dart**
   - `_updateCustomerCredit` - only updates balance now
   - `_updateCustomerTotalSales` - NEW: updates totalSales for all synced sales

3. **lib/Menu/CustomerManagement.dart**
   - `CustomerCreditsPage` - Added support for `sale_payment` and `credit_sale` display
   - Ledger comments updated for clarity

4. **flutter_launcher_icons.yaml**
   - Added adaptive icon configuration

## How Credit & Sales Tracking Now Works

### When a Cash/Online Sale is Made (with customer):
1. Invoice created in `sales` collection
2. Customer's `totalSales` field is updated ✓
3. Entry added to `credits` collection with `type: 'sale_payment'`
4. Shows in Payment Log as "Sale Payment" (green)

### When a Credit Sale is Made:
1. Customer's `balance` field is increased (credit due)
2. Customer's `totalSales` field is updated ✓
3. Entry added to `credits` collection with `type: 'credit_sale'`
4. Invoice created in `sales` collection
5. Shows in Payment Log as "Credit Sale" (orange)

### When a Split Sale is Made (with customer):
1. Credit portion: Updates balance only
2. Customer's `totalSales` field is updated (full amount) ✓
3. Paid portion: Adds `sale_payment` entry for Cash+Online amount
4. Credit portion: Adds `credit_sale` entry
5. Both show in Payment Log

### When Payment is Received:
1. Customer's `balance` field is decreased
2. Entry added to `credits` collection with `type: 'payment_received'`
3. Shows in Payment Log as "Payment Received" (green)

### Ledger Calculation:
- Invoices from `sales` → Debit entries
- Immediate payments (Cash/Online) → Credit entries (from sales)
- `payment_received` from `credits` → Credit entries
- `add_credit` from `credits` → Debit entries
- `credit_sale` from `credits` → Skipped (already tracked via invoice)
- `sale_payment` from `credits` → Skipped (already tracked via invoice)

## Payment Log Entry Types

| Type | Display | Color | Icon | Description |
|------|---------|-------|------|-------------|
| `payment_received` | Payment Received | Green | ↓ | Credit payment received |
| `sale_payment` | Sale Payment | Green | 🛍️ | Cash/Online/Split payment |
| `credit_sale` | Credit Sale | Orange | 📃 | Sale on credit |
| `add_credit` | Credit Added | Red | ↑ | Manual credit added |

## Testing
After deploying, create different types of sales and verify:
1. Cash sale with customer → totalSales updated, shows in Payment Log
2. Online sale with customer → totalSales updated, shows in Payment Log  
3. Split sale with customer → totalSales updated (full amount), shows in Payment Log
4. Credit sale → totalSales updated, shows in Payment Log as "Credit Sale"
5. Customer Detail page `totalSales` matches Customer Menu page
6. Ledger shows correct closing balance

