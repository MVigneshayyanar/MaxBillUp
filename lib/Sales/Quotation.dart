import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/Sales/QuotationPreview.dart';
import 'dart:math';
import 'package:maxbillup/utils/firestore_service.dart';

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

  @override
  void initState() {
    super.initState();
    _uid = widget.uid;
  }

  @override
  void dispose() {
    _cashDiscountController.dispose();
    _percentageController.dispose();
    super.dispose();
  }

  double get _discountAmount {
    if (_isBillWise) {
      if (_cashDiscountAmount > 0) {
        return _cashDiscountAmount;
      } else if (_percentageDiscount > 0) {
        return widget.totalAmount * (_percentageDiscount / 100);
      }
    }
    return 0.0;
  }

  double get _newTotal => widget.totalAmount - _discountAmount;

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
        'items': widget.cartItems.map((item) => {
          'productId': item.productId,
          'name': item.name,
          'price': item.price,
          'quantity': item.quantity,
          'total': item.total,
        }).toList(),
        'subtotal': widget.totalAmount,
        'discount': _discountAmount,
        'total': _newTotal,
        'discountType': _cashDiscountAmount > 0 ? 'cash' : _percentageDiscount > 0 ? 'percentage' : 'none',
        'discountValue': _cashDiscountAmount > 0 ? _cashDiscountAmount : _percentageDiscount,
        'customerPhone': _selectedCustomerPhone,
        'customerName': _selectedCustomerName,
        'customerGST': _selectedCustomerGST,
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String(),
        'staffId': widget.uid,
        'staffName': staffName ?? widget.userEmail ?? 'Unknown Staff',
        'status': 'active',
      };

      // Save quotation to Firestore
      await FirestoreService().addDocument('quotations', quotationData);

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        // Navigate to Quotation Preview
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
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
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data()?['name'] as String?;
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
      backgroundColor: const Color(0xFF1565C0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
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
                  color: const Color(0xFF1E88E5),
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
                    const SizedBox(height: 24),

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
                hintText: 'Search customer',
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

