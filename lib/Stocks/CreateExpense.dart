import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/services/number_generator_service.dart';

// --- UI CONSTANTS ---
const Color _primaryColor = Color(0xFF2F7CF6);
const Color _successColor = Color(0xFF4CAF50);
const Color _errorColor = Color(0xFFFF5252);
const Color _cardBorder = Color(0xFFE3F2FD);
const Color _scaffoldBg = Colors.white;

class CreateExpensePage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;
  final bool isStockPurchase;

  const CreateExpensePage({
    super.key,
    required this.uid,
    required this.onBack,
    this.isStockPurchase = false,
  });

  @override
  State<CreateExpensePage> createState() => _CreateExpensePageState();
}

class _CreateExpensePageState extends State<CreateExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _billNumberController = TextEditingController();
  final TextEditingController _totalAmountController = TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();
  final TextEditingController _gstinController = TextEditingController();
  final TextEditingController _gstAmountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // Vendor fields
  final TextEditingController _vendorNameController = TextEditingController();
  final TextEditingController _vendorPhoneController = TextEditingController();
  final TextEditingController _vendorGSTINController = TextEditingController();
  final TextEditingController _vendorAddressController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'General';
  bool _isLoading = false;
  List<String> _categories = ['General', 'Salary', 'EB Bill', 'Stock Purchase', 'Other'];
  String? _selectedVendor;
  List<Map<String, dynamic>> _vendors = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadVendors();
    if (widget.isStockPurchase) {
      _selectedCategory = 'Stock Purchase';
    }
  }

  Future<void> _loadCategories() async {
    try {
      final stream = await FirestoreService().getCollectionStream('expenseCategories');
      final snapshot = await stream.first;

      if (mounted) {
        setState(() {
          final loadedCategories = snapshot.docs
              .map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data['name'] ?? 'General').toString();
              })
              .toList();

          if (loadedCategories.isNotEmpty) {
            _categories = ['General', 'Salary', 'EB Bill', 'Stock Purchase', 'Other', ...loadedCategories];
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading categories: $e");
    }
  }

  Future<void> _loadVendors() async {
    try {
      final vendorsCollection = await FirestoreService().getStoreCollection('vendors');
      final snapshot = await vendorsCollection.get();

      if (mounted) {
        setState(() {
          _vendors = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'name': data['name'] ?? '',
              'phone': data['phone'] ?? '',
              'gstin': data['gstin'] ?? '',
              'address': data['address'] ?? '',
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint("Error loading vendors: $e");
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _billNumberController.dispose();
    _totalAmountController.dispose();
    _paidAmountController.dispose();
    _gstinController.dispose();
    _gstAmountController.dispose();
    _notesController.dispose();
    _vendorNameController.dispose();
    _vendorPhoneController.dispose();
    _vendorGSTINController.dispose();
    _vendorAddressController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: _primaryColor),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showVendorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Select Vendor',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: _vendors.isEmpty
                    ? const Center(child: Text('No vendors found'))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _vendors.length,
                        itemBuilder: (context, index) {
                          final vendor = _vendors[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _primaryColor.withValues(alpha: 0.1),
                              child: Text(
                                vendor['name'][0].toUpperCase(),
                                style: const TextStyle(color: _primaryColor),
                              ),
                            ),
                            title: Text(vendor['name']),
                            subtitle: Text(vendor['phone']),
                            onTap: () {
                              Navigator.pop(context);
                              setState(() {
                                _selectedVendor = vendor['id'];
                                _vendorNameController.text = vendor['name'];
                                _vendorPhoneController.text = vendor['phone'];
                                _vendorGSTINController.text = vendor['gstin'] ?? '';
                                _vendorAddressController.text = vendor['address'] ?? '';
                              });
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showAddVendorDialog();
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Add New Vendor', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showAddVendorDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final gstinCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add New Vendor', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Vendor Name *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: gstinCtrl,
                decoration: InputDecoration(
                  labelText: 'GSTIN',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name and Phone are required')),
                );
                return;
              }

              try {
                final vendorsCollection = await FirestoreService().getStoreCollection('vendors');
                final docRef = await vendorsCollection.add({
                  'name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'gstin': gstinCtrl.text.trim().isEmpty ? null : gstinCtrl.text.trim(),
                  'address': addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                });

                await _loadVendors();

                if (mounted) {
                  Navigator.pop(context);
                  setState(() {
                    _selectedVendor = docRef.id;
                    _vendorNameController.text = nameCtrl.text.trim();
                    _vendorPhoneController.text = phoneCtrl.text.trim();
                    _vendorGSTINController.text = gstinCtrl.text.trim();
                    _vendorAddressController.text = addressCtrl.text.trim();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vendor added successfully'),
                      backgroundColor: _successColor,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final totalAmount = double.tryParse(_totalAmountController.text.trim()) ?? 0.0;
      final paidAmount = double.tryParse(_paidAmountController.text.trim()) ?? 0.0;
      final gstAmount = double.tryParse(_gstAmountController.text.trim()) ?? 0.0;
      final creditAmount = totalAmount - paidAmount;

      final expensesCollection = await FirestoreService().getStoreCollection('expenses');

      await expensesCollection.add({
        'name': _nameController.text.trim(),
        'title': _nameController.text.trim(), // For backward compatibility
        'billNumber': _billNumberController.text.trim(),
        'category': _selectedCategory,
        'totalAmount': totalAmount,
        'paidAmount': paidAmount,
        'creditAmount': creditAmount,
        'gstAmount': gstAmount,
        'gstin': _gstinController.text.trim().isEmpty ? null : _gstinController.text.trim(),
        'vendorId': _selectedVendor,
        'vendorName': _vendorNameController.text.trim().isEmpty ? null : _vendorNameController.text.trim(),
        'vendorPhone': _vendorPhoneController.text.trim().isEmpty ? null : _vendorPhoneController.text.trim(),
        'vendorGSTIN': _vendorGSTINController.text.trim().isEmpty ? null : _vendorGSTINController.text.trim(),
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'date': Timestamp.fromDate(_selectedDate),
        'timestamp': FieldValue.serverTimestamp(),
        'createdBy': widget.uid,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('expense_added_successfully')),
            backgroundColor: _successColor,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  double get _creditAmount {
    final total = double.tryParse(_totalAmountController.text.trim()) ?? 0.0;
    final paid = double.tryParse(_paidAmountController.text.trim()) ?? 0.0;
    return total - paid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: AppBar(
        title: Text(
          widget.isStockPurchase ? 'Add Stock Purchase' : context.tr('create_expense'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Selection (at top with color indicator)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Category *',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _cardBorder),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      items: _categories.map((cat) {
                        return DropdownMenuItem(value: cat, child: Text(cat));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedCategory = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Bill Number (renamed from Invoice Number)
              Text(
                '${widget.isStockPurchase ? 'Purchase Bill Number' : 'Bill Number'} *',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _errorColor),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _billNumberController,
                decoration: InputDecoration(
                  hintText: 'Enter bill number',
                  prefixIcon: const Icon(Icons.receipt, color: _primaryColor),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _cardBorder),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bill number is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Expense Name
              Text(
                'Expense Name *',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Enter expense name',
                  prefixIcon: const Icon(Icons.title, color: _primaryColor),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _cardBorder),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Expense name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Total Amount
              Text(
                'Total Amount *',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _totalAmountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '0.00',
                  prefixIcon: const Icon(Icons.currency_rupee, color: _primaryColor),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _cardBorder),
                  ),
                ),
                onChanged: (val) => setState(() {}),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Total amount is required';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Paid/Advance Amount
              Text(
                'Paid/Advance Amount *',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _paidAmountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '0.00',
                  prefixIcon: const Icon(Icons.payment, color: _successColor),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _cardBorder),
                  ),
                ),
                onChanged: (val) => setState(() {}),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Paid amount is required';
                  }
                  final paid = double.tryParse(value);
                  final total = double.tryParse(_totalAmountController.text.trim());
                  if (paid == null) return 'Enter a valid amount';
                  if (total != null && paid > total) {
                    return 'Paid amount cannot exceed total';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Credit Amount Display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _creditAmount > 0 ? Colors.orange.shade50 : _successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _creditAmount > 0 ? Colors.orange : _successColor,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Credit Amount:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _creditAmount > 0 ? Colors.orange.shade700 : _successColor,
                      ),
                    ),
                    Text(
                      '${_creditAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _creditAmount > 0 ? Colors.orange.shade700 : _successColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // GSTIN
              Text(
                'GSTIN',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _gstinController,
                decoration: InputDecoration(
                  hintText: 'Enter GSTIN',
                  prefixIcon: const Icon(Icons.receipt_long, color: _primaryColor),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // GST Amount
              Text(
                'GST Amount',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _gstAmountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '0.00',
                  prefixIcon: const Icon(Icons.calculate, color: _primaryColor),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Vendor Selection
              Text(
                'Vendor (Optional)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _showVendorDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_add, color: _primaryColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _vendorNameController.text.isEmpty
                              ? 'Select or Add Vendor'
                              : _vendorNameController.text,
                          style: TextStyle(
                            color: _vendorNameController.text.isEmpty
                                ? Colors.grey
                                : Colors.black87,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Date Selection
              Text(
                'Date *',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: _primaryColor),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('dd MMM yyyy').format(_selectedDate),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Notes
              Text(
                'Notes',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add notes (optional)',
                  prefixIcon: const Icon(Icons.note, color: _primaryColor),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveExpense,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          context.tr('save_expense'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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

