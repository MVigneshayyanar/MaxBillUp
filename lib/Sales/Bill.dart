import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/Sales/Invoice.dart';
import 'dart:math';

class BillPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final List<CartItem> cartItems;
  final double totalAmount;

  const BillPage({
    super.key,
    required this.uid,
    this.userEmail,
    required this.cartItems,
    required this.totalAmount,
  });

  @override
  State<BillPage> createState() => _BillPageState();
}

class _BillPageState extends State<BillPage> {
  late String _uid;
  String? _selectedCustomerPhone;
  String? _selectedCustomerName;
  String? _selectedCustomerGST;
  double _discountAmount = 0.0;
  String _creditNote = '';

  @override
  void initState() {
    super.initState();
    _uid = widget.uid;
  }

  double get _finalAmount => widget.totalAmount - _discountAmount;

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

  void _showDiscountDialog() {
    final TextEditingController discountController = TextEditingController(
      text: _discountAmount.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Discount'),
        content: TextField(
          controller: discountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Discount Amount',
            border: OutlineInputBorder(),
            prefixText: '₹ ',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final discount = double.tryParse(discountController.text) ?? 0.0;
              setState(() {
                _discountAmount = discount;
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showCreditNoteDialog() {
    final TextEditingController noteController = TextEditingController(
      text: _creditNote,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Credit Note'),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Credit Note',
            border: OutlineInputBorder(),
            hintText: 'Enter note...',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _creditNote = noteController.text;
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _clearOrder() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Order'),
        content: const Text('Are you sure you want to clear this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to sale page
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: Color(0xFFFF5252)),
            ),
          ),
        ],
      ),
    );
  }

  void _proceedToPayment(String paymentMode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentPage(
          uid: _uid,
          userEmail: widget.userEmail,
          cartItems: widget.cartItems,
          totalAmount: _finalAmount,
          paymentMode: paymentMode,
          customerPhone: _selectedCustomerPhone,
          customerName: _selectedCustomerName,
          customerGST: _selectedCustomerGST,
          discountAmount: _discountAmount,
          creditNote: _creditNote,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        title: const Text(
          'Bill Details',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Add Customer Details Button
          GestureDetector(
            onTap: _showCustomerDialog,
            child: Container(
              margin: EdgeInsets.all(screenWidth * 0.04),
              padding: EdgeInsets.symmetric(
                vertical: screenHeight * 0.02,
                horizontal: screenWidth * 0.04,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF2196F3),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.person_add,
                    color: Color(0xFF2196F3),
                    size: 24,
                  ),
                  SizedBox(width: screenWidth * 0.02),
                  Text(
                    _selectedCustomerName ?? 'Add Customer Details',
                    style: TextStyle(
                      color: const Color(0xFF2196F3),
                      fontSize: screenWidth * 0.04,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Items List
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
              itemCount: widget.cartItems.length,
              itemBuilder: (context, index) {
                final item = widget.cartItems[index];
                return Container(
                  margin: EdgeInsets.only(bottom: screenHeight * 0.015),
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                              fontSize: screenWidth * 0.04,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '- 0.00',
                            style: TextStyle(
                              fontSize: screenWidth * 0.035,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenHeight * 0.008),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₹${item.price.toStringAsFixed(2)} × ${item.quantity}',
                            style: TextStyle(
                              fontSize: screenWidth * 0.035,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            '0.00',
                            style: TextStyle(
                              fontSize: screenWidth * 0.035,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenHeight * 0.008),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₹${item.total.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: screenWidth * 0.045,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '₹${item.total.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: screenWidth * 0.045,
                              color: const Color(0xFF2196F3),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Bottom Section
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Drag Handle
                Container(
                  margin: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
                  width: screenWidth * 0.1,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                  child: Column(
                    children: [
                      // Clear Order and Items Count
                      Row(
                        children: [
                          TextButton(
                            onPressed: _clearOrder,
                            child: const Text(
                              'Clear Order',
                              style: TextStyle(
                                color: Color(0xFFFF5252),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Items Count : ${widget.cartItems.length}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: screenHeight * 0.01),

                      // Amount Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Amount :',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Rs ${widget.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: screenHeight * 0.015),

                      // Add Discount Button
                      GestureDetector(
                        onTap: _showDiscountDialog,
                        child: Text(
                          _discountAmount > 0
                              ? 'Discount: ₹${_discountAmount.toStringAsFixed(2)}'
                              : 'Add Discount',
                          style: const TextStyle(
                            color: Color(0xFF2196F3),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.01),

                      // Add Credit Note Button
                      GestureDetector(
                        onTap: _showCreditNoteDialog,
                        child: Text(
                          _creditNote.isNotEmpty ? 'Note: $_creditNote' : 'Add Credit Note',
                          style: const TextStyle(
                            color: Color(0xFF2196F3),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.015),

                      // Divider
                      Divider(thickness: 1, color: Colors.grey[300]),

                      SizedBox(height: screenHeight * 0.015),

                      // Total Amount
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Amount :',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Rs ${_finalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 24,
                              color: Color(0xFF2196F3),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: screenHeight * 0.02),

                      // Payment Methods
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildPaymentButton(
                            icon: Icons.money,
                            label: 'Cash',
                            onTap: () => _proceedToPayment('Cash'),
                          ),
                          _buildPaymentButton(
                            icon: Icons.credit_card,
                            label: 'Online',
                            onTap: () => _proceedToPayment('Online'),
                          ),
                          _buildPaymentButton(
                            icon: Icons.access_time,
                            label: 'Set\nlater',
                            onTap: () => _proceedToPayment('Set later'),
                          ),
                          _buildPaymentButton(
                            icon: Icons.note_alt,
                            label: 'Credit',
                            onTap: () => _proceedToPayment('Credit'),
                          ),
                          _buildPaymentButton(
                            icon: Icons.call_split,
                            label: 'Split',
                            onTap: () => _proceedToPayment('Split'),
                          ),
                        ],
                      ),

                      SizedBox(height: screenHeight * 0.02),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF2196F3), width: 2),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF2196F3),
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddCustomerDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController gstController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: gstController,
              decoration: const InputDecoration(
                labelText: 'GST No (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              final gst = gstController.text.trim();

              if (name.isEmpty || phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter name and phone number'),
                    backgroundColor: Color(0xFFFF5252),
                  ),
                );
                return;
              }

              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.uid)
                    .collection('customers')
                    .doc(phone)
                    .set({
                  'name': name,
                  'phone': phone,
                  'gst': gst.isEmpty ? null : gst,
                  'balance': 0.0,
                  'lastUpdated': FieldValue.serverTimestamp(),
                });

                if (mounted) {
                  Navigator.pop(context);
                  widget.onCustomerSelected(phone, name, gst.isEmpty ? null : gst);
                  Navigator.pop(context);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error adding customer: $e'),
                      backgroundColor: const Color(0xFFFF5252),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: screenWidth * 0.9,
        height: screenHeight * 0.7,
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Existing Customer',
                  style: TextStyle(
                    fontSize: screenWidth * 0.05,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            SizedBox(height: screenHeight * 0.02),

            // Search Bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Contact/Name/GST No',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: screenWidth * 0.02),
                GestureDetector(
                  onTap: _showAddCustomerDialog,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.person_add,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: screenHeight * 0.02),

            // Customer List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.uid)
                    .collection('customers')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('No customers found'),
                    );
                  }

                  final customers = snapshot.data!.docs.where((doc) {
                    if (_searchQuery.isEmpty) return true;

                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final phone = (data['phone'] ?? '').toString().toLowerCase();
                    final gst = (data['gst'] ?? '').toString().toLowerCase();

                    return name.contains(_searchQuery) ||
                        phone.contains(_searchQuery) ||
                        gst.contains(_searchQuery);
                  }).toList();

                  if (customers.isEmpty) {
                    return const Center(
                      child: Text('No matching customers'),
                    );
                  }

                  return ListView.builder(
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final customerData = customers[index].data() as Map<String, dynamic>;
                      final name = customerData['name'] ?? 'Unknown';
                      final phone = customerData['phone'] ?? '';
                      final gst = customerData['gst'];
                      final balance = customerData['balance'] ?? 0.0;

                      return GestureDetector(
                        onTap: () {
                          widget.onCustomerSelected(phone, name, gst);
                          Navigator.pop(context);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2196F3),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Phone Number',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      phone,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (gst != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'GST No:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        gst,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Current Bal:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    balance.toStringAsFixed(2),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
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

// Payment Page
class PaymentPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final List<CartItem> cartItems;
  final double totalAmount;
  final String paymentMode;
  final String? customerPhone;
  final String? customerName;
  final String? customerGST;
  final double discountAmount;
  final String creditNote;

  const PaymentPage({
    super.key,
    required this.uid,
    this.userEmail,
    required this.cartItems,
    required this.totalAmount,
    required this.paymentMode,
    this.customerPhone,
    this.customerName,
    this.customerGST,
    required this.discountAmount,
    required this.creditNote,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  double _cashReceived = 0.0;
  final TextEditingController _displayController = TextEditingController(text: '0.0');

  double get _change => _cashReceived - widget.totalAmount;

  void _onNumberPressed(String value) {
    setState(() {
      if (_displayController.text == '0.0') {
        _displayController.text = value;
      } else {
        _displayController.text += value;
      }
      _cashReceived = double.tryParse(_displayController.text) ?? 0.0;
    });
  }

  void _onBackspace() {
    setState(() {
      if (_displayController.text.isNotEmpty) {
        _displayController.text = _displayController.text.substring(0, _displayController.text.length - 1);
        if (_displayController.text.isEmpty) {
          _displayController.text = '0.0';
        }
        _cashReceived = double.tryParse(_displayController.text) ?? 0.0;
      }
    });
  }

  Future<void> _completeSale() async {
    try {
      // Generate invoice number
      final random = Random();
      final invoiceNumber = (100000 + random.nextInt(900000)).toString();

      // Prepare sale data
      final saleData = {
        'invoiceNumber': invoiceNumber,
        'items': widget.cartItems.map((item) => {
          'productId': item.productId,
          'name': item.name,
          'price': item.price,
          'quantity': item.quantity,
          'total': item.total,
        }).toList(),
        'subtotal': widget.totalAmount + widget.discountAmount,
        'discount': widget.discountAmount,
        'total': widget.totalAmount,
        'paymentMode': widget.paymentMode,
        'cashReceived': _cashReceived,
        'change': _change,
        'customerPhone': widget.customerPhone,
        'customerName': widget.customerName,
        'customerGST': widget.customerGST,
        'creditNote': widget.creditNote,
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String(),
      };

      // Save sale to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('sales')
          .add(saleData);

      // Update product stock
      for (var item in widget.cartItems) {
        if (item.productId.isNotEmpty) {
          final productRef = FirebaseFirestore.instance
              .collection('users')
              .doc(widget.uid)
              .collection('Products')
              .doc(item.productId);

          await FirebaseFirestore.instance.runTransaction((transaction) async {
            final productDoc = await transaction.get(productRef);
            if (productDoc.exists) {
              final currentStock = productDoc.data()?['currentStock'] ?? 0.0;
              final newStock = currentStock - item.quantity;
              transaction.update(productRef, {'currentStock': newStock});
            }
          });
        }
      }

      if (mounted) {
        // Navigate to Invoice page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => InvoicePage(
              uid: widget.uid,
              userEmail: widget.userEmail,
              businessName: 'Business Trial',
              businessLocation: 'Tamilnadu',
              businessPhone: '+91 ${widget.uid}',
              invoiceNumber: invoiceNumber,
              dateTime: DateTime.now(),
              items: widget.cartItems.map((item) => {
                'name': item.name,
                'quantity': item.quantity,
                'price': item.price,
                'total': item.total,
              }).toList(),
              subtotal: widget.totalAmount + widget.discountAmount,
              discount: widget.discountAmount,
              total: widget.totalAmount,
              paymentMode: widget.paymentMode,
              cashReceived: _cashReceived,
              customerName: widget.customerName,
              customerPhone: widget.customerPhone,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing sale: $e'),
            backgroundColor: const Color(0xFFFF5252),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        title: const Text(
          'Payment',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          SizedBox(height: screenHeight * 0.02),

          // Info Cards
          Padding(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
            child: Row(
              children: [
                Expanded(
                  child: _buildInfoCard('Due', widget.totalAmount.toStringAsFixed(1)),
                ),
                SizedBox(width: screenWidth * 0.02),
                Expanded(
                  child: _buildInfoCard('Mode', widget.paymentMode),
                ),
                SizedBox(width: screenWidth * 0.02),
                Expanded(
                  child: _buildInfoCard('Items', widget.cartItems.length.toString().padLeft(2, '0')),
                ),
              ],
            ),
          ),

          SizedBox(height: screenHeight * 0.03),

          // Cash Received Section
          const Text(
            'Cash Received',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),

          SizedBox(height: screenHeight * 0.02),

          // Display
          Container(
            margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.2),
            padding: EdgeInsets.all(screenWidth * 0.05),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _displayController.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: screenWidth * 0.12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          SizedBox(height: screenHeight * 0.015),

          // Change Display
          Text(
            'change : ${_change.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 18,
              color: Color(0xFF2196F3),
              fontWeight: FontWeight.w600,
            ),
          ),

          SizedBox(height: screenHeight * 0.03),

          // Number Pad
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
              child: GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: screenWidth * 0.04,
                mainAxisSpacing: screenHeight * 0.02,
                childAspectRatio: 1.5,
                children: [
                  _buildNumberButton('1'),
                  _buildNumberButton('2'),
                  _buildNumberButton('3'),
                  _buildNumberButton('4'),
                  _buildNumberButton('5'),
                  _buildNumberButton('6'),
                  _buildNumberButton('7'),
                  _buildNumberButton('8'),
                  _buildNumberButton('9'),
                  _buildNumberButton('.'),
                  _buildNumberButton('0'),
                  _buildBackspaceButton(),
                ],
              ),
            ),
          ),

          // Bill Button
          Padding(
            padding: EdgeInsets.all(screenWidth * 0.04),
            child: SizedBox(
              width: double.infinity,
              height: screenHeight * 0.07,
              child: ElevatedButton(
                onPressed: _cashReceived >= widget.totalAmount ? _completeSale : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Bill',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              color: Color(0xFF2196F3),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberButton(String number) {
    return GestureDetector(
      onTap: () => _onNumberPressed(number),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return GestureDetector(
      onTap: _onBackspace,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Icon(
            Icons.backspace_outlined,
            size: 32,
          ),
        ),
      ),
    );
  }
}

