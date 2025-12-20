import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';

// =============================================================================
// UI CONSTANTS & THEME
// =============================================================================
const Color _primaryColor = Color(0xFF2196F3);
const Color _drColor = Color(0xFFFF5252);     // RED: Debit / Balance Due
const Color _crColor = Color(0xFF4CAF50);     // GREEN: Credit / Total Paid
const Color _cardBorder = Color(0xFFE3F2FD);   // Soft high-end border
const Color _scaffoldBg = Colors.white;

// =============================================================================
// MAIN PAGE: CUSTOMER DETAILS
// =============================================================================

class CustomerDetailsPage extends StatefulWidget {
  final String customerId;
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

  // --- DELETE LOGIC ---
  Future<void> _confirmDelete(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Customer", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("This action cannot be undone. Are you sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              try {
                await FirestoreService().deleteDocument('customers', widget.customerId);
                if (mounted) { Navigator.pop(ctx); Navigator.pop(context); }
              } catch (e) { Navigator.pop(ctx); }
            },
            child: const Text("Delete", style: TextStyle(color: _drColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- EDIT LOGIC ---
  void _showEditDialog(BuildContext context, String currentName, String? currentGst) {
    final nameController = TextEditingController(text: currentName);
    final gstController = TextEditingController(text: currentGst ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Edit Details", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogInput(nameController, "Name", Icons.person_outline),
            const SizedBox(height: 12),
            _buildDialogInput(gstController, "GST No", Icons.receipt_outlined),
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
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("Update", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // --- ADD CREDIT MODAL ---
  void _showAddCreditModal(BuildContext context, double currentBalance, double currentTotalSales) {
    final amountController = TextEditingController();
    String selectedMethod = "Cash";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Sales Credit", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close, size: 28), onPressed: () => Navigator.pop(context))
                  ],
                ),
                Text(widget.customerData['name'], style: const TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 24),
                _buildDialogInput(amountController, "Amount to Add", Icons.add_circle_outline, isNum: true),
                const SizedBox(height: 24),
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
                  width: double.infinity, height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                    onPressed: () async {
                      final amount = double.tryParse(amountController.text) ?? 0.0;
                      if (amount <= 0) return;
                      await _processTransaction(amount, currentBalance, currentTotalSales, selectedMethod);
                      if (mounted) Navigator.pop(context);
                    },
                    child: const Text("Save Credit", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- UI HELPERS ---
  Widget _buildDialogInput(TextEditingController ctrl, String lbl, IconData icon, {bool isNum = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      decoration: InputDecoration(
        labelText: lbl, prefixIcon: Icon(icon, color: _primaryColor, size: 20),
        filled: true, fillColor: _primaryColor.withOpacity(0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
            width: 60, height: 60,
            decoration: BoxDecoration(shape: BoxShape.circle, color: isSelected ? _primaryColor : Colors.white, border: Border.all(color: isSelected ? _primaryColor : _cardBorder, width: 2)),
            child: Icon(icon, color: isSelected ? Colors.white : _primaryColor, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? _primaryColor : Colors.black87)),
        ],
      ),
    );
  }

  // --- FIRESTORE LOGIC ---
  Future<void> _processTransaction(double amount, double oldBalance, double oldTotalSales, String method) async {
    try {
      final customersCollection = await FirestoreService().getStoreCollection('customers');
      final creditsCollection = await FirestoreService().getStoreCollection('credits');
      final customerRef = customersCollection.doc(widget.customerId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.update(customerRef, {
          'balance': oldBalance + amount,
          'totalSales': oldTotalSales + amount,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      });

      await creditsCollection.add({
        'customerId': widget.customerId, 'customerName': widget.customerData['name'], 'amount': amount,
        'type': 'add_credit', 'method': method, 'timestamp': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Credit Added Successfully')));
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
  }

  // --- BUILD ---
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentReference>(
      future: FirestoreService().getDocumentReference('customers', widget.customerId),
      builder: (context, docRefSnapshot) {
        if (!docRefSnapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        return StreamBuilder<DocumentSnapshot>(
          stream: docRefSnapshot.data!.snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
            if (!snapshot.data!.exists) return const Scaffold(body: Center(child: Text("Customer not found")));

            var data = snapshot.data!.data() as Map<String, dynamic>;
            double balance = (data['balance'] ?? 0).toDouble();
            double totalSales = (data['totalSales'] ?? 0).toDouble();

            return Scaffold(
              backgroundColor: _scaffoldBg,
              appBar: AppBar(
                title: Text(context.tr('customerdetails'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                backgroundColor: _primaryColor, elevation: 0, centerTitle: true,
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              body: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          // HEADER CARD
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _cardBorder),
                              boxShadow: [BoxShadow(color: _primaryColor.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text(data['name'] ?? 'Unknown', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                                    Row(
                                      children: [
                                        IconButton(icon: const Icon(Icons.edit_outlined, color: _primaryColor), onPressed: () => _showEditDialog(context, data['name'], data['gst'])),
                                        IconButton(icon: const Icon(Icons.delete_outline, color: _drColor), onPressed: () => _confirmDelete(context)),
                                      ],
                                    )
                                  ],
                                ),
                                const Divider(height: 32, color: _cardBorder),
                                _buildSummaryDetail("Phone", data['phone'] ?? '--', Icons.phone_android_outlined),
                                const SizedBox(height: 12),
                                _buildSummaryDetail("GST No", data['gst'] ?? '---', Icons.description_outlined),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    _buildBalanceBox("Total Sales", totalSales, _crColor), // GREEN
                                    const SizedBox(width: 12),
                                    _buildBalanceBox("Outstanding", balance, _drColor),   // RED
                                  ],
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // MENU
                          _buildMenuItem("Bills", Icons.receipt_long_outlined, context),
                          const SizedBox(height: 12),
                          _buildMenuItem("Credit Details", Icons.history_edu_outlined, context),
                          const SizedBox(height: 12),
                          _buildMenuItem("ledger", Icons.account_balance_wallet_outlined, context),
                        ],
                      ),
                    ),
                  ),
                  _buildBottomBar(balance, totalSales),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryDetail(String l, String v, IconData i) {
    return Row(children: [
      Icon(i, size: 18, color: _primaryColor.withOpacity(0.7)),
      const SizedBox(width: 8),
      Text("$l: ", style: const TextStyle(color: Colors.black54)),
      Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _buildBalanceBox(String lbl, double amt, Color c) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: c.withOpacity(0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withOpacity(0.15))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(lbl, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c)),
          const SizedBox(height: 6),
          Text("₹${amt.toStringAsFixed(2)}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c)),
        ]),
      ),
    );
  }

  Widget _buildMenuItem(String title, IconData icon, BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _cardBorder)),
      child: ListTile(
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: _primaryColor, size: 20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        trailing: const Icon(Icons.chevron_right, color: _primaryColor),
        onTap: () {
          if (title == "Bills") Navigator.push(context, CupertinoPageRoute(builder: (_) => CustomerBillsPage(phone: widget.customerId)));
          else if (title == "Credit Details") Navigator.push(context, CupertinoPageRoute(builder: (_) => CustomerCreditsPage(customerId: widget.customerId)));
          else if (title == "ledger") Navigator.push(context, CupertinoPageRoute(builder: (_) => CustomerLedgerPage(customerId: widget.customerId, customerName: widget.customerData['name'])));
        },
      ),
    );
  }

  Widget _buildBottomBar(double balance, double totalSales) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))]),
      child: Row(children: [
        Expanded(child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () => _showAddCreditModal(context, balance, totalSales),
          child: const Text("Add Credit", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        )),
        const SizedBox(width: 12),
        Expanded(child: OutlinedButton(
          style: OutlinedButton.styleFrom(side: const BorderSide(color: _primaryColor, width: 2), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () {
            Navigator.push(context, CupertinoPageRoute(builder: (context) => _ReceiveCreditPage(customerId: widget.customerId, customerData: widget.customerData, currentBalance: balance, currentTotalSales: totalSales)));
          },
          child: const Text("Receive Credit", style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)),
        )),
      ]),
    );
  }
}

