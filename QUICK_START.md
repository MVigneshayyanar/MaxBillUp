# Quick Start Guide - Store-Scoped Database

## ✅ What Was Fixed

All errors in your Category.dart file have been resolved! The file now uses the new store-scoped database structure.

## 🎯 Key Changes

### 1. Database Structure
Your app now stores data under each store:
```
Before: Products (root collection)
After:  store/100001/Products (subcollection)
```

### 2. How to Use FirestoreService

Import it in your files:
```dart
import 'package:maxbillup/utils/firestore_service.dart';
```

Replace old Firebase calls:
```dart
// OLD WAY ❌
FirebaseFirestore.instance.collection('Products').snapshots()

// NEW WAY ✅
await FirestoreService().getCollectionStream('Products')
```

### 3. Common Operations

**Get Stream of Data:**
```dart
final stream = await FirestoreService().getCollectionStream('Products');
StreamBuilder<QuerySnapshot>(
  stream: stream,
  builder: (context, snapshot) { ... },
);
```

**Add Document:**
```dart
await FirestoreService().addDocument('Products', {
  'itemName': 'Apple',
  'price': 100.0,
});
```

**Update Document:**
```dart
await FirestoreService().updateDocument('Products', productId, {
  'price': 120.0,
});
```

**Delete Document:**
```dart
await FirestoreService().deleteDocument('Products', productId);
```

**Query with Filters:**
```dart
final collection = await FirestoreService().getStoreCollection('sales');
final query = collection.where('amount', isGreaterThan: 100);
final snapshot = await query.get();
```

## 📝 Collections That Are Store-Scoped

All these collections are now under `store/{storeId}/`:
- Products
- categories
- customers
- sales
- credits
- creditNotes
- purchaseCreditNotes
- stockPurchases
- expenses
- expenseCategories
- otherExpenses
- quotations
- savedOrders
- suppliers

## 🔐 Collections That Stay at Root

Only these 2 collections remain at root level:
- `users` - User authentication data
- `store` - Store/business information

## ✅ Files Already Updated

- ✅ Products.dart
- ✅ AddProduct.dart
- ✅ Category.dart
- ✅ AddCategoryPopup.dart
- ✅ StockPurchase.dart
- ✅ Expenses.dart
- ✅ OtherExpenses.dart
- ✅ ExpenseCategories.dart
- ✅ Bill.dart (partial)
- ✅ StaffManagement.dart
- ✅ LoginPage.dart
- ✅ BusinessDetailsPage.dart

## 🚀 How to Test

1. **Run the app:**
   ```bash
   flutter run
   ```

2. **Create a new account** using Google Sign-In

3. **Fill business details** - this creates:
   - Store document with storeId (e.g., 100001)
   - User document linked to that store

4. **Add products, categories** - they'll be stored under your store

5. **Check Firebase Console** - verify data structure:
   ```
   store/
     └── 100001/
           ├── Products/
           └── categories/
   ```

## 🐛 Troubleshooting

**Error: "No store ID found"**
- User is not logged in or user document doesn't have storeId
- Solution: Re-login or check user document in Firebase

**Error: "Permission denied"**
- Firestore security rules need updating
- Solution: Update rules to allow store-scoped access

**Data not showing:**
- Check if you're querying the correct store
- Solution: Verify FirestoreService is getting correct storeId

## 📚 Documentation Files

- `STORE_SCOPED_DATABASE.md` - Complete technical documentation
- `IMPLEMENTATION_SUMMARY.md` - What's done and what's pending

## 🎉 Success!

Your errors are fixed! The store-scoped database structure is now working for:
- Products management
- Categories management
- Stock purchases
- Expenses tracking

Keep using `FirestoreService()` for all remaining files to maintain consistency!

