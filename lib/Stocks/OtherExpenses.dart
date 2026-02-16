import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/services/currency_service.dart';
import 'package:heroicons/heroicons.dart';

// --- UI CONSTANTS ---
const Color _primaryColor = Color(0xFF2F7CF6);
const Color _errorColor = Color(0xFFFF5252);
const Color _cardBorder = Color(0xFFE3F2FD);
const Color _scaffoldBg = Colors.white;

class OtherExpensesPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;

  const OtherExpensesPage({super.key, required this.uid, required this.onBack});

  @override
  State<OtherExpensesPage> createState() => _OtherExpensesPageState();
}

class _OtherExpensesPageState extends State<OtherExpensesPage> {
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late Future<Stream<QuerySnapshot>> _streamFuture;
  String _currencySymbol = '';

  @override
  void initState() {
    super.initState();
    _streamFuture = FirestoreService().getCollectionStream('otherExpenses');
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    _loadCurrency();
  }

  void _loadCurrency() async {
    final storeId = await FirestoreService().getCurrentStoreId();
    if (storeId == null) return;
    final doc = await FirebaseFirestore.instance.collection('store').doc(storeId).get();
    if (doc.exists && mounted) {
      final data = doc.data();
      setState(() {
        _currencySymbol = CurrencyService.getSymbolWithSpace(data?['currency']);
      });
    }
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
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: Text(context.tr('other_expenses'),
            style: const TextStyle(color: Colors.white,fontWeight: FontWeight.bold)),
        backgroundColor: _primaryColor,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Filter & Add Section
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
                          const HeroIcon(HeroIcons.calendarDays, color: _primaryColor, size: 18),
                          const SizedBox(width: 10),
                          Text(DateFormat('dd - MM - yyyy').format(_selectedDate),
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => CreateOtherExpensePage(
                          uid: widget.uid,
                          onBack: () => Navigator.pop(context),
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const HeroIcon(HeroIcons.plus, color: Colors.white),
                )
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
                  prefixIcon: const HeroIcon(HeroIcons.magnifyingGlass, color: _primaryColor, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),

          // List Content
          Expanded(
            child: FutureBuilder<Stream<QuerySnapshot>>(
              future: _streamFuture,
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
                      return _buildEmpty();
                    }

                    final expenses = snapshot.data!.docs.where((doc) {
                      if (_searchQuery.isEmpty) return true;
                      final data = doc.data() as Map<String, dynamic>;
                      final title = (data['title'] ?? '').toString().toLowerCase();
                      final description = (data['description'] ?? '').toString().toLowerCase();
                      return title.contains(_searchQuery) || description.contains(_searchQuery);
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
                        final title = data['title'] ?? 'Other Expense';
                        final description = data['description'] ?? '';
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
                                  builder: (context) => OtherExpenseDetailsPage(
                                    expenseId: expenses[index].id,
                                    expenseData: data,
                                    currencySymbol: _currencySymbol,
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
                                if (description.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    description,
                                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(dateString,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                            trailing: Text(
                              '$_currencySymbol${amount.toStringAsFixed(2)}',
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

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HeroIcon(HeroIcons.documentText, size: 80, color: _primaryColor.withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text("No other expenses found",
              style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold, color: Colors.grey)),
        ],
      ),
    );
  }
}

// --- CREATE OTHER EXPENSE PAGE ---
class CreateOtherExpensePage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;

  const CreateOtherExpensePage({super.key, required this.uid, required this.onBack});

  @override
  State<CreateOtherExpensePage> createState() => _CreateOtherExpensePageState();
}

class _CreateOtherExpensePageState extends State<CreateOtherExpensePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _paymentMode = 'Cash';
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
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
        const SnackBar(content: Text('Please fill in required fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirestoreService().addDocument('otherExpenses', {
        'title': _titleController.text,
        'amount': double.parse(_amountController.text),
        'description': _descriptionController.text,
        'paymentMode': _paymentMode,
        'timestamp': Timestamp.fromDate(_selectedDate),
        'uid': widget.uid,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Other expense saved successfully')),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: Text(context.tr('new_other_expense'),
            style: const TextStyle(color: Colors.white,fontWeight: FontWeight.bold)),
        backgroundColor: _primaryColor,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField('Title *', _titleController, HeroIcons.pencil),
            const SizedBox(height: 16),
            _buildTextField('Amount *', _amountController, HeroIcons.currencyRupee, isNum: true),
            const SizedBox(height: 16),
            const Text("Date", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildDatePicker(),
            const SizedBox(height: 16),
            const Text("Payment Mode", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildDropdown(),
            const SizedBox(height: 16),
            _buildTextField('Description', _descriptionController, HeroIcons.documentText, lines: 3),
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
                  "Save Expense",
                  style: TextStyle(color: Colors.white, fontSize: 18,fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, HeroIcons icon,
      {bool isNum = false, int lines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14,fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: lines,
          keyboardType: isNum ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            prefixIcon: HeroIcon(icon, color: _primaryColor, size: 20),
            filled: true,
            fillColor: _primaryColor.withOpacity(0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () => _selectDate(context),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _primaryColor.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const HeroIcon(HeroIcons.calendar, size: 18, color: _primaryColor),
            const SizedBox(width: 12),
            Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<String>(
        value: _paymentMode,
        isExpanded: true,
        underline: const SizedBox(),
        items: ['Cash', 'Credit', 'UPI', 'Card']
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) => setState(() => _paymentMode = v!),
      ),
    );
  }
}

// --- OTHER EXPENSE DETAILS PAGE ---
class OtherExpenseDetailsPage extends StatelessWidget {
  final String expenseId;
  final Map<String, dynamic> expenseData;
  final String currencySymbol;

  const OtherExpenseDetailsPage({super.key, required this.expenseId, required this.expenseData, required this.currencySymbol});

  @override
  Widget build(BuildContext context) {
    final timestamp = expenseData['timestamp'] as Timestamp?;
    final date = timestamp?.toDate();
    final dateString =
    date != null ? DateFormat('dd MMM yyyy, h:mm a').format(date) : 'N/A';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: const Text("Expense Details",
            style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold)),
        backgroundColor: _primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
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
                style: const TextStyle(fontSize: 24,fontWeight: FontWeight.bold, color: _primaryColor),
              ),
              const Divider(height: 32, color: _cardBorder),
              _buildDetailRow("Date", dateString),
              _buildDetailRow("Payment", expenseData['paymentMode'] ?? 'Cash'),
              _buildDetailRow("Description", expenseData['description'] ?? 'None'),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total Amount", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  Text(
                    "$currencySymbol${(expenseData['amount'] ?? 0).toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 24,fontWeight: FontWeight.bold, color: _errorColor),
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
            child: Text(
              "$label:",
              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}