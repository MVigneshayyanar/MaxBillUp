import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/utils/translation_helper.dart';

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

