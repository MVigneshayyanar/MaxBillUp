// common_widgets.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/Colors.dart';
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
    VoidCallback? onCustomer, // New: Add customer button callback
    String? customerName, // New: Show customer name if selected
    bool isQuotationMode = false,
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
          // Customer button - show if callback provided
          if (onCustomer != null) ...[
            _buildCustomerButton(
              onCustomer,
              customerName,
            ),
            const SizedBox(width: 12),
          ],
          const Spacer(),
          IntrinsicWidth(
            child: GestureDetector(
              onTap: () {
                if (isQuotationMode && onQuotation != null) {
                  onQuotation();
                } else {
                  onBill();
                }
              },
              child: Container(
                height: 64, // ✅ height stays fixed
                padding: const EdgeInsets.symmetric(horizontal: 24), // ✅ width grows
                decoration: BoxDecoration(
                  color: const Color(0xFF2F7CF6),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2F7CF6).withAlpha((0.3 * 255).toInt()),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      totalBill.toStringAsFixed(0),
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isQuotationMode ? 'Quotation' : context.tr('bill'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )

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
              color: Colors.black.withAlpha((0.1 * 255).toInt()),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xFF2F7CF6), size: 26),
      ),
    );
  }

  static Widget _buildCustomerButton(VoidCallback onTap, String? customerName) {
    final hasCustomer = customerName != null && customerName.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: EdgeInsets.symmetric(horizontal: hasCustomer ? 12 : 0),
        constraints: BoxConstraints(
          minWidth: 56,
          maxWidth: hasCustomer ? 150 : 56,
        ),
        decoration: BoxDecoration(
          color: hasCustomer ? const Color(0xFF2F7CF6).withAlpha((0.1 * 255).toInt()) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasCustomer ? const Color(0xFF2F7CF6) : const Color(0xFF2F7CF6).withAlpha((0.5 * 255).toInt()),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.1 * 255).toInt()),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasCustomer ? Icons.person : Icons.person_add_outlined,
              color: const Color(0xFF2F7CF6),
              size: 26,
            ),
            if (hasCustomer) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  customerName,
                  style: const TextStyle(
                    color: Color(0xFF2F7CF6),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
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

  // Customer Selection Dialog
  static void showCustomerSelectionDialog({
    required BuildContext context,
    required Function(String phone, String name, String? gst) onCustomerSelected,
  }) {
    final searchController = TextEditingController();
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              height: 600,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Select Customer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: context.tr('search'),
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onChanged: (value) {
                            setDialogState(() => searchQuery = value.toLowerCase());
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showAddCustomerDialog(context, onCustomerSelected);
                        },
                        icon: const Icon(Icons.person_add, color: kPrimaryColor),
                        style: IconButton.styleFrom(backgroundColor: kPrimaryColor.withAlpha((0.1 * 255).toInt())),
                        tooltip: 'Add Customer',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: FutureBuilder<Stream<QuerySnapshot>>(
                      future: FirestoreService().getCollectionStream('customers'),
                      builder: (context, streamSnapshot) {
                        if (!streamSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                        return StreamBuilder<QuerySnapshot>(
                          stream: streamSnapshot.data,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const Center(child: Text('No customers'));
                            final customers = snapshot.data!.docs.where((doc) {
                              if (searchQuery.isEmpty) return true;
                              final data = doc.data() as Map<String, dynamic>;
                              final name = (data['name'] ?? '').toString().toLowerCase();
                              final phone = (data['phone'] ?? '').toString().toLowerCase();
                              final gst = (data['gst'] ?? '').toString().toLowerCase();
                              return name.contains(searchQuery) || phone.contains(searchQuery) || gst.contains(searchQuery);
                            }).toList();

                            return ListView.separated(
                              itemCount: customers.length,
                              separatorBuilder: (ctx, i) => const Divider(),
                              itemBuilder: (context, index) {
                                final data = customers[index].data() as Map<String, dynamic>;
                                return ListTile(
                                  onTap: () {
                                    onCustomerSelected(data['phone'], data['name'], data['gst']);
                                    Navigator.pop(ctx);
                                  },
                                  title: Text(data['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(data['phone'] ?? ''),
                                  trailing: Text(
                                    'Bal: ${(data['balance'] ?? 0).toStringAsFixed(2)}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: (data['balance'] ?? 0) > 0 ? Colors.red : Colors.green
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static void _showAddCustomerDialog(
    BuildContext context,
    Function(String phone, String name, String? gst) onCustomerSelected,
  ) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final gstCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('New Customer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: gstCtrl,
                decoration: InputDecoration(
                  labelText: 'GST (Optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(context.tr('cancel')),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;
                      try {
                        await FirestoreService().setDocument('customers', phoneCtrl.text.trim(), {
                          'name': nameCtrl.text.trim(),
                          'phone': phoneCtrl.text.trim(),
                          'gst': gstCtrl.text.trim().isEmpty ? null : gstCtrl.text.trim(),
                          'balance': 0.0,
                          'totalSales': 0.0,
                          'timestamp': FieldValue.serverTimestamp(),
                          'lastUpdated': FieldValue.serverTimestamp(),
                        });
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          onCustomerSelected(phoneCtrl.text.trim(), nameCtrl.text.trim(), gstCtrl.text.trim());
                        }
                      } catch (e) {
                        showSnackBar(context, 'Error adding customer: $e', bgColor: Colors.red);
                      }
                    },
                    child: Text(context.tr('add'), style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

