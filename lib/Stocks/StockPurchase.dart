import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/services/number_generator_service.dart';

// --- UI CONSTANTS ---
const Color _primaryColor = Color(0xFF2F7CF6);
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
      backgroundColor: kGreyBg,
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

// ---------------- CreateStockPurchasePage ----------------
// ---------------- CreateStockPurchasePage ----------------
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
  final TextEditingController _totalAmountController = TextEditingController();
  final TextEditingController _creditAmountController = TextEditingController();
  final TextEditingController _taxAmountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _paymentMode = 'Cash';
  bool _showAdvancedDetails = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _supplierNameController.dispose();
    _supplierPhoneController.dispose();
    _invoiceNumberController.dispose();
    _totalAmountController.dispose();
    _creditAmountController.dispose();
    _taxAmountController.dispose();
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
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _savePurchase() async {
    if (_supplierNameController.text.isEmpty || _totalAmountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in required fields')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final totalAmount = double.parse(_totalAmountController.text);
      final taxAmount = _taxAmountController.text.isEmpty ? 0.0 : double.parse(_taxAmountController.text);
      final creditAmount = _paymentMode == 'Credit'
          ? double.tryParse(_creditAmountController.text) ?? totalAmount
          : null;

      final invoiceNumber = _invoiceNumberController.text.isEmpty
          ? 'INV${DateTime.now().millisecondsSinceEpoch}'
          : _invoiceNumberController.text;

      await FirestoreService().addDocument('stockPurchases', {
        'supplierName': _supplierNameController.text,
        'supplierPhone': _supplierPhoneController.text,
        'invoiceNumber': invoiceNumber,
        'totalAmount': totalAmount,
        'taxAmount': taxAmount,
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
          'amount': creditAmount,
          'timestamp': Timestamp.fromDate(_selectedDate),
          'status': 'Available',
          'notes': _notesController.text,
          'uid': widget.uid,
          'type': 'Purchase Credit',
          'items': [],
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_paymentMode == 'Credit' ? 'Purchase saved & credit note created' : 'Purchase saved successfully')),
        );
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
        title: const Text('New Stock Purchase', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _primaryColor,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: widget.onBack),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Basic Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildTextField(controller: _supplierNameController, label: 'Supplier Name *', isRequired: true),
            const SizedBox(height: 12),
            _buildTextField(controller: _supplierPhoneController, label: 'Supplier Phone', keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            _buildTextField(controller: _invoiceNumberController, label: 'Invoice Number'),
            const SizedBox(height: 12),
            _buildTextField(controller: _totalAmountController, label: 'Total Amount *', isRequired: true, keyboardType: TextInputType.number),
            const SizedBox(height: 12),

            // Date & Payment Mode row
            // Date & Payment Mode Row
            Row(
              children: [
                // Date
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 18, color: _primaryColor),
                          const SizedBox(width: 8),
                          Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Payment Mode
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                    child: DropdownButton<String>(
                      value: _paymentMode,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: ['Cash', 'Online', 'Credit'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => _paymentMode = v!),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

// Credit Amount (only if Payment Mode = Credit)
            if (_paymentMode == 'Credit')
              _buildTextField(
                controller: _creditAmountController,
                label: 'Credit Amount',
                keyboardType: TextInputType.number,
              ),


            const SizedBox(height: 20),
            // Advanced Details Dropdown
            InkWell(
              onTap: () => setState(() => _showAdvancedDetails = !_showAdvancedDetails),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Advanced Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Icon(_showAdvancedDetails ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_showAdvancedDetails)
              Column(
                children: [
                  _buildTextField(controller: _taxAmountController, label: 'Tax Amount', keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  _buildTextField(controller: _notesController, label: 'Notes', maxLines: 3),
                  const SizedBox(height: 12),
                  if (_paymentMode == 'Credit')
                    _buildTextField(controller: _creditAmountController, label: 'Credit Amount', keyboardType: TextInputType.number),
                ],
              ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _savePurchase,
                style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Purchase', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        )
        ,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    IconData? suffixIcon,
    VoidCallback? onSuffixTap,
  }) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;

        return TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          decoration: InputDecoration(
            labelText: label,
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            labelStyle: TextStyle(
              color: hasText ? _primaryColor : Colors.black54,
              fontSize: 15,
            ),
            floatingLabelStyle: const TextStyle(
              color: _primaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: Colors.grey[100],
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            suffixIcon: suffixIcon != null
                ? IconButton(
              icon: Icon(suffixIcon, size: 20, color: _primaryColor),
              onPressed: onSuffixTap,
            )
                : null,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: hasText ? _primaryColor : Colors.grey.shade300, width: hasText ? 1.5 : 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _primaryColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            errorStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          validator: isRequired
              ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
              : null,
        );
      },
    );
  }

}


// ---------------- StockPurchaseDetailsPage ----------------
class StockPurchaseDetailsPage extends StatefulWidget {
  final String purchaseId;
  final Map<String, dynamic> purchaseData;

  const StockPurchaseDetailsPage({super.key, required this.purchaseId, required this.purchaseData});

  @override
  State<StockPurchaseDetailsPage> createState() => _StockPurchaseDetailsPageState();
}

class _StockPurchaseDetailsPageState extends State<StockPurchaseDetailsPage> {
  bool _showAdvancedDetails = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.purchaseData;
    final date = (data['timestamp'] as Timestamp?)?.toDate();
    final dateString = date != null ? DateFormat('dd MMM yyyy, h:mm a').format(date) : 'N/A';
    final paymentMode = data['paymentMode'] ?? 'N/A';
    final totalAmount = (data['totalAmount'] ?? 0.0).toStringAsFixed(2);
    final creditAmount = paymentMode == 'Credit' ? totalAmount : null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Purchase Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top basic info row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      data['supplierName'] ?? 'Unknown Supplier',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryColor),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(dateString, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(paymentMode, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  )
                ],
              ),
              const Divider(height: 32, color: _cardBorder),

              // Total amount row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total Amount", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  Text(
                    "₹$totalAmount",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Advanced Details Toggle
              InkWell(
                onTap: () => setState(() => _showAdvancedDetails = !_showAdvancedDetails),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Advanced Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Icon(_showAdvancedDetails ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down)
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Advanced Details content
              if (_showAdvancedDetails)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Invoice', data['invoiceNumber'] ?? 'N/A'),
                    _buildDetailRow('Phone', data['supplierPhone'] ?? 'N/A'),
                    _buildDetailRow('Notes', data['notes'] ?? 'N/A'),
                    _buildDetailRow('Payment Mode', paymentMode),
                    if (creditAmount != null) _buildDetailRow('Credit Amount', "₹$creditAmount"),
                    if (data['taxAmount'] != null) _buildDetailRow('Tax Amount', "₹${data['taxAmount'].toString()}"),
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
            width: 120,
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
