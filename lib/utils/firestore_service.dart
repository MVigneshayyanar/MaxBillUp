import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firestore service that handles all store-scoped database operations
/// All collections (except 'store' and 'users') are nested under the user's store
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // REMOVED: String? _cachedStoreId;
  // We no longer store the ID in memory.

  /// Get the current user's store ID
  /// This will perform a network fetch every time it is called.
  Future<String?> getCurrentStoreId() async {
    final user = _auth.currentUser;
    final uid = user?.uid;
    final email = user?.email;
    if (uid == null) return null;

    try {
      // 1) Try users collection first (user doc is the preferred place to store mapping)
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        final storeIdFromUser = data?['storeId'];
        if (storeIdFromUser != null && storeIdFromUser.toString().isNotEmpty) {
          return storeIdFromUser.toString();
        }
        // also accept alternative field names if present
        final storeDocId = data?['storeDocId'];
        if (storeDocId != null && storeDocId.toString().isNotEmpty) {
          return storeDocId.toString();
        }
      }

      // 2) Fallback: search store collection by ownerUid
      final byUid = await _firestore
          .collection('store')
          .where('ownerUid', isEqualTo: uid)
          .limit(1)
          .get();
      if (byUid.docs.isNotEmpty) {
        final doc = byUid.docs.first;
        final data = doc.data();
        // prefer explicit storeId field, otherwise use document id
        final storeId = data['storeId'] ?? doc.id;
        return storeId?.toString();
      }

      // 3) Fallback: search store collection by ownerEmail (if email available)
      if (email != null && email.isNotEmpty) {
        final byEmail = await _firestore
            .collection('store')
            .where('ownerEmail', isEqualTo: email)
            .limit(1)
            .get();
        if (byEmail.docs.isNotEmpty) {
          final doc = byEmail.docs.first;
          final data = doc.data();
          final storeId = data['storeId'] ?? doc.id;
          return storeId?.toString();
        }
      }
    } catch (e, st) {
      print('Error getting store ID: $e\n$st');
    }

    return null;
  }

  /// Get the whole store document (document from `store` collection)
  /// Returns null if not found.
  Future<DocumentSnapshot?> getCurrentStoreDoc() async {
    final storeId = await getCurrentStoreId();
    if (storeId == null) return null;

    try {
      // Try to find a document with a storeId field equal to storeId
      final byField = await _firestore
          .collection('store')
          .where('storeId', isEqualTo: storeId)
          .limit(1)
          .get();
      if (byField.docs.isNotEmpty) return byField.docs.first;

      // Fallback: treat storeId as document id
      final doc = await _firestore.collection('store').doc(storeId).get();
      if (doc.exists) return doc;
    } catch (e) {
      print('Error getting store document: $e');
    }
    return null;
  }

  /// Associate the currently signed-in user with a storeId in `users` collection.
  Future<void> setUserStoreId(String storeId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('No authenticated user');

    await _firestore.collection('users').doc(uid).set({
      'storeId': storeId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // REMOVED: _cachedStoreId = storeId;
  }

  // REMOVED: void clearCache()

  /// Get reference to a store-scoped collection
  Future<CollectionReference> getStoreCollection(String collectionName) async {
    final storeId = await getCurrentStoreId();
    if (storeId == null) {
      throw Exception('No store ID found for current user');
    }
    return _firestore.collection('store').doc(storeId).collection(collectionName);
  }

  /// Get a stream of documents from a store-scoped collection
  Future<Stream<QuerySnapshot>> getCollectionStream(String collectionName) async {
    final collection = await getStoreCollection(collectionName);
    return collection.snapshots();
  }

  /// Get a single document from a store-scoped collection
  Future<DocumentSnapshot> getDocument(String collectionName, String docId) async {
    final collection = await getStoreCollection(collectionName);
    return collection.doc(docId).get();
  }

  /// Add a document to a store-scoped collection
  Future<DocumentReference> addDocument(String collectionName, Map<String, dynamic> data) async {
    final collection = await getStoreCollection(collectionName);
    return collection.add(data);
  }

  /// Update a document in a store-scoped collection
  Future<void> updateDocument(String collectionName, String docId, Map<String, dynamic> data) async {
    final collection = await getStoreCollection(collectionName);
    return collection.doc(docId).update(data);
  }

  /// Set a document in a store-scoped collection
  Future<void> setDocument(String collectionName, String docId, Map<String, dynamic> data) async {
    final collection = await getStoreCollection(collectionName);
    return collection.doc(docId).set(data);
  }

  /// Delete a document from a store-scoped collection
  Future<void> deleteDocument(String collectionName, String docId) async {
    final collection = await getStoreCollection(collectionName);
    return collection.doc(docId).delete();
  }

  /// Get a document reference from a store-scoped collection
  Future<DocumentReference> getDocumentReference(String collectionName, String docId) async {
    final collection = await getStoreCollection(collectionName);
    return collection.doc(docId);
  }

  /// Query a store-scoped collection
  Future<Query> query(String collectionName) async {
    final collection = await getStoreCollection(collectionName);
    return collection;
  }

  /// Batch write operations to a store-scoped collection
  Future<void> writeBatch(String collectionName, List<Map<String, dynamic>> operations) async {
    final collection = await getStoreCollection(collectionName);
    final batch = _firestore.batch();

    for (var op in operations) {
      final docId = op['docId'] as String;
      final data = op['data'] as Map<String, dynamic>;
      final type = op['type'] as String? ?? 'set'; // 'set', 'update', 'delete'

      final docRef = collection.doc(docId);
      switch (type) {
        case 'set':
          batch.set(docRef, data);
          break;
        case 'update':
          batch.update(docRef, data);
          break;
        case 'delete':
          batch.delete(docRef);
          break;
      }
    }

    await batch.commit();
  }

  /// Run a transaction on store-scoped data
  Future<T> runTransaction<T>(String collectionName, Future<T> Function(Transaction) transactionHandler) async {
    return _firestore.runTransaction((transaction) => transactionHandler(transaction));
  }

  /// Get all documents from a store-scoped collection
  Future<List<DocumentSnapshot>> getAllDocuments(String collectionName) async {
    final collection = await getStoreCollection(collectionName);
    final snapshot = await collection.get();
    return snapshot.docs;
  }

  /// Query documents with where clause
  Future<List<DocumentSnapshot>> queryDocuments(
      String collectionName,
      String field,
      dynamic value,
      ) async {
    final collection = await getStoreCollection(collectionName);
    final snapshot = await collection.where(field, isEqualTo: value).get();
    return snapshot.docs;
  }

  /// Query documents with multiple where clauses
  Future<List<DocumentSnapshot>> queryDocumentsMultiple(
      String collectionName,
      List<Map<String, dynamic>> whereConditions,
      ) async {
    var query = await getStoreCollection(collectionName) as Query;

    for (var condition in whereConditions) {
      final field = condition['field'] as String;
      final value = condition['value'];
      final operator = condition['operator'] as String? ?? 'isEqualTo';

      switch (operator) {
        case 'isEqualTo':
          query = query.where(field, isEqualTo: value);
          break;
        case 'isLessThan':
          query = query.where(field, isLessThan: value);
          break;
        case 'isLessThanOrEqualTo':
          query = query.where(field, isLessThanOrEqualTo: value);
          break;
        case 'isGreaterThan':
          query = query.where(field, isGreaterThan: value);
          break;
        case 'isGreaterThanOrEqualTo':
          query = query.where(field, isGreaterThanOrEqualTo: value);
          break;
        case 'arrayContains':
          query = query.where(field, arrayContains: value);
          break;
      }
    }

    final snapshot = await query.get();
    return snapshot.docs;
  }

  // Direct access to users collection (not store-scoped)
  CollectionReference get usersCollection => _firestore.collection('users');

  // Direct access to store collection (not store-scoped)
  CollectionReference get storeCollection => _firestore.collection('store');
}