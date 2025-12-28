import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/Sales/QuotationPreview.dart';
import 'dart:math';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';

// --- UI CONSTANTS ---
const Color _primaryColor = Color(0xFF2F7CF6);
const Color _cardBorder = Color(0xFFE3F2FD);
const Color _scaffoldBg = Colors.white;

class QuotationPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final List<CartItem> cartItems;
  final double totalAmount;
  final String? customerPhone;
  final String? customerName;
  final String? customerGST;

  const QuotationPage({
    super.key,
    required this.uid,
    this.userEmail,
    required this.cartItems,
    required this.totalAmount,
    this.customerPhone,
    this.customerName,
    this.customerGST,
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

  late List<TextEditingController> _itemDiscountControllers;
  late List<double> _itemDiscounts;

  @override
  void initState() {
    super.initState();
    _uid = widget.uid;
    // Initialize with passed customer info
    _selectedCustomerPhone = widget.customerPhone;
    _selectedCustomerName = widget.customerName;
    _selectedCustomerGST = widget.customerGST;
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
      return _itemDiscounts.fold(0.0, (sum, discount) => sum + discount);
    }
    return 0.0;
  }

  double get _newTotal => widget.totalAmount - _discountAmount;

  double _getItemTotalAfterDiscount(int index) {
    final item = widget.cartItems[index];
    return item.total - _itemDiscounts[index];
  }

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

      final random = Random();
      final quotationNumber = (100000 + random.nextInt(900000)).toString();
      final staffName = await _fetchStaffName(widget.uid);

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
        'staffName': staffName ?? 'Staff',
        'status': 'active',
      };

      final docRef = await FirestoreService().addDocument('quotations', quotationData);

      try {
        await FirestoreService().updateDocument('quotations', docRef.id, {'quotationId': docRef.id});
      } catch (e) {
        debugPrint('Unable to write quotationId: $e');
      }

      if (mounted) {
        Navigator.pop(context);
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
              quotationDocId: docRef.id,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<String?> _fetchStaffName(String uid) async {
    try {
      final doc = await FirestoreService().usersCollection.doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        return data?['name'] as String?;
      }
    } catch (e) {
      debugPrint('Error fetching staff name: $e');
      return null;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'New Quotation',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: GestureDetector(
              onTap: _showCustomerDialog,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: _primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.person_add_outlined, color: _primaryColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedCustomerName ?? 'Add Customer Details',
                        style: TextStyle(
                          color: _selectedCustomerName != null ? Colors.black87 : Colors.grey[600],
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Discount Setup', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _buildToggleBtn('Bill Wise', _isBillWise, () => setState(() => _isBillWise = true)),
                        const SizedBox(width: 12),
                        _buildToggleBtn('Item Wise', !_isBillWise, () => setState(() => _isBillWise = false)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_isBillWise) ...[
                      _buildSummaryRow('Original Total', widget.totalAmount),
                      const SizedBox(height: 24),
                      _buildInputLabel('Cash Discount'),
                      _buildTextField(_cashDiscountController, 'Amount', (v) => _updateCashDiscount(), Icons.money),
                      const SizedBox(height: 16),
                      Center(child: Text('OR', style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold, fontSize: 12))),
                      const SizedBox(height: 16),
                      _buildInputLabel('Percentage Discount'),
                      _buildTextField(_percentageController, 'Percentage %', (v) => _updatePercentageDiscount(), Icons.percent),
                    ] else ...[
                      _buildInputLabel('Individual Item Discounts'),
                      const SizedBox(height: 12),
                      ...widget.cartItems.asMap().entries.map((entry) => _buildItemDiscountCard(entry.key, entry.value)),
                    ],
                    const SizedBox(height: 32),
                    _buildFinalSummary(),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _generateQuotation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Generate Quotation', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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

  Widget _buildToggleBtn(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? _primaryColor : _primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? _primaryColor : _cardBorder),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: isSelected ? Colors.white : _primaryColor, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)));

  Widget _buildTextField(TextEditingController ctrl, String hint, Function(String) onChange, IconData icon) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      onChanged: onChange,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: _primaryColor, size: 20),
        filled: true,
        fillColor: _primaryColor.withOpacity(0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildItemDiscountCard(int index, CartItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1)),
              Text('Qty: ${item.quantity}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Rs ${item.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              SizedBox(
                width: 100,
                height: 40,
                child: TextField(
                  controller: _itemDiscountControllers[index],
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _updateItemDiscount(index, v),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: 'Disc',
                    filled: true,
                    fillColor: _primaryColor.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w500)),
        Text('Rs ${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildFinalSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Discount', style: TextStyle(fontWeight: FontWeight.w500)),
              Text('- Rs ${_discountAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Final Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text('Rs ${_newTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: _primaryColor)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomerSelectionDialog extends StatefulWidget {
  final String uid;
  final Function(String phone, String name, String? gst) onCustomerSelected;

  const _CustomerSelectionDialog({required this.uid, required this.onCustomerSelected});

  @override
  State<_CustomerSelectionDialog> createState() => _CustomerSelectionDialogState();
}

class _CustomerSelectionDialogState extends State<_CustomerSelectionDialog> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select Customer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: context.tr('search'),
                prefixIcon: const Icon(Icons.search, color: _primaryColor),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<CollectionReference>(
                future: FirestoreService().getStoreCollection('customers'),
                builder: (context, collectionSnapshot) {
                  if (!collectionSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                  return StreamBuilder<QuerySnapshot>(
                    stream: collectionSnapshot.data!.orderBy('name').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final customers = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return (data['name'] ?? '').toString().toLowerCase().contains(_searchQuery) || (data['phone'] ?? '').toString().contains(_searchQuery);
                      }).toList();
                      if (customers.isEmpty) return const Center(child: Text('No customers found'));
                      return ListView.builder(
                        itemCount: customers.length,
                        itemBuilder: (context, index) {
                          final data = customers[index].data() as Map<String, dynamic>;
                          return ListTile(
                            leading: CircleAvatar(backgroundColor: _primaryColor.withOpacity(0.1), child: Text(data['name'][0].toUpperCase(), style: const TextStyle(color: _primaryColor))),
                            title: Text(data['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(data['phone'] ?? ''),
                            onTap: () {
                              widget.onCustomerSelected(data['phone'] ?? '', data['name'] ?? '', data['gst']);
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