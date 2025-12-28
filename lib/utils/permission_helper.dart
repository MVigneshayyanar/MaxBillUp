import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/utils/firestore_service.dart';

// ==========================================
// PERMISSION HELPER
// ==========================================
class PermissionHelper {
  static Future<Map<String, dynamic>> getUserPermissions(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final role = data['role'] ?? 'Staff';

        // Admin has all permissions
        if (role.toLowerCase() == 'admin' || role.toLowerCase() == 'administrator') {
          return {
            'role': role,
            'permissions': _getAllPermissions(),
          };
        }

        return {
          'role': role,
          'permissions': data['permissions'] as Map<String, dynamic>? ?? {},
        };
      }
    } catch (e) {
      print('Error fetching permissions: $e');
    }

    return {
      'role': 'Staff',
      'permissions': {},
    };
  }

  static Map<String, bool> _getAllPermissions() {
    return {
      // Menu Items (7)
      'quotation': true,
      'billHistory': true,
      'creditNotes': true,
      'customerManagement': true,
      'expenses': true,
      'creditDetails': true,
      'staffManagement': true,

      // Report Items (14)
      'analytics': true,
      'daybook': true,
      'salesSummary': true,
      'salesReport': true,
      'itemSalesReport': true,
      'topCustomer': true,
      'stockReport': true,
      'lowStockProduct': true,
      'topProducts': true,
      'topCategory': true,
      'expensesReport': true,
      'taxReport': true,
      'hsnReport': true,
      'staffSalesReport': true,

      // Stock Items (2)
      'addProduct': true,
      'addCategory': true,

      // Bill Actions (3)
      'saleReturn': true,
      'cancelBill': true,
      'editBill': true,
    };
  }

  static Future<bool> hasPermission(String uid, String permission) async {
    final userData = await getUserPermissions(uid);
    final permissions = userData['permissions'] as Map<String, dynamic>;
    return permissions[permission] == true;
  }

  static Future<bool> isAdmin(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final role = (data['role'] ?? '').toString().toLowerCase();
        return role == 'admin' || role == 'administrator';
      }
    } catch (e) {
      print('Error checking admin status: $e');
    }
    return false;
  }

  static Future<bool> isActive(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['isActive'] ?? true;
      }
    } catch (e) {
      print('Error checking active status: $e');
    }
    return true;
  }

  // Check if current logged-in user is admin (without uid parameter)
  static Future<bool> isCurrentUserAdmin() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      // Get store ID
      final storeId = await FirestoreService().getCurrentStoreId();
      if (storeId == null) return false;

      // Check if user is the store owner
      final storeDoc = await FirebaseFirestore.instance
          .collection('store')  // FIXED: Changed from 'stores' to 'store'
          .doc(storeId)
          .get();

      if (!storeDoc.exists) return false;

      final storeData = storeDoc.data() as Map<String, dynamic>;
      final ownerId = storeData['ownerId'] as String?;

      return currentUser.uid == ownerId;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  // Get current user's staff permissions
  static Future<Map<String, dynamic>> getCurrentUserPermissions() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return {};

      // Get store ID
      final storeId = await FirestoreService().getCurrentStoreId();
      if (storeId == null) return {};

      // Get staff document
      final staffDoc = await FirebaseFirestore.instance
          .collection('store')  // FIXED: Changed from 'stores' to 'store'
          .doc(storeId)
          .collection('staff')
          .doc(currentUser.uid)
          .get();

      if (!staffDoc.exists) return {};

      final staffData = staffDoc.data() as Map<String, dynamic>;
      return staffData['permissions'] as Map<String, dynamic>? ?? {};
    } catch (e) {
      print('Error getting staff permissions: $e');
      return {};
    }
  }

  static Future<void> showPermissionDeniedDialog(context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock, color: Colors.red),
            SizedBox(width: 8),
            Text('Access Denied'),
          ],
        ),
        content: const Text(
          'You don\'t have permission to perform this action. Please contact your administrator.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('ok')),
          ),
        ],
      ),
    );
  }
}

