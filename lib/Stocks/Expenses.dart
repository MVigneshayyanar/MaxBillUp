import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/Stocks/AddExpenseTypePopup.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/services/number_generator_service.dart';

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
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: kPrimaryColor)),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        title: Text(context.tr('expenses'),
            style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: kPrimaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kWhite, size: 20),
          onPressed: widget.onBack,
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ENTERPRISE HEADER: DATE & NEW BUTTON
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: const BoxDecoration(
              color: kWhite,
              border: Border(bottom: BorderSide(color: kGrey200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDate(context),
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kGrey200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, color: kPrimaryColor, size: 18),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('dd-MM-yyyy').format(_selectedDate),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kBlack87),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () {
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
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(color: kPrimaryColor, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.add_rounded, color: kWhite, size: 24),
                  ),
                ),
              ],
            ),
          ),

          // SEARCH BAR
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: const BoxDecoration(
              color: kWhite,
              border: Border(bottom: BorderSide(color: kGrey200)),
            ),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kGrey200),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kBlack87),
                decoration: const InputDecoration(
                  hintText: "Search expense name or type...",
                  hintStyle: TextStyle(color: kBlack54, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: kPrimaryColor, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 7),
                ),
              ),
            ),
          ),

          // LIST
          Expanded(
            child: FutureBuilder<Stream<QuerySnapshot>>(
              future: _expensesStreamFuture,
              builder: (context, futureSnapshot) {
                if (futureSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                }
                if (!futureSnapshot.hasData) return const Center(child: Text("Unable to load expenses"));

                return StreamBuilder<QuerySnapshot>(
                  stream: futureSnapshot.data!,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();

                    final expenses = snapshot.data!.docs.where((doc) {
                      if (_searchQuery.isEmpty) return true;
                      final data = doc.data() as Map<String, dynamic>;
                      final name = (data['expenseName'] ?? '').toString().toLowerCase();
                      final type = (data['expenseType'] ?? '').toString().toLowerCase();
                      return name.contains(_searchQuery) || type.contains(_searchQuery);
                    }).toList();

                    if (expenses.isEmpty) return _buildNoResults();

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      itemCount: expenses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return _buildExpenseCard(context, expenses[index].id, expenses[index].data() as Map<String, dynamic>);
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

  Widget _buildExpenseCard(BuildContext context, String id, Map<String, dynamic> data) {
    final amount = (data['amount'] ?? 0.0) as num;
    final ts = data['timestamp'] as Timestamp?;
    final dateStr = ts != null ? DateFormat('dd-MM-yy • hh:mm a').format(ts.toDate()) : 'N/A';

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => ExpenseDetailsPage(
                  expenseId: id,
                  expenseData: data,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${data['referenceNumber'] ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.w900, color: kPrimaryColor, fontSize: 12)),
                    Text(dateStr, style: const TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: kOrange.withOpacity(0.1),
                      radius: 18,
                      child: const Icon(Icons.receipt_long_rounded, color: kOrange, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['expenseName'] ?? 'Expense',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kBlack87), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(data['expenseType'] ?? 'General',
                              style: const TextStyle(color: kPrimaryColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                    Text("Rs ${amount.toStringAsFixed(2)}",
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: kErrorColor)),
                  ],
                ),
                const Divider(height: 24, color: kGrey100),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text((data['paymentMode'] ?? 'Cash').toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54, letterSpacing: 0.5)),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: kGrey400),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.receipt_long_outlined, size: 64, color: kGrey300), const SizedBox(height: 16), const Text('No expenses found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kBlack87))]));
  Widget _buildNoResults() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.search_off_rounded, size: 64, color: kGrey300), const SizedBox(height: 16), Text('No matches for "$_searchQuery"', style: const TextStyle(color: kBlack54))]));
}

// ---------------- CreateExpensePage ----------------
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
          _expenseTypes = snapshot.docs.map((doc) => (doc.data() as Map<String, dynamic>)['name'].toString()).toList();
        });
      }
    } catch (e) { debugPrint(e.toString()); }
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
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: kPrimaryColor)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedExpenseType == 'Select Expense Type') return;

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text);
      final referenceNumber = 'EXP${DateTime.now().millisecondsSinceEpoch}';
      final expenseName = _expenseNameController.text.trim();
      final creditAmount = _paymentMode == 'Credit' ? (double.tryParse(_creditAmountController.text) ?? amount) : 0.0;

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense saved successfully'), backgroundColor: kGoogleGreen));
        widget.onBack();
      }
    } catch (e) { debugPrint(e.toString()); } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveExpenseName(String name) async {
    try {
      final col = await FirestoreService().getStoreCollection('expenseNames');
      final query = await col.where('name', isEqualTo: name).limit(1).get();
      if (query.docs.isNotEmpty) {
        await col.doc(query.docs.first.id).update({'usageCount': FieldValue.increment(1), 'lastUsed': FieldValue.serverTimestamp()});
      } else {
        await col.add({'name': name, 'usageCount': 1, 'lastUsed': FieldValue.serverTimestamp(), 'createdAt': FieldValue.serverTimestamp()});
      }
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<List<String>> _getExpenseNameSuggestions(String query) async {
    try {
      final col = await FirestoreService().getStoreCollection('expenseNames');
      final snap = await col.orderBy('usageCount', descending: true).limit(10).get();
      return snap.docs.map((doc) => doc['name'].toString()).where((n) => n.toLowerCase().contains(query.toLowerCase())).toList();
    } catch (e) { return []; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        title: const Text('New Expense', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: kPrimaryColor, centerTitle: true, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 20), onPressed: widget.onBack),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildSectionLabel("BASIC DETAILS"),
                  _buildExpenseTypeDropdown(),
                  const SizedBox(height: 16),
                  _buildAutocompleteExpenseName(),
                  const SizedBox(height: 16),
                  _buildModernField(_amountController, "Total Amount *", Icons.payments_rounded, type: TextInputType.number, isMandatory: true),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _buildDateSelector()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildPaymentDropdown()),
                  ]),
                  if (_paymentMode == 'Credit') ...[
                    const SizedBox(height: 16),
                    _buildModernField(_creditAmountController, "Initial Credit Amount", Icons.account_balance_wallet_rounded, type: TextInputType.number),
                  ],

                  const SizedBox(height: 24),
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: _buildSectionLabel("ADDITIONAL INFORMATION"),
                      children: [
                        _buildModernField(_advanceNotesController, "Advance Notes", Icons.notes_rounded, maxLines: 3),
                        const SizedBox(height: 16),
                        _buildModernField(_taxNumberController, "Tax/GST Ref No", Icons.description_rounded),
                        const SizedBox(height: 16),
                        _buildModernField(_taxAmountController, "Tax Component", Icons.percent_rounded, type: TextInputType.number),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildBottomAction(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 10, left: 4), child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5)));

  Widget _buildModernField(TextEditingController ctrl, String label, IconData icon, {TextInputType type = TextInputType.text, int maxLines = 1, bool isMandatory = false}) {
    return ValueListenableBuilder(
      valueListenable: ctrl,
      builder: (context, val, child) {
        bool filled = ctrl.text.isNotEmpty;
        return TextFormField(
          controller: ctrl, keyboardType: type, maxLines: maxLines,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack87),
          decoration: InputDecoration(
            labelText: label, prefixIcon: Icon(icon, color: filled ? kPrimaryColor : kBlack54, size: 20),
            filled: true, fillColor: kWhite,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: filled ? kPrimaryColor : kGrey200, width: filled ? 1.5 : 1.0)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kErrorColor)),
          ),
          validator: isMandatory ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
        );
      },
    );
  }

  Widget _buildAutocompleteExpenseName() {
    return Autocomplete<String>(
      optionsBuilder: (v) => v.text.isEmpty ? const Iterable<String>.empty() : _getExpenseNameSuggestions(v.text),
      onSelected: (s) => _expenseNameController.text = s,
      fieldViewBuilder: (ctx, ctrl, focus, onSub) {
        if (ctrl.text.isEmpty && _expenseNameController.text.isNotEmpty) ctrl.text = _expenseNameController.text;
        ctrl.addListener(() => _expenseNameController.text = ctrl.text);
        return _buildModernField(ctrl, "Expense Name *", Icons.shopping_basket_rounded, isMandatory: true);
      },
      optionsViewBuilder: (ctx, onSel, options) => Align(alignment: Alignment.topLeft, child: Material(elevation: 4, borderRadius: BorderRadius.circular(12), child: Container(width: MediaQuery.of(context).size.width - 40, constraints: const BoxConstraints(maxHeight: 200), decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)), child: ListView.separated(padding: EdgeInsets.zero, shrinkWrap: true, itemCount: options.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (ctx, i) => ListTile(dense: true, leading: const Icon(Icons.history_rounded, size: 18, color: kPrimaryColor), title: Text(options.elementAt(i), style: const TextStyle(fontWeight: FontWeight.w600)), onTap: () => onSel(options.elementAt(i))))))),
    );
  }

  Widget _buildExpenseTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedExpenseType, isExpanded: true, icon: const Icon(Icons.arrow_drop_down_rounded, color: kBlack54),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kBlack87),
          items: [
            const DropdownMenuItem(value: 'Select Expense Type', child: Text('Select Expense Type', style: TextStyle(color: kBlack54))),
            const DropdownMenuItem(value: 'Add Expense Type', child: Row(children: [Icon(Icons.add_circle_outline, size: 18, color: kPrimaryColor), SizedBox(width: 8), Text('New Category', style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w800))])),
            ..._expenseTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))),
          ],
          onChanged: (v) async {
            if (v == 'Add Expense Type') {
              final res = await showDialog<String>(context: context, builder: (_) => AddExpenseTypePopup(uid: widget.uid));
              if (res != null && res.isNotEmpty) { setState(() { _selectedExpenseType = res; if (!_expenseTypes.contains(res)) _expenseTypes.add(res); }); }
            } else if (v != 'Select Expense Type') setState(() => _selectedExpenseType = v!);
          },
        ),
      ),
    );
  }

  Widget _buildDateSelector() => GestureDetector(onTap: () => _selectDate(context), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)), child: Row(children: [const Icon(Icons.calendar_today_rounded, size: 16, color: kPrimaryColor), const SizedBox(width: 10), Text(DateFormat('dd-MM-yy').format(_selectedDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))])));
  Widget _buildPaymentDropdown() => Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _paymentMode, isExpanded: true, icon: const Icon(Icons.arrow_drop_down_rounded, color: kBlack54), items: ['Cash', 'Credit', 'Online'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)))).toList(), onChanged: (v) => setState(() => _paymentMode = v!))));
  Widget _buildBottomAction() => SafeArea(child: Container(padding: const EdgeInsets.fromLTRB(20, 12, 20, 12), decoration: const BoxDecoration(color: kWhite, border: Border(top: BorderSide(color: kGrey200))), child: SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: _isLoading ? null : _saveExpense, style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _isLoading ? const CircularProgressIndicator(color: kWhite) : const Text('SAVE EXPENSE', style: TextStyle(color: kWhite, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.5))))));
}

// ---------------- ExpenseDetailsPage ----------------
class ExpenseDetailsPage extends StatelessWidget {
  final String expenseId;
  final Map<String, dynamic> expenseData;

  const ExpenseDetailsPage({super.key, required this.expenseId, required this.expenseData});

  @override
  Widget build(BuildContext context) {
    final date = (expenseData['timestamp'] as Timestamp?)?.toDate();
    final dateStr = date != null ? DateFormat('dd-MM-yyyy, hh:mm a').format(date) : 'N/A';
    final total = (expenseData['amount'] ?? 0.0).toDouble();

    return Scaffold(
      backgroundColor: kPrimaryColor,
      appBar: AppBar(
        title: const Text('Expense Info', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: kPrimaryColor, centerTitle: true, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 20), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.delete_outline_rounded, color: kWhite), onPressed: () => _showDeleteDialog(context)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  CircleAvatar(backgroundColor: kOrange.withOpacity(0.1), radius: 18, child: const Icon(Icons.receipt_long_rounded, color: kOrange, size: 18)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(expenseData['expenseName'] ?? 'General Expense', style: const TextStyle(color: kOrange, fontSize: 15, fontWeight: FontWeight.w700)),
                      Text(expenseData['expenseType'] ?? 'Uncategorized', style: const TextStyle(color: kBlack54, fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text((expenseData['paymentMode'] ?? 'Cash').toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kPrimaryColor))),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(color: kWhite, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TRANSACTION DETAILS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: kBlack54, letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    _buildRow(Icons.tag_rounded, 'Reference ID', expenseData['referenceNumber'] ?? 'N/A'),
                    _buildRow(Icons.calendar_month_rounded, 'Date Recorded', dateStr),
                    _buildRow(Icons.description_rounded, 'Tax Number', expenseData['taxNumber'] ?? '--'),
                    _buildRow(Icons.notes_rounded, 'Note', expenseData['advanceNotes'] ?? '--'),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: kGrey100)),

                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('TOTAL EXPENSE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: kBlack54)),
                      Text('Rs ${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kErrorColor)),
                    ]),

                    if (expenseData['taxAmount'] != null && expenseData['taxAmount'] != 0.0) ...[
                      const SizedBox(height: 8),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Tax Amount Included', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kBlack54)),
                        Text('Rs ${expenseData['taxAmount']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kBlack87)),
                      ]),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Expense?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this expense? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              await FirestoreService().deleteDocument('expenses', expenseId);
              if (context.mounted) { Navigator.pop(ctx); Navigator.pop(context, true); }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kErrorColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('DELETE', style: TextStyle(color: kWhite,fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(IconData i, String l, String v) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [Icon(i, size: 14, color: kGrey400), const SizedBox(width: 10), Text('$l: ', style: const TextStyle(color: kBlack54, fontSize: 11, fontWeight: FontWeight.w500)), Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: kBlack87), overflow: TextOverflow.ellipsis))]));
}