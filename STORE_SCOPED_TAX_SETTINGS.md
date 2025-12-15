# Store-Scoped Tax Settings Implementation

## Date: December 15, 2025

## Overview
Made the tax settings for Quick Sale **store-scoped** to ensure each store has independent tax configurations.

## Problem
Previously, tax settings were stored globally in the root `settings` collection, which meant:
- ❌ All stores shared the same tax configuration
- ❌ Changes by one store affected all other stores
- ❌ No isolation between different business locations

## Solution
Updated to use **store-scoped** settings collection that properly isolates tax configurations per store.

## Changes Made

### 1. TaxSettings.dart (`lib/Settings/TaxSettings.dart`)

#### _loadDefaultTaxType() Method
**Before:**
```dart
final doc = await FirestoreService().getDocument('settings', 'taxSettings');
```

**After:**
```dart
final settingsCollection = await FirestoreService().getStoreCollection('settings');
final doc = await settingsCollection.doc('taxSettings').get();
```

#### _saveDefaultTaxType() Method
**Before:**
```dart
await FirestoreService().setDocument('settings', 'taxSettings', {
  'defaultTaxType': _defaultTaxType,
  'updatedAt': FieldValue.serverTimestamp(),
});
```

**After:**
```dart
final settingsCollection = await FirestoreService().getStoreCollection('settings');
await settingsCollection.doc('taxSettings').set({
  'defaultTaxType': _defaultTaxType,
  'updatedAt': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));
```

#### Quick Sale Tax Tab Update Button
**Before:**
```dart
await FirebaseFirestore.instance
    .collection('settings')
    .doc('quick_sale_config')
    .set({...});
```

**After:**
```dart
final settingsCollection = await FirestoreService().getStoreCollection('settings');
await settingsCollection.doc('taxSettings').set({
  'defaultTaxType': _defaultTaxType,
  'updatedAt': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));
```

### 2. QuickSale.dart (`lib/Sales/QuickSale.dart`)

#### initState() - Load Tax Settings
**Before:**
```dart
final settingsDoc = await firestoreService.getDocument('settings', 'taxSettings');
```

**After:**
```dart
final settingsCollection = await firestoreService.getStoreCollection('settings');
final settingsDoc = await settingsCollection.doc('taxSettings').get();
```

## Firestore Structure

### Before (Global)
```
/settings
  /taxSettings
    - defaultTaxType: "Price is without Tax"
    - updatedAt: timestamp
```
All stores read/write to the same document ❌

### After (Store-Scoped)
```
/stores
  /{storeId}
    /settings
      /taxSettings
        - defaultTaxType: "Price is without Tax"
        - updatedAt: timestamp
```
Each store has its own settings document ✅

## Benefits

### 1. Store Isolation
- ✅ Each store manages its own tax settings independently
- ✅ Changes in Store A don't affect Store B
- ✅ Different stores can have different tax configurations

### 2. Multi-Store Support
- ✅ Proper multi-tenant architecture
- ✅ Each business location has unique settings
- ✅ Supports franchise/chain store operations

### 3. Data Integrity
- ✅ No accidental overwrites between stores
- ✅ Settings persist even when switching stores
- ✅ Clear ownership of tax configurations

## Testing

### Test Case 1: Single Store
1. Go to Tax Settings
2. Set default tax type to "Price includes Tax"
3. Save settings
4. Go to Quick Sale
5. **Verify:** Tax type matches what was set

### Test Case 2: Multiple Stores
1. Switch to Store A
2. Set default tax type to "Price includes Tax"
3. Switch to Store B
4. Set default tax type to "Price is without Tax"
5. Switch back to Store A
6. **Verify:** Store A still has "Price includes Tax"
7. Switch to Store B
8. **Verify:** Store B still has "Price is without Tax"

### Test Case 3: New Store
1. Create a new store
2. Go to Tax Settings
3. **Verify:** Default tax type is "Price is without Tax" (default value)
4. Settings don't inherit from other stores

## Migration Notes

### For Existing Installations
If your app already has tax settings in the global `settings` collection:

1. **Data Migration Script** (run once):
```dart
// Copy global settings to each store
final stores = await FirebaseFirestore.instance.collection('stores').get();
final globalSettings = await FirebaseFirestore.instance
    .collection('settings')
    .doc('taxSettings')
    .get();

if (globalSettings.exists) {
  for (var store in stores.docs) {
    await store.reference
        .collection('settings')
        .doc('taxSettings')
        .set(globalSettings.data()!);
  }
}
```

2. **Manual Migration**:
   - Note current tax settings
   - Update app
   - Re-enter tax settings for each store

## Related Collections

The following are already store-scoped and work correctly:
- ✅ `taxes` collection (tax rates)
- ✅ `Products` collection
- ✅ `sales` collection
- ✅ `customers` collection

## Summary

All tax-related settings are now properly **store-scoped**:
- ✅ Default tax type (Price includes/without Tax)
- ✅ Tax rates (GST, SGST, CGST, etc.)
- ✅ Active tax toggles for Quick Sale
- ✅ Tax configurations per store

Each store operates independently with its own tax configuration! 🎉

