import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Required for Date Formatting

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
                await FirebaseFirestore.instance.collection('customers').doc(widget.customerId).delete();
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
              await FirebaseFirestore.instance.collection('customers').doc(widget.customerId).update({
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Sales Credit", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
                    ],
                  ),
                  Text(widget.customerData['name'], style: const TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text("Outstanding Balance: ₹$currentBalance", style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 20),

                  const Text("Enter Amount", style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: '0.0',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Payment Method Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildPaymentIcon(Icons.money, "Cash", selectedMethod, (val) => setModalState(() => selectedMethod = val)),
                      _buildPaymentIcon(Icons.credit_card, "Online", selectedMethod, (val) => setModalState(() => selectedMethod = val)),
                      _buildPaymentIcon(Icons.handshake, "Waive Off", selectedMethod, (val) => setModalState(() => selectedMethod = val)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007AFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      onPressed: () async {
                        final amount = double.tryParse(amountController.text) ?? 0.0;
                        if (amount <= 0) return;

                        await _processTransaction(amount, currentBalance, currentTotalSales, selectedMethod);
                        if (mounted) Navigator.pop(context);
                      },
                      child: const Text("Save Credit", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 20),
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
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? const Color(0xFF007AFF) : Colors.white,
              border: Border.all(
                color: isSelected ? const Color(0xFF007AFF) : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            child: Icon(icon, color: isSelected ? Colors.white : const Color(0xFF007AFF)),
          ),
          const SizedBox(height: 5),
          Text(label, style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? const Color(0xFF007AFF) : Colors.black
          ))
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
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('customers').doc(widget.customerId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          if (!snapshot.data!.exists) return const Scaffold(body: Center(child: Text("Customer not found")));

          var data = snapshot.data!.data() as Map<String, dynamic>;
          double balance = (data['balance'] ?? 0).toDouble();
          double totalSales = (data['totalSales'] ?? 0).toDouble();

          return Scaffold(
            backgroundColor: Colors.grey[50],
            appBar: AppBar(
              title: const Text('Customer Details', style: TextStyle(color: Colors.white)),
              backgroundColor: const Color(0xFF007AFF),
              centerTitle: true,
              leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
            ),
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(data['name'] ?? 'Unknown', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF007AFF))),
                            Row(children: [
                              InkWell(
                                onTap: () => _showEditDialog(context, data['name'], data['gst']),
                                child: const Icon(Icons.edit, size: 22, color: Colors.grey),
                              ),
                              const SizedBox(width: 15),
                              InkWell(
                                onTap: () => _confirmDelete(context),
                                child: const Icon(Icons.delete, size: 22, color: Colors.redAccent),
                              ),
                            ])
                          ],
                        ),
                        const Divider(height: 25),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text("Phone Number", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                              Text(data['phone'] ?? '--', style: const TextStyle(fontWeight: FontWeight.w500)),
                            ]),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text("GST No", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                              Text(data['gst'] ?? '---', style: const TextStyle(fontWeight: FontWeight.w500)),
                            ]),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text("Total Sales", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                              Text("₹${totalSales.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                            ]),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text("Credit Amount", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                              Text("₹${balance.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF007AFF))),
                            ]),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // NAVIGATION LINKS (UPDATED)
                  _buildMenuItem("Bills", context),
                  const SizedBox(height: 10),
                  _buildMenuItem("Credit Details", context),
                  const SizedBox(height: 10),
                  _buildMenuItem("Ledger", context),

                  const Spacer(),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007AFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      onPressed: () => _showAddCreditModal(context, balance, totalSales),
                      child: const Text("Add Credit", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  )
                ],
              ),
            ),
          );
        }
    );
  }

  // --- UPDATED NAVIGATION LOGIC ---
  Widget _buildMenuItem(String title, BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          if (title == "Bills") {
            Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerBillsPage(phone: widget.customerId)));
          } else if (title == "Credit Details") {
            Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerCreditsPage(customerId: widget.customerId)));
          } else if (title == "Ledger") {
            Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerLedgerPage(customerId: widget.customerId, customerName: widget.customerData['name'])));
          }
        },
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
      appBar: AppBar(title: const Text("Bill History"), backgroundColor: const Color(0xFF007AFF), foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sales')
            .where('customerPhone', isEqualTo: phone)
            .orderBy('date', descending: true) // Ensure you have an index for this in Firestore!
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No bills found"));

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (c, i) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              DateTime date;
              try { date = DateTime.parse(data['date']); } catch (e) { date = DateTime.now(); }
              String formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Inv: ${data['invoiceNumber'] ?? '---'}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text("₹${data['total']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(formattedDate, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      const Divider(),
                      Text("Items: ${(data['items'] as List).length}", style: const TextStyle(fontSize: 12)),
                      Text("Payment: ${data['paymentMode'] ?? 'Unknown'}", style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
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
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No credit history"));

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (c, i) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              Timestamp ts = data['timestamp'] ?? Timestamp.now();
              String formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate());
              String type = data['type'] ?? 'credit';
              bool isPayment = type == 'add_credit';

              return ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                leading: CircleAvatar(
                  backgroundColor: isPayment ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  child: Icon(isPayment ? Icons.arrow_downward : Icons.arrow_upward, color: isPayment ? Colors.green : Colors.red),
                ),
                title: Text(isPayment ? "Payment Received" : "Credit Used"),
                subtitle: Text("$formattedDate\nMethod: ${data['method'] ?? 'N/A'}"),
                trailing: Text("₹${data['amount']}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isPayment ? Colors.green : Colors.red)),
              );
            },
          );
        },
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