import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';

// --- IMPORTS FROM YOUR PROJECT ---
// Update these paths to match your actual project structure
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/Sales/Invoice.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/models/sale.dart';
import 'package:maxbillup/services/sale_sync_service.dart';
import 'package:maxbillup/services/local_stock_service.dart';
import 'package:maxbillup/services/number_generator_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/utils/plan_permission_helper.dart';

// --- CONSTANTS FOR STYLING ---
const Color kPrimaryColor = Color(0xFF2F7CF6);
const Color kBackgroundColor = Color(0xFFF8F9FA);
const Color kCardColor = Colors.white;
const Color kTextColor = Color(0xFF333333);
const double kRadius = 16.0;

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
  List<Map<String, dynamic>> _selectedCreditNotes = [];
  double _totalCreditNotesAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _uid = widget.uid;

    if (widget.discountAmount != null) {
      _discountAmount = widget.discountAmount!;
    }
    if (widget.customerPhone != null) {
      _selectedCustomerPhone = widget.customerPhone;
      _selectedCustomerName = widget.customerName;
      _selectedCustomerGST = widget.customerGST;
    }
  }

  // --- CALCULATIONS ---

  // Calculate subtotal (without tax)
  double get _subtotal {
    return widget.cartItems.fold(0.0, (sum, item) {
      if (item.taxType == 'Price includes Tax') {
        // Remove tax from price to get base amount
        return sum + (item.basePrice * item.quantity);
      } else {
        // Price is already without tax
        return sum + item.total;
      }
    });
  }

  // Calculate total tax amount
  double get _totalTax {
    return widget.cartItems.fold(0.0, (sum, item) => sum + item.taxAmount);
  }

  // Calculate total with tax
  double get _totalWithTax {
    return widget.cartItems.fold(0.0, (sum, item) => sum + item.totalWithTax);
  }

  double get _finalAmount {
    final amountAfterDiscount = _totalWithTax - _discountAmount;
    final creditToApply = _totalCreditNotesAmount > amountAfterDiscount
        ? amountAfterDiscount
        : _totalCreditNotesAmount;
    return amountAfterDiscount - creditToApply;
  }

  double get _actualCreditUsed {
    final amountAfterDiscount = _totalWithTax - _discountAmount;
    return _totalCreditNotesAmount > amountAfterDiscount
        ? amountAfterDiscount
        : _totalCreditNotesAmount;
  }

  // --- DIALOGS ---
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
    final TextEditingController percentController = TextEditingController();
    final TextEditingController amountController = TextEditingController(
      text: _discountAmount > 0 ? _discountAmount.toString() : '',
    );
    double total = widget.totalAmount;
    bool isPercentEditing = false;
    bool isAmountEditing = false;

    void updateFromPercent() {
      if (isPercentEditing) return;
      isPercentEditing = true;
      double percent = double.tryParse(percentController.text) ?? 0.0;
      double amount = (percent / 100.0) * total;
      amountController.text = amount > 0 ? amount.toStringAsFixed(2) : '';
      isPercentEditing = false;
    }

    void updateFromAmount() {
      if (isAmountEditing) return;
      isAmountEditing = true;
      double amount = double.tryParse(amountController.text) ?? 0.0;
      double percent = total > 0 ? (amount / total) * 100.0 : 0.0;
      percentController.text = percent > 0 ? percent.toStringAsFixed(2) : '';
      isAmountEditing = false;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('discount'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: percentController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '${context.tr('discount')} (%)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.percent),
                ),
                onChanged: (val) => updateFromPercent(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '${context.tr('discount')} ${context.tr('amount')}',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.money_off),
                ),
                onChanged: (val) => updateFromAmount(),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.tr('cancel')),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      double amount = double.tryParse(amountController.text) ?? 0.0;
                      setState(() => _discountAmount = amount);
                      Navigator.pop(context);
                    },
                    child: Text(context.tr('apply'), style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreditNoteDialog() {
    final TextEditingController noteController = TextEditingController(text: _creditNote);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('add_internal_note')),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Note',
            border: OutlineInputBorder(),
            hintText: 'e.g. Delivered to...',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('cancel'))),
          ElevatedButton(
            onPressed: () {
              setState(() => _creditNote = noteController.text);
              Navigator.pop(context);
            },
            child: Text(context.tr('save')),
          ),
        ],
      ),
    );
  }

  void _showCreditNotesDialog() {
    if (_selectedCustomerPhone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer first'), backgroundColor: Colors.orange),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.tr('available_credit_notes')),
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
                      return const Center(child: Text('No notes found'));
                    }

                    final creditNotes = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['customerPhone'] == _selectedCustomerPhone &&
                          data['status'] == 'Available';
                    }).toList();

                    if (creditNotes.isEmpty) {
                      return const Center(child: Text('No available credit notes'));
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
                            title: Text('CN: $creditNoteNumber', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Amt: Rs ${amount.toStringAsFixed(2)}'),
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
                setDialogState(() {
                  _selectedCreditNotes.clear();
                  _totalCreditNotesAmount = 0.0;
                });
                Navigator.pop(context);
              },
              child: Text(context.tr('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {});
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _clearOrder() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('clear_order')),
        content: const Text('Are you sure you want to discard this bill?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('cancel'))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- NAVIGATION ---
  void _proceedToPayment(String paymentMode) {
    // FIX: Using Navigator.push instead of push to prevent black screen on back
    final route = CupertinoPageRoute(
      builder: (context) => paymentMode == 'Split'
          ? SplitPaymentPage(
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
        quotationId: widget.quotationId,
      )
          : PaymentPage(
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
        quotationId: widget.quotationId,
      ),
    );
    Navigator.push(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,

        title: const Text(
          'Bill Summary',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _clearOrder,
            tooltip: "Clear Order",
          )
        ],
      ),
      body: Column(
        children: [
          // 1. Customer Section
          _buildCustomerSection(),

          // 2. Items List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: widget.cartItems.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return _buildItemRow(widget.cartItems[index]);
              },
            ),
          ),

          // 3. Bottom Summary Panel
          _buildBottomPanel(),
        ],
      ),
    );
  }

  Widget _buildCustomerSection() {
    final bool hasCustomer = _selectedCustomerName != null;
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: InkWell(
        onTap: _showCustomerDialog,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hasCustomer ? kPrimaryColor.withOpacity(0.08) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasCustomer ? kPrimaryColor.withOpacity(0.3) : Colors.grey[300]!,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: hasCustomer ? kPrimaryColor : Colors.grey[300],
                radius: 20,
                child: Icon(hasCustomer ? Icons.person : Icons.person_add, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasCustomer ? _selectedCustomerName! : 'Assign Customer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: hasCustomer ? kTextColor : Colors.grey[600],
                    ),
                  ),
                  if (hasCustomer)
                    Text(
                      _selectedCustomerPhone ?? '',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                ],
              ),
              const Spacer(),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemRow(CartItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: kBackgroundColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${item.quantity}x', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                Row(
                  children: [
                    Text(
                      '@ ${item.price.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    if (item.taxPercentage != null && item.taxPercentage! > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${item.taxPercentage}% ${item.taxName ?? 'Tax'}',
                          style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.totalWithTax.toStringAsFixed(2),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (item.taxAmount > 0)
                Text(
                  '(+${item.taxAmount.toStringAsFixed(2)} tax)',
                  style: TextStyle(color: Colors.grey[600], fontSize: 10),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(height: 4, width: 40, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Totals
                _buildSummaryRow('Subtotal', _subtotal.toStringAsFixed(2)),
                const SizedBox(height: 8),

                // Show tax if applicable
                if (_totalTax > 0) ...[
                  _buildSummaryRow('Tax', _totalTax.toStringAsFixed(2)),
                  const SizedBox(height: 8),
                ],

                _buildClickableRow('Discount', '- ${_discountAmount.toStringAsFixed(2)}', Colors.green, _showDiscountDialog),
                const SizedBox(height: 8),
                if (_selectedCreditNotes.isNotEmpty)
                  _buildClickableRow(
                    'Credit Notes (${_selectedCreditNotes.length})',
                    '- ${_actualCreditUsed.toStringAsFixed(2)}',
                    Colors.orange,
                    _showCreditNotesDialog,
                  )
                else
                  GestureDetector(
                    onTap: _showCreditNotesDialog,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Credit Notes', style: TextStyle(color: Colors.grey, fontSize: 14)),
                        Row(
                          children: [
                            Text('Apply', style: TextStyle(color: kPrimaryColor, fontSize: 14)),
                            SizedBox(width: 4),
                            Icon(Icons.add_circle_outline, size: 16, color: kPrimaryColor),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Divider and Note
                const SizedBox(height: 12),
                const Divider(),
                GestureDetector(
                  onTap: _showCreditNoteDialog,
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note, size: 18, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _creditNote.isEmpty ? 'Add internal note...' : _creditNote,
                          style: TextStyle(color: _creditNote.isEmpty ? Colors.grey : kTextColor, fontStyle: FontStyle.italic, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),

                // Grand Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Payable', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                      'Rs ${_finalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kPrimaryColor),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Payment Methods
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPayBtn(Icons.money, 'Cash', () => _proceedToPayment('Cash')),
                    _buildPayBtn(Icons.qr_code_2, 'Online', () => _proceedToPayment('Online')),
                    _buildPayBtn(Icons.schedule, 'Later', () => _proceedToPayment('Set later')),
                    _buildPayBtn(Icons.credit_score, 'Credit', () => _proceedToPayment('Credit')),
                    _buildPayBtn(Icons.call_split, 'Split', () => _proceedToPayment('Split')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildClickableRow(String label, String value, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              const SizedBox(width: 4),
              const Icon(Icons.edit, size: 14, color: kPrimaryColor),
            ],
          ),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildPayBtn(IconData icon, String label, VoidCallback onTap) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: kBackgroundColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Icon(icon, color: kPrimaryColor, size: 24),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kTextColor)),
      ],
    );
  }
}

// ==========================================
// 2. CUSTOMER SELECTION DIALOG
// ==========================================
class _CustomerSelectionDialog extends StatefulWidget {
  final String uid;
  final Function(String phone, String name, String? gst) onCustomerSelected;
  const _CustomerSelectionDialog({required this.uid, required this.onCustomerSelected});
  @override
  State<_CustomerSelectionDialog> createState() => _CustomerSelectionDialogState();
}

class _CustomerSelectionDialogState extends State<_CustomerSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // For pre-filling add customer dialog
  String? _prefillName;
  String? _prefillPhone;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _importFromContacts() async {
    // Check plan permission first (async)
    final canImport = await PlanPermissionHelper.canImportContacts();
    if (!canImport) {
      PlanPermissionHelper.showUpgradeDialog(context, 'Import Contacts');
      return;
    }

    if (!await FlutterContacts.requestPermission()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contacts permission denied'), backgroundColor: Colors.red),
      );
      return;
    }
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No contacts found'), backgroundColor: Colors.orange),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) {
        List<Contact> filteredContacts = contacts;
        final TextEditingController contactSearchController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void filterContacts(String query) {
              setDialogState(() {
                filteredContacts = contacts.where((c) {
                  final name = c.displayName.toLowerCase();
                  final phone = c.phones.isNotEmpty ? c.phones.first.number.replaceAll(' ', '').toLowerCase() : '';
                  return name.contains(query.toLowerCase()) || phone.contains(query.toLowerCase());
                }).toList();
              });
            }
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: SizedBox(
                width: 350,
                height: 500,
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Select Contact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        controller: contactSearchController,
                        decoration: const InputDecoration(
                          hintText: 'Search by name or phone',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: filterContacts,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredContacts.length,
                        itemBuilder: (context, index) {
                          final c = filteredContacts[index];
                          final phone = c.phones.isNotEmpty ? c.phones.first.number.replaceAll(' ', '') : '';
                          return ListTile(
                            title: Text(c.displayName),
                            subtitle: Text(phone),
                            onTap: phone.isNotEmpty
                                ? () {
                                    setState(() {
                                      _prefillName = c.displayName;
                                      _prefillPhone = phone;
                                    });
                                    Navigator.pop(context);
                                    _showAddCustomerDialog();
                                  }
                                : null,
                            enabled: phone.isNotEmpty,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddCustomerDialog() {
    final nameCtrl = TextEditingController(text: _prefillName ?? '');
    final phoneCtrl = TextEditingController(text: _prefillPhone ?? '');
    final gstCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
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
                    onPressed: () => Navigator.pop(context),
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
                        if (mounted) {
                          Navigator.pop(context);
                          widget.onCustomerSelected(phoneCtrl.text.trim(), nameCtrl.text.trim(), gstCtrl.text.trim());
                        }
                      } catch (e) {
                        // Handle error
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
      ).then((_) {
      // Clear prefill after dialog closes
      setState(() {
        _prefillName = null;
        _prefillPhone = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
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
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: context.tr('search'),
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _showAddCustomerDialog,
                  icon: const Icon(Icons.person_add, color: kPrimaryColor),
                  style: IconButton.styleFrom(backgroundColor: kPrimaryColor.withOpacity(0.1)),
                  tooltip: 'Add Customer',
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _importFromContacts,
                  icon: const Icon(Icons.import_contacts, color: kPrimaryColor),
                  style: IconButton.styleFrom(backgroundColor: kPrimaryColor.withOpacity(0.1)),
                  tooltip: 'Import from Contacts',
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
                        if (_searchQuery.isEmpty) return true;
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['name'] ?? '').toString().toLowerCase();
                        final phone = (data['phone'] ?? '').toString().toLowerCase();
                        final gst = (data['gst'] ?? '').toString().toLowerCase();
                        return name.contains(_searchQuery) || phone.contains(_searchQuery) || gst.contains(_searchQuery);
                      }).toList();

                      return ListView.separated(
                        itemCount: customers.length,
                        separatorBuilder: (ctx, i) => const Divider(),
                        itemBuilder: (context, index) {
                          final data = customers[index].data() as Map<String, dynamic>;
                          return ListTile(
                            onTap: () {
                              widget.onCustomerSelected(data['phone'], data['name'], data['gst']);
                              Navigator.pop(context);
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
  }
}

// ==========================================
// 3. SPLIT PAYMENT PAGE
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
  final String? quotationId;

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
    this.quotationId,
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
    // Use credit automatically if customer exists (convenience)
    if (widget.customerPhone != null) {
      _creditController.text = '0.00';
    }
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

  // --- HELPER LOGIC ---
  Future<String?> _fetchStaffName(String uid) async {
    try {
      final doc = await FirestoreService().usersCollection.doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        return data?['name'] as String?;
      }
    } catch (e) {
      return null;
    }
    return null;
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

  Future<Map<String, String?>> _fetchBusinessDetails() async {
    try {
      final storeId = await FirestoreService().getCurrentStoreId();
      if (storeId == null) return {'businessName': null, 'location': null, 'businessPhone': null};
      final doc = await FirestoreService().storeCollection.doc(storeId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        return {
          'businessName': data?['businessName'] as String?,
          'location': data?['location'] as String? ?? data?['businessLocation'] as String?,
          'businessPhone': data?['businessPhone'] as String?,
        };
      }
      return {'businessName': null, 'location': null, 'businessPhone': null};
    } catch (e) {
      debugPrint('Error fetching business details: $e');
      return {'businessName': null, 'location': null, 'businessPhone': null};
    }
  }

  Future<void> _updateCustomerCredit(String phone, double amount, String invoiceNumber) async {
    final customerRef = await FirestoreService().getDocumentReference('customers', phone);
    String customerName = 'Unknown';

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final customerDoc = await transaction.get(customerRef);
      if (customerDoc.exists) {
        customerName = (customerDoc.data() as Map<String, dynamic>?)?['name'] ?? 'Unknown';
        final currentBalance = (customerDoc.data() as Map<String, dynamic>?)?['balance'] as double? ?? 0.0;
        final newBalance = currentBalance + amount;
        transaction.update(customerRef, {
          'balance': newBalance,
          'lastUpdated': FieldValue.serverTimestamp()
        });
      }
    });

    final staffName = await _fetchStaffName(widget.uid);
    final businessDetails = await _fetchBusinessDetails();
    final businessLocation = businessDetails['location'];
    final businessPhone = businessDetails['businessPhone'];
    final businessName = businessDetails['businessName'];

    await FirestoreService().addDocument('credits', {
      'customerId': phone,
      'customerName': customerName,
      'amount': amount,
      'type': 'credit_sale',
      'method': 'Credit',
      'invoiceNumber': invoiceNumber,
      'timestamp': FieldValue.serverTimestamp(),
      'date': DateTime.now().toIso8601String(),
      'note': 'Split Payment - Inv #$invoiceNumber',
      'staffId': widget.uid,
      'staffName': staffName ?? 'Staff',
      'businessLocation': businessLocation ?? 'Tirunelveli',
      'businessPhone': businessPhone ?? '',
      'businessName': businessName ?? '',
    });
  }

  Future<void> _updateProductStock() async {
    try {
      print('🟢 [SplitPayment] Starting stock update for ${widget.cartItems.length} items...');
      final localStockService = context.read<LocalStockService>();

      for (var cartItem in widget.cartItems) {
        try {
          print('🟢 [SplitPayment] Updating stock for ${cartItem.name}, qty: -${cartItem.quantity}');
          final productRef = await FirestoreService().getDocumentReference('Products', cartItem.productId);

          // Decrement stock with timeout to prevent hanging in offline mode
          await productRef.update({'currentStock': FieldValue.increment(-(cartItem.quantity))})
              .timeout(const Duration(seconds: 3), onTimeout: () {
            print('🟢 [SplitPayment] Stock update timeout - continuing anyway');
          });
          print('🟢 [SplitPayment] ✓ Stock decremented for ${cartItem.name}');

          // Also update local cache so SaleAll page shows updated stock immediately
          await localStockService.updateLocalStock(cartItem.productId, -cartItem.quantity);

          // Best-effort clamp to zero - use cache to avoid hanging
          try {
            final snap = await productRef.get(const GetOptions(source: Source.cache))
                .timeout(const Duration(seconds: 2), onTimeout: () {
              throw TimeoutException('Cache timeout');
            });
            final current = (snap.data() as Map<String, dynamic>?)?['currentStock'] ?? 0;
            if ((current as num) < 0) {
              await productRef.update({'currentStock': 0})
                  .timeout(const Duration(seconds: 2), onTimeout: () {});
            }
          } catch (_) {}
        } catch (e) {
          debugPrint('🔴 [SplitPayment] Stock error for ${cartItem.productId}: $e');
        }
      }
      print('🟢 [SplitPayment] ✅ Stock update completed');
    } catch (e) {
      debugPrint('🔴 [SplitPayment] Stock update error: $e');
    }
  }

  Future<void> _updateProductStockLocally() async {
    try {
      print('📦 [SplitPayment] Starting LOCAL stock update for ${widget.cartItems.length} items...');
      final localStockService = context.read<LocalStockService>();

      for (var cartItem in widget.cartItems) {
        try {
          print('📦 [SplitPayment] Updating local stock for ${cartItem.name}, qty: -${cartItem.quantity}');
          await localStockService.updateLocalStock(cartItem.productId, -cartItem.quantity);
          print('📦 [SplitPayment] ✓ Local stock updated for ${cartItem.name}');
        } catch (e) {
          debugPrint('🔴 [SplitPayment] Local stock error for ${cartItem.productId}: $e');
        }
      }
      print('📦 [SplitPayment] ✅ Local stock update completed - UI will refresh!');
    } catch (e) {
      debugPrint('🔴 [SplitPayment] Local stock update error: $e');
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

  Future<void> _processSplitSale() async {
    if (_dueAmount > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment short by ${_dueAmount.toStringAsFixed(2)}'), backgroundColor: Colors.red));
      return;
    }
    if (_creditAmount > 0 && widget.customerPhone == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer required for Credit'), backgroundColor: Colors.red));
      return;
    }

    try {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

      // Generate sequential invoice number from backend
      final invoiceNumber = await NumberGeneratorService.generateInvoiceNumber();
      print('🟢 [SplitPayment] Generated invoice: $invoiceNumber');

      // Check connectivity with timeout
      bool isOnline = false;
      try {
        final connectivityResult = await Connectivity().checkConnectivity().timeout(
          const Duration(seconds: 2),
          onTimeout: () => [ConnectivityResult.none],
        );
        isOnline = !connectivityResult.contains(ConnectivityResult.none);
        print('🟢 [SplitPayment] Connectivity: $isOnline');
      } catch (e) {
        print('🔴 [SplitPayment] Connectivity check failed: $e');
        isOnline = false;
      }

      // Fetch business details from store-scoped backend
      final businessDetails = await _fetchBusinessDetails();
      String? staffName = await _fetchStaffName(widget.uid);
      String? businessLocation = businessDetails['location'];
      String? businessPhone = businessDetails['businessPhone'];
      String? businessName = businessDetails['businessName'];
      print('🟢 [SplitPayment] Using staff: $staffName, location: $businessLocation, phone: $businessPhone, name: $businessName');

      // Calculate tax information before creating sale data
      final Map<String, double> taxMap = {};
      for (var item in widget.cartItems) {
        if (item.taxAmount > 0 && item.taxName != null) {
          taxMap[item.taxName!] = (taxMap[item.taxName!] ?? 0.0) + item.taxAmount;
        }
      }
      final taxList = taxMap.entries.map((e) => {'name': e.key, 'amount': e.value}).toList();
      final totalTax = taxMap.values.fold(0.0, (a, b) => a + b);

      // Base sale data without Firestore-specific fields (includes tax info)
      final baseSaleData = {
        'invoiceNumber': invoiceNumber,
        'items': widget.cartItems.map((item) => {
          'productId': item.productId, 'name': item.name, 'price': item.price,
          'quantity': item.quantity, 'total': item.total,
        }).toList(),
        'subtotal': widget.totalAmount + widget.discountAmount,
        'discount': widget.discountAmount,
        'total': widget.totalAmount,
        'taxes': taxList, // Tax breakdown by name
        'totalTax': totalTax, // Total tax amount
        'paymentMode': 'Split',
        'cashReceived_split': _cashAmount,
        'onlineReceived_split': _onlineAmount,
        'creditIssued_split': _creditAmount,
        'cashReceived': _totalPaid - _creditAmount,
        'customerPhone': widget.customerPhone,
        'customerName': widget.customerName,
        'customerGST': widget.customerGST,
        'creditNote': widget.creditNote,
        'date': DateTime.now().toIso8601String(),
        'staffId': widget.uid,
        'staffName': staffName ?? 'Staff',
        'businessLocation': businessLocation ?? 'Tirunelveli',
        'businessPhone': businessPhone ?? '',
        'businessName': businessName ?? '',
        'savedOrderId': widget.savedOrderId,
        'selectedCreditNotes': widget.selectedCreditNotes,
        'quotationId': widget.quotationId,
      };

      if (isOnline) {
        // Add Firestore-specific timestamp for online saves
        final saleData = {
          ...baseSaleData,
          'timestamp': FieldValue.serverTimestamp(),
        };
        // Online: Save directly to Firestore
        try {
          // Handle Credit
          if (_creditAmount > 0 && widget.customerPhone != null) {
            await _updateCustomerCredit(widget.customerPhone!, _creditAmount, invoiceNumber).timeout(
              const Duration(seconds: 10),
            );
          }

          await FirestoreService().addDocument('sales', saleData).timeout(
            const Duration(seconds: 10),
          );

          await _updateProductStock().timeout(
            const Duration(seconds: 10),
          );

          if (widget.savedOrderId != null) {
            try {
              await FirestoreService().deleteDocument('savedOrders', widget.savedOrderId!).timeout(
                const Duration(seconds: 5),
              );
            } catch (e) {
              print('Error deleting saved order: $e');
            }
          }

          // Mark credit notes used
          if (widget.selectedCreditNotes.isNotEmpty) {
            try {
              await _markCreditNotesAsUsed(invoiceNumber, widget.selectedCreditNotes).timeout(
                const Duration(seconds: 5),
              );
            } catch (e) {
              print('Error marking credit notes: $e');
            }
          }

          if (widget.quotationId != null && widget.quotationId!.isNotEmpty) {
            try {
              await FirestoreService().updateDocument('quotations', widget.quotationId!, {
                'status': 'settled', 'billed': true, 'settledAt': FieldValue.serverTimestamp()
              }).timeout(
                const Duration(seconds: 5),
              );
            } catch (e) {
              print('Error updating quotation: $e');
            }
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sale completed successfully'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          // If online save fails, save offline
          print('Online save failed, saving offline: $e');
          final offlineSaleData = {
            ...baseSaleData,
            'timestamp': DateTime.now().toIso8601String(),
          };
          await _saveOfflineSale(invoiceNumber, offlineSaleData);
          // Update stock locally when offline
          await _updateProductStockLocally();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Saved offline. Will sync when online.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        // Offline: Save to local storage (use baseSaleData without Firestore-specific fields)
        final offlineSaleData = {
          ...baseSaleData,
          'timestamp': DateTime.now().toIso8601String(), // Use regular timestamp for offline
        };
        await _saveOfflineSale(invoiceNumber, offlineSaleData);
        // Update stock locally when offline
        await _updateProductStockLocally();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offline mode: Sale saved locally. Will sync when online.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }

      if (mounted) {
        print('🟢 [SplitPayment] Closing loading dialog');
        Navigator.pop(context); // loading
        // Pop back to root or Sales page
        Navigator.popUntil(context, (route) => route.isFirst);

        print('🟢 [SplitPayment] Navigating to invoice with business details: $businessName, $businessLocation, $businessPhone');

        // Calculate invoice display totals
        final subtotalAmount = widget.cartItems.fold(0.0, (sum, item) {
          if (item.taxType == 'Price includes Tax') {
            return sum + (item.basePrice * item.quantity);
          } else {
            return sum + item.total;
          }
        });
        final totalWithTax = widget.cartItems.fold(0.0, (sum, item) => sum + item.totalWithTax);

        // Tax info already included in sale data, just reuse for invoice display
        print('✅ [SplitPayment] Tax info already saved in sale data: $taxList, Total: $totalTax');

        // Show Invoice
        Navigator.push(context, CupertinoPageRoute(
            builder: (_) => InvoicePage(
              uid: widget.uid,
              userEmail: widget.userEmail,
              businessName: businessName ?? 'Business',
              businessLocation: businessLocation ?? 'Tirunelveli',
              businessPhone: businessPhone ?? '',
              invoiceNumber: invoiceNumber,
              dateTime: DateTime.now(),
              items: widget.cartItems.map((e)=> {
                'name':e.name,
                'quantity':e.quantity,
                'price':e.price,
                'total':e.totalWithTax,
                'taxPercentage':e.taxPercentage ?? 0,
                'taxAmount':e.taxAmount, // Actual tax amount per item
              }).toList(),
              subtotal: subtotalAmount,
              discount: widget.discountAmount,
              taxes: taxList, // Dynamic tax list grouped by name
              total: totalWithTax - widget.discountAmount,
              paymentMode: 'Split',
              cashReceived: _totalPaid - _creditAmount,
              customerName: widget.customerName,
              customerPhone: widget.customerPhone,
            )
        ));
      }

    } catch (e) {
      print('Error in _processSplitSale: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }


  Future<void> _saveOfflineSale(String invoiceNumber, Map<String, dynamic> saleData) async {
    try {
      final saleSyncService = Provider.of<SaleSyncService>(context, listen: false);

      // Create a Sale object for offline storage
      final sale = Sale(
        id: invoiceNumber,
        data: saleData,
        isSynced: false,
      );

      // Save to local storage
      await saleSyncService.saveSale(sale);
      print('Sale saved offline successfully (Split): $invoiceNumber');
    } catch (e) {
      print('Error saving offline sale to sync service (Split): $e');
      // Don't rethrow - allow invoice generation to continue
      // The sale data is still in memory and invoice can be generated
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isComplete = _dueAmount <= 0.01 && _dueAmount >= -0.01;
    bool isOverpaid = _dueAmount < -0.01;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(context.tr('split_payment'), style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Total Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kPrimaryColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: kPrimaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  Text(context.tr('total_bill_amount'), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('Rs ${widget.totalAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Inputs
            _buildSplitInput('Cash Received', Icons.money, _cashController),
            const SizedBox(height: 12),
            _buildSplitInput('Online / UPI', Icons.qr_code, _onlineController),
            const SizedBox(height: 12),
            _buildSplitInput('Credit Book', Icons.menu_book, _creditController, enabled: widget.customerPhone != null),
            if (widget.customerPhone == null)
              const Padding(
                padding: EdgeInsets.only(top: 4, left: 12),
                child: Align(alignment: Alignment.centerLeft, child: Text('* Select customer to use credit', style: TextStyle(color: Colors.orange, fontSize: 12))),
              ),

            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 10),

            // Summary
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Paid So Far', style: TextStyle(fontSize: 16)),
                Text(
                  _totalPaid.toStringAsFixed(2),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(isOverpaid ? 'Change to Return' : 'Remaining Due', style: const TextStyle(fontSize: 16)),
                Text(
                  (isOverpaid ? _dueAmount.abs() : _dueAmount).toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isComplete ? Colors.grey : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          height: 55,
          child: ElevatedButton(
            onPressed: (isComplete || isOverpaid) ? _processSplitSale : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              disabledBackgroundColor: Colors.grey[300],
            ),
            child: const Text('Settle Bill', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildSplitInput(String label, IconData icon, TextEditingController controller, {bool enabled = true}) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: enabled ? kPrimaryColor : Colors.grey),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryColor, width: 2)),
      ),
    );
  }
}

// ==========================================
// 5. PAYMENT PAGE (Calculated Style - Modernized)
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
  final String? quotationId;

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
    this.quotationId,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  double _cashReceived = 0.0;
  final TextEditingController _displayController = TextEditingController(text: '0.0');
  double get _change => _cashReceived - widget.totalAmount;

  @override
  void initState() {
    super.initState();
    if (widget.paymentMode == 'Cash' || widget.paymentMode == 'Online') {
      _cashReceived = widget.totalAmount;
      _displayController.text = widget.totalAmount.toStringAsFixed(1);
    } else {
      _cashReceived = 0.0;
      _displayController.text = '0.0';
    }
  }

  // --- LOGIC FOR KEYPAD ---
  void _onNumberPressed(String value) {
    setState(() {
      String currentText = _displayController.text;
      if (value == '.') {
        if (!currentText.contains('.')) _displayController.text += value;
      } else {
        if (currentText == '0.0' || currentText == '0') {
          _displayController.text = value;
        } else {
          _displayController.text += value;
        }
      }
      _cashReceived = double.tryParse(_displayController.text) ?? 0.0;
    });
  }

  void _onBackspace() {
    setState(() {
      String text = _displayController.text;
      if (text.isNotEmpty) {
        text = text.substring(0, text.length - 1);
        _displayController.text = text.isEmpty ? '0.0' : text;
        _cashReceived = double.tryParse(_displayController.text) ?? 0.0;
      }
    });
  }

  // Reuse similar helpers (Staff, Credit, Stock) as SplitPaymentPage
  Future<String?> _fetchStaffName(String uid) async {
    try {
      final doc = await FirestoreService().usersCollection.doc(uid).get();
      return (doc.data() as Map<String, dynamic>?)?['name'] as String?;
    } catch (e) { return null; }
  }

  Future<String?> _fetchBusinessLocation(String uid) async {
    try {
      final doc = await FirestoreService().getDocument('users', uid);
      return (doc.data() as Map<String, dynamic>?)?['businessName'] as String?;
    } catch (e) { return 'Tirunelveli'; }
  }

  Future<Map<String, String?>> _fetchBusinessDetails() async {
    try {
      final storeId = await FirestoreService().getCurrentStoreId();
      if (storeId == null) return {'businessName': null, 'location': null, 'businessPhone': null};
      final doc = await FirestoreService().storeCollection.doc(storeId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        return {
          'businessName': data?['businessName'] as String?,
          'location': data?['location'] as String? ?? data?['businessLocation'] as String?,
          'businessPhone': data?['businessPhone'] as String?,
        };
      }
      return {'businessName': null, 'location': null, 'businessPhone': null};
    } catch (e) {
      debugPrint('Error fetching business details: $e');
      return {'businessName': null, 'location': null, 'businessPhone': null};
    }
  }

  Future<void> _updateCustomerCredit(String phone, double amount, String invoiceNumber) async {
    final customerRef = await FirestoreService().getDocumentReference('customers', phone);
    String customerName = 'Unknown';

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final customerDoc = await transaction.get(customerRef);
      if (customerDoc.exists) {
        customerName = (customerDoc.data() as Map<String, dynamic>?)?['name'] ?? 'Unknown';
        final currentBalance = (customerDoc.data() as Map<String, dynamic>?)?['balance'] as double? ?? 0.0;
        final newBalance = currentBalance + amount;
        transaction.update(customerRef, {
          'balance': newBalance,
          'lastUpdated': FieldValue.serverTimestamp()
        });
      }
    });

    final staffName = await _fetchStaffName(widget.uid);
    final businessDetails = await _fetchBusinessDetails();
    final businessLocation = businessDetails['location'];
    final businessPhone = businessDetails['businessPhone'];
    final businessName = businessDetails['businessName'];

    await FirestoreService().addDocument('credits', {
      'customerId': phone,
      'customerName': customerName,
      'amount': amount,
      'type': 'credit_sale',
      'method': 'Credit',
      'invoiceNumber': invoiceNumber,
      'timestamp': FieldValue.serverTimestamp(),
      'date': DateTime.now().toIso8601String(),
      'note': 'Split Payment - Inv #$invoiceNumber',
      'staffId': widget.uid,
      'staffName': staffName ?? 'Staff',
      'businessLocation': businessLocation ?? 'Tirunelveli',
      'businessPhone': businessPhone ?? '',
      'businessName': businessName ?? '',
    });
  }

  Future<void> _updateProductStock() async {
    try {
      print('🔵 [PaymentPage] Starting stock update for ${widget.cartItems.length} items...');
      final localStockService = context.read<LocalStockService>();

      for (var cartItem in widget.cartItems) {
        try {
          print('🔵 [PaymentPage] Updating stock for ${cartItem.name}, qty: -${cartItem.quantity}');
          final productRef = await FirestoreService().getDocumentReference('Products', cartItem.productId);

          // Decrement stock with timeout to prevent hanging in offline mode
          await productRef.update({'currentStock': FieldValue.increment(-(cartItem.quantity))})
              .timeout(const Duration(seconds: 3), onTimeout: () {
            print('🔵 [PaymentPage] Stock update timeout - continuing anyway');
          });
          print('🔵 [PaymentPage] ✓ Stock decremented for ${cartItem.name}');

          // Also update local cache so SaleAll page shows updated stock immediately
          await localStockService.updateLocalStock(cartItem.productId, -cartItem.quantity);

          // Best-effort clamp to zero - use cache to avoid hanging
          try {
            final snap = await productRef.get(const GetOptions(source: Source.cache))
                .timeout(const Duration(seconds: 2), onTimeout: () {
              throw TimeoutException('Cache timeout');
            });
            final current = (snap.data() as Map<String, dynamic>?)?['currentStock'] ?? 0;
            if ((current as num) < 0) {
              await productRef.update({'currentStock': 0})
                  .timeout(const Duration(seconds: 2), onTimeout: () {});
            }
          } catch (_) {}
        } catch (e) {
          debugPrint('🔴 [PaymentPage] Stock error for ${cartItem.productId}: $e');
        }
      }
      print('🔵 [PaymentPage] ✅ Stock update completed');
    } catch (e) {
      debugPrint('🔴 [PaymentPage] Stock update error: $e');
    }
  }

  Future<void> _updateProductStockLocally() async {
    try {
      print('📦 [PaymentPage] Starting LOCAL stock update for ${widget.cartItems.length} items...');
      final localStockService = context.read<LocalStockService>();

      for (var cartItem in widget.cartItems) {
        try {
          print('📦 [PaymentPage] Updating local stock for ${cartItem.name}, qty: -${cartItem.quantity}');
          await localStockService.updateLocalStock(cartItem.productId, -cartItem.quantity);
          print('📦 [PaymentPage] ✓ Local stock updated for ${cartItem.name}');
        } catch (e) {
          debugPrint('🔴 [PaymentPage] Local stock error for ${cartItem.productId}: $e');
        }
      }
      print('📦 [PaymentPage] ✅ Local stock update completed - UI will refresh!');
    } catch (e) {
      debugPrint('🔴 [PaymentPage] Local stock update error: $e');
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

  Future<void> _completeSale() async {
    if (widget.paymentMode == 'Credit' && widget.customerPhone == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer required for Credit')));
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
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

      // Generate sequential invoice number from backend
      final invoiceNumber = await NumberGeneratorService.generateInvoiceNumber();
      print('🔵 [PaymentPage] Generated invoice: $invoiceNumber');

      // Check connectivity with timeout
      bool isOnline = false;
      try {
        final connectivityResult = await Connectivity().checkConnectivity().timeout(
          const Duration(seconds: 2),
          onTimeout: () => [ConnectivityResult.none],
        );
        isOnline = !connectivityResult.contains(ConnectivityResult.none);
        print('🔵 [PaymentPage] Connectivity: $isOnline');
      } catch (e) {
        print('🔴 [PaymentPage] Connectivity check failed: $e');
        isOnline = false;
      }

      // Fetch business details from store-scoped backend
      final businessDetails = await _fetchBusinessDetails();
      String? staffName = await _fetchStaffName(widget.uid);
      String? businessLocation = businessDetails['location'];
      String? businessPhone = businessDetails['businessPhone'];
      String? businessName = businessDetails['businessName'];
      print('🔵 [PaymentPage] Using staff: $staffName, location: $businessLocation, phone: $businessPhone, name: $businessName');

      final amountReceived = _cashReceived;  // Use actual cash received
      final changeGiven = _cashReceived > widget.totalAmount ? (_cashReceived - widget.totalAmount) : 0.0;  // Calculate actual change
      final creditAmount = widget.paymentMode == 'Credit' ? (widget.totalAmount - _cashReceived) : 0.0;  // Amount added to customer credit

      // Calculate tax information before creating sale data
      final Map<String, double> taxMap = {};
      for (var item in widget.cartItems) {
        if (item.taxAmount > 0 && item.taxName != null) {
          taxMap[item.taxName!] = (taxMap[item.taxName!] ?? 0.0) + item.taxAmount;
        }
      }
      final taxList = taxMap.entries.map((e) => {'name': e.key, 'amount': e.value}).toList();
      final totalTax = taxMap.values.fold(0.0, (a, b) => a + b);

      // Base sale data without Firestore-specific fields (includes tax info)
      final baseSaleData = {
        'invoiceNumber': invoiceNumber,
        'items': widget.cartItems.map((e)=> {'productId':e.productId, 'name':e.name, 'quantity':e.quantity, 'price':e.price, 'total':e.total}).toList(),
        'subtotal': widget.totalAmount + widget.discountAmount,
        'discount': widget.discountAmount,
        'total': widget.totalAmount,
        'taxes': taxList, // Tax breakdown by name
        'totalTax': totalTax, // Total tax amount
        'paymentMode': widget.paymentMode,
        'cashReceived': amountReceived,
        'change': changeGiven,
        'creditAmount': creditAmount,  // Amount added to customer credit balance
        'customerPhone': widget.customerPhone,
        'customerName': widget.customerName,
        'customerGST': widget.customerGST,
        'creditNote': widget.creditNote,
        'date': DateTime.now().toIso8601String(),
        'staffId': widget.uid,
        'staffName': staffName ?? 'Staff',
        'businessLocation': businessLocation ?? 'Tirunelveli',
        'businessPhone': businessPhone ?? '',
        'businessName': businessName ?? '',
        'savedOrderId': widget.savedOrderId,
        'selectedCreditNotes': widget.selectedCreditNotes,
        'quotationId': widget.quotationId,
      };

      if (isOnline) {
        // Add Firestore-specific timestamp for online saves
        final saleData = {
          ...baseSaleData,
          'timestamp': FieldValue.serverTimestamp(),
        };
        // Online: Save directly to Firestore
        try {
          print('🔵 [PaymentPage] Starting online save...');

          if (widget.paymentMode == 'Credit') {
            print('🔵 [PaymentPage] Updating customer credit...');
            // Calculate actual credit amount: totalAmount - cashReceived
            // If paymentMode is 'Credit', customer might have paid partial amount
            final creditAmount = widget.totalAmount - _cashReceived;
            if (creditAmount > 0) {
              await _updateCustomerCredit(widget.customerPhone!, creditAmount, invoiceNumber).timeout(
                const Duration(seconds: 10),
              );
            }
          }

          print('🔵 [PaymentPage] Adding sale document...');
          await FirestoreService().addDocument('sales', saleData).timeout(
            const Duration(seconds: 10),
          );

          print('🔵 [PaymentPage] Updating product stock...');
          await _updateProductStock().timeout(
            const Duration(seconds: 10),
          );

          if (widget.savedOrderId != null) {
            try {
              await FirestoreService().deleteDocument('savedOrders', widget.savedOrderId!).timeout(
                const Duration(seconds: 5),
              );
            } catch (e) {
              print('Error deleting saved order: $e');
            }
          }

          // Mark credit notes used
          if (widget.selectedCreditNotes.isNotEmpty) {
            try {
              await _markCreditNotesAsUsed(invoiceNumber, widget.selectedCreditNotes).timeout(
                const Duration(seconds: 5),
              );
            } catch (e) {
              print('Error marking credit notes: $e');
            }
          }

          if (widget.quotationId != null && widget.quotationId!.isNotEmpty) {
            try {
              await FirestoreService().updateDocument('quotations', widget.quotationId!, {
                'status': 'settled', 'billed': true, 'settledAt': FieldValue.serverTimestamp()
              }).timeout(
                const Duration(seconds: 5),
              );
            } catch (e) {
              print('Error updating quotation: $e');
            }
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sale completed successfully'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          // If online save fails, save offline
          print('Online save failed, saving offline: $e');
          final offlineSaleData = {
            ...baseSaleData,
            'timestamp': DateTime.now().toIso8601String(),
          };
          await _saveOfflineSale(invoiceNumber, offlineSaleData);
          // Update stock locally when offline
          await _updateProductStockLocally();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Saved offline. Will sync when online.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        // Offline: Save to local storage (use baseSaleData without Firestore-specific fields)
        print('🔵 [PaymentPage] OFFLINE MODE - Saving locally...');
        final offlineSaleData = {
          ...baseSaleData,
          'timestamp': DateTime.now().toIso8601String(), // Use regular timestamp for offline
        };
        await _saveOfflineSale(invoiceNumber, offlineSaleData);
        // Update stock locally when offline
        await _updateProductStockLocally();
        print('🔵 [PaymentPage] Offline save completed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offline mode: Sale saved locally. Will sync when online.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }

      if (mounted) {
        print('🔵 [PaymentPage] Closing loading dialog');
        Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog

        print('🔵 [PaymentPage] Navigating to invoice with business details: $businessName, $businessLocation, $businessPhone');

        // Calculate invoice display totals
        final subtotalAmount = widget.cartItems.fold(0.0, (sum, item) {
          if (item.taxType == 'Price includes Tax') {
            return sum + (item.basePrice * item.quantity);
          } else {
            return sum + item.total;
          }
        });
        final totalWithTax = widget.cartItems.fold(0.0, (sum, item) => sum + item.totalWithTax);

        // Tax info already included in sale data, just reuse for invoice display
        print('✅ [PaymentPage] Tax info already saved in sale data: $taxList, Total: $totalTax');

        // Show Invoice
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => InvoicePage(
              uid: widget.uid,
              userEmail: widget.userEmail,
              businessName: businessName ?? 'Business',
              businessLocation: businessLocation ?? 'Location',
              businessPhone: businessPhone ?? '',
              invoiceNumber: invoiceNumber,
              dateTime: DateTime.now(),
              items: widget.cartItems.map((e)=> {
                'name':e.name,
                'quantity':e.quantity,
                'price':e.price,
                'total':e.totalWithTax,
                'taxPercentage':e.taxPercentage ?? 0,
                'taxAmount':e.taxAmount, // Actual tax amount per item
              }).toList(),
              subtotal: subtotalAmount,
              discount: widget.discountAmount,
              taxes: taxList, // Dynamic tax list grouped by name
              total: totalWithTax - widget.discountAmount,
              paymentMode: widget.paymentMode,
              cashReceived: amountReceived,
              customerName: widget.customerName,
              customerPhone: widget.customerPhone,
            ),
          ),
        );
      }

    } catch (e) {
      print('Error in _completeSale: $e');
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog if error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _saveOfflineSale(String invoiceNumber, Map<String, dynamic> saleData) async {
    try {
      final saleSyncService = Provider.of<SaleSyncService>(context, listen: false);

      // Create a Sale object for offline storage
      final sale = Sale(
        id: invoiceNumber,
        data: saleData,
        isSynced: false,
      );

      // Save to local storage
      await saleSyncService.saveSale(sale);
      print('Sale saved offline successfully (Payment): $invoiceNumber');
    } catch (e) {
      print('Error saving offline sale to sync service (Payment): $e');
      // Don't rethrow - allow invoice generation to continue
      // The sale data is still in memory and invoice can be generated
    }
  }


  @override
  Widget build(BuildContext context) {
    bool canPay = widget.paymentMode == 'Credit' || _cashReceived >= widget.totalAmount;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text('${widget.paymentMode} Payment', style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),

          // Display Area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Text(context.tr('total_bill'), style: const TextStyle(color: Colors.grey)),
                Text(widget.totalAmount.toStringAsFixed(2), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // Input Display
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: canPay ? kPrimaryColor : Colors.grey[300]!, width: 2),
                  ),
                  child: Column(
                    children: [
                      const Text('Received Amount', style: TextStyle(color: Colors.grey)),
                      Text(
                        _displayController.text,
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: kTextColor),
                      ),
                    ],
                  ),
                ),

                // Change Display
                const SizedBox(height: 16),
                if (widget.paymentMode != 'Credit')
                  Text(
                    'Change:  ${_change > 0 ? _change.toStringAsFixed(2) : '0.00'}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _change >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
              ],
            ),
          ),

          const Spacer(),

          // Keypad
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              children: [
                _buildKeyRow(['1', '2', '3']),
                const SizedBox(height: 16),
                _buildKeyRow(['4', '5', '6']),
                const SizedBox(height: 16),
                _buildKeyRow(['7', '8', '9']),
                const SizedBox(height: 16),
                _buildKeyRow(['.', '0', 'back']),
                const SizedBox(height: 24),

                // Pay Button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: canPay ? _completeSale : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('Complete Sale', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      )
      );
  }

  Widget _buildKeyRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) {
        if (key == 'back') {
          return _buildKeyBtn(icon: Icons.backspace_outlined, onTap: _onBackspace);
        }
        return _buildKeyBtn(label: key, onTap: () => _onNumberPressed(key));
      }).toList(),
    );
  }

  Widget _buildKeyBtn({String? label, IconData? icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: kBackgroundColor,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, size: 28, color: Colors.grey[800])
              : Text(label!, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: kTextColor)),
        ),
      ),
    );
  }
}
