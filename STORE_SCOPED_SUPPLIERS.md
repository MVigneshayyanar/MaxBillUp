# Store-Scoped Suppliers Implementation

## Date: December 15, 2025

## Overview
Made the **suppliers** collection store-scoped to ensure each store has independent supplier records.

## Problem
Previously, suppliers were stored in the root `suppliers` collection, which meant:
- ❌ All stores shared the same supplier records
- ❌ Supplier data was not isolated per store
- ❌ Multi-store operations could cause data conflicts

**Firestore Structure Before:**
```
/suppliers
  /{phoneNumber}
    - name: "Supplier Name"
    - phone: "1234567890"
    - creditBalance: 100000
    - createdAt: timestamp
```

## Solution
Updated to use **store-scoped** suppliers collection that properly isolates supplier data per store.

**Firestore Structure After:**
```
/stores
  /{storeId}
    /suppliers
      /{phoneNumber}
        - name: "Supplier Name"
        - phone: "1234567890"
        - creditBalance: 100000
        - createdAt: timestamp
        - uid: "user-id"
```

## Changes Made

### 1. StockPurchase.dart (`lib/Stocks/StockPurchase.dart`)

#### Supplier Credit Balance Update
**Before:**
```dart
final supplierRef = FirebaseFirestore.instance
    .collection('suppliers')
    .doc(_supplierPhoneController.text);
```

**After:**
```dart
final suppliersCollection = await FirestoreService().getStoreCollection('suppliers');
final supplierRef = suppliersCollection.doc(_supplierPhoneController.text);
```

**Changes:**
- ✅ Supplier creation is now store-scoped
- ✅ Supplier credit balance updates are store-scoped
- ✅ Fixed type casting issue with `supplierDoc.data()`

### 2. Menu.dart (`lib/Menu/Menu.dart`)

#### Purchase Credit Note Payment
**Before:**
```dart
final supplierRef = FirebaseFirestore.instance
    .collection('suppliers')
    .doc(supplierPhone);
```

**After:**
```dart
final suppliersCollection = await FirestoreService().getStoreCollection('suppliers');
final supplierRef = suppliersCollection.doc(supplierPhone);
```

**Changes:**
- ✅ Supplier balance updates when paying purchase credit notes are now store-scoped

## When Suppliers Are Created/Updated

### 1. Stock Purchase with Credit Payment Mode
**Location:** `StockPurchase.dart`

When a purchase is made with "Credit" payment mode:
1. A purchase credit note is created
2. If supplier phone is provided:
   - **Check if supplier exists** in store-scoped suppliers collection
   - **If exists:** Update `creditBalance` by adding purchase amount
   - **If not exists:** Create new supplier record with:
     - `name`: Supplier name
     - `phone`: Supplier phone (used as document ID)
     - `creditBalance`: Purchase amount
     - `createdAt`: Timestamp
     - `uid`: User ID

### 2. Purchase Credit Note Payment
**Location:** `Menu.dart` - Purchase Credit Notes section

When a purchase credit note is paid:
1. Payment is recorded in `purchaseCreditNotePayments` collection
2. Credit note status is updated (Partial/Paid)
3. **Supplier balance is updated:** `creditBalance` is reduced by payment amount

## Benefits

### 1. Store Isolation
- ✅ Each store manages its own supplier records
- ✅ Store A's suppliers don't appear in Store B
- ✅ Credit balances are tracked separately per store

### 2. Multi-Store Support
- ✅ Proper multi-tenant architecture
- ✅ Franchise/chain stores can operate independently
- ✅ No data conflicts between stores

### 3. Data Integrity
- ✅ Supplier data belongs to specific store
- ✅ Credit balances are accurate per store
- ✅ No accidental overwrites between stores

## Testing

### Test Case 1: Create Supplier via Purchase
1. Go to Stock Purchase
2. Enter supplier details (Name, Phone)
3. Select "Credit" payment mode
4. Save purchase
5. **Verify in Firestore:** Supplier created under `/stores/{storeId}/suppliers/{phone}`
6. **Verify:** `creditBalance` equals purchase amount

### Test Case 2: Update Existing Supplier
1. Create a purchase with existing supplier (Credit mode)
2. **Verify:** Supplier's `creditBalance` increases
3. **Verify:** Supplier record updated under correct store path

### Test Case 3: Pay Purchase Credit Note
1. Go to Purchase Credit Notes
2. Pay a credit note partially/fully
3. **Verify:** Supplier's `creditBalance` decreases by payment amount
4. **Verify:** All updates happen in store-scoped collection

### Test Case 4: Multiple Stores
1. Switch to Store A
2. Create a purchase with Supplier X (phone: 1234567890)
3. Switch to Store B
4. Create a purchase with Supplier X (phone: 1234567890)
5. **Verify:** Two separate supplier records exist:
   - `/stores/storeA/suppliers/1234567890`
   - `/stores/storeB/suppliers/1234567890`
6. **Verify:** Each has independent credit balance

## Migration Notes

### For Existing Installations

If your app already has suppliers in the root `suppliers` collection, you'll need to migrate them:

**Migration Script (run once per store):**
```dart
// Get all suppliers from root collection
final rootSuppliers = await FirebaseFirestore.instance
    .collection('suppliers')
    .get();

// Get store ID
final storeId = await FirestoreService().getCurrentStoreId();

if (storeId != null) {
  final storeSuppliers = await FirebaseFirestore.instance
      .collection('stores')
      .doc(storeId)
      .collection('suppliers');
  
  // Copy each supplier to store-scoped collection
  for (var supplier in rootSuppliers.docs) {
    await storeSuppliers.doc(supplier.id).set(supplier.data());
  }
  
  print('Migrated ${rootSuppliers.docs.length} suppliers to store $storeId');
}
```

**Note:** This migration should be done for each store separately.

## Related Collections Now Store-Scoped

✅ **Previously implemented:**
- `Products`
- `sales`
- `customers`
- `taxes`
- `settings`
- `expenses`
- `expenseCategories`
- `purchaseCreditNotes`
- `quotations`
- `creditNotes`

✅ **Now implemented:**
- `suppliers`

## Code Quality Improvements

### Type Safety Fix
Fixed type casting issue in supplier balance update:

**Before (Error):**
```dart
final currentBalance = supplierDoc.data()?['creditBalance'] ?? 0.0;
```

**After (Fixed):**
```dart
final supplierData = supplierDoc.data() as Map<String, dynamic>?;
final currentBalance = (supplierData?['creditBalance'] ?? 0.0) as num;
final newBalance = currentBalance.toDouble() + amount;
```

This ensures proper type safety when reading Firestore data.

## Summary

Suppliers are now fully **store-scoped**:
- ✅ Created under `/stores/{storeId}/suppliers`
- ✅ Each store has independent supplier records
- ✅ Credit balances tracked separately per store
- ✅ No conflicts between stores
- ✅ Proper multi-tenant architecture

Each store can now manage its own supplier relationships independently! 🎉