// =============================================================================
// SUB-PAGE: RECEIVE CREDIT FORM
// =============================================================================

class _ReceiveCreditPage extends StatefulWidget {
  final String customerId; final Map<String, dynamic> customerData; final double currentBalance; final double currentTotalSales;
  const _ReceiveCreditPage({required this.customerId, required this.customerData, required this.currentBalance, required this.currentTotalSales});

  @override
  State<_ReceiveCreditPage> createState() => _ReceiveCreditPageState();
}

class _ReceiveCreditPageState extends State<_ReceiveCreditPage> {
  final TextEditingController _amountController = TextEditingController();
  double _enteredAmount = 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Receive Payment", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: _primaryColor, iconTheme: const IconThemeData(color: Colors.white), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.customerData['name'] ?? 'Unknown', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _primaryColor)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: _drColor.withOpacity(0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: _drColor.withOpacity(0.1))),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("Outstanding", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text("₹${widget.currentBalance.toStringAsFixed(2)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _drColor)),
            ]),
          ),
          const SizedBox(height: 32),
          const Text("Amount Received:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) => setState(() { _enteredAmount = double.tryParse(v) ?? 0.0; }),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _primaryColor),
            decoration: InputDecoration(prefixText: "₹ ", filled: true, fillColor: _primaryColor.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
          ),
          const Spacer(),
          SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (_enteredAmount <= 0) return;
              final cCol = await FirestoreService().getStoreCollection('customers');
              final crCol = await FirestoreService().getStoreCollection('credits');
              await cCol.doc(widget.customerId).update({'balance': widget.currentBalance - _enteredAmount});
              await crCol.add({
                'customerId': widget.customerId, 'customerName': widget.customerData['name'], 'amount': _enteredAmount,
                'type': 'payment_received', 'method': 'Cash', 'timestamp': FieldValue.serverTimestamp(),
              });
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Confirm Payment", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          )),
        ]),
      ),
    );
  }
}

// =============================================================================
// SUB-PAGE: REAL ACCOUNTING LEDGER
// =============================================================================

class LedgerItem {
  final DateTime date; final String particulars; final double debit; final double credit; double balance;
  LedgerItem({required this.date, required this.particulars, required this.debit, required this.credit, this.balance = 0});
}

class CustomerLedgerPage extends StatefulWidget {
  final String customerId; final String customerName;
  const CustomerLedgerPage({super.key, required this.customerId, required this.customerName});

  @override
  State<CustomerLedgerPage> createState() => _CustomerLedgerPageState();
}

class _CustomerLedgerPageState extends State<CustomerLedgerPage> {
  List<LedgerItem> _items = []; bool _loading = true;

  @override
  void initState() { super.initState(); _fetchLedger(); }

  Future<void> _fetchLedger() async {
    final sCol = await FirestoreService().getStoreCollection('sales');
    final cCol = await FirestoreService().getStoreCollection('credits');
    final res = await Future.wait([sCol.where('customerPhone', isEqualTo: widget.customerId).get(), cCol.where('customerId', isEqualTo: widget.customerId).get()]);
    List<LedgerItem> items = [];
    for (var d in res[0].docs) {
      final data = d.data() as Map<String, dynamic>; double amt = (data['total'] ?? 0).toDouble();
      items.add(LedgerItem(date: (data['timestamp'] as Timestamp).toDate(), particulars: "Invoice #${data['invoiceNumber']}", debit: amt, credit: 0));
      if (data['paymentMode'] == 'Cash' || data['paymentMode'] == 'Online') items.add(LedgerItem(date: (data['timestamp'] as Timestamp).toDate(), particulars: "Paid - Inv #${data['invoiceNumber']}", debit: 0, credit: amt));
    }
    for (var d in res[1].docs) {
      final data = d.data() as Map<String, dynamic>;
      if (data['type'] == 'payment_received') items.add(LedgerItem(date: (data['timestamp'] as Timestamp).toDate(), particulars: "Paid (${data['method']})", debit: 0, credit: (data['amount'] ?? 0).toDouble()));
    }
    items.sort((a, b) => a.date.compareTo(b.date));
    double running = 0; for (var i in items) { running += i.debit - i.credit; i.balance = running; }
    setState(() { _items = items.reversed.toList(); _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text("${widget.customerName} Ledger", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: _primaryColor, iconTheme: const IconThemeData(color: Colors.white), elevation: 0),
      body: _loading ? const Center(child: CircularProgressIndicator()) : Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(color: _primaryColor.withOpacity(0.06), border: const Border(bottom: BorderSide(color: _cardBorder))),
          child: const Row(children: [
            Expanded(flex: 2, child: Text("Date", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            Expanded(flex: 3, child: Text("Particulars", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            Expanded(flex: 2, child: Text("Dr (-)", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _drColor))),
            Expanded(flex: 2, child: Text("Cr (+)", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _crColor))),
            Expanded(flex: 2, child: Text("Balance", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          ]),
        ),
        Expanded(child: ListView.builder(
          itemCount: _items.length,
          itemBuilder: (c, i) {
            final item = _items[i];
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F8FE)))),
              child: Row(children: [
                Expanded(flex: 2, child: Text(DateFormat('dd/MM/yy').format(item.date), style: const TextStyle(fontSize: 12))),
                Expanded(flex: 3, child: Text(item.particulars, style: const TextStyle(fontSize: 11, color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Expanded(flex: 2, child: Text(item.debit > 0 ? item.debit.toStringAsFixed(0) : "-", textAlign: TextAlign.right, style: const TextStyle(color: _drColor, fontWeight: FontWeight.w600))),
                Expanded(flex: 2, child: Text(item.credit > 0 ? item.credit.toStringAsFixed(0) : "-", textAlign: TextAlign.right, style: const TextStyle(color: _crColor, fontWeight: FontWeight.w600))),
                Expanded(flex: 2, child: Text(item.balance.toStringAsFixed(0), textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: item.balance > 0 ? _drColor : _crColor))),
              ]),
            );
          },
        )),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("Closing Balance:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text("₹${(_items.isNotEmpty ? _items.first.balance : 0).toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: (_items.isNotEmpty && _items.first.balance > 0) ? _drColor : _crColor)),
          ]),
        ),
      ]),
    );
  }
}

// =============================================================================
// SUB-PAGE: BILLS & CREDITS LISTS
// =============================================================================

class CustomerBillsPage extends StatelessWidget {
  final String phone; const CustomerBillsPage({super.key, required this.phone});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Bill History", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: _primaryColor, iconTheme: const IconThemeData(color: Colors.white)),
      body: FutureBuilder<QuerySnapshot>(
        future: FirestoreService().getStoreCollection('sales').then((c) => c.where('customerPhone', isEqualTo: phone).get()),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16), itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _cardBorder)),
                child: ListTile(
                  title: Text("Invoice #${data['invoiceNumber']}", style: const TextStyle(fontWeight: FontWeight.bold, color: _primaryColor)),
                  subtitle: Text(DateFormat('dd MMM yyyy').format((data['timestamp'] as Timestamp).toDate())),
                  trailing: Text("₹${data['total']}", style: const TextStyle(fontWeight: FontWeight.bold, color: _crColor, fontSize: 16)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CustomerCreditsPage extends StatelessWidget {
  final String customerId; const CustomerCreditsPage({super.key, required this.customerId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Payment History", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: _primaryColor, iconTheme: const IconThemeData(color: Colors.white)),
      body: FutureBuilder<QuerySnapshot>(
        future: FirestoreService().getStoreCollection('credits').then((c) => c.where('customerId', isEqualTo: customerId).get()),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16), itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>; bool isPayment = data['type'] == 'payment_received';
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: isPayment ? _crColor.withOpacity(0.05) : _drColor.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: isPayment ? _crColor.withOpacity(0.1) : _drColor.withOpacity(0.1))),
                child: ListTile(
                  leading: Icon(isPayment ? Icons.arrow_downward : Icons.arrow_upward, color: isPayment ? _crColor : _drColor),
                  title: Text(isPayment ? "Payment Received" : "Credit Added", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(DateFormat('dd MMM yyyy').format((data['timestamp'] as Timestamp).toDate())),
                  trailing: Text("₹${data['amount']}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isPayment ? _crColor : _drColor)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}