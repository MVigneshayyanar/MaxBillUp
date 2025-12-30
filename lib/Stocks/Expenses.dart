import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/Stocks/AddExpenseTypePopup.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/services/number_generator_service.dart';

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
                      final name = (data['expenseName'] ?? '').toString().toLowerCase();
                      final type = (data['expenseType'] ?? '').toString().toLowerCase();
                      return name.contains(_searchQuery) || type.contains(_searchQuery);
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
                        final name = data['expenseName'] ?? 'Expense';
                        final type = data['expenseType'] ?? 'Uncategorized';
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
                              name,
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
                                    type,
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
                              '${amount.toStringAsFixed(2)}',
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
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _expenseNameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _advanceNotesController = TextEditingController();
  final TextEditingController _taxNumberController = TextEditingController();
  final TextEditingController _taxAmountController = TextEditingController();
  final TextEditingController _creditAmountController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedExpenseType = 'Select Expense Type';
  String _paymentMode = 'Cash';
  bool _isLoading = false;
  List<String> _expenseTypes = [];

  @override
  void initState() {
    super.initState();
    _loadExpenseTypes();
  }

  Future<void> _loadExpenseTypes() async {
    try {
      final stream = await FirestoreService().getCollectionStream('expenseCategories');
      final snapshot = await stream.first;
      if (mounted) {
        setState(() {
          _expenseTypes = snapshot.docs
              .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return (data['name'] ?? '').toString();
          })
              .toList();
        });
      }
    } catch (e) {
      debugPrint("Error loading expense types: $e");
    }
  }

  @override
  void dispose() {
    _expenseNameController.dispose();
    _amountController.dispose();
    _advanceNotesController.dispose();
    _taxNumberController.dispose();
    _taxAmountController.dispose();
    _creditAmountController.dispose();
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
          colorScheme: const ColorScheme.light(primary: kPrimaryColor),
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
    if (!_formKey.currentState!.validate()) return;
    if (_selectedExpenseType == 'Select Expense Type' || _selectedExpenseType == 'Add Expense Type') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a valid expense type.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text);
      final referenceNumber = 'EXP${DateTime.now().millisecondsSinceEpoch}';
      final expenseName = _expenseNameController.text.trim();
      final creditAmount = _paymentMode == 'Credit'
          ? (double.tryParse(_creditAmountController.text) ?? amount)
          : 0.0;

      await FirestoreService().addDocument('expenses', {
        'expenseName': expenseName,
        'amount': amount,
        'expenseType': _selectedExpenseType,
        'paymentMode': _paymentMode,
        'creditAmount': creditAmount,
        'advanceNotes': _advanceNotesController.text.trim(),
        'taxNumber': _taxNumberController.text.trim(),
        'taxAmount': double.tryParse(_taxAmountController.text) ?? 0.0,
        'timestamp': Timestamp.fromDate(_selectedDate),
        'uid': widget.uid,
        'referenceNumber': referenceNumber,
      });

      // Add or update expense name in expenseNames collection
      await _saveExpenseName(expenseName);

      if (_paymentMode == 'Credit' && creditAmount > 0) {
        final creditNoteNumber = await NumberGeneratorService.generateExpenseCreditNoteNumber();

        await FirestoreService().addDocument('purchaseCreditNotes', {
          'creditNoteNumber': creditNoteNumber,
          'invoiceNumber': referenceNumber,
          'purchaseNumber': referenceNumber,
          'supplierName': 'Expense: $expenseName',
          'supplierPhone': '',
          'amount': creditAmount,
          'paidAmount': 0.0,
          'timestamp': Timestamp.fromDate(_selectedDate),
          'status': 'Available',
          'notes': _advanceNotesController.text,
          'uid': widget.uid,
          'type': 'Expense Credit',
          'category': _selectedExpenseType,
          'items': [],
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_paymentMode == 'Credit'
                ? 'Expense saved and credit note created'
                : 'Expense saved successfully'),
            backgroundColor: _successColor,
          ),
        );
        widget.onBack();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.tr('error')}: $e'), backgroundColor: _errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveExpenseName(String expenseName) async {
    try {
      final expenseNamesCollection = await FirestoreService().getStoreCollection('expenseNames');

      final querySnapshot = await expenseNamesCollection
          .where('name', isEqualTo: expenseName)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final docId = querySnapshot.docs.first.id;
        final docData = querySnapshot.docs.first.data() as Map<String, dynamic>?;
        final currentCount = docData?['usageCount'] ?? 0;

        await expenseNamesCollection.doc(docId).update({
          'usageCount': currentCount + 1,
          'lastUsed': FieldValue.serverTimestamp(),
        });
      } else {
        await expenseNamesCollection.add({
          'name': expenseName,
          'usageCount': 1,
          'lastUsed': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error saving expense name: $e');
    }
  }

  Future<List<String>> _getExpenseNameSuggestions(String query) async {
    try {
      final expenseNamesCollection = await FirestoreService().getStoreCollection('expenseNames');
      final snapshot = await expenseNamesCollection
          .orderBy('usageCount', descending: true)
          .limit(10)
          .get();

      final List<String> suggestions = snapshot.docs
          .map((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        return (data?['name'] ?? '').toString();
      })
          .where((name) => name.toLowerCase().contains(query.toLowerCase()))
          .toList();

      return suggestions;
    } catch (e) {
      debugPrint('Error fetching expense name suggestions: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(
        title: Text(context.tr('new_expense'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kPrimaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSectionHeader("Basic Details"),
                  const SizedBox(height: 12),
                  _buildExpenseTypeDropdown(),
                  const SizedBox(height: 16),
                  _buildAutocompleteExpenseName(),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _amountController,
                    label: "Total Amount *",
                    keyboardType: TextInputType.number,
                    isRequired: true,
                  ),
                  const SizedBox(height: 16),
                  _buildDatePicker(),
                  const SizedBox(height: 16),
                  _buildPaymentModeDropdown(),

                  // Credit Amount field (shown only when Credit is selected)
                  if (_paymentMode == 'Credit') ...[
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _creditAmountController,
                      label: "Credit Amount",
                      keyboardType: TextInputType.number,
                    ),
                  ],

                  const SizedBox(height: 24),
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: _buildSectionHeader("Advanced Details"),
                      children: [
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _advanceNotesController,
                          label: "Advance Notes",
                          lines: 3,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _taxNumberController,
                          label: "Tax Number",
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _taxAmountController,
                          label: "Tax Amount",
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
            _buildBottomSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: kBlack87,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    int lines = 1,
  }) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;

        return TextFormField(
          controller: controller,
          maxLines: lines,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: kBlack87,
          ),
          decoration: InputDecoration(
            labelText: label,
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            labelStyle: TextStyle(
              color: hasText ? kPrimaryColor : kBlack54,
              fontSize: 15,
            ),
            floatingLabelStyle: const TextStyle(
              color: kPrimaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: kGreyBg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: hasText ? kPrimaryColor : kGrey300,
                width: hasText ? 1.5 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: kPrimaryColor,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: kErrorColor,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: kErrorColor,
                width: 1.5,
              ),
            ),
            errorStyle: const TextStyle(
              color: kErrorColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          validator: isRequired
              ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
              : null,
        );
      },
    );
  }

  Widget _buildAutocompleteExpenseName() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) async {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<String>.empty();
            }
            return await _getExpenseNameSuggestions(textEditingValue.text);
          },
          onSelected: (String selection) {
            _expenseNameController.text = selection;
          },
          fieldViewBuilder: (BuildContext context, TextEditingController fieldTextEditingController,
              FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
            if (fieldTextEditingController.text.isEmpty && _expenseNameController.text.isNotEmpty) {
              fieldTextEditingController.text = _expenseNameController.text;
            }
            fieldTextEditingController.addListener(() {
              _expenseNameController.text = fieldTextEditingController.text;
            });

            return ValueListenableBuilder<TextEditingValue>(
              valueListenable: fieldTextEditingController,
              builder: (context, value, _) {
                final bool hasText = value.text.isNotEmpty;

                return TextFormField(
                  controller: fieldTextEditingController,
                  focusNode: fieldFocusNode,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: kBlack87,
                  ),
                  decoration: InputDecoration(
                    labelText: "Expense Name *",
                    floatingLabelBehavior: FloatingLabelBehavior.auto,
                    labelStyle: TextStyle(
                      color: hasText ? kPrimaryColor : kBlack54,
                      fontSize: 15,
                    ),
                    floatingLabelStyle: const TextStyle(
                      color: kPrimaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    filled: true,
                    fillColor: kGreyBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: hasText ? kPrimaryColor : kGrey300,
                        width: hasText ? 1.5 : 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: kPrimaryColor,
                        width: 1.5,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: kErrorColor,
                        width: 1,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: kErrorColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                );
              },
            );
          },
          optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected,
              Iterable<String> options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  width: MediaQuery.of(context).size.width - 32,
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return InkWell(
                        onTap: () => onSelected(option),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: index == options.length - 1 ? Colors.transparent : kGrey200,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.history, size: 18, color: kPrimaryColor),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  option,
                                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildExpenseTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: kGreyBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kGrey300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedExpenseType,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: kBlack54),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kBlack87),
              items: [
                const DropdownMenuItem<String>(
                  value: 'Select Expense Type',
                  child: Text('Select Expense Type', style: TextStyle(color: kBlack54)),
                ),
                const DropdownMenuItem<String>(
                  value: 'Add Expense Type',
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline, size: 18, color: kPrimaryColor),
                      SizedBox(width: 8),
                      Text('Add Expense Type', style: TextStyle(color: kPrimaryColor)),
                    ],
                  ),
                ),
                ..._expenseTypes.map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
                }).toList(),
              ],
              onChanged: (String? newValue) async {
                if (newValue == null) return;
                if (newValue == 'Add Expense Type') {
                  // Show AddExpenseTypePopup
                  final selectedType = await showDialog<String>(
                    context: context,
                    builder: (context) => AddExpenseTypePopup(uid: widget.uid),
                  );

                  if (selectedType != null && selectedType.isNotEmpty) {
                    setState(() {
                      _selectedExpenseType = selectedType;
                      // Add new type to expenseTypes if not exists
                      if (!_expenseTypes.contains(selectedType)) {
                        _expenseTypes.add(selectedType);
                      }
                    });
                  }
                } else if (newValue != 'Select Expense Type') {
                  setState(() => _selectedExpenseType = newValue);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () => _selectDate(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: kGreyBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kGrey300),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, color: kPrimaryColor, size: 18),
            const SizedBox(width: 12),
            Text(
              DateFormat('dd MMM yyyy').format(_selectedDate),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kBlack87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentModeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: kGreyBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kGrey300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _paymentMode,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: kBlack54),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kBlack87),
          items: ['Cash', 'Credit', 'Online'].map((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) setState(() => _paymentMode = newValue);
          },
        ),
      ),
    );
  }

  Widget _buildBottomSaveButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: kWhite,
        border: Border(top: BorderSide(color: kGrey200)),
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveExpense,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryColor,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
          'Save Expense',
          style: TextStyle(color: kWhite, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class ExpenseDetailsPage extends StatelessWidget {
  final String expenseId;
  final Map<String, dynamic> expenseData;

  const ExpenseDetailsPage(
      {super.key, required this.expenseId, required this.expenseData});

  @override
  Widget build(BuildContext context) {
    final timestamp = expenseData['timestamp'] as Timestamp?;
    final date = timestamp?.toDate();
    final dateString = date != null ? DateFormat('dd MMM yyyy, h:mm a').format(
        date) : 'N/A';

    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: AppBar(
        title: Text(context.tr('expense_details'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight
                .bold)),
        backgroundColor: _primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () {
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
                expenseData['expenseName'] ?? 'Expense',
                style: const TextStyle(fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor),
              ),
              const Divider(height: 32, color: _cardBorder),
              _buildDetailRow('Expense Type',
                  expenseData['expenseType'] ?? 'Uncategorized'),
              _buildDetailRow('Date', dateString),
              _buildDetailRow(
                  'Payment Mode', expenseData['paymentMode'] ?? 'Cash'),
              if (expenseData['advanceNotes'] != null &&
                  expenseData['advanceNotes']
                      .toString()
                      .isNotEmpty)
                _buildDetailRow('Advance Notes', expenseData['advanceNotes']),
              if (expenseData['taxNumber'] != null && expenseData['taxNumber']
                  .toString()
                  .isNotEmpty)
                _buildDetailRow('Tax Number', expenseData['taxNumber']),
              if (expenseData['taxAmount'] != null &&
                  expenseData['taxAmount'] != 0.0)
                _buildDetailRow('Tax Amount',
                    '${(expenseData['taxAmount'] ?? 0.0).toStringAsFixed(2)}'),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total Amount", style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
                  Text(
                    "${(expenseData['amount'] ?? 0.0).toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _errorColor),
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
      builder: (ctx) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Delete Expense?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text(
                'Are you sure you want to delete this expense? This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await FirestoreService().deleteDocument(
                        'expenses', expenseId);
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      Navigator.pop(context, true);
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                    'Delete', style: TextStyle(color: Colors.white)),
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
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                  color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
