# Store-Scoped Database Structure

## Overview
This document explains the new store-scoped Firestore database structure implemented in MaxBillUp.

## Database Structure

### Root Collections
Only two collections exist at the root level:
1. **store** - Contains all store/business information
2. **users** - Contains user authentication and store linkage

### Store Collection Structure
```
Firestore
├── store (collection)
│   └── {storeId} (document - e.g., "100001", "100002")
│       ├── storeId: 100001
│       ├── ownerName: "John Doe"
│       ├── ownerEmail: "john@example.com"
│       ├── ownerUid: "firebase_auth_uid"
│       ├── businessName: "My Store"
│       ├── businessPhone: "9876543210"
│       ├── createdAt: timestamp
│       ├── updatedAt: timestamp
│       │
│       ├── Products (subcollection)
│       │   └── {productId} (documents)
│       │
│       ├── categories (subcollection)
│       │   └── {categoryId} (documents)
│       │
│       ├── customers (subcollection)
│       │   └── {customerId} (documents)
│       │
│       ├── sales (subcollection)
│       │   └── {saleId} (documents)
│       │
│       ├── credits (subcollection)
│       │   └── {creditId} (documents)
│       │
│       ├── creditNotes (subcollection)
│       │   └── {creditNoteId} (documents)
│       │
│       ├── purchaseCreditNotes (subcollection)
│       │   └── {purchaseCreditNoteId} (documents)
│       │
│       ├── stockPurchases (subcollection)
│       │   └── {purchaseId} (documents)
│       │
│       ├── expenses (subcollection)
│       │   └── {expenseId} (documents)
│       │
│       ├── expenseCategories (subcollection)
│       │   └── {categoryId} (documents)
│       │
│       ├── otherExpenses (subcollection)
│       │   └── {expenseId} (documents)
│       │
│       ├── quotations (subcollection)
│       │   └── {quotationId} (documents)
│       │
│       ├── savedOrders (subcollection)
│       │   └── {orderId} (documents)
│       │
│       └── suppliers (subcollection)
│           └── {supplierId} (documents)
│
└── users (collection)
    └── {userId} (document - using Firebase Auth UID)
        ├── uid: "firebase_auth_uid"
        ├── email: "user@example.com"
        ├── name: "User Name"
        ├── phone: "1234567890"
        ├── storeId: 100001  # Links user to their store
        ├── role: "owner" | "staff" | "admin"
        ├── permissions: { ... }
        ├── createdAt: timestamp
        └── updatedAt: timestamp
```

## Store ID Generation
- Store IDs are sequential integers starting from 100001
- Format: 100001, 100002, 100003, etc.
- When a new business registers, the system fetches the highest existing storeId and adds 1

## FirestoreService Usage

### Import the Service
```dart
import 'package:maxbillup/utils/firestore_service.dart';
```

### Common Operations

#### 1. Get a Collection Stream
```dart
final stream = await FirestoreService().getCollectionStream('Products');
StreamBuilder<QuerySnapshot>(
  stream: stream,
  builder: (context, snapshot) {
    // Handle data
  },
);
```

#### 2. Add a Document
```dart
await FirestoreService().addDocument('Products', {
  'itemName': 'Product Name',
  'price': 100.0,
  'createdAt': FieldValue.serverTimestamp(),
});
```

#### 3. Update a Document
```dart
await FirestoreService().updateDocument('Products', productId, {
  'price': 150.0,
  'updatedAt': FieldValue.serverTimestamp(),
});
```

#### 4. Get a Document
```dart
final doc = await FirestoreService().getDocument('Products', productId);
if (doc.exists) {
  final data = doc.data() as Map<String, dynamic>;
  // Use data
}
```

#### 5. Delete a Document
```dart
await FirestoreService().deleteDocument('Products', productId);
```

#### 6. Query with Filters
```dart
final collection = await FirestoreService().getStoreCollection('sales');
final query = collection
    .where('timestamp', isGreaterThan: startDate)
    .where('timestamp', isLessThan: endDate);
final snapshot = await query.get();
```

#### 7. Direct Collection Access (for users/store)
```dart
// Access users collection (not store-scoped)
final userDoc = await FirestoreService().usersCollection.doc(uid).get();

// Access store collection
final storeDoc = await FirestoreService().storeCollection.doc(storeId).get();
```

## Migration from Old Structure

### Old Structure (Root Collections)
```
Firestore
├── Products (collection)
├── categories (collection)
├── customers (collection)
├── sales (collection)
└── users (collection)
```

### New Structure (Store-Scoped)
```
Firestore
├── store (collection)
│   └── 100001 (document)
│       ├── Products (subcollection)
│       ├── categories (subcollection)
│       ├── customers (subcollection)
│       └── sales (subcollection)
└── users (collection)
```

## Files Updated

The following files have been updated to use the store-scoped structure:

### Stock Management
- ✅ `lib/Stocks/Products.dart`
- ✅ `lib/Stocks/AddProduct.dart`
- ✅ `lib/Stocks/Category.dart`
- ✅ `lib/Stocks/StockPurchase.dart`
- ✅ `lib/Stocks/Expenses.dart`
- ✅ `lib/Stocks/OtherExpenses.dart`
- ✅ `lib/Stocks/ExpenseCategories.dart`

### Sales
- ✅ `lib/Sales/Bill.dart`
- ⏳ `lib/Sales/saleall.dart` (needs update)
- ⏳ `lib/Sales/QuickSale.dart` (needs update)
- ⏳ `lib/Sales/Quotation.dart` (needs update)

### Menu
- ⏳ `lib/Menu/Menu.dart` (needs update)
- ⏳ `lib/Menu/CustomerManagement.dart` (needs update)

### Reports
- ⏳ `lib/Reports/Reports.dart` (needs update)

### Settings
- ✅ `lib/Settings/StaffManagement.dart`

## Benefits

1. **Data Isolation**: Each store's data is completely isolated
2. **Scalability**: Better performance as each store queries only its own data
3. **Multi-tenancy**: Easy to manage multiple stores in one Firebase project
4. **Security**: Firestore security rules can easily restrict access per store
5. **Clean Structure**: Clear hierarchy and organization

## Security Rules Example

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own user document
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
    
    // Store owners can read their store
    match /store/{storeId} {
      allow read: if request.auth != null && 
                     get(/databases/$(database)/documents/users/$(request.auth.uid)).data.storeId == int(storeId);
      
      // Store subcollections - only accessible by users of that store
      match /{subcollection}/{document=**} {
        allow read, write: if request.auth != null && 
                              get(/databases/$(database)/documents/users/$(request.auth.uid)).data.storeId == int(storeId);
      }
    }
  }
}
```

## Notes

- The `FirestoreService` automatically caches the storeId for performance
- Call `FirestoreService().clearCache()` on logout to clear cached storeId
- All store-scoped operations require a valid storeId from the logged-in user
- Staff members inherit the storeId from their creator (owner)

## Next Steps

1. Update remaining files to use `FirestoreService()`
2. Implement Firestore security rules
3. Create data migration script for existing users
4. Test all features with the new structure

