import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/utils/firestore_service.dart';

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

  // Store the future to prevent re-fetching on every setState
  late Future<Stream<QuerySnapshot>> _purchasesStreamFuture;

  @override
  void initState() {
    super.initState();
    // Initialize the stream future once
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
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Stock Purchase', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF007AFF),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Date Picker and Create New Button
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Color(0xFF007AFF), size: 20),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('dd - MM - yyyy').format(_selectedDate),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to create new stock purchase
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateStockPurchasePage(
                            uid: widget.uid,
                            onBack: () => Navigator.pop(context),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      'Create New',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // List of Stock Purchases
          Expanded(
            child: FutureBuilder<Stream<QuerySnapshot>>(
              future: _purchasesStreamFuture,
              builder: (context, futureSnapshot) {
                if (futureSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!futureSnapshot.hasData) {
                  return const Center(child: Text("Unable to load stock purchases"));
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: futureSnapshot.data!,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No stock purchases found',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
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
                        child: Text(
                          'No matching purchases found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: purchases.length,
                      itemBuilder: (context, index) {
                        final data = purchases[index].data() as Map<String, dynamic>;
                        final supplierName = data['supplierName'] ?? 'Unknown Supplier';
                        final invoiceNumber = data['invoiceNumber'] ?? 'N/A';
                        final amount = (data['totalAmount'] ?? 0.0) as num;
                        final timestamp = data['timestamp'] as Timestamp?;
                        final date = timestamp?.toDate();
                        final dateString = date != null ? DateFormat('dd MMM yyyy').format(date) : 'N/A';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              supplierName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                Text(
                                  'Invoice: $invoiceNumber',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dateString,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Text(
                              '₹${amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF007AFF),
                              ),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => StockPurchaseDetailsPage(
                                    purchaseId: purchases[index].id,
                                    purchaseData: data,
                                  ),
                                ),
                              );
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
        ],
      ),
    );
  }
}

// Create Stock Purchase Page
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
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _savePurchase() async {
    if (_supplierNameController.text.isEmpty || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in required fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final amount = double.parse(_amountController.text);
      final invoiceNumber = _invoiceNumberController.text.isEmpty
          ? 'INV${DateTime.now().millisecondsSinceEpoch}'
          : _invoiceNumberController.text;

      // Save the stock purchase
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

      // If payment mode is Credit, create a purchase credit note
      if (_paymentMode == 'Credit') {
        final creditNoteNumber = 'PCN${DateTime.now().millisecondsSinceEpoch}';

        await FirestoreService().addDocument('purchaseCreditNotes', {
          'creditNoteNumber': creditNoteNumber,
          'invoiceNumber': invoiceNumber,
          'purchaseNumber': invoiceNumber, // For consistency with detail page
          'supplierName': _supplierNameController.text,
          'supplierPhone': _supplierPhoneController.text,
          'amount': amount,
          'timestamp': Timestamp.fromDate(_selectedDate),
          'status': 'Available',
          'notes': _notesController.text,
          'uid': widget.uid,
          'type': 'Purchase Credit',
          'items': [], // Empty array for now, can be expanded later with item details
        });

        // Update supplier's credit balance if supplier phone is provided
        if (_supplierPhoneController.text.isNotEmpty) {
          final supplierRef = FirebaseFirestore.instance
              .collection('suppliers')
              .doc(_supplierPhoneController.text);

          await FirebaseFirestore.instance.runTransaction((transaction) async {
            final supplierDoc = await transaction.get(supplierRef);

            if (supplierDoc.exists) {
              // Update existing supplier
              final currentBalance = supplierDoc.data()?['creditBalance'] ?? 0.0;
              final newBalance = currentBalance + amount;
              transaction.update(supplierRef, {
                'creditBalance': newBalance,
                'lastUpdated': FieldValue.serverTimestamp(),
              });
            } else {
              // Create new supplier record
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _paymentMode == 'Credit'
                  ? 'Stock purchase saved and credit note created'
                  : 'Stock purchase saved successfully'
            ),
          ),
        );
        widget.onBack();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('New Stock Purchase', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF007AFF),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField('Supplier Name *', _supplierNameController),
            const SizedBox(height: 16),
            _buildTextField('Supplier Phone', _supplierPhoneController, keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
            _buildTextField('Invoice Number', _invoiceNumberController),
            const SizedBox(height: 16),
            _buildTextField('Amount *', _amountController, keyboardType: TextInputType.number),
            const SizedBox(height: 16),

            // Date Picker
            const Text('Date', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Color(0xFF007AFF), size: 20),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('dd MMM yyyy').format(_selectedDate),
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Payment Mode
            const Text('Payment Mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButton<String>(
                value: _paymentMode,
                isExpanded: true,
                underline: const SizedBox(),
                items: ['Cash', 'Credit', 'UPI', 'Card'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _paymentMode = newValue;
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 16),

            _buildTextField('Notes', _notesController, maxLines: 3),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _savePurchase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Save Purchase',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF007AFF)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}

// Stock Purchase Details Page
class StockPurchaseDetailsPage extends StatelessWidget {
  final String purchaseId;
  final Map<String, dynamic> purchaseData;

  const StockPurchaseDetailsPage({
    super.key,
    required this.purchaseId,
    required this.purchaseData,
  });

  @override
  Widget build(BuildContext context) {
    final timestamp = purchaseData['timestamp'] as Timestamp?;
    final date = timestamp?.toDate();
    final dateString = date != null ? DateFormat('dd MMM yyyy, h:mm a').format(date) : 'N/A';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Purchase Details', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF007AFF),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    purchaseData['supplierName'] ?? 'Unknown Supplier',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF007AFF),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('Invoice Number', purchaseData['invoiceNumber'] ?? 'N/A'),
                  const SizedBox(height: 12),
                  _buildDetailRow('Phone', purchaseData['supplierPhone'] ?? 'N/A'),
                  const SizedBox(height: 12),
                  _buildDetailRow('Date', dateString),
                  const SizedBox(height: 12),
                  _buildDetailRow('Payment Mode', purchaseData['paymentMode'] ?? 'N/A'),
                  const SizedBox(height: 12),
                  _buildDetailRow('Amount', '₹${(purchaseData['totalAmount'] ?? 0.0).toStringAsFixed(2)}'),
                  if (purchaseData['notes'] != null && purchaseData['notes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow('Notes', purchaseData['notes']),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
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
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

