import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:heroicons/heroicons.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/utils/plan_permission_helper.dart';
import 'package:maxbillup/utils/amount_formatter.dart';
import 'package:maxbillup/utils/responsive_helper.dart';
import 'package:intl/intl.dart';

class CommonWidgets {
  // Show snackbar message (Standardized)
  static void showSnackBar(BuildContext context, String message, {Color? bgColor}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontWeight: FontWeight.w600, fontSize: R.sp(context, 13))),
        backgroundColor: bgColor ?? kPrimaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: R.radius(context, 12)),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  // Action buttons for bottom bar (Enterprise Flat Redesign)
  static Widget buildActionButtons({
    required BuildContext context,
    required VoidCallback onSaveOrder,
    required VoidCallback onBill,
    required double totalBill,
    VoidCallback? onQuotation,
    VoidCallback? onPrint,
    VoidCallback? onCustomer,
    String? customerName,
    String? savedOrderName,
    bool isQuotationMode = false,
    String currencySymbol = 'Rs ',
  }) {
    if (isQuotationMode) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      bottom: false, // Don't add extra safe area padding
      child: Container(
        decoration: const BoxDecoration(
          color: kWhite,
          border: Border(top: BorderSide(color: kGrey200, width: 1)),
        ),
        padding: EdgeInsets.fromLTRB(R.sp(context, 16), R.sp(context, 6), R.sp(context, 16), R.sp(context, 6)),
        child: Row(
          children: [
            // Save order button with order name display
            _buildActionIconButtonWithText(
              savedOrderName != null && savedOrderName.isNotEmpty
                  ? HeroIcons.bookmark
                  : HeroIcons.bookmark,
              onSaveOrder,
              savedOrderName != null && savedOrderName.isNotEmpty ? kOrange : kPrimaryColor,
              savedOrderName,
              context,
            ),
            SizedBox(width: R.sp(context, 10)),

            // Customer button
            if (onCustomer != null) ...[
              _buildActionIconButton(
                customerName != null && customerName.isNotEmpty ? HeroIcons.user : HeroIcons.userPlus,
                onCustomer,
                customerName != null && customerName.isNotEmpty ? kOrange : kPrimaryColor,
                context,
              ),
              SizedBox(width: R.sp(context, 10)),
            ],

            const Spacer(),

            // Main Bill button (Premium UI Upgrade)
            GestureDetector(
              onTap: onBill,
              child: Container(
                height: R.sp(context, 60),
                padding: EdgeInsets.symmetric(horizontal: R.sp(context, 20)),
                decoration: BoxDecoration(
                  color: kPrimaryColor,
                  borderRadius: R.radius(context, 16),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimaryColor.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HeroIcon(HeroIcons.banknotes, color: kWhite, size: R.sp(context, 18)),
                    SizedBox(width: R.sp(context, 10)),
                    Text(
                      "$currencySymbol${AmountFormatter.format(totalBill)}",
                      style: TextStyle(color: kWhite, fontSize: R.sp(context, 18), fontWeight: FontWeight.w900),
                    ),
                    SizedBox(width: R.sp(context, 10)),
                    Container(width: 1.5, height: R.sp(context, 20), color: kWhite.withOpacity(0.3)),
                    SizedBox(width: R.sp(context, 10)),
                    Text(
                      context.tr('Bill'),
                      style: TextStyle(color: kWhite, fontSize: R.sp(context, 18), fontWeight: FontWeight.w900, letterSpacing: 1.0),
                    ),
                    // const SizedBox(width: 10),

                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildActionIconButton(HeroIcons icon, VoidCallback onTap, Color color, BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: R.radius(context, 12),
      child: Container(
        height: R.sp(context, 50),
        width: R.sp(context, 50),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: R.radius(context, 12),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        ),
        child: HeroIcon(icon, color: color, size: R.sp(context, 22)),
      ),
    );
  }

  static Widget _buildActionIconButtonWithText(HeroIcons icon, VoidCallback onTap, Color color, String? text, BuildContext context) {
    if (text == null || text.isEmpty) {
      return _buildActionIconButton(icon, onTap, color, context);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: R.radius(context, 12),
      child: Container(
        height: R.sp(context, 50),
        padding: EdgeInsets.symmetric(horizontal: R.sp(context, 12)),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: R.radius(context, 12),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HeroIcon(icon, color: color, size: R.sp(context, 20)),
            SizedBox(width: R.sp(context, 8)),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: R.sp(context, 120)),
              child: Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: R.sp(context, 13),
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Save Order Dialog (Enterprise Flat)
  static void showSaveOrderDialog({
    required BuildContext context,
    required String uid,
    required List<CartItem> cartItems,
    required double totalBill,
    required void Function(String orderName, String? orderId) onSuccess,
    String? savedOrderId,
    String? savedOrderName,
    String? savedOrderPhone,
  }) {
    if (cartItems.isEmpty) {
      showSnackBar(context, context.tr('cart_is_empty'), bgColor: kOrange);
      return;
    }

    final orderNameCtrl = TextEditingController(text: savedOrderName ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kWhite,
        shape: RoundedRectangleBorder(borderRadius: R.radius(context, 16)),
        title: Text(savedOrderId != null ? 'Update Order' : 'Save Order',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: R.sp(context, 16), color: kBlack87)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              savedOrderId != null
                  ? 'Update the saved order with new items'
                  : 'Enter a name for this order',
              style: TextStyle(color: kBlack54, fontSize: R.sp(context, 13), fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: R.sp(context, 16)),
            _buildDialogField(
              controller: orderNameCtrl,
              label: 'Order Name',
              icon: HeroIcons.bookmark,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.w800, color: kBlack54)),
          ),
          ElevatedButton(
            onPressed: () async {
              final orderName = orderNameCtrl.text.trim();

              // Require order name
              if (orderName.isEmpty) {
                showSnackBar(ctx, 'Please provide an order name', bgColor: kErrorColor);
                return;
              }

              Navigator.pop(ctx);

              String? resultOrderId;
              if (savedOrderId != null) {
                // Update existing saved order
                await _updateOrderInFirebase(
                  orderId: savedOrderId,
                  uid: uid,
                  orderName: orderName,
                  cartItems: cartItems,
                  totalBill: totalBill,
                  context: context,
                );
                resultOrderId = savedOrderId; // Use the same orderId for updates
              } else {
                // Create new saved order and capture the returned orderId
                resultOrderId = await _saveOrderToFirebase(
                  uid: uid,
                  orderName: orderName,
                  cartItems: cartItems,
                  totalBill: totalBill,
                  context: context,
                );
              }
              onSuccess(orderName, resultOrderId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text(savedOrderId != null ? 'UPDATE ORDER' : 'SAVE ORDER',
                style: const TextStyle(fontWeight: FontWeight.w800, color: kWhite)),
          ),
        ],
      ),
    );
  }

  static Widget _buildDialogField({required TextEditingController controller, required String label, required HeroIcons icon, TextInputType? keyboardType, Function(String)? onChanged}) {
    return Builder(
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: kGreyBg,
          borderRadius: R.radius(context, 12),
          border: Border.all(color: kGrey200),
        ),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: TextStyle(fontSize: R.sp(context, 14), fontWeight: FontWeight.w600, color: kBlack87),
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Padding(
              padding: R.all(context, 12),
              child: HeroIcon(icon, color: kPrimaryColor, size: R.sp(context, 18)),
            ),
            labelStyle: TextStyle(color: kBlack54, fontSize: R.sp(context, 13)),
          ),
        ),
      ),
    );
  }

  static Future<String?> _fetchStaffName(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return doc.data()?['name'] as String?;
    } catch (e) { return null; }
  }

  static Future<String?> _saveOrderToFirebase({
    required String uid,
    required String orderName,
    required List<CartItem> cartItems,
    required double totalBill,
    required BuildContext context,
  }) async {
    try {
      final staffName = await _fetchStaffName(uid);

      final items = cartItems.map((item) => {
        'productId': item.productId,
        'name': item.name,
        'price': item.price,
        'quantity': item.quantity,
        'total': item.total,
        'taxName': item.taxName,
        'taxPercentage': item.taxPercentage,
        'taxType': item.taxType,
      }).toList();

      final docRef = await FirestoreService().addDocument('savedOrders', {
        'orderName': orderName,
        'items': items,
        'total': totalBill,
        'timestamp': FieldValue.serverTimestamp(),
        'staffId': uid,
        'staffName': staffName ?? 'Unknown Staff',
      });

      if (context.mounted) showSnackBar(context, 'Order saved successfully', bgColor: kGoogleGreen);
      return docRef.id; // Return the created document ID
    } catch (e) {
      if (context.mounted) showSnackBar(context, 'Error: ${e.toString()}', bgColor: kErrorColor);
      return null;
    }
  }

  static Future<void> _updateOrderInFirebase({
    required String orderId,
    required String uid,
    required String orderName,
    required List<CartItem> cartItems,
    required double totalBill,
    required BuildContext context,
  }) async {
    try {
      final staffName = await _fetchStaffName(uid);

      final items = cartItems.map((item) => {
        'productId': item.productId,
        'name': item.name,
        'price': item.price,
        'quantity': item.quantity,
        'total': item.total,
        'taxName': item.taxName,
        'taxPercentage': item.taxPercentage,
        'taxType': item.taxType,
      }).toList();

      await FirestoreService().updateDocument('savedOrders', orderId, {
        'orderName': orderName,
        'items': items,
        'total': totalBill,
        'timestamp': FieldValue.serverTimestamp(),
        'staffId': uid,
        'staffName': staffName ?? 'Unknown Staff',
      });

      if (context.mounted) showSnackBar(context, 'Order updated successfully', bgColor: kGoogleGreen);
    } catch (e) {
      if (context.mounted) showSnackBar(context, 'Error: ${e.toString()}', bgColor: kErrorColor);
    }
  }

  // Customer Selection Dialog (Remastered)
  static void showCustomerSelectionDialog({
    required BuildContext context,
    required Function(String phone, String name, String? gst) onCustomerSelected,
    String? selectedCustomerPhone,
  }) {
    final searchController = TextEditingController();
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            backgroundColor: kWhite,
            shape: RoundedRectangleBorder(borderRadius: R.radius(context, 20)),
            child: Container(
              height: R.dialogHeight(context, pct: 72),
              padding: R.all(context, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('SELECT CUSTOMER', style: TextStyle(fontSize: R.sp(context, 16), fontWeight: FontWeight.w900, color: kBlack87, letterSpacing: 0.5)),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const HeroIcon(HeroIcons.xMark, color: kBlack54)),
                    ],
                  ),
                  SizedBox(height: R.sp(context, 12)),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(color: kGreyBg, borderRadius: R.radius(context, 12), border: Border.all(color: kGrey200)),
                          child: TextField(
                            controller: searchController,
                            style: TextStyle(fontSize: R.sp(context, 14), fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              hintText: 'Search...',
                              prefixIcon: Padding(
                                padding: R.all(context, 12),
                                child: const HeroIcon(HeroIcons.magnifyingGlass, color: kPrimaryColor),
                              ),
                              
                              
                            ),
                            onChanged: (value) => setDialogState(() => searchQuery = value.toLowerCase()),
                          ),
                        ),
                      ),
                      SizedBox(width: R.sp(context, 10)),
                      _squareActionBtn(HeroIcons.userPlus, () { Navigator.pop(ctx); _showAddCustomerDialog(context, onCustomerSelected); }, kPrimaryColor, context),
                      SizedBox(width: R.sp(context, 8)),
                      _squareActionBtn(HeroIcons.phone, () { Navigator.pop(ctx); _importFromContacts(context, onCustomerSelected); }, kGoogleGreen, context),
                    ],
                  ),
                  SizedBox(height: R.sp(context, 12)),
                  if (selectedCustomerPhone != null && selectedCustomerPhone.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: R.sp(context, 10), horizontal: R.sp(context, 16)),
                      child: InkWell(
                        onTap: () { onCustomerSelected('', '', null); Navigator.pop(ctx); },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: R.sp(context, 10), horizontal: R.sp(context, 16)),
                          decoration: BoxDecoration(color: kErrorColor.withOpacity(0.08), borderRadius: R.radius(context, 8)),
                          child: Row(children: [const HeroIcon(HeroIcons.link, size: 16, color: kErrorColor), SizedBox(width: R.sp(context, 12)), Text('Remove Customer', style: TextStyle(color: kErrorColor, fontWeight: FontWeight.w800, fontSize: R.sp(context, 12)))]),
                        ),
                      ),
                    ),
                  Expanded(
                    child: FutureBuilder<Stream<QuerySnapshot>>(
                      future: FirestoreService().getCollectionStream('customers'),
                      builder: (context, streamSnapshot) {
                        if (!streamSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                        return StreamBuilder<QuerySnapshot>(
                          stream: streamSnapshot.data,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No customers found', style: TextStyle(color: kBlack54, fontWeight: FontWeight.w600)));

                            final customers = snapshot.data!.docs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final name = (data['name'] ?? '').toString().toLowerCase();
                              final phone = (data['phone'] ?? '').toString().toLowerCase();
                              return name.contains(searchQuery) || phone.contains(searchQuery);
                            }).toList();

                            return ListView.separated(
                              padding: EdgeInsets.only(top: R.sp(context, 10)),
                              itemCount: customers.length,
                              separatorBuilder: (ctx, i) => const Divider(height: 1, color: kGrey100),
                              itemBuilder: (context, index) {
                                final data = customers[index].data() as Map<String, dynamic>;
                                final phone = data['phone'] ?? '';
                                final isSelected = selectedCustomerPhone == phone;
                                final balance = (data['balance'] ?? 0.0) as num;
                                final rating = (data['rating'] ?? 0) as num;

                                return ListTile(
                                  onTap: () { onCustomerSelected(phone, data['name'] ?? 'Unknown', data['gst']); Navigator.pop(ctx); },
                                  contentPadding: EdgeInsets.symmetric(horizontal: R.sp(context, 8), vertical: R.sp(context, 4)),
                                  leading: CircleAvatar(
                                    backgroundColor: isSelected ? kPrimaryColor : kGreyBg,
                                    child: Text((data['name'] ?? 'U')[0].toUpperCase(), style: TextStyle(color: isSelected ? kWhite : kPrimaryColor, fontWeight: FontWeight.w900)),
                                  ),
                                  title: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(data['name'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.w700, fontSize: R.sp(context, 14)), overflow: TextOverflow.ellipsis),
                                      if (rating > 0) ...[
                                        SizedBox(height: R.sp(context, 2)),
                                        Row(
                                          children: List.generate(5, (i) => HeroIcon(
                                            HeroIcons.star,
                                            size: R.sp(context, 12),
                                            color: i < rating ? kOrange : kGrey300,
                                            style: i < rating ? HeroIconStyle.solid : HeroIconStyle.outline,
                                          )),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: EdgeInsets.only(top: R.sp(context, 4)),
                                    child: Text(phone, style: TextStyle(fontSize: R.sp(context, 11), color: kBlack54, fontWeight: FontWeight.w500)),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('${balance.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w900, color: balance > 0 ? kErrorColor : kGoogleGreen, fontSize: R.sp(context, 13))),
                                      Text('Balance', style: TextStyle(fontSize: R.sp(context, 8), fontWeight: FontWeight.w800, color: kBlack54)),
                                    ],
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

  static Widget _squareActionBtn(HeroIcons icon, VoidCallback onTap, Color color, BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: R.radius(context, 10),
      child: Container(
        height: R.sp(context, 48), width: R.sp(context, 48),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: R.radius(context, 10), border: Border.all(color: color.withOpacity(0.2))),
        child: HeroIcon(icon, color: color, size: R.sp(context, 20)),
      ),
    );
  }

  static void _showAddCustomerDialog(BuildContext context, Function(String phone, String name, String? gst) onCustomerSelected) {
    final phoneCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final gstCtrl = TextEditingController();
    final balanceCtrl = TextEditingController(text: '0');
    bool isLoading = false;
    bool customerExists = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: kWhite,
          shape: RoundedRectangleBorder(borderRadius: R.radius(context, 16)),
          title: Text('NEW CUSTOMER', style: TextStyle(fontSize: R.sp(context, 16), fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogField(
                  controller: phoneCtrl,
                  label: 'Phone Number',
                  icon: HeroIcons.phone,
                  keyboardType: TextInputType.phone,
                  onChanged: (value) async {
                    if (value.length >= 10) {
                      setDialogState(() => isLoading = true);
                      try {
                        final collection = await FirestoreService().getStoreCollection('customers');
                        final doc = await collection.doc(value).get();
                        if (doc.exists) {
                          final data = doc.data() as Map<String, dynamic>?;
                          nameCtrl.text = data?['name'] ?? '';
                          gstCtrl.text = data?['gst'] ?? '';
                          final balance = (data?['balance'] ?? 0.0) as num;
                          balanceCtrl.text = balance.toString();
                          setDialogState(() => customerExists = true);
                        } else {
                          setDialogState(() => customerExists = false);
                        }
                      } catch (e) {
                        debugPrint(e.toString());
                      }
                      setDialogState(() => isLoading = false);
                    }
                  },
                ),
                SizedBox(height: R.sp(context, 12)),
                if (isLoading)
                  Padding(
                    padding: R.all(context, 8),
                    child: const CircularProgressIndicator(strokeWidth: 3, color: kPrimaryColor),
                  )
                else ...[
                  if (customerExists)
                    Container(
                      padding: R.all(context, 8),
                      margin: EdgeInsets.only(bottom: R.sp(context, 12)),
                      decoration: BoxDecoration(
                        color: kOrange.withOpacity(0.1),
                        borderRadius: R.radius(context, 8),
                        border: Border.all(color: kOrange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          HeroIcon(HeroIcons.informationCircle, color: kOrange, size: R.sp(context, 18)),
                          SizedBox(width: R.sp(context, 8)),
                          Expanded(
                            child: Text(
                              'Customer exists! Fields auto-filled.',
                              style: TextStyle(color: kOrange, fontSize: R.sp(context, 11), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  _buildDialogField(controller: nameCtrl, label: 'Full Name', icon: HeroIcons.user),
                  SizedBox(height: R.sp(context, 12)),
                  _buildDialogField(controller: gstCtrl, label: 'GST Number (Optional)', icon: HeroIcons.documentText),
                  SizedBox(height: R.sp(context, 12)),
                  _buildDialogField(controller: balanceCtrl, label: 'Last Due Amount', icon: HeroIcons.wallet, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL", style: TextStyle(fontWeight: FontWeight.w800, color: kBlack54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () async {
                final phone = phoneCtrl.text.trim();
                final name = nameCtrl.text.trim();
                if (name.isEmpty || phone.isEmpty) return;
                final balance = double.tryParse(balanceCtrl.text) ?? 0.0;
                final newBalance = balance;

                await FirestoreService().setDocument('customers', phone, {
                  'name': name,
                  'phone': phone,
                  'gst': gstCtrl.text.trim().isEmpty ? null : gstCtrl.text.trim(),
                  'balance': newBalance,
                  'totalSales': customerExists ? FieldValue.increment(0) : newBalance,
                  'purchaseCount': customerExists ? FieldValue.increment(0) : 0,
                  'lastUpdated': FieldValue.serverTimestamp(),
                });

                // Only add credit entry if it's a new balance being added
                if (!customerExists && balance > 0) {
                  final credits = await FirestoreService().getStoreCollection('credits');
                  await credits.add({
                    'customerId': phone,
                    'customerName': name,
                    'amount': balance,
                    'type': 'add_credit',
                    'method': 'Manual',
                    'timestamp': FieldValue.serverTimestamp(),
                    'date': DateTime.now().toIso8601String(),
                    'note': 'Opening Balance',
                  });
                }

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  onCustomerSelected(phone, name, gstCtrl.text.trim().isEmpty ? null : gstCtrl.text.trim());
                }
              },
              child: Text(customerExists ? 'UPDATE CUSTOMER' : 'ADD CUSTOMER', style: const TextStyle(color: kWhite, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _importFromContacts(BuildContext context, Function(String phone, String name, String? gst) onCustomerSelected) async {
    final canImport = await PlanPermissionHelper.canImportContacts();
    if (!canImport) { PlanPermissionHelper.showUpgradeDialog(context, 'Import Contacts'); return; }

    if (!await FlutterContacts.requestPermission()) { showSnackBar(context, 'Contacts permission denied', bgColor: kErrorColor); return; }

    final contacts = await FlutterContacts.getContacts(withProperties: true);
    if (contacts.isEmpty) { showSnackBar(context, 'No contacts found', bgColor: kOrange); return; }

    showDialog(
      context: context,
      builder: (ctx) {
        List<Contact> filtered = contacts;
        final ctrl = TextEditingController();
        return StatefulBuilder(
          builder: (ctx, setDialogState) => Dialog(
            backgroundColor: kWhite,
            shape: RoundedRectangleBorder(borderRadius: R.radius(context, 20)),
            child: Container(
              height: R.dialogHeight(context, pct: 70), padding: R.all(context, 20),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('IMPORT CONTACT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: R.sp(context, 15))), IconButton(onPressed: () => Navigator.pop(ctx), icon: const HeroIcon(HeroIcons.xMark))]),
                  Container(decoration: BoxDecoration(color: kGreyBg, borderRadius: R.radius(context, 12)), child: TextField(controller: ctrl, decoration: InputDecoration(hintText: 'Search...', prefixIcon: Padding(
                    padding: R.all(context, 12),
                    child: const HeroIcon(HeroIcons.magnifyingGlass, color: kPrimaryColor),
                  )))),
                  SizedBox(height: R.sp(context, 12)),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: kGrey100),
                      itemBuilder: (ctx, i) {
                        final c = filtered[i];
                        final phone = c.phones.isNotEmpty ? c.phones.first.number.replaceAll(RegExp(r'[^0-9+]'), '') : '';
                        return ListTile(
                          title: Text(c.displayName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: R.sp(context, 14))),
                          subtitle: Text(phone, style: TextStyle(fontSize: R.sp(context, 12), color: kBlack54)),
                          onTap: phone.isNotEmpty ? () { Navigator.pop(ctx); _showAddCustomerDialogWithPrefill(context, onCustomerSelected, prefillName: c.displayName, prefillPhone: phone); } : null,
                          trailing: HeroIcon(HeroIcons.chevronRight, size: R.sp(context, 18), color: kGrey400),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static void _showAddCustomerDialogWithPrefill(BuildContext context, Function(String phone, String name, String? gst) onCustomerSelected, {String? prefillName, String? prefillPhone}) {
    final phoneCtrl = TextEditingController(text: prefillPhone);
    final nameCtrl = TextEditingController(text: prefillName);
    final gstCtrl = TextEditingController();
    final balanceCtrl = TextEditingController(text: '0');
    bool isLoading = false;
    bool customerExists = false;

    // Check if customer exists on initial load
    if (prefillPhone != null && prefillPhone.length >= 10) {
      Future.delayed(Duration.zero, () async {
        try {
          final collection = await FirestoreService().getStoreCollection('customers');
          final doc = await collection.doc(prefillPhone).get();
          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>?;
            nameCtrl.text = data?['name'] ?? prefillName ?? '';
            gstCtrl.text = data?['gst'] ?? '';
            final balance = (data?['balance'] ?? 0.0) as num;
            balanceCtrl.text = balance.toString();
            customerExists = true;
          }
        } catch (e) {
          debugPrint(e.toString());
        }
      });
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: kWhite,
          shape: RoundedRectangleBorder(borderRadius: R.radius(context, 16)),
          title: Text('VERIFY CUSTOMER', style: TextStyle(fontWeight: FontWeight.w900, fontSize: R.sp(context, 16))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(
                controller: phoneCtrl,
                label: 'Phone Number',
                icon: HeroIcons.phone,
                keyboardType: TextInputType.phone,
                onChanged: (value) async {
                  if (value.length >= 10) {
                    setDialogState(() => isLoading = true);
                    try {
                      final collection = await FirestoreService().getStoreCollection('customers');
                      final doc = await collection.doc(value).get();
                      if (doc.exists) {
                        final data = doc.data() as Map<String, dynamic>?;
                        nameCtrl.text = data?['name'] ?? '';
                        gstCtrl.text = data?['gst'] ?? '';
                        final balance = (data?['balance'] ?? 0.0) as num;
                        balanceCtrl.text = balance.toString();
                        setDialogState(() => customerExists = true);
                      } else {
                        setDialogState(() => customerExists = false);
                      }
                    } catch (e) {
                      debugPrint(e.toString());
                    }
                    setDialogState(() => isLoading = false);
                  }
                },
              ),
              const SizedBox(height: 12),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(strokeWidth: 3, color: kPrimaryColor),
                )
              else ...[
                if (customerExists)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: kOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kOrange.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        HeroIcon(HeroIcons.informationCircle, color: kOrange, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Customer exists! Fields auto-filled.',
                            style: TextStyle(color: kOrange, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                _buildDialogField(controller: nameCtrl, label: 'Name', icon: HeroIcons.user),
                const SizedBox(height: 12),
                _buildDialogField(controller: gstCtrl, label: 'GST (Optional)', icon: HeroIcons.documentText),
                const SizedBox(height: 12),
                _buildDialogField(controller: balanceCtrl, label: 'Last Due', icon: HeroIcons.wallet, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL", style: TextStyle(fontWeight: FontWeight.w800, color: kBlack54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () async {
                if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;
                final balance = double.tryParse(balanceCtrl.text) ?? 0.0;

                await FirestoreService().setDocument('customers', phoneCtrl.text.trim(), {
                  'name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'gst': gstCtrl.text.trim().isEmpty ? null : gstCtrl.text.trim(),
                  'balance': balance,
                  'totalSales': customerExists ? FieldValue.increment(0) : balance,
                  'purchaseCount': customerExists ? FieldValue.increment(0) : 0,
                  'lastUpdated': FieldValue.serverTimestamp(),
                });

                // Only add credit entry if it's a new balance being added
                if (!customerExists && balance > 0) {
                  final credits = await FirestoreService().getStoreCollection('credits');
                  await credits.add({
                    'customerId': phoneCtrl.text.trim(),
                    'customerName': nameCtrl.text.trim(),
                    'amount': balance,
                    'type': 'add_credit',
                    'method': 'Manual',
                    'timestamp': FieldValue.serverTimestamp(),
                    'date': DateTime.now().toIso8601String(),
                    'note': 'Opening Balance',
                  });
                }

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  onCustomerSelected(phoneCtrl.text.trim(), nameCtrl.text.trim(), gstCtrl.text.trim().isEmpty ? null : gstCtrl.text.trim());
                }
              },
              child: Text(customerExists ? 'UPDATE' : 'CONFIRM', style: const TextStyle(color: kWhite, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}
