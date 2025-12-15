import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/Sales/QuotationPreview.dart';
import 'dart:math';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';


class QuotationPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final List<CartItem> cartItems;
  final double totalAmount;

  const QuotationPage({
    super.key,
    required this.uid,
    this.userEmail,
    required this.cartItems,
    required this.totalAmount,
  });

  @override
  State<QuotationPage> createState() => _QuotationPageState();
}

class _QuotationPageState extends State<QuotationPage> {
  late String _uid;
  String? _selectedCustomerPhone;
  String? _selectedCustomerName;
  String? _selectedCustomerGST;

  bool _isBillWise = true; // true = Bill Wise, false = Item Wise
  double _cashDiscountAmount = 0.0;
  double _percentageDiscount = 0.0;

  final TextEditingController _cashDiscountController = TextEditingController();
  final TextEditingController _percentageController = TextEditingController();

  // Item-wise discount controllers and values
  late List<TextEditingController> _itemDiscountControllers;
  late List<double> _itemDiscounts; // Stores discount amount for each item

  @override
  void initState() {
    super.initState();
    _uid = widget.uid;
    // Initialize item-wise discount controllers
    _itemDiscountControllers = List.generate(
      widget.cartItems.length,
      (_) => TextEditingController(),
    );
    _itemDiscounts = List.filled(widget.cartItems.length, 0.0);
  }

  @override
  void dispose() {
    _cashDiscountController.dispose();
    _percentageController.dispose();
    // Dispose item-wise discount controllers
    for (var controller in _itemDiscountControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  double get _discountAmount {
    if (_isBillWise) {
      if (_cashDiscountAmount > 0) {
        return _cashDiscountAmount;
      } else if (_percentageDiscount > 0) {
        return widget.totalAmount * (_percentageDiscount / 100);
      }
    } else {
      // Item-wise discount: sum of all item discounts
      return _itemDiscounts.fold(0.0, (sum, discount) => sum + discount);
    }
    return 0.0;
  }

  double get _newTotal => widget.totalAmount - _discountAmount;

  // Get item total after discount
  double _getItemTotalAfterDiscount(int index) {
    final item = widget.cartItems[index];
    return item.total - _itemDiscounts[index];
  }

  // Update item discount
  void _updateItemDiscount(int index, String value) {
    setState(() {
      final discount = double.tryParse(value) ?? 0.0;
      final maxDiscount = widget.cartItems[index].total;
      _itemDiscounts[index] = discount.clamp(0.0, maxDiscount);
    });
  }

  void _showCustomerDialog() {
    showDialog(
      context: context,
      builder: (context) => _CustomerSelectionDialog(
        uid: _uid,
        onCustomerSelected: (phone, name, gst) {
          setState(() {
            _selectedCustomerPhone = phone;
            _selectedCustomerName = name;
            _selectedCustomerGST = gst;
          });
        },
      ),
    );
  }

  void _updateCashDiscount() {
    setState(() {
      _cashDiscountAmount = double.tryParse(_cashDiscountController.text) ?? 0.0;
      if (_cashDiscountAmount > 0) {
        _percentageDiscount = 0.0;
        _percentageController.clear();
      }
    });
  }

  void _updatePercentageDiscount() {
    setState(() {
      _percentageDiscount = double.tryParse(_percentageController.text) ?? 0.0;
      if (_percentageDiscount > 0) {
        _cashDiscountAmount = 0.0;
        _cashDiscountController.clear();
      }
    });
  }

  Future<void> _generateQuotation() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Generate quotation number
      final random = Random();
      final quotationNumber = (100000 + random.nextInt(900000)).toString();

      // Fetch staff name
      final staffName = await _fetchStaffName(widget.uid);

      // Prepare quotation data
      final quotationData = {
        'quotationNumber': quotationNumber,
        'items': widget.cartItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return {
            'productId': item.productId,
            'name': item.name,
            'price': item.price,
            'quantity': item.quantity,
            'total': item.total,
            'discount': _isBillWise ? 0.0 : _itemDiscounts[index],
            'finalTotal': _isBillWise ? item.total : _getItemTotalAfterDiscount(index),
          };
        }).toList(),
        'subtotal': widget.totalAmount,
        'discount': _discountAmount,
        'total': _newTotal,
        'discountMode': _isBillWise ? 'billWise' : 'itemWise',
        'discountType': _isBillWise
            ? (_cashDiscountAmount > 0 ? 'cash' : _percentageDiscount > 0 ? 'percentage' : 'none')
            : 'itemWise',
        'discountValue': _isBillWise
            ? (_cashDiscountAmount > 0 ? _cashDiscountAmount : _percentageDiscount)
            : _itemDiscounts,
        'customerPhone': _selectedCustomerPhone,
        'customerName': _selectedCustomerName,
        'customerGST': _selectedCustomerGST,
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String(),
        'staffId': widget.uid,
        'staffName': staffName ?? widget.userEmail ?? 'Unknown Staff',
        'status': 'active',
      };

      // Save quotation to Firestore and capture document reference
      final docRef = await FirestoreService().addDocument('quotations', quotationData);

      // write the generated doc id back into the document as `quotationId` for easier lookups
      try {
        await FirestoreService().updateDocument('quotations', docRef.id, {'quotationId': docRef.id});
      } catch (e) {
        // ignore: avoid_print
        print('Unable to write quotationId back to doc: $e');
      }

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        // Navigate to Quotation Preview and pass quotation document id so it can be updated when billed
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => QuotationPreviewPage(
              uid: widget.uid,
              userEmail: widget.userEmail,
              quotationNumber: quotationNumber,
              items: widget.cartItems,
              subtotal: widget.totalAmount,
              discount: _discountAmount,
              total: _newTotal,
              customerName: _selectedCustomerName,
              customerPhone: _selectedCustomerPhone,
              staffName: staffName,
              quotationDocId: docRef.id, // <-- pass the created doc id
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating quotation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _fetchStaffName(String uid) async {
    try {
      final doc = await FirestoreService().getDocument('users', uid);
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        return data?['name'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching staff name: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      backgroundColor: const Color(0xFF2196F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(), // Back button works
        ),
        title: const Text(
          'New Quotation',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Customer Details Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: GestureDetector(
              onTap: _showCustomerDialog,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_add, color: Colors.white70, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedCustomerName ?? 'Add Customer Details',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main Content
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add Discount',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Bill Wise / Item Wise Toggle
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isBillWise = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: _isBillWise ? const Color(0xFF2196F3) : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Bill Wise',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _isBillWise ? Colors.white : Colors.grey[600],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isBillWise = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: !_isBillWise ? const Color(0xFF2196F3) : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Item Wise',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: !_isBillWise ? Colors.white : Colors.grey[600],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Show different UI based on discount mode
                    if (_isBillWise) ...[
                      // Bill Wise Discount UI
                      // Total Amount
                      const Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Rs ${widget.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Cash Discount
                      const Text(
                        'Cash Discount',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _cashDiscountController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _updateCashDiscount(),
                        decoration: InputDecoration(
                          hintText: 'Amount',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // OR Divider
                      const Center(
                        child: Text(
                          'or',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Percentage Discount
                      const Text(
                        'Percentage Discount',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _percentageController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _updatePercentageDiscount(),
                        decoration: InputDecoration(
                          hintText: 'Percentage',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ] else ...[
                      // Item Wise Discount UI
                      const Text(
                        'Item Discounts',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // List of items with discount inputs
                      ...widget.cartItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '${item.quantity} x Rs ${item.price.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Text('Total: ', style: TextStyle(fontSize: 13)),
                                        Text(
                                          'Rs ${item.total.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    height: 40,
                                    child: TextField(
                                      controller: _itemDiscountControllers[index],
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) => _updateItemDiscount(index, value),
                                      textAlign: TextAlign.center,
                                      decoration: InputDecoration(
                                        hintText: 'Discount',
                                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Colors.grey[300]!),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Colors.grey[300]!),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: Color(0xFF2196F3)),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      ),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                              if (_itemDiscounts[index] > 0) ...[
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      'After Discount: ',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                    Text(
                                      'Rs ${_getItemTotalAfterDiscount(index).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF4CAF50),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 24),

                    // Discount Summary
                    if (_discountAmount > 0) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _isBillWise ? 'Bill Discount' : 'Total Item Discounts',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '- Rs ${_discountAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // New Total
                    const Text(
                      'New Total',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rs ${_newTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Update Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _generateQuotation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Update',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Customer Selection Dialog
// - Already supports search and import from contacts (Firestore customers collection)
// - List updates as you type in the search box
class _CustomerSelectionDialog extends StatefulWidget {
  final String uid;
  final Function(String phone, String name, String? gst) onCustomerSelected;

  const _CustomerSelectionDialog({
    required this.uid,
    required this.onCustomerSelected,
  });

  @override
  State<_CustomerSelectionDialog> createState() => _CustomerSelectionDialogState();
}

class _CustomerSelectionDialogState extends State<_CustomerSelectionDialog> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Customer',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: context.tr('search'),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<CollectionReference>(
                future: FirestoreService().getStoreCollection('customers'),
                builder: (context, collectionSnapshot) {
                  if (!collectionSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: collectionSnapshot.data!.orderBy('name').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('No customers found'));
                      }

                      final customers = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['name'] ?? '').toString().toLowerCase();
                        final phone = (data['phone'] ?? '').toString().toLowerCase();
                        return name.contains(_searchQuery) || phone.contains(_searchQuery);
                      }).toList();

                      return ListView.builder(
                        itemCount: customers.length,
                        itemBuilder: (context, index) {
                          final data = customers[index].data() as Map<String, dynamic>;
                          final name = data['name'] ?? 'Unknown';
                          final phone = data['phone'] ?? '';
                          final gst = data['gst'];

                          return ListTile(
                            title: Text(name),
                            subtitle: Text(phone),
                            onTap: () {
                              widget.onCustomerSelected(phone, name, gst);
                              Navigator.pop(context);
                            },
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
  }
}
