import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/Sales/Invoice.dart';
import 'dart:math';
import 'package:maxbillup/utils/firestore_service.dart';

// ==========================================
// 1. BILL PAGE (Main State Widget)
// ==========================================
class BillPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final List<CartItem> cartItems;
  final double totalAmount;
  final String? savedOrderId;
  final double? discountAmount;
  final String? customerPhone;
  final String? customerName;
  final String? customerGST;
  final String? quotationId;

  const BillPage({
    super.key,
    required this.uid,
    this.userEmail,
    required this.cartItems,
    required this.totalAmount,
    this.savedOrderId,
    this.discountAmount,
    this.customerPhone,
    this.customerName,
    this.customerGST,
    this.quotationId,
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
  List<Map<String, dynamic>> _selectedCreditNotes = []; // Track selected credit notes
  double _totalCreditNotesAmount = 0.0; // Total amount from credit notes

  @override
  void initState() {
    super.initState();
    _uid = widget.uid;

    // Initialize with quotation data if provided
    if (widget.discountAmount != null) {
      _discountAmount = widget.discountAmount!;
    }
    if (widget.customerPhone != null) {
      _selectedCustomerPhone = widget.customerPhone;
      _selectedCustomerName = widget.customerName;
      _selectedCustomerGST = widget.customerGST;
    }
  }

  double get _finalAmount {
    final amountAfterDiscount = widget.totalAmount - _discountAmount;
    final creditToApply = _totalCreditNotesAmount > amountAfterDiscount
        ? amountAfterDiscount
        : _totalCreditNotesAmount;
    return amountAfterDiscount - creditToApply;
  }

  double get _actualCreditUsed {
    final amountAfterDiscount = widget.totalAmount - _discountAmount;
    return _totalCreditNotesAmount > amountAfterDiscount
        ? amountAfterDiscount
        : _totalCreditNotesAmount;
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
              Navigator.pop(context);
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

  void _showCreditNotesDialog() {
    if (_selectedCustomerPhone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a customer first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Available Credit Notes'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: FutureBuilder<Stream<QuerySnapshot>>(
              future: FirestoreService().getCollectionStream('creditNotes'),
              builder: (context, futureSnapshot) {
                if (!futureSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: futureSnapshot.data!,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No available credit notes',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    // Filter credit notes for this customer with Available status
                    final creditNotes = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['customerPhone'] == _selectedCustomerPhone &&
                             data['status'] == 'Available';
                    }).toList();

                    if (creditNotes.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No available credit notes',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: creditNotes.length,
                      itemBuilder: (context, index) {
                        final doc = creditNotes[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final creditNoteNumber = data['creditNoteNumber'] ?? 'N/A';
                        final amount = (data['amount'] ?? 0.0) as num;
                        final isSelected = _selectedCreditNotes.any((cn) => cn['id'] == doc.id);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: CheckboxListTile(
                            title: Text(
                              'Credit Note: $creditNoteNumber',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF007AFF),
                              ),
                            ),
                            subtitle: Text(
                              'Amount: Rs ${amount.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            value: isSelected,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  _selectedCreditNotes.add({
                                    'id': doc.id,
                                    'creditNoteNumber': creditNoteNumber,
                                    'amount': amount.toDouble(),
                                    'data': data,
                                  });
                                } else {
                                  _selectedCreditNotes.removeWhere((cn) => cn['id'] == doc.id);
                                }
                                _totalCreditNotesAmount = _selectedCreditNotes.fold(
                                  0.0,
                                  (sum, cn) => sum + (cn['amount'] as double),
                                );
                              });
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Reset selections
                setDialogState(() {
                  _selectedCreditNotes.clear();
                  _totalCreditNotesAmount = 0.0;
                });
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amountAfterDiscount = widget.totalAmount - _discountAmount;

                setState(() {
                  // Credit notes already updated in dialog state
                });
                Navigator.pop(context);

                // Show warning if credit notes exceed bill amount
                if (_totalCreditNotesAmount > amountAfterDiscount) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Credit notes applied: Rs ${_totalCreditNotesAmount.toStringAsFixed(2)}\n'
                        'Bill amount: Rs ${amountAfterDiscount.toStringAsFixed(2)}\n'
                        'Only Rs ${amountAfterDiscount.toStringAsFixed(2)} will be used. Remaining credit will stay available.',
                      ),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${_selectedCreditNotes.length} credit note(s) applied: Rs ${_totalCreditNotesAmount.toStringAsFixed(2)}',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
              ),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _proceedToPayment(String paymentMode) {
    // If Split is selected, navigate to the dedicated split payment page.
    if (paymentMode == 'Split') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SplitPaymentPage(
            uid: _uid,
            userEmail: widget.userEmail,
            cartItems: widget.cartItems,
            totalAmount: _finalAmount,
            customerPhone: _selectedCustomerPhone,
            customerName: _selectedCustomerName,
            customerGST: _selectedCustomerGST,
            discountAmount: _discountAmount,
            creditNote: _creditNote,
            savedOrderId: widget.savedOrderId,
            selectedCreditNotes: _selectedCreditNotes,
          ),
        ),
      );
      return;
    }

    // For single payment modes (Cash, Online, Credit, Set later), go to the simple PaymentPage.
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
          savedOrderId: widget.savedOrderId,
          selectedCreditNotes: _selectedCreditNotes,
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

                      // Use Credit Notes Button
                      GestureDetector(
                        onTap: _showCreditNotesDialog,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedCreditNotes.isNotEmpty
                                  ? 'Credit Notes Applied: ${_selectedCreditNotes.length} (₹${_actualCreditUsed.toStringAsFixed(2)})'
                                  : 'Use Credit Notes',
                              style: TextStyle(
                                color: _selectedCreditNotes.isNotEmpty
                                    ? Colors.green
                                    : const Color(0xFF2196F3),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_selectedCreditNotes.isNotEmpty && _totalCreditNotesAmount > _actualCreditUsed)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '(₹${(_totalCreditNotesAmount - _actualCreditUsed).toStringAsFixed(2)} excess - will remain available)',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.01),

                      // Add Credit Note Button
                      GestureDetector(
                        onTap: _showCreditNoteDialog,
                        child: Text(
                          _creditNote.isNotEmpty
                              ? 'Note: $_creditNote'
                              : 'Add Credit Note',
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

// ==========================================
// 2. CUSTOMER SELECTION DIALOG
// ==========================================
class _CustomerSelectionDialog extends StatefulWidget {
  final String uid;
  final Function(String phone, String name, String? gst) onCustomerSelected;

  const _CustomerSelectionDialog({
    required this.uid,
    required this.onCustomerSelected,
  });

  @override
  State<_CustomerSelectionDialog> createState() =>
      _CustomerSelectionDialogState();
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
                // Save customer to store-scoped collection
                await FirestoreService().setDocument('customers', phone, {
                  'name': name,
                  'phone': phone,
                  'gst': gst.isEmpty ? null : gst,
                  'balance': 0.0,
                  'totalSales': 0.0,
                  'timestamp': FieldValue.serverTimestamp(),
                  'lastUpdated': FieldValue.serverTimestamp(),
                });

                if (mounted) {
                  Navigator.pop(context);
                  widget.onCustomerSelected(
                      phone, name, gst.isEmpty ? null : gst);
                  // Do NOT pop the main dialog here, only the inner Add dialog
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
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
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
              child: FutureBuilder<Stream<QuerySnapshot>>(
                future: FirestoreService().getCollectionStream('customers'),
                builder: (context, streamSnapshot) {
                  if (!streamSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return StreamBuilder<QuerySnapshot>(
                    stream: streamSnapshot.data,
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
                              Navigator.pop(context); // Close the dialog
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
                                  // Balance display column
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

// ==========================================
// 4. SPLIT PAYMENT PAGE (New Dedicated Page)
// ==========================================
class SplitPaymentPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final List<CartItem> cartItems;
  final double totalAmount;
  final String? customerPhone;
  final String? customerName;
  final String? customerGST;
  final double discountAmount;
  final String creditNote;
  final String? savedOrderId;
  final List<Map<String, dynamic>> selectedCreditNotes;

  const SplitPaymentPage({
    super.key,
    required this.uid,
    this.userEmail,
    required this.cartItems,
    required this.totalAmount,
    this.customerPhone,
    this.customerName,
    this.customerGST,
    required this.discountAmount,
    required this.creditNote,
    this.savedOrderId,
    this.selectedCreditNotes = const [],
  });

  @override
  State<SplitPaymentPage> createState() => _SplitPaymentPageState();
}

class _SplitPaymentPageState extends State<SplitPaymentPage> {
  final TextEditingController _cashController = TextEditingController(text: '0.00');
  final TextEditingController _onlineController = TextEditingController(text: '0.00');
  final TextEditingController _creditController = TextEditingController(text: '0.00');

  double _cashAmount = 0.0;
  double _onlineAmount = 0.0;
  double _creditAmount = 0.0;
  double get _totalPaid => _cashAmount + _onlineAmount + _creditAmount;
  double get _dueAmount => widget.totalAmount - _totalPaid;

  @override
  void initState() {
    super.initState();
    // Pre-fill credit if customer is selected (common POS feature for quick credit selection)
    if (widget.customerPhone != null) {
      _creditController.text = widget.totalAmount.toStringAsFixed(2);
      _creditAmount = widget.totalAmount;
    }
    _updateStateOnInput();
  }

  void _updateStateOnInput() {
    // Listener to update state whenever any text field changes
    _cashController.addListener(_updateAmounts);
    _onlineController.addListener(_updateAmounts);
    _creditController.addListener(_updateAmounts);
  }

  void _updateAmounts() {
    setState(() {
      _cashAmount = double.tryParse(_cashController.text) ?? 0.0;
      _onlineAmount = double.tryParse(_onlineController.text) ?? 0.0;
      _creditAmount = double.tryParse(_creditController.text) ?? 0.0;
    });
  }

  @override
  void dispose() {
    _cashController.dispose();
    _onlineController.dispose();
    _creditController.dispose();
    super.dispose();
  }

  // --- Firestore Helpers (fetches user name from users/{uid}) ---
  Future<String?> _fetchStaffName(String uid) async {
    try {
      // Fetch user document from users/{uid}
      final doc = await FirestoreService().usersCollection.doc(uid).get();
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

  Future<String?> _fetchBusinessLocation(String uid) async {
    try {
      final doc = await FirestoreService().getDocument('users', uid);
      final data = doc.data() as Map<String, dynamic>?;
      return data?['businessName'] as String? ?? data?['location'] as String?;
    } catch (e) {
      return 'Tirunelveli';
    }
  }

  Future<void> _updateCustomerCredit(String phone, double amount, String invoiceNumber) async {
    final customerRef = await FirestoreService().getDocumentReference('customers', phone);

    // Get customer name
    String customerName = 'Unknown Customer';
    final customerDoc = await customerRef.get();
    if (customerDoc.exists) {
      customerName = (customerDoc.data() as Map<String, dynamic>?)?['name'] as String? ?? 'Unknown Customer';
    }

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final customerDoc = await transaction.get(customerRef);

      if (customerDoc.exists) {
        final currentBalance = (customerDoc.data() as Map<String, dynamic>?)?['balance'] as double? ?? 0.0;
        final newBalance = currentBalance + amount;
        transaction.update(customerRef, {
          'balance': newBalance,
          'lastUpdated': FieldValue.serverTimestamp()
        });
      }
    });

    // Get staff name and business location
    final staffName = await _fetchStaffName(widget.uid);
    final businessLocation = await _fetchBusinessLocation(widget.uid);

    // Add detailed credit transaction record
    await FirestoreService().addDocument('credits', {
      'customerId': phone,
      'customerName': customerName,
      'amount': amount,
      'type': 'credit_sale',
      'method': 'Credit',
      'invoiceNumber': invoiceNumber,
      'timestamp': FieldValue.serverTimestamp(),
      'date': DateTime.now().toIso8601String(),
      'note': 'Credit sale - Invoice #$invoiceNumber',
      'staffId': widget.uid,
      'staffName': staffName ?? widget.userEmail ?? 'Unknown Staff',
      'businessLocation': businessLocation ?? 'Tirunelveli',
      'itemCount': widget.cartItems.length,
      'items': widget.cartItems.map((item) => {
        'productId': item.productId,
        'name': item.name,
        'quantity': item.quantity,
        'price': item.price,
        'total': item.total,
      }).toList(),
    });
  }

  Future<void> _updateProductStock() async {
    try {
      // Iterate through each cart item and reduce stock
      for (var cartItem in widget.cartItems) {
        final productRef = await FirestoreService().getDocumentReference('Products', cartItem.productId);

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final productDoc = await transaction.get(productRef);

          if (productDoc.exists) {
            final productData = productDoc.data() as Map<String, dynamic>?;
            final stockEnabled = productData?['stockEnabled'] as bool? ?? false;

            // Only update stock if stock tracking is enabled for this product
            if (stockEnabled) {
              final currentStock = productData?['currentStock'] as double? ?? 0.0;
              final newStock = currentStock - cartItem.quantity;

              transaction.update(productRef, {
                'currentStock': newStock,
              });
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error updating product stock: $e');
      // Don't throw error - sale should complete even if stock update fails
    }
  }
  // -----------------------------------------------------------------------------------

  Future<void> _markCreditNotesAsUsed(String invoiceNumber, List<Map<String, dynamic>> selectedCreditNotes) async {
    try {
      // Mark all selected credit notes as "Used"
      for (var creditNote in selectedCreditNotes) {
        await FirestoreService().updateDocument('creditNotes', creditNote['id'], {
          'status': 'Used',
          'usedInInvoice': invoiceNumber,
          'usedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error marking credit notes as used: $e');
      // Don't throw error - sale should complete even if credit note update fails
    }
  }

  Future<void> _processSplitSale() async {
    // 1. Validation
    if (_totalPaid < widget.totalAmount && _dueAmount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment short by ₹${_dueAmount.toStringAsFixed(2)}. Cannot complete sale.'),
          backgroundColor: const Color(0xFFFF5252),
        ),
      );
      return;
    }
    if (_dueAmount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Excess payment received. Please adjust the amounts.'),
          backgroundColor: const Color(0xFFFF9800),
        ),
      );
      return;
    }
    if (_creditAmount > 0 && widget.customerPhone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer details are required to issue Credit.'),
          backgroundColor: const Color(0xFFFF5252),
        ),
      );
      return;
    }


    try {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      // 2. Fetch required metadata
      final invoiceNumber = (100000 + Random().nextInt(900000)).toString();
      final staffName = await _fetchStaffName(widget.uid);
      final businessLocation = await _fetchBusinessLocation(widget.uid);

      // 3. Handle Credit Logic
      if (_creditAmount > 0 && widget.customerPhone != null) {
        await _updateCustomerCredit(widget.customerPhone!, _creditAmount, invoiceNumber);
      }

      // 4. Prepare sale data
      final saleData = {
        'invoiceNumber': invoiceNumber,
        'items': widget.cartItems.map((item) => {
          'productId': item.productId, 'name': item.name, 'price': item.price,
          'quantity': item.quantity, 'total': item.total,
        }).toList(),

        'subtotal': widget.totalAmount + widget.discountAmount,
        'discount': widget.discountAmount,
        'total': widget.totalAmount,
        'paymentMode': 'Split', // Recorded as Split

        // Record all amounts received
        'cashReceived_split': _cashAmount,
        'onlineReceived_split': _onlineAmount,
        'creditIssued_split': _creditAmount,
        'cashReceived': _totalPaid - _creditAmount, // Total cash/online received
        'change': _dueAmount < 0 ? -_dueAmount : 0.0,

        'customerPhone': widget.customerPhone,
        'customerName': widget.customerName,
        'customerGST': widget.customerGST,
        'creditNote': widget.creditNote,
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String(),
        'staffId': widget.uid,
        'staffName': staffName ?? widget.userEmail ?? 'Unknown Staff',
        'businessLocation': businessLocation ?? 'Tirunelveli',
      };

      // 5. Save sale and handle cleanup
      await FirestoreService().addDocument('sales', saleData);

      // 6. Update product stock
      await _updateProductStock();

      // 7. Mark credit notes as used
      if (widget.selectedCreditNotes.isNotEmpty) {
        await _markCreditNotesAsUsed(invoiceNumber, widget.selectedCreditNotes);
      }

      if (widget.savedOrderId != null && widget.savedOrderId!.isNotEmpty) {
        final savedOrderRef = await FirestoreService().getDocumentReference('savedOrders', widget.savedOrderId!);
        await savedOrderRef.delete();
      }

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        // Pop BillPage with success result first
        Navigator.pop(context, true);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sale Completed (Split)')),
        );

        // Navigate to Invoice page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InvoicePage(
              // Assuming InvoicePage can handle the full saleData breakup
              uid: widget.uid,
              userEmail: widget.userEmail,
              businessName: 'Business Trial',
              businessLocation: businessLocation ?? 'Tirunelveli',
              businessPhone: '+91 ${widget.uid}',
              invoiceNumber: invoiceNumber,
              dateTime: DateTime.now(),
              items: widget.cartItems.map((item) => {'name': item.name, 'quantity': item.quantity, 'price': item.price, 'total': item.total}).toList(),
              subtotal: widget.totalAmount + widget.discountAmount,
              discount: widget.discountAmount,
              total: widget.totalAmount,
              paymentMode: 'Split',
              cashReceived: _totalPaid - _creditAmount,
              customerName: widget.customerName,
              customerPhone: widget.customerPhone,
            ),
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing split sale: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // We update the due amount display dynamically
    String dueDisplay = _dueAmount <= 0 ? '₹0.00 (Change: ₹${(-_dueAmount).toStringAsFixed(2)})' : '₹${_dueAmount.toStringAsFixed(2)} Due';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Split', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2196F3),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Details Header (If needed)
            if (widget.customerName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text('Customer: ${widget.customerName ?? ''}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),

            // Total Amount Display
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Amount :', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                Text('Rs ${widget.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2196F3))),
              ],
            ),
            const Divider(),

            // Input Fields
            _buildInputField('Cash', _cashController),
            _buildInputField('Online', _onlineController),
            _buildInputField('Credit (Requires Customer)', _creditController),

            const SizedBox(height: 20),

            // Summary and Due
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Paid:', style: TextStyle(fontSize: 16)),
                Text('₹${_totalPaid.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_dueAmount > 0 ? 'Balance Due:' : 'Status:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  dueDisplay,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _dueAmount > 0 ? Colors.red.shade700 : Colors.green.shade700,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Save/Settle Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: (_dueAmount == 0 || _dueAmount < 0) ? _processSplitSale : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Settle Bill',
                  style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          prefixText: '₹ ',
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

// ==========================================
// 5. PAYMENT PAGE (Simple Single Input Page)
// ==========================================
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
  final String? savedOrderId;
  final List<Map<String, dynamic>> selectedCreditNotes;

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
    this.savedOrderId,
    this.selectedCreditNotes = const [],
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  double _cashReceived = 0.0;
  final TextEditingController _displayController =
  TextEditingController(text: '0.0');

  double get _change => _cashReceived - widget.totalAmount;

  @override
  void initState() {
    super.initState();
    // Pre-fill total if payment mode isn't 'Credit' or 'Set later'
    if (widget.paymentMode == 'Cash' || widget.paymentMode == 'Online') {
      _cashReceived = widget.totalAmount;
      _displayController.text = widget.totalAmount.toStringAsFixed(1);
    } else {
      // Enable manual input/keypad starting from 0.0
      _cashReceived = 0.0;
      _displayController.text = '0.0';
    }
  }

  void _onNumberPressed(String value) {
    setState(() {
      if (value == '.') {
        if (!_displayController.text.contains('.')) {
          _displayController.text += value;
        }
      } else {
        String currentText = _displayController.text;
        if (currentText == '0.0' || currentText == '0') {
          currentText = value;
        } else {
          currentText += value;
        }

        if (currentText.split('.').length > 1 && currentText.split('.')[1].length > 2) {
          // Restrict to two decimals
        } else {
          _displayController.text = currentText;
        }
      }
      _cashReceived = double.tryParse(_displayController.text) ?? 0.0;
    });
  }

  void _onBackspace() {
    setState(() {
      if (_displayController.text.isNotEmpty) {
        String currentText = _displayController.text;
        currentText = currentText.substring(0, currentText.length - 1);

        if (currentText.isEmpty || currentText == '.') {
          _displayController.text = '0.0';
        } else {
          _displayController.text = currentText;
        }
        _cashReceived = double.tryParse(_displayController.text) ?? 0.0;
      }
    });
  }

  // FETCH STAFF NAME FUNCTION
  Future<String?> _fetchStaffName(String uid) async {
    try {
      final doc = await FirestoreService().usersCollection.doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        return data?['name'] as String?;
      }
    } catch (e) {
      debugPrint('Error fetching staff name: $e');
    }
    return null;
  }

  // FETCH BUSINESS LOCATION FUNCTION
  Future<String?> _fetchBusinessLocation(String uid) async {
    try {
      final doc = await FirestoreService().getDocument('users', uid);
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        return data?['businessName'] as String? ?? data?['location'] as String?;
      }
    } catch (e) {
      debugPrint('Error fetching business location: $e');
    }
    return 'Tirunelveli';
  }

  // --- Firestore Helper: fetch businessName and location from /store/{storeId} ---
  Future<Map<String, String?>> _fetchBusinessDetails() async {
    try {
      final storeId = await FirestoreService().getCurrentStoreId();
      if (storeId == null) return {'businessName': null, 'location': null};
      final doc = await FirestoreService().storeCollection.doc(storeId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        return {
          'businessName': data?['businessName'] as String?,
          'location': data?['location'] as String? ?? data?['businessLocation'] as String?
        };
      }
      return {'businessName': null, 'location': null};
    } catch (e) {
      debugPrint('Error fetching business details: $e');
      return {'businessName': null, 'location': null};
    }
  }

  // Helper method for Credit Payment: Update customer's credit balance
  Future<void> _updateCustomerCredit(String phone, double amount, String invoiceNumber) async {
    final customerRef = await FirestoreService().getDocumentReference('customers', phone);

    // Get customer name
    String customerName = 'Unknown Customer';
    final customerDoc = await customerRef.get();
    if (customerDoc.exists) {
      customerName = (customerDoc.data() as Map<String, dynamic>?)?['name'] as String? ?? 'Unknown Customer';
    }

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final customerDoc = await transaction.get(customerRef);

      if (customerDoc.exists) {
        final currentBalance = (customerDoc.data() as Map<String, dynamic>?)?['balance'] as double? ?? 0.0;
        final newBalance = currentBalance + amount;
        transaction.update(customerRef, {
          'balance': newBalance,
          'lastUpdated': FieldValue.serverTimestamp()
        });
      }
    });

    // Get staff name and business location
    final staffName = await _fetchStaffName(widget.uid);
    final businessLocation = await _fetchBusinessLocation(widget.uid);

    // Add detailed credit transaction record
    await FirestoreService().addDocument('credits', {
      'customerId': phone,
      'customerName': customerName,
      'amount': amount,
      'type': 'credit_sale',
      'method': 'Credit',
      'invoiceNumber': invoiceNumber,
      'timestamp': FieldValue.serverTimestamp(),
      'date': DateTime.now().toIso8601String(),
      'note': 'Credit sale - Invoice #$invoiceNumber',
      'staffId': widget.uid,
      'staffName': staffName ?? widget.userEmail ?? 'Unknown Staff',
      'businessLocation': businessLocation ?? 'Tirunelveli',
      'itemCount': widget.cartItems.length,
      'items': widget.cartItems.map((item) => {
        'productId': item.productId,
        'name': item.name,
        'quantity': item.quantity,
        'price': item.price,
        'total': item.total,
      }).toList(),
    });
  }

  Future<void> _updateProductStock() async {
    try {
      // Iterate through each cart item and reduce stock
      for (var cartItem in widget.cartItems) {
        final productRef = await FirestoreService().getDocumentReference('Products', cartItem.productId);

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final productDoc = await transaction.get(productRef);

          if (productDoc.exists) {
            final productData = productDoc.data() as Map<String, dynamic>?;
            final stockEnabled = productData?['stockEnabled'] as bool? ?? false;

            // Only update stock if stock tracking is enabled for this product
            if (stockEnabled) {
              final currentStock = productData?['currentStock'] as double? ?? 0.0;
              final newStock = currentStock - cartItem.quantity;

              transaction.update(productRef, {
                'currentStock': newStock,
              });
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error updating product stock: $e');
      // Don't throw error - sale should complete even if stock update fails
    }
  }

  Future<void> _markCreditNotesAsUsed(String invoiceNumber, List<Map<String, dynamic>> selectedCreditNotes) async {
    try {
      // Mark all selected credit notes as "Used"
      for (var creditNote in selectedCreditNotes) {
        await FirestoreService().updateDocument('creditNotes', creditNote['id'], {
          'status': 'Used',
          'usedInInvoice': invoiceNumber,
          'usedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error marking credit notes as used: $e');
      // Don't throw error - sale should complete even if credit note update fails
    }
  }

  // Helper method for Set Later Payment: Save to savedOrders and return to menu
  Future<void> _saveOrderForLater() async {
    try {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      final staffName = await _fetchStaffName(widget.uid);
      final items = widget.cartItems.map((item) => {
        'productId': item.productId, 'name': item.name, 'price': item.price,
        'quantity': item.quantity, 'total': item.total,
      }).toList();

      await FirebaseFirestore.instance
          .collection('savedOrders')
          .add({
        'customerName': widget.customerName,
        'customerPhone': widget.customerPhone,
        'items': items,
        'total': widget.totalAmount,
        'timestamp': FieldValue.serverTimestamp(),
        'staffId': widget.uid,
        'staffName': staffName ?? 'Unknown Staff',
      });

      if (widget.savedOrderId != null && widget.savedOrderId!.isNotEmpty) {
        await FirestoreService().deleteDocument('savedOrders', widget.savedOrderId!);
      }

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order saved for later payment.'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        // Navigate back to the root (MenuPage or Sales Page)
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving order: $e'),
            backgroundColor: const Color(0xFFFF5252),
          ),
        );
      }
    }
  }


  Future<void> _completeSale() async {

    // 1. Handle validation for Credit and Set Later payment modes
    if ((widget.paymentMode == 'Credit' || widget.paymentMode == 'Set later') && widget.customerPhone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer details are required for Credit or Set Later payments.'),
          backgroundColor: Color(0xFFFF5252),
        ),
      );
      return;
    }

    // Handle 'Set later' flow immediately by saving to savedOrders and popping
    if (widget.paymentMode == 'Set later') {
      await _saveOrderForLater();
      return;
    }

    // Validation for Cash/Online (must be fully paid or overpaid)
    if (widget.paymentMode != 'Credit' && _cashReceived < widget.totalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment amount is insufficient.'),
          backgroundColor: Color(0xFFFF5252),
        ),
      );
      return;
    }


    try {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      // 1. Generate invoice number
      final random = Random();
      final invoiceNumber = (100000 + random.nextInt(900000)).toString();

      // 2. FETCH STAFF NAME AND LOCATION
      final staffName = await _fetchStaffName(widget.uid);
      final businessLocation = await _fetchBusinessLocation(widget.uid);

      // Determine amounts for saleData based on Credit mode
      final double amountReceived = (widget.paymentMode == 'Credit') ? 0.0 : _cashReceived;
      final double changeGiven = (widget.paymentMode == 'Credit') ? 0.0 : _change;

      // 3. Prepare sale data
      final saleData = {
        'invoiceNumber': invoiceNumber,
        'items': widget.cartItems.map((item) => {
          'productId': item.productId, 'name': item.name, 'price': item.price,
          'quantity': item.quantity, 'total': item.total,
        }).toList(),
        'subtotal': widget.totalAmount + widget.discountAmount,
        'discount': widget.discountAmount,
        'total': widget.totalAmount,
        'paymentMode': widget.paymentMode,
        'cashReceived': amountReceived,
        'change': changeGiven,
        'customerPhone': widget.customerPhone,
        'customerName': widget.customerName,
        'customerGST': widget.customerGST,
        'creditNote': widget.creditNote,
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String(),
        'staffId': widget.uid,
        'staffName': staffName ?? widget.userEmail ?? 'Unknown Staff',
        'businessLocation': businessLocation ?? 'Tirunelveli',
      };

      // 4. Handle Credit Logic (Add total amount to customer's balance)
      if (widget.paymentMode == 'Credit' && widget.customerPhone != null) {
        await _updateCustomerCredit(widget.customerPhone!, widget.totalAmount, invoiceNumber);
      }

      // 5. Save sale to Firestore
      await FirestoreService().addDocument('sales', saleData);

      // 6. Update product stock
      await _updateProductStock();

      // 7. Mark credit notes as used
      if (widget.selectedCreditNotes.isNotEmpty) {
        await _markCreditNotesAsUsed(invoiceNumber, widget.selectedCreditNotes);
      }

      // 8. Delete saved order if applicable (Settle Order Logic)
      if (widget.savedOrderId != null && widget.savedOrderId!.isNotEmpty) {
        await FirestoreService().deleteDocument('savedOrders', widget.savedOrderId!);
      }

      if (mounted) {
        // Close loading dialog
        Navigator.pop(context);

        // Pop BillPage with success result first
        Navigator.pop(context, true);

        // Navigate to Invoice page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InvoicePage(
              uid: widget.uid,
              userEmail: widget.userEmail,
              businessName: 'Business Trial',
              businessLocation: businessLocation ?? 'Tirunelveli',
              businessPhone: '+91 ${widget.uid}',
              invoiceNumber: invoiceNumber,
              dateTime: DateTime.now(),
              items: widget.cartItems.map((item) => {'name': item.name, 'quantity': item.quantity, 'price': item.price, 'total': item.total}).toList(),
              subtotal: widget.totalAmount + widget.discountAmount,
              discount: widget.discountAmount,
              total: widget.totalAmount,
              paymentMode: widget.paymentMode,
              cashReceived: amountReceived,
              customerName: widget.customerName,
              customerPhone: widget.customerPhone,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Close loading dialog
        Navigator.pop(context);

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
                  child: _buildInfoCard(
                      'Due', widget.totalAmount.toStringAsFixed(1)),
                ),
                SizedBox(width: screenWidth * 0.02),
                Expanded(
                  child: _buildInfoCard('Mode', widget.paymentMode),
                ),
                SizedBox(width: screenWidth * 0.02),
                Expanded(
                  child: _buildInfoCard(
                      'Items', widget.cartItems.length.toString().padLeft(2, '0')),
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
                // Enabled for Credit or if amount received is sufficient
                onPressed:
                widget.paymentMode == 'Credit' || _cashReceived >= widget.totalAmount
                    ? _completeSale
                    : null,
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

