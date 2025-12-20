import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/services/number_generator_service.dart';

// --- UI CONSTANTS ---
const Color _primaryColor = Color(0xFF2196F3);
const Color _cardBorder = Color(0xFFE3F2FD);
const Color _scaffoldBg = Colors.white;

class StockPurchasePage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;

  const StockPurchasePage({super.key, required this.uid, required this.onBack});

  @override
  State<StockPurchasePage> createState() => _StockPurchasePageState();
}

class _StockPurchasePageState extends State<StockPurchasePage> {
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  late Future<Stream<QuerySnapshot>> _purchasesStreamFuture;

  @override
  void initState() {
    super.initState();
    _purchasesStreamFuture = FirestoreService().getCollectionStream('stockPurchases');

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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: _primaryColor),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: AppBar(
        title: Text(context.tr('stock_purchase'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter & Add Button Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _cardBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_outlined, color: _primaryColor, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('dd - MM - yyyy').format(_selectedDate),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => CreateStockPurchasePage(
                          uid: widget.uid,
                          onBack: () => Navigator.pop(context),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add, color: Colors.white, size: 20),
                  label: const Text(
                    'New',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _cardBorder),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: context.tr('search'),
                  prefixIcon: const Icon(Icons.search, color: _primaryColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),

          // List of Purchases
          Expanded(
            child: FutureBuilder<Stream<QuerySnapshot>>(
              future: _purchasesStreamFuture,
              builder: (context, futureSnapshot) {
                if (futureSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!futureSnapshot.hasData) {
                  return const Center(child: Text("Unable to load purchases"));
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: futureSnapshot.data!,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyState();
                    }

                    final purchases = snapshot.data!.docs.where((doc) {
                      if (_searchQuery.isEmpty) return true;
                      final data = doc.data() as Map<String, dynamic>;
                      final supplierName = (data['supplierName'] ?? '').toString().toLowerCase();
                      final invoiceNumber = (data['invoiceNumber'] ?? '').toString().toLowerCase();
                      return supplierName.contains(_searchQuery) || invoiceNumber.contains(_searchQuery);
                    }).toList();

                    if (purchases.isEmpty) {
                      return const Center(
                        child: Text('No matching purchases found', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: purchases.length,
                      itemBuilder: (context, index) {
                        final data = purchases[index].data() as Map<String, dynamic>;
                        return _buildPurchaseCard(context, purchases[index].id, data);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseCard(BuildContext context, String id, Map<String, dynamic> data) {
    final date = (data['timestamp'] as Timestamp?)?.toDate();
    final dateString = date != null ? DateFormat('dd MMM yyyy').format(date) : 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        onTap: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => StockPurchaseDetailsPage(
                purchaseId: id,
                purchaseData: data,
              ),
            ),
          );
        },
        title: Text(
          data['supplierName'] ?? 'Unknown Supplier',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text('Invoice: ${data['invoiceNumber'] ?? 'N/A'}', style: const TextStyle(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 4),
            Text(dateString, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        trailing: Text(
          '₹${(data['totalAmount'] ?? 0.0).toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: _primaryColor.withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text('No stock purchases found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
        ],
      ),
    );
  }
}

class CreateStockPurchasePage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;

  const CreateStockPurchasePage({super.key, required this.uid, required this.onBack});

  @override
  State<CreateStockPurchasePage> createState() => _CreateStockPurchasePageState();
}

class _CreateStockPurchasePageState extends State<CreateStockPurchasePage> {
  final TextEditingController _supplierNameController = TextEditingController();
  final TextEditingController _supplierPhoneController = TextEditingController();
  final TextEditingController _invoiceNumberController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _paymentMode = 'Cash';
  bool _isLoading = false;

  @override
  void dispose() {
    _supplierNameController.dispose();
    _supplierPhoneController.dispose();
    _invoiceNumberController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: _primaryColor)),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _savePurchase() async {
    if (_supplierNameController.text.isEmpty || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in required fields')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text);
      final invoiceNumber = _invoiceNumberController.text.isEmpty
          ? 'INV${DateTime.now().millisecondsSinceEpoch}'
          : _invoiceNumberController.text;

      await FirestoreService().addDocument('stockPurchases', {
        'supplierName': _supplierNameController.text,
        'supplierPhone': _supplierPhoneController.text,
        'invoiceNumber': invoiceNumber,
        'totalAmount': amount,
        'paymentMode': _paymentMode,
        'notes': _notesController.text,
        'timestamp': Timestamp.fromDate(_selectedDate),
        'uid': widget.uid,
      });

      if (_paymentMode == 'Credit') {
        final creditNoteNumber = await NumberGeneratorService.generatePurchaseCreditNoteNumber();
        await FirestoreService().addDocument('purchaseCreditNotes', {
          'creditNoteNumber': creditNoteNumber,
          'invoiceNumber': invoiceNumber,
          'purchaseNumber': invoiceNumber,
          'supplierName': _supplierNameController.text,
          'supplierPhone': _supplierPhoneController.text,
          'amount': amount,
          'timestamp': Timestamp.fromDate(_selectedDate),
          'status': 'Available',
          'notes': _notesController.text,
          'uid': widget.uid,
          'type': 'Purchase Credit',
          'items': [],
        });

        if (_supplierPhoneController.text.isNotEmpty) {
          final suppliersCollection = await FirestoreService().getStoreCollection('suppliers');
          final supplierRef = suppliersCollection.doc(_supplierPhoneController.text);

          await FirebaseFirestore.instance.runTransaction((transaction) async {
            final supplierDoc = await transaction.get(supplierRef);
            if (supplierDoc.exists) {
              // Fix: Explicitly cast data() to Map<String, dynamic>? to use the [] operator
              final data = supplierDoc.data() as Map<String, dynamic>?;
              final currentBalance = (data?['creditBalance'] ?? 0.0) as num;
              transaction.update(supplierRef, {
                'creditBalance': currentBalance.toDouble() + amount,
                'lastUpdated': FieldValue.serverTimestamp(),
              });
            } else {
              transaction.set(supplierRef, {
                'name': _supplierNameController.text,
                'phone': _supplierPhoneController.text,
                'creditBalance': amount,
                'createdAt': FieldValue.serverTimestamp(),
                'lastUpdated': FieldValue.serverTimestamp(),
                'uid': widget.uid,
              });
            }
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_paymentMode == 'Credit'
                ? 'Stock purchase saved and credit note created'
                : 'Stock purchase saved successfully')));
        widget.onBack();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(context.tr('new_stock_purchase'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputField('Supplier Name *', _supplierNameController, Icons.person_outline),
            const SizedBox(height: 16),
            _buildInputField('Supplier Phone', _supplierPhoneController, Icons.phone_outlined,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
            _buildInputField('Invoice Number', _invoiceNumberController, Icons.receipt_long_outlined),
            const SizedBox(height: 16),
            _buildInputField('Amount *', _amountController, Icons.currency_rupee, keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            const Text('Date', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: _primaryColor.withOpacity(0.04), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, color: _primaryColor, size: 18),
                    const SizedBox(width: 12),
                    Text(DateFormat('dd MMM yyyy').format(_selectedDate),
                        style: const TextStyle(fontSize: 16, color: Colors.black87)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Payment Mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildDropdownContainer(
              child: DropdownButton<String>(
                value: _paymentMode,
                isExpanded: true,
                underline: const SizedBox(),
                items: ['Cash', 'Credit', 'UPI', 'Card'].map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) setState(() => _paymentMode = newValue);
                },
              ),
            ),
            const SizedBox(height: 16),
            _buildInputField('Notes', _notesController, Icons.notes_outlined, lines: 3),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _savePurchase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Purchase',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController ctrl, IconData icon,
      {TextInputType keyboardType = TextInputType.text, int lines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          maxLines: lines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: _primaryColor, size: 20),
            filled: true,
            fillColor: _primaryColor.withOpacity(0.04),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: _primaryColor.withOpacity(0.04), borderRadius: BorderRadius.circular(12)),
      child: child,
    );
  }
}

class StockPurchaseDetailsPage extends StatelessWidget {
  final String purchaseId;
  final Map<String, dynamic> purchaseData;

  const StockPurchaseDetailsPage({super.key, required this.purchaseId, required this.purchaseData});

  @override
  Widget build(BuildContext context) {
    final date = (purchaseData['timestamp'] as Timestamp?)?.toDate();
    final dateString = date != null ? DateFormat('dd MMM yyyy, h:mm a').format(date) : 'N/A';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(context.tr('purchase_details'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _cardBorder),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                purchaseData['supplierName'] ?? 'Unknown Supplier',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _primaryColor),
              ),
              const Divider(height: 32, color: _cardBorder),
              _buildDetailRow('Invoice', purchaseData['invoiceNumber'] ?? 'N/A'),
              _buildDetailRow('Phone', purchaseData['supplierPhone'] ?? 'N/A'),
              _buildDetailRow('Date', dateString),
              _buildDetailRow('Payment Mode', purchaseData['paymentMode'] ?? 'N/A'),
              if (purchaseData['notes'] != null && purchaseData['notes'].toString().isNotEmpty)
                _buildDetailRow('Notes', purchaseData['notes']),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total Amount", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  Text(
                    "₹${(purchaseData['totalAmount'] ?? 0.0).toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _primaryColor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}