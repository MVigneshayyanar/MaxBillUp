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

  String? _cachedStoreId;

  /// Get the current user's store ID
  Future<String?> getCurrentStoreId() async {
    // Return cached value if available
    if (_cachedStoreId != null) return _cachedStoreId;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final storeId = userDoc.data()?['storeId'];
        _cachedStoreId = storeId?.toString();
        return _cachedStoreId;
      }
    } catch (e) {
      print('Error getting store ID: $e');
    }
    return null;
  }

  /// Clear cached store ID (call on logout)
  void clearCache() {
    _cachedStoreId = null;
  }

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

  // Direct access to users collection (not store-scoped)
  CollectionReference get usersCollection => _firestore.collection('users');

  // Direct access to store collection (not store-scoped)
  CollectionReference get storeCollection => _firestore.collection('store');
}

