import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Required for Date Formatting
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';

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
    try {
      // Get store-scoped collections
      final customersCollection = await FirestoreService().getStoreCollection('customers');
      final creditsCollection = await FirestoreService().getStoreCollection('credits');

      final customerRef = customersCollection.doc(widget.customerId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
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
      });

      // Add credit transaction record (store-scoped)
      await creditsCollection.add({
        'customerId': widget.customerId,
        'customerName': widget.customerData['name'],
        'amount': amount,
        'type': 'add_credit',
        'method': method,
        'timestamp': FieldValue.serverTimestamp(),
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
                title: Text(context.tr('customerdetails'), style: const TextStyle(color: Colors.white)),
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
            Navigator.push(context, CupertinoPageRoute(builder: (_) => CustomerBillsPage(phone: widget.customerId)));
          } else if (title == "Credit Details") {
            Navigator.push(context, CupertinoPageRoute(builder: (_) => CustomerCreditsPage(customerId: widget.customerId)));
          } else if (title == "ledger") {
            Navigator.push(context, CupertinoPageRoute(builder: (_) => CustomerLedgerPage(customerId: widget.customerId, customerName: widget.customerData['name'])));
          }
        },
      ),
    );
  }

  // --- RECEIVE CREDIT MODAL (Opens Payment Entry Form) ---
  void _showReceiveCreditModal(BuildContext context, double currentBalance, double currentTotalSales) {
    _addAmountController.clear();

    Navigator.push(
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

      // Get store-scoped collections
      final customersCollection = await FirestoreService().getStoreCollection('customers');
      final creditsCollection = await FirestoreService().getStoreCollection('credits');

      final customerRef = customersCollection.doc(widget.customerId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(customerRef);
        if (!snapshot.exists) throw Exception("Customer does not exist!");

        // Reduce balance when payment is received
        double newBalance = widget.currentBalance - _enteredAmount;

        transaction.update(customerRef, {
          'balance': newBalance,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      });

      // Add credit transaction record (store-scoped)
      await creditsCollection.add({
        'customerId': widget.customerId,
        'customerName': widget.customerData['name'],
        'amount': _enteredAmount,
        'type': 'payment_received',
        'method': 'Cash',
        'timestamp': FieldValue.serverTimestamp(),
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
        title: Text(context.tr('customerdetails'), style: const TextStyle(color: Colors.white)),
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

class CustomerBillsPage extends StatefulWidget {
  final String phone;
  const CustomerBillsPage({super.key, required this.phone});

  @override
  State<CustomerBillsPage> createState() => _CustomerBillsPageState();
}

class _CustomerBillsPageState extends State<CustomerBillsPage> {
  List<Map<String, dynamic>> _bills = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  Future<void> _loadBills() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('📋 Loading bills for customer phone: ${widget.phone}');

      final salesCollection = await FirestoreService().getStoreCollection('sales');
      debugPrint('📋 Sales collection path: ${salesCollection.path}');

      final snapshot = await salesCollection
          .where('customerPhone', isEqualTo: widget.phone)
          .get();

      debugPrint('📋 Found ${snapshot.docs.length} bills');

      final bills = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      // Sort by timestamp descending
      bills.sort((a, b) {
        Timestamp? aTime;
        Timestamp? bTime;

        if (a['timestamp'] != null) aTime = a['timestamp'] as Timestamp;
        if (b['timestamp'] != null) bTime = b['timestamp'] as Timestamp;

        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;

        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _bills = bills;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading bills: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Bill History", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2196F3),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBills,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadBills,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_bills.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text("No bills found", style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 8),
            Text("Phone: ${widget.phone}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBills,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _bills.length,
        itemBuilder: (context, index) {
          final data = _bills[index];
          final invoiceNumber = data['invoiceNumber'] ?? 'N/A';
          final total = (data['total'] ?? 0).toDouble();
          final paymentMode = data['paymentMode'] ?? 'N/A';

          // Parse date
          String formattedDate = 'N/A';
          try {
            if (data['timestamp'] != null) {
              final ts = data['timestamp'] as Timestamp;
              formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate());
            } else if (data['date'] != null) {
              final dt = DateTime.parse(data['date']);
              formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(dt);
            }
          } catch (e) {
            formattedDate = 'N/A';
          }

          return Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Amount',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      Text(
                        '₹${total.toStringAsFixed(2)}',
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
      ),
    );
  }

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

class CustomerCreditsPage extends StatefulWidget {
  final String customerId;
  const CustomerCreditsPage({super.key, required this.customerId});

  @override
  State<CustomerCreditsPage> createState() => _CustomerCreditsPageState();
}

class _CustomerCreditsPageState extends State<CustomerCreditsPage> {
  List<Map<String, dynamic>> _credits = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCredits();
  }

  Future<void> _loadCredits() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('📋 Loading credits for customer: ${widget.customerId}');

      final creditsCollection = await FirestoreService().getStoreCollection('credits');
      debugPrint('📋 Credits collection path: ${creditsCollection.path}');

      final snapshot = await creditsCollection
          .where('customerId', isEqualTo: widget.customerId)
          .get();

      debugPrint('📋 Found ${snapshot.docs.length} credit records');

      final credits = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      // Sort by timestamp descending
      credits.sort((a, b) {
        final aTime = a['timestamp'] as Timestamp? ?? Timestamp.now();
        final bTime = b['timestamp'] as Timestamp? ?? Timestamp.now();
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _credits = credits;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading credits: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Credit/Payment History"),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCredits,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCredits,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_credits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text("No credit/payment history", style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 8),
            Text("Customer ID: ${widget.customerId}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCredits,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _credits.length,
        separatorBuilder: (c, i) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final data = _credits[index];
          final ts = data['timestamp'] as Timestamp? ?? Timestamp.now();
          final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate());
          final type = (data['type'] ?? 'credit').toString();
          final isPayment = type == 'payment_received';
          final isCreditSale = type == 'credit_sale';

          String title = isPayment
              ? "Payment Received"
              : isCreditSale
                  ? "Credit Sale"
                  : "Credit Added";

          String subtitle = formattedDate;
          if (data['method'] != null) subtitle += "\nMethod: ${data['method']}";
          if (data['invoiceNumber'] != null) subtitle += "\nInvoice: #${data['invoiceNumber']}";
          if (data['staffName'] != null) subtitle += "\nStaff: ${data['staffName']}";

          final amount = (data['amount'] ?? 0).toDouble();

          return ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: CircleAvatar(
              backgroundColor: isPayment
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              child: Icon(
                isPayment ? Icons.arrow_downward : Icons.arrow_upward,
                color: isPayment ? Colors.green : Colors.orange,
              ),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
            trailing: Text(
              "₹${amount.toStringAsFixed(2)}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isPayment ? Colors.green : Colors.orange,
              ),
            ),
            onTap: () {
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
      ),
    );
  }
}

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
                child: Text(context.tr('close'), style: const TextStyle(color: Colors.white)),
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
  List<LedgerItem> _ledgerItems = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLedger();
  }

  Future<void> _loadLedger() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('📊 Loading ledger for customer: ${widget.customerId}');

      // Get store-scoped collections
      final salesCollection = await FirestoreService().getStoreCollection('sales');
      final creditsCollection = await FirestoreService().getStoreCollection('credits');

      debugPrint('📊 Sales collection path: ${salesCollection.path}');
      debugPrint('📊 Credits collection path: ${creditsCollection.path}');

      final results = await Future.wait([
        salesCollection.where('customerPhone', isEqualTo: widget.customerId).get(),
        creditsCollection.where('customerId', isEqualTo: widget.customerId).get(),
      ]);

      final salesDocs = results[0].docs;
      final creditDocs = results[1].docs;

      debugPrint('📊 Found ${salesDocs.length} sales records');
      debugPrint('📊 Found ${creditDocs.length} credit records');

      List<LedgerItem> items = [];

      // Process ALL sales (debit entries - all purchases by customer)
      for (var doc in salesDocs) {
        final data = doc.data() as Map<String, dynamic>;
        DateTime date;
        try {
          if (data['timestamp'] != null) {
            date = (data['timestamp'] as Timestamp).toDate();
          } else if (data['date'] != null) {
            date = DateTime.parse(data['date']);
          } else {
            date = DateTime.now();
          }
        } catch (e) {
          date = DateTime.now();
        }

        final paymentMode = (data['paymentMode'] ?? 'Cash').toString();
        final total = (data['total'] ?? 0).toDouble();
        final invoiceNumber = data['invoiceNumber'] ?? 'N/A';

        // Add ALL bills to ledger as debit (purchase)
        items.add(LedgerItem(
          date: date,
          description: "Invoice #$invoiceNumber ($paymentMode)",
          debit: total,
          credit: 0,
        ));

        // If payment was Cash/Online/Split, also add immediate payment as credit
        final lowerPaymentMode = paymentMode.toLowerCase();
        if (lowerPaymentMode == 'cash' || lowerPaymentMode == 'online') {
          // Immediate full payment
          items.add(LedgerItem(
            date: date,
            description: "Paid - Inv #$invoiceNumber ($paymentMode)",
            debit: 0,
            credit: total,
          ));
        } else if (lowerPaymentMode == 'split') {
          // Split payment - add cash portion as credit
          final cashReceived = (data['cashReceived'] ?? 0).toDouble();
          if (cashReceived > 0) {
            items.add(LedgerItem(
              date: date,
              description: "Paid (Split) - Inv #$invoiceNumber",
              debit: 0,
              credit: cashReceived,
            ));
          }
        }
        // Credit bills don't get immediate credit entry - they remain as outstanding
      }

      // Process credits (credit entries - payments received for credit sales)
      for (var doc in creditDocs) {
        final data = doc.data() as Map<String, dynamic>;
        DateTime date;
        try {
          if (data['timestamp'] != null) {
            date = (data['timestamp'] as Timestamp).toDate();
          } else {
            date = DateTime.now();
          }
        } catch (e) {
          date = DateTime.now();
        }

        String type = (data['type'] ?? '').toString();

        if (type == 'payment_received') {
          // Payment received for credit sales - reduces outstanding balance
          items.add(LedgerItem(
            date: date,
            description: "Payment Received (${data['method'] ?? 'Cash'})",
            debit: 0,
            credit: (data['amount'] ?? 0).toDouble(),
          ));
        }
        // Note: We don't add credit_sale or add_credit here anymore since
        // all sales are already captured from the sales collection
      }

      // Sort by date ascending for running balance calculation
      items.sort((a, b) => a.date.compareTo(b.date));

      // Calculate running balance
      double runningBalance = 0.0;
      for (var item in items) {
        runningBalance = runningBalance + item.debit - item.credit;
        item.balance = runningBalance;
      }

      // Reverse for display (newest first)
      items = items.reversed.toList();

      if (mounted) {
        setState(() {
          _ledgerItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error generating ledger: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading ledger: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text("Customer Ledger", style: TextStyle(fontSize: 16)),
            Text(widget.customerName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300)),
          ],
        ),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLedger,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadLedger,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_ledgerItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text("No transactions found", style: TextStyle(fontSize: 16, color: Colors.grey)),
            SizedBox(height: 8),
            Text("Credit sales and payments will appear here", style: TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      );
    }

    final currentBalance = _ledgerItems.isNotEmpty ? _ledgerItems.first.balance : 0.0;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          color: Colors.grey[200],
          child: const Row(
            children: [
              Expanded(flex: 2, child: Text("Date", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              Expanded(flex: 3, child: Text("Particulars", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              Expanded(flex: 2, child: Text("Debit", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.red))),
              Expanded(flex: 2, child: Text("Credit", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.green))),
              Expanded(flex: 2, child: Text("Balance", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            ],
          ),
        ),
        // Ledger entries
        Expanded(
          child: ListView.separated(
            itemCount: _ledgerItems.length,
            separatorBuilder: (c, i) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = _ledgerItems[index];
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                color: index % 2 == 0 ? Colors.white : Colors.grey[50],
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        DateFormat('dd/MM/yy').format(item.date),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        item.description,
                        style: const TextStyle(fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        item.debit > 0 ? '₹${item.debit.toStringAsFixed(0)}' : "-",
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        item.credit > 0 ? '₹${item.credit.toStringAsFixed(0)}' : "-",
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '₹${item.balance.toStringAsFixed(0)}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          color: item.balance > 0 ? Colors.red : Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // Total balance footer
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Outstanding Balance:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(
                '₹${currentBalance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: currentBalance > 0 ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
