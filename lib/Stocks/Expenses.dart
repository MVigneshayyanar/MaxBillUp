import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/services/number_generator_service.dart';
import 'package:maxbillup/Stocks/CreateExpense.dart';

// --- UI CONSTANTS ---
const Color _primaryColor = Color(0xFF2F7CF6);
const Color _errorColor = Color(0xFFFF5252);
const Color _cardBorder = Color(0xFFE3F2FD);
const Color _scaffoldBg = Colors.white;
const Color _successColor = Color(0xFF4CAF50);


class ExpensesPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;

  const ExpensesPage({super.key, required this.uid, required this.onBack});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  late Future<Stream<QuerySnapshot>> _expensesStreamFuture;

  @override
  void initState() {
    super.initState();
    // Optimization: Initialize stream future once
    _expensesStreamFuture = FirestoreService().getCollectionStream('expenses');

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
        title: Text(context.tr('expenses'),
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
                BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
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
                        builder: (context) => CreateExpensePage(
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

          // Search Bar Section
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

          // List of Expenses
          Expanded(
            child: FutureBuilder<Stream<QuerySnapshot>>(
              future: _expensesStreamFuture,
              builder: (context, futureSnapshot) {
                if (futureSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!futureSnapshot.hasData) {
                  return const Center(child: Text("Unable to load expenses"));
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

                    final expenses = snapshot.data!.docs.where((doc) {
                      if (_searchQuery.isEmpty) return true;
                      final data = doc.data() as Map<String, dynamic>;
                      final title = (data['title'] ?? '').toString().toLowerCase();
                      final category = (data['category'] ?? '').toString().toLowerCase();
                      return title.contains(_searchQuery) || category.contains(_searchQuery);
                    }).toList();

                    if (expenses.isEmpty) {
                      return const Center(
                        child: Text(
                          'No matching expenses found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: expenses.length,
                      itemBuilder: (context, index) {
                        final data = expenses[index].data() as Map<String, dynamic>;
                        final title = data['title'] ?? 'Expense';
                        final category = data['category'] ?? 'Uncategorized';
                        final amount = (data['amount'] ?? 0.0) as num;
                        final timestamp = data['timestamp'] as Timestamp?;
                        final date = timestamp?.toDate();
                        final dateString =
                        date != null ? DateFormat('dd MMM yyyy').format(date) : 'N/A';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _cardBorder),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (context) => ExpenseDetailsPage(
                                    expenseId: expenses[index].id,
                                    expenseData: data,
                                  ),
                                ),
                              );
                            },
                            title: Text(
                              title,
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
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: _primaryColor.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: Text(
                                    category,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: _primaryColor,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dateString,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                            trailing: Text(
                              '₹${amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _errorColor,
                              ),
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 80, color: _primaryColor.withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text(
            'No expenses found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// Create Expense Page
class CreateExpensePage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;

  const CreateExpensePage({super.key, required this.uid, required this.onBack});

  @override
  State<CreateExpensePage> createState() => _CreateExpensePageState();
}

class _CreateExpensePageState extends State<CreateExpensePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'General';
  String _paymentMode = 'Cash';
  bool _isLoading = false;
  List<String> _categories = ['General'];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final stream = await FirestoreService().getCollectionStream('expenseCategories');
      final snapshot = await stream.first;

      if (mounted) {
        setState(() {
          _categories = snapshot.docs
              .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return (data['name'] ?? 'General').toString();
          })
              .toList();
          if (_categories.isEmpty) _categories = ['General'];
          if (!_categories.contains(_selectedCategory)) _selectedCategory = _categories.first;
        });
      }
    } catch (e) {
      debugPrint("Error loading categories: $e");
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
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

  Future<void> _saveExpense() async {
    if (_titleController.text.isEmpty || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('fill_required_fields'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text);
      final referenceNumber = 'EXP${DateTime.now().millisecondsSinceEpoch}';

      await FirestoreService().addDocument('expenses', {
        'title': _titleController.text,
        'amount': amount,
        'category': _selectedCategory,
        'paymentMode': _paymentMode,
        'notes': _notesController.text,
        'timestamp': Timestamp.fromDate(_selectedDate),
        'uid': widget.uid,
        'referenceNumber': referenceNumber,
      });

      if (_paymentMode == 'Credit') {
        final creditNoteNumber = await NumberGeneratorService.generateExpenseCreditNoteNumber();

        await FirestoreService().addDocument('purchaseCreditNotes', {
          'creditNoteNumber': creditNoteNumber,
          'invoiceNumber': referenceNumber,
          'purchaseNumber': referenceNumber,
          'supplierName': 'Expense: ${_titleController.text}',
          'supplierPhone': '',
          'amount': amount,
          'timestamp': Timestamp.fromDate(_selectedDate),
          'status': 'Available',
          'notes': _notesController.text,
          'uid': widget.uid,
          'type': 'Expense Credit',
          'category': _selectedCategory,
          'items': [],
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_paymentMode == 'Credit'
                ? 'Expense saved and credit note created'
                : 'Expense saved successfully'),
          ),
        );
        widget.onBack();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.tr('error')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(context.tr('new_expense'),
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
            _buildInputField('Expense Title *', _titleController, Icons.title_outlined),
            const SizedBox(height: 16),
            _buildInputField('Amount *', _amountController, Icons.currency_rupee,
                keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            const Text('Category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildDropdownContainer(
              child: DropdownButton<String>(
                value: _selectedCategory,
                isExpanded: true,
                underline: const SizedBox(),
                items: _categories.map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) setState(() => _selectedCategory = newValue);
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text('Date', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, color: _primaryColor, size: 18),
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
                onPressed: _isLoading ? null : _saveExpense,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  'Save Expense',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
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
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class ExpenseDetailsPage extends StatelessWidget {
  final String expenseId;
  final Map<String, dynamic> expenseData;

  const ExpenseDetailsPage({super.key, required this.expenseId, required this.expenseData});

  @override
  Widget build(BuildContext context) {
    final timestamp = expenseData['timestamp'] as Timestamp?;
    final date = timestamp?.toDate();
    final dateString = date != null ? DateFormat('dd MMM yyyy, h:mm a').format(date) : 'N/A';

    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: AppBar(
        title: Text(context.tr('expense_details'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () {
              // TODO: Navigate to edit expense page
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit functionality coming soon')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: () => _showDeleteDialog(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _cardBorder),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                expenseData['title'] ?? 'Expense',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _primaryColor),
              ),
              const Divider(height: 32, color: _cardBorder),
              _buildDetailRow('Category', expenseData['category'] ?? 'Uncategorized'),
              _buildDetailRow('Date', dateString),
              _buildDetailRow('Payment Mode', expenseData['paymentMode'] ?? 'Cash'),
              if (expenseData['notes'] != null && expenseData['notes'].toString().isNotEmpty)
                _buildDetailRow('Notes', expenseData['notes']),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total Amount", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  Text(
                    "₹${(expenseData['amount'] ?? 0.0).toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _errorColor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Expense?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Are you sure you want to delete this expense? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirestoreService().deleteDocument('expenses', expenseId);
                if (context.mounted) {
                  Navigator.pop(ctx); // Close dialog
                  Navigator.pop(context, true); // Go back to expenses list
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Expense deleted successfully'),
                      backgroundColor: _successColor,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _errorColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
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
            child: Text(
              '$label:',
              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}