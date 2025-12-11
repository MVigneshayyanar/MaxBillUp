// common_widgets.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/utils/firestore_service.dart';

class CommonWidgets {
  // Show snackbar message
  static void showSnackBar(BuildContext context, String message, {Color? bgColor}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bgColor ?? const Color(0xFF00B8FF),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  // Action buttons for bottom bar
  static Widget buildActionButtons({
    required BuildContext context,
    required VoidCallback onSaveOrder,
    required VoidCallback onBill,
    required double totalBill,
    VoidCallback? onQuotation,
  }) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildIconButton(
            Icons.bookmark_border,
            onSaveOrder,
          ),
          const SizedBox(width: 12),
          if (onQuotation != null) ...[
            _buildIconButton(
              Icons.description_outlined,
              onQuotation,
            ),
            const SizedBox(width: 12),
          ],
          // _buildIconButton(
          //   Icons.print,
          //   () {
          //     showSnackBar(context, 'Print functionality coming soon');
          //   },
          // ),
          const Spacer(),
          GestureDetector(
            onTap: onBill,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2196F3).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    totalBill.toStringAsFixed(2),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Bill',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2196F3), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xFF2196F3), size: 26),
      ),
    );
  }

  // Save Order Dialog
  static void showSaveOrderDialog({
    required BuildContext context,
    required String uid,
    required List<CartItem> cartItems,
    required double totalBill,
    required VoidCallback onSuccess,
  }) {
    if (cartItems.isEmpty) {
      showSnackBar(context, 'Cart is empty!', bgColor: const Color(0xFFFF9800));
      return;
    }

    final phoneCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Save Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Customer Phone Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                onChanged: (value) async {
                  if (value.length >= 10) {
                    setDialogState(() => isLoading = true);

                    // Fetch customer data from store-scoped customers collection
                    try {
                      final collection = await FirestoreService().getStoreCollection('customers');
                      final doc = await collection.doc(value).get();

                      if (doc.exists) {
                        final data = doc.data() as Map<String, dynamic>?;
                        nameCtrl.text = data?['name'] ?? '';
                      }
                    } catch (e) {
                      debugPrint('Error fetching customer: $e');
                    }

                    setDialogState(() => isLoading = false);
                  }
                },
              ),
              const SizedBox(height: 16),
              if (isLoading)
                const CircularProgressIndicator()
              else
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Customer Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final phone = phoneCtrl.text.trim();
                final name = nameCtrl.text.trim();

                if (phone.isEmpty || name.isEmpty) {
                  showSnackBar(context, 'Please enter phone number and name',
                      bgColor: const Color(0xFFFF5252));
                  return;
                }

                Navigator.pop(ctx);
                await _saveOrderToFirebase(
                  uid: uid,
                  phone: phone,
                  name: name,
                  cartItems: cartItems,
                  totalBill: totalBill,
                  context: context,
                );
                onSuccess();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
              ),
              child: const Text('Save Order'),
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to fetch staff name
  static Future<String?> _fetchStaffName(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (doc.exists) {
        final data = doc.data();
        // Safely access the 'name' field and cast it.
        return data?['name'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching staff name: $e');
      return null;
    }
  }

  // UPDATED FUNCTION: Saves customer to store-scoped collection, adds staff name/ID, and adds business location
  static Future<void> _saveOrderToFirebase({
    required String uid,
    required String phone,
    required String name,
    required List<CartItem> cartItems,
    required double totalBill,
    required BuildContext context,
  }) async {
    try {
      // 1. Fetch Staff Name
      final staffName = await _fetchStaffName(uid);

      // 2. Save customer to the store-scoped 'customers' collection
      await FirestoreService().setDocument('customers', phone, {
        'name': name,
        'phone': phone,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // 3. Prepare items list
      final items = cartItems
          .map((item) => {
        'productId': item.productId,
        'name': item.name,
        'price': item.price,
        'quantity': item.quantity,
        'total': item.total,
      })
          .toList();

      // 4. Save order to 'savedOrders' collection
      await FirestoreService().addDocument('savedOrders', {
        'customerName': name,
        'customerPhone': phone,
        'items': items,
        'total': totalBill,
        'timestamp': FieldValue.serverTimestamp(),
        // ADDED STAFF ID AND NAME
        'staffId': uid,
        'staffName': staffName ?? 'Unknown Staff',
      });

      if (context.mounted) {
        showSnackBar(context, 'Order saved successfully!',
            bgColor: const Color(0xFF4CAF50));
      }
    } catch (e) {
      if (context.mounted) {
        showSnackBar(context, 'Error saving order: $e',
            bgColor: const Color(0xFFFF5252));
      }
    }
  }
}