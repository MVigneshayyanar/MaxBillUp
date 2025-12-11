import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Required for Date Formatting
import 'package:maxbillup/utils/firestore_service.dart';

// =============================================================================
// MAIN PAGE: CUSTOMER DETAILS
// =============================================================================

class CustomerDetailsPage extends StatefulWidget {
  final String customerId; // This is the Phone Number (Document ID)
  final Map<String, dynamic> customerData;

  const CustomerDetailsPage({super.key, required this.customerId, required this.customerData});

  @override
  State<CustomerDetailsPage> createState() => _CustomerDetailsPageState();
}

class _CustomerDetailsPageState extends State<CustomerDetailsPage> {
  final TextEditingController _addAmountController = TextEditingController();

  @override
  void dispose() {
    _addAmountController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 1. DELETE CUSTOMER LOGIC
  // ---------------------------------------------------------------------------
  Future<void> _confirmDelete(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Customer"),
        content: const Text("Are you sure? This action cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel")
          ),
          TextButton(
            onPressed: () async {
              try {
                // Delete from Firestore
                await FirestoreService().deleteDocument('customers', widget.customerId);
                if (mounted) {
                  Navigator.pop(ctx); // Close Dialog
                  Navigator.pop(context); // Go back to List Page
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer Deleted')));
                }
              } catch (e) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. EDIT CUSTOMER LOGIC
  // ---------------------------------------------------------------------------
  void _showEditDialog(BuildContext context, String currentName, String? currentGst) {
    final nameController = TextEditingController(text: currentName);
    final gstController = TextEditingController(text: currentGst ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Name")),
            const SizedBox(height: 10),
            TextField(controller: gstController, decoration: const InputDecoration(labelText: "GST No")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await FirestoreService().updateDocument('customers', widget.customerId, {
                'name': nameController.text.trim(),
                'gst': gstController.text.trim().isEmpty ? null : gstController.text.trim(),
              });
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007AFF)),
            child: const Text("Update", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. ADD CREDIT / TRANSACTION LOGIC
  // ---------------------------------------------------------------------------
  void _showAddCreditModal(BuildContext context, double currentBalance, double currentTotalSales) {
    final amountController = TextEditingController();
    String selectedMethod = "Cash"; // Default payment method

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Sales Credit",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 28),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.customerData['name'],
                    style: const TextStyle(
                      color: Color(0xFF2196F3),
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Phone Number
                  Text(
                    "Phone Number",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.customerId,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Total Sales Credit
                  Text(
                    "Total Sales Credit :",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentBalance.toStringAsFixed(2),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Received Amount
                  const Text(
                    "Received amount:",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: '0:0',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      suffixText: '0/15',
                      suffixStyle: TextStyle(color: Colors.grey[400]),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Payment Method Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildPaymentIcon(Icons.money, "Cash", selectedMethod, (val) => setModalState(() => selectedMethod = val)),
                      _buildPaymentIcon(Icons.credit_card, "Online", selectedMethod, (val) => setModalState(() => selectedMethod = val)),
                      _buildPaymentIcon(Icons.handshake, "Waive Off", selectedMethod, (val) => setModalState(() => selectedMethod = val)),
                    ],
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      onPressed: () async {
                        final amount = double.tryParse(amountController.text) ?? 0.0;
                        if (amount <= 0) return;

                        await _processTransaction(amount, currentBalance, currentTotalSales, selectedMethod);
                        if (mounted) Navigator.pop(context);
                      },
                      child: const Text(
                        "Save Credit",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }
      ),
    );
  }

  Widget _buildPaymentIcon(IconData icon, String label, String currentSelection, Function(String) onSelect) {
    bool isSelected = label == currentSelection;
    return GestureDetector(
      onTap: () => onSelect(label),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? const Color(0xFF2196F3) : Colors.white,
              border: Border.all(
                color: isSelected ? const Color(0xFF2196F3) : Colors.grey.shade300,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF2196F3),
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? const Color(0xFF2196F3) : Colors.black87,
            ),
          )
        ],
      ),
    );
  }

  // --- FIRESTORE TRANSACTION ---
  Future<void> _processTransaction(double amount, double oldBalance, double oldTotalSales, String method) async {
    final firestore = FirebaseFirestore.instance;
    final customerRef = firestore.collection('customers').doc(widget.customerId);
    final creditsRef = firestore.collection('credits').doc();

    try {
      await firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(customerRef);
        if (!snapshot.exists) throw Exception("Customer does not exist!");

        // Adding credit increases balance and sales
        double newBalance = oldBalance + amount;
        double newTotalSales = oldTotalSales + amount;

        transaction.update(customerRef, {
          'balance': newBalance,
          'totalSales': newTotalSales,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        transaction.set(creditsRef, {
          'customerId': widget.customerId,
          'customerName': widget.customerData['name'],
          'amount': amount,
          'type': 'add_credit',
          'method': method,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Credit Added Successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ---------------------------------------------------------------------------
  // 4. MAIN BUILD METHOD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentReference>(
      future: FirestoreService().getDocumentReference('customers', widget.customerId),
      builder: (context, docRefSnapshot) {
        if (!docRefSnapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: docRefSnapshot.data!.snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
            if (!snapshot.data!.exists) return const Scaffold(body: Center(child: Text("Customer not found")));

            var data = snapshot.data!.data() as Map<String, dynamic>;
            double balance = (data['balance'] ?? 0).toDouble();
            double totalSales = (data['totalSales'] ?? 0).toDouble();

            return Scaffold(
              backgroundColor: const Color(0xFF2196F3),
              appBar: AppBar(
                title: const Text('Customer Details', style: TextStyle(color: Colors.white)),
              backgroundColor: const Color(0xFF2196F3),
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context)
              ),
            ),
            body: Container(
              color: Colors.grey[100],
              child: Column(
                children: [
                  // Main Content
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          // Customer Info Card
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Name with Edit and Delete icons
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      data['name'] ?? 'Unknown',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2196F3),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Color(0xFF2196F3), size: 22),
                                          onPressed: () => _showEditDialog(context, data['name'], data['gst']),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                        const SizedBox(width: 12),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red, size: 22),
                                          onPressed: () => _confirmDelete(context),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Phone Number and GST No
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Phone Number",
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          data['phone'] ?? '--',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "GST No",
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          data['gst'] ?? '---',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Total Sales and Credit Amount
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Total Sales :",
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          totalSales.toStringAsFixed(2),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "Credit Amount",
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          balance.toStringAsFixed(2),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Color(0xFF2196F3),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Menu Items
                          _buildMenuItem("Bills", context),
                          const SizedBox(height: 12),
                          _buildMenuItem("Credit Details", context),
                          const SizedBox(height: 12),
                          _buildMenuItem("ledger", context),
                          const SizedBox(height: 100), // Space for bottom buttons
                        ],
                      ),
                    ),
                  ),

                  // Bottom Action Buttons
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2196F3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                            ),
                            onPressed: () => _showAddCreditModal(context, balance, totalSales),
                            child: const Text(
                              "Add Credit",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF2196F3), width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: () => _showReceiveCreditModal(context, balance, totalSales),
                            child: const Text(
                              "Receive Credit",
                              style: TextStyle(
                                color: Color(0xFF2196F3),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ); // Close Scaffold
          }, // Close StreamBuilder builder
        ); // Close StreamBuilder
      }, // Close FutureBuilder builder
    ); // Close FutureBuilder - close return statement
  } // Close build method

  // --- UPDATED NAVIGATION LOGIC ---
  Widget _buildMenuItem(String title, BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          if (title == "Bills") {
            Navigator.pushReplacement(context, CupertinoPageRoute(builder: (_) => CustomerBillsPage(phone: widget.customerId)));
          } else if (title == "Credit Details") {
            Navigator.pushReplacement(context, CupertinoPageRoute(builder: (_) => CustomerCreditsPage(customerId: widget.customerId)));
          } else if (title == "ledger") {
            Navigator.pushReplacement(context, CupertinoPageRoute(builder: (_) => CustomerLedgerPage(customerId: widget.customerId, customerName: widget.customerData['name'])));
          }
        },
      ),
    );
  }

  // --- RECEIVE CREDIT MODAL (Opens Payment Entry Form) ---
  void _showReceiveCreditModal(BuildContext context, double currentBalance, double currentTotalSales) {
    _addAmountController.clear();

    Navigator.pushReplacement(
      context,
      CupertinoPageRoute(
        builder: (context) => _ReceiveCreditPage(
          customerId: widget.customerId,
          customerData: widget.customerData,
          currentBalance: currentBalance,
          currentTotalSales: currentTotalSales,
        ),
      ),
    );
  }
}

// =============================================================================
// RECEIVE CREDIT PAGE (Payment Entry Form)
// =============================================================================

class _ReceiveCreditPage extends StatefulWidget {
  final String customerId;
  final Map<String, dynamic> customerData;
  final double currentBalance;
  final double currentTotalSales;

  const _ReceiveCreditPage({
    required this.customerId,
    required this.customerData,
    required this.currentBalance,
    required this.currentTotalSales,
  });

  @override
  State<_ReceiveCreditPage> createState() => _ReceiveCreditPageState();
}

class _ReceiveCreditPageState extends State<_ReceiveCreditPage> {
  final TextEditingController _amountController = TextEditingController();
  double _enteredAmount = 0.0;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String value) {
    setState(() {
      _enteredAmount = double.tryParse(value) ?? 0.0;
    });
  }

  double get _newBalance => widget.currentBalance - _enteredAmount;

  Future<void> _savePayment() async {
    if (_enteredAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final firestore = FirebaseFirestore.instance;
      final customerRef = firestore.collection('customers').doc(widget.customerId);

      await firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(customerRef);
        if (!snapshot.exists) throw Exception("Customer does not exist!");

        // Reduce balance when payment is received
        double newBalance = widget.currentBalance - _enteredAmount;

        transaction.update(customerRef, {
          'balance': newBalance,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // Add credit transaction record
        await firestore.collection('credits').add({
          'customerId': widget.customerId,
          'customerName': widget.customerData['name'],
          'amount': _enteredAmount,
          'type': 'payment_received',
          'method': 'Cash',
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        Navigator.pop(context); // Go back to customer details
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment received successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2196F3),
      appBar: AppBar(
        title: const Text('Customer Details', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(0),
            topRight: Radius.circular(0),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer Name
              Text(
                widget.customerData['name'] ?? 'Unknown',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2196F3),
                ),
              ),
              const SizedBox(height: 20),

              // Phone Number and Outstanding Balance
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Phone Number",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.customerData['phone'] ?? '--',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "Outstanding Balance",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Rs ${widget.currentBalance.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF2196F3),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Add Amount Section
              const Text(
                "Add amount:",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: _onAmountChanged,
                decoration: InputDecoration(
                  hintText: '0:0',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  suffixText: '0/8',
                  suffixStyle: TextStyle(color: Colors.grey[400]),
                ),
              ),
              const SizedBox(height: 24),

              // New Balance
              const Text(
                "New Balance",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Rs ${_newBalance.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2196F3),
                ),
              ),
              const Spacer(),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  onPressed: _savePayment,
                  child: const Text(
                    "Save",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SUB-PAGE 1: BILLS HISTORY
// =============================================================================

class CustomerBillsPage extends StatelessWidget {
  final String phone;
  const CustomerBillsPage({super.key, required this.phone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Bill History", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2196F3),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sales')
            .where('customerPhone', isEqualTo: phone)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No bills found",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          // Sort documents by timestamp in memory
          var docs = snapshot.data!.docs.toList();
          docs.sort((a, b) {
            var aData = a.data() as Map<String, dynamic>;
            var bData = b.data() as Map<String, dynamic>;

            Timestamp? aTimestamp = aData['timestamp'] as Timestamp?;
            Timestamp? bTimestamp = bData['timestamp'] as Timestamp?;

            if (aTimestamp == null && bTimestamp == null) return 0;
            if (aTimestamp == null) return 1;
            if (bTimestamp == null) return -1;

            return bTimestamp.compareTo(aTimestamp); // descending
          });

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String invoiceNumber = data['invoiceNumber'] ?? 'N/A';
              double total = (data['total'] ?? 0).toDouble();
              String paymentMode = data['paymentMode'] ?? 'N/A';

              // Parse date - try timestamp first, then date string
              String formattedDate = 'N/A';
              try {
                if (data['timestamp'] != null) {
                  Timestamp ts = data['timestamp'] as Timestamp;
                  formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate());
                } else if (data['date'] != null) {
                  DateTime dt = DateTime.parse(data['date']);
                  formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(dt);
                }
              } catch (e) {
                formattedDate = 'N/A';
              }

              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Invoice #$invoiceNumber',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2196F3),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getPaymentModeColor(paymentMode).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              paymentMode,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _getPaymentModeColor(paymentMode),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Amount',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            ' ${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ); // Close ListView
        }, // Close StreamBuilder builder
      ), // Close StreamBuilder (body parameter)
    ); // Close Scaffold
  } // Close build method

  Color _getPaymentModeColor(String mode) {
    switch (mode.toLowerCase()) {
      case 'cash':
        return const Color(0xFF4CAF50);
      case 'online':
        return const Color(0xFF2196F3);
      case 'credit':
        return const Color(0xFFFF9800);
      case 'split':
        return const Color(0xFF9C27B0);
      default:
        return Colors.grey;
    }
  }
}

// =============================================================================
// SUB-PAGE 2: CREDIT HISTORY
// =============================================================================

class CustomerCreditsPage extends StatelessWidget {
  final String customerId;
  const CustomerCreditsPage({super.key, required this.customerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Credit/Payment History"), backgroundColor: const Color(0xFF007AFF), foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('credits')
            .where('customerId', isEqualTo: customerId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No credit history"));

          // Sort documents by timestamp in memory
          var docs = snapshot.data!.docs.toList();
          docs.sort((a, b) {
            var aData = a.data() as Map<String, dynamic>;
            var bData = b.data() as Map<String, dynamic>;

            Timestamp aTimestamp = aData['timestamp'] as Timestamp? ?? Timestamp.now();
            Timestamp bTimestamp = bData['timestamp'] as Timestamp? ?? Timestamp.now();

            return bTimestamp.compareTo(aTimestamp); // descending
          });

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (c, i) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              Timestamp ts = data['timestamp'] ?? Timestamp.now();
              String formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate());
              String type = data['type'] ?? 'credit';
              bool isPayment = type == 'add_credit';
              bool isCreditSale = type == 'credit_sale';

              String title = isPayment
                  ? "Payment Received"
                  : isCreditSale
                      ? "Credit Sale"
                      : "Credit Used";

              String subtitle = "$formattedDate\nMethod: ${data['method'] ?? 'N/A'}";
              if (data['invoiceNumber'] != null) {
                subtitle += "\nInvoice: #${data['invoiceNumber']}";
              }
              if (data['staffName'] != null) {
                subtitle += "\nStaff: ${data['staffName']}";
              }
              if (data['businessLocation'] != null) {
                subtitle += "\nLocation: ${data['businessLocation']}";
              }
              if (data['itemCount'] != null && data['itemCount'] > 0) {
                subtitle += "\nItems: ${data['itemCount']}";
              }

              return ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                leading: CircleAvatar(
                  backgroundColor: isPayment ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                  child: Icon(
                    isPayment ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isPayment ? Colors.green : Colors.red
                  ),
                ),
                title: Text(title),
                subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
                trailing: Text(
                  " ${data['amount']}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isPayment ? Colors.green : Colors.red
                  )
                ),
                onTap: () {
                  // Show detailed credit information in a dialog
                  if (data['items'] != null && (data['items'] as List).isNotEmpty) {
                    showDialog(
                      context: context,
                      builder: (context) => _CreditDetailsDialog(
                        data: data,
                        isPayment: isPayment,
                        isCreditSale: isCreditSale,
                      ),
                    );
                  }
                },
              );
            },
          ); // Close ListView
        }, // Close StreamBuilder builder
      ), // Close StreamBuilder (body parameter)
    ); // Close Scaffold
  } // Close build method
} // Close CustomerCreditsPage class

// =============================================================================
// CREDIT DETAILS DIALOG
// =============================================================================
class _CreditDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isPayment;
  final bool isCreditSale;

  const _CreditDetailsDialog({
    required this.data,
    required this.isPayment,
    required this.isCreditSale,
  });

  @override
  Widget build(BuildContext context) {
    Timestamp ts = data['timestamp'] ?? Timestamp.now();
    String formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate());

    List<dynamic> items = data['items'] ?? [];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  isPayment ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isPayment ? Colors.green : Colors.red,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isPayment ? "Payment Received" : isCreditSale ? "Credit Sale Details" : "Credit Used",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),

            // Transaction Details
            _buildDetailRow('Invoice Number', '#${data['invoiceNumber'] ?? 'N/A'}'),
            _buildDetailRow('Date & Time', formattedDate),
            _buildDetailRow('Amount', ' ${data['amount']?.toStringAsFixed(2) ?? '0.00'}',
              valueColor: isPayment ? Colors.green : Colors.red),
            _buildDetailRow('Method', data['method'] ?? 'N/A'),

            if (data['staffName'] != null)
              _buildDetailRow('Staff', data['staffName']),

            if (data['businessLocation'] != null)
              _buildDetailRow('Location', data['businessLocation']),

            if (data['note'] != null)
              _buildDetailRow('Note', data['note']),

            // Items Section
            if (items.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Items Purchased',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 250),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index] as Map<String, dynamic>;
                    return ListTile(
                      dense: true,
                      title: Text(
                        item['name'] ?? 'Unknown Item',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        'Qty: ${item['quantity']} ×  ${item['price']?.toStringAsFixed(2) ?? '0.00'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Text(
                        ' ${item['total']?.toStringAsFixed(2) ?? '0.00'}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Close Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Close', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SUB-PAGE 3: LEDGER (MERGED & SORTED)
// =============================================================================

class LedgerItem {
  final DateTime date;
  final String description;
  final double debit;
  final double credit;
  double balance;

  LedgerItem({required this.date, required this.description, required this.debit, required this.credit, this.balance = 0.0});
}

class CustomerLedgerPage extends StatefulWidget {
  final String customerId;
  final String customerName;

  const CustomerLedgerPage({super.key, required this.customerId, required this.customerName});

  @override
  State<CustomerLedgerPage> createState() => _CustomerLedgerPageState();
}

class _CustomerLedgerPageState extends State<CustomerLedgerPage> {
  Future<List<LedgerItem>>? _ledgerFuture;

  @override
  void initState() {
    super.initState();
    _ledgerFuture = _generateLedger();
  }

  Future<List<LedgerItem>> _generateLedger() async {
    final firestore = FirebaseFirestore.instance;
    final results = await Future.wait([
      firestore.collection('sales').where('customerPhone', isEqualTo: widget.customerId).get(),
      firestore.collection('credits').where('customerId', isEqualTo: widget.customerId).get(),
    ]);

    final salesDocs = results[0].docs;
    final creditDocs = results[1].docs;
    List<LedgerItem> items = [];

    for (var doc in salesDocs) {
      final data = doc.data();
      DateTime date;
      try { date = DateTime.parse(data['date']); } catch (e) { date = DateTime(2000); }
      items.add(LedgerItem(date: date, description: "Invoice #${data['invoiceNumber']}", debit: (data['total'] ?? 0).toDouble(), credit: 0));
    }

    for (var doc in creditDocs) {
      final data = doc.data();
      Timestamp ts = data['timestamp'] ?? Timestamp.now();
      items.add(LedgerItem(date: ts.toDate(), description: "Payment (${data['method'] ?? 'Unknown'})", debit: 0, credit: (data['amount'] ?? 0).toDouble()));
    }

    items.sort((a, b) => a.date.compareTo(b.date));

    double runningBalance = 0.0;
    for (var item in items) {
      runningBalance = runningBalance + item.debit - item.credit;
      item.balance = runningBalance;
    }

    return items.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(children: [const Text("Customer Ledger", style: TextStyle(fontSize: 16)), Text(widget.customerName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300))]),
        backgroundColor: const Color(0xFF007AFF), foregroundColor: Colors.white, centerTitle: true,
      ),
      body: FutureBuilder<List<LedgerItem>>(
        future: _ledgerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("No transaction history"));

          final ledger = snapshot.data!;
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8), color: Colors.grey[200],
                child: const Row(children: [
                  Expanded(flex: 2, child: Text("Date", style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 3, child: Text("Particulars", style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text("Debit", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text("Credit", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text("Bal", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                ]),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: ledger.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = ledger[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      color: index % 2 == 0 ? Colors.white : Colors.grey[50],
                      child: Row(children: [
                        Expanded(flex: 2, child: Text(DateFormat('dd/MM/yy').format(item.date), style: const TextStyle(fontSize: 12))),
                        Expanded(flex: 3, child: Text(item.description, style: const TextStyle(fontSize: 12))),
                        Expanded(flex: 2, child: Text(item.debit > 0 ? item.debit.toStringAsFixed(1) : "-", textAlign: TextAlign.right, style: const TextStyle(color: Colors.red, fontSize: 12))),
                        Expanded(flex: 2, child: Text(item.credit > 0 ? item.credit.toStringAsFixed(1) : "-", textAlign: TextAlign.right, style: const TextStyle(color: Colors.green, fontSize: 12))),
                        Expanded(flex: 2, child: Text(item.balance.toStringAsFixed(1), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      ]),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}