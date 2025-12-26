// common_widgets.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';

class CommonWidgets {
  // Show snackbar message
  static void showSnackBar(BuildContext context, String message, {Color? bgColor}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bgColor ?? const Color(0xFF2F7CF6),
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
    VoidCallback? onPrint,
    bool isQuotationMode = false, // New parameter for quotation mode
  }) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Only show save order button if not in quotation mode
          if (!isQuotationMode) ...[
            _buildIconButton(
              Icons.bookmark_border,
              onSaveOrder,
            ),
            const SizedBox(width: 12),
          ],
          // Show quotation icon button only if not in quotation mode and onQuotation is provided
          if (!isQuotationMode && onQuotation != null) ...[
            _buildIconButton(
              Icons.description_outlined,
              onQuotation,
            ),
            const SizedBox(width: 12),
          ],
          // Show print button if onPrint is provided
          if (onPrint != null) ...[
            _buildIconButton(
              Icons.print_outlined,
              onPrint,
            ),
            const SizedBox(width: 12),
          ],
          const Spacer(),
          GestureDetector(
            onTap: () {
              // In quotation mode, use onQuotation if provided, otherwise onBill
              // In normal mode, use onBill
              if (isQuotationMode && onQuotation != null) {
                onQuotation();
              } else {
                onBill();
              }
            },
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: const Color(0xFF2F7CF6),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2F7CF6).withOpacity(0.3),
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
                  Text(
                    isQuotationMode ? 'Quotation' : context.tr('bill'),
                    style: const TextStyle(
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
          border: Border.all(color: const Color(0xFF2F7CF6), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xFF2F7CF6), size: 26),
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
      showSnackBar(context, context.tr('cart_is_empty'), bgColor: const Color(0xFFFF9800));
      return;
    }

    final phoneCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(context.tr('save_order')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: context.tr('customer_phone_number'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.phone),
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
                  decoration: InputDecoration(
                    labelText: context.tr('customer_name'),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                final phone = phoneCtrl.text.trim();
                final name = nameCtrl.text.trim();

                if (phone.isEmpty || name.isEmpty) {
                  showSnackBar(context, context.tr('enter_phone_and_name'),
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
                backgroundColor: const Color(0xFF2F7CF6),
              ),
              child: Text(context.tr('save_order')),
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
        showSnackBar(context, context.tr('order_saved_success'),
            bgColor: const Color(0xFF4CAF50));
      }
    } catch (e) {
      if (context.mounted) {
        showSnackBar(context, context.tr('error_saving_order').replaceFirst('{0}', e.toString()),
            bgColor: const Color(0xFFFF5252));
      }
    }
  }
}