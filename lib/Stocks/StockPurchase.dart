import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/services/number_generator_service.dart';
import 'package:maxbillup/services/currency_service.dart';
import 'package:heroicons/heroicons.dart';

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
  String _currencySymbol = '';

  @override
  void initState() {
    super.initState();
    _purchasesStreamFuture = FirestoreService().getCollectionStream('stockPurchases');
    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text.toLowerCase()));
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
    if (picked != null && picked != _selectedDate) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) widget.onBack();
      },
      child: Scaffold(
        backgroundColor: kGreyBg,
        appBar: AppBar(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          title: const Text('Stock Purchases', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
          backgroundColor: kPrimaryColor,
          leading: IconButton(
            icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 20),
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
              decoration: const BoxDecoration(color: kWhite, border: Border(bottom: BorderSide(color: kGrey200))),
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
                            const HeroIcon(HeroIcons.calendarDays, color: kPrimaryColor, size: 18),
                            const SizedBox(width: 12),
                            Text(
                              DateFormat('dd MMM yyyy').format(_selectedDate),
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
                      Navigator.push(context, CupertinoPageRoute(builder: (_) => CreateStockPurchasePage(uid: widget.uid, onBack: () { Navigator.pop(context); setState(() {}); })));
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 46, width: 46,
                      decoration: BoxDecoration(color: kPrimaryColor, borderRadius: BorderRadius.circular(12)),
                      child: const HeroIcon(HeroIcons.plus, color: kWhite, size: 24),
                    ),
                  ),
                ],
              ),
            ),

            // SEARCH BAR
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: const BoxDecoration(color: kWhite, border: Border(bottom: BorderSide(color: kGrey200))),
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
                    hintText: "Search supplier or invoice...",
                    hintStyle: TextStyle(color: kBlack54, fontSize: 14),
                    prefixIcon: HeroIcon(HeroIcons.magnifyingGlass, color: kPrimaryColor, size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 7),
                  ),
                ),
              ),
            ),

            Expanded(
              child: FutureBuilder<Stream<QuerySnapshot>>(
                future: _purchasesStreamFuture,
                builder: (context, futureSnapshot) {
                  if (futureSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                  if (!futureSnapshot.hasData) return const Center(child: Text("Unable to load purchases"));

                  return StreamBuilder<QuerySnapshot>(
                    stream: futureSnapshot.data!,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();

                      final purchases = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final sName = (data['supplierName'] ?? '').toString().toLowerCase();
                        final inv = (data['invoiceNumber'] ?? '').toString().toLowerCase();
                        return sName.contains(_searchQuery) || inv.contains(_searchQuery);
                      }).toList();

                      if (purchases.isEmpty) return _buildNoResults();

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: purchases.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return _buildPurchaseCard(context, purchases[index].id, purchases[index].data() as Map<String, dynamic>);
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

  Widget _buildPurchaseCard(BuildContext context, String id, Map<String, dynamic> data) {
    final ts = data['timestamp'] as Timestamp?;
    final dateStr = ts != null ? DateFormat('dd MMM yyyy • hh:mm a').format(ts.toDate()) : 'N/A';
    final amount = (data['totalAmount'] ?? 0.0).toDouble();

    return Container(
      decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => StockPurchaseDetailsPage(purchaseId: id, purchaseData: data, currencySymbol: _currencySymbol))),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${data['invoiceNumber'] ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.w900, color: kPrimaryColor, fontSize: 12)),
                    Text(dateStr, style: const TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: kOrange.withOpacity(0.1), radius: 18,
                      child: const HeroIcon(HeroIcons.buildingStorefront, color: kOrange, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(data['supplierName'] ?? 'Unknown Supplier',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kOrange), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Text('$_currencySymbol${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: kPrimaryColor)),
                  ],
                ),
                const Divider(height: 24, color: kGrey100),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text((data['paymentMode'] ?? 'Cash').toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54, letterSpacing: 0.5)),
                    const HeroIcon(HeroIcons.chevronRight, size: 12, color: kGrey400),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [HeroIcon(HeroIcons.shoppingCart, size: 64, color: kGrey300), const SizedBox(height: 16), const Text('No stock purchases found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kBlack87))]));
  Widget _buildNoResults() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const HeroIcon(HeroIcons.magnifyingGlass, size: 64, color: kGrey300), const SizedBox(height: 16), Text('No matches for "$_searchQuery"', style: const TextStyle(color: kBlack54))]));
}

// ---------------- CreateStockPurchasePage ----------------
class CreateStockPurchasePage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;

  const CreateStockPurchasePage({super.key, required this.uid, required this.onBack});

  @override
  State<CreateStockPurchasePage> createState() => _CreateStockPurchasePageState();
}

class _CreateStockPurchasePageState extends State<CreateStockPurchasePage> {
  final _formKey = GlobalKey<FormState>();
  final _supplierNameController = TextEditingController(), _supplierPhoneController = TextEditingController(), _supplierGstinController = TextEditingController(), _invoiceNumberController = TextEditingController(), _totalAmountController = TextEditingController(), _paidAmountController = TextEditingController(), _taxAmountController = TextEditingController(), _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _paymentMode = 'Cash';
  bool _isLoading = false, _showAdvanced = false;
  List<Map<String, dynamic>> _vendors = [];
  String? _selectedVendorId;
  String _currencySymbol = '';

  // Auto-calculated credit amount
  double get _creditAmount {
    final total = double.tryParse(_totalAmountController.text) ?? 0.0;
    final paid = double.tryParse(_paidAmountController.text) ?? 0.0;
    return (total - paid).clamp(0.0, double.infinity);
  }

  @override
  void initState() { super.initState(); _loadVendors(); _loadCurrency(); }

  void _loadCurrency() async {
    final storeId = await FirestoreService().getCurrentStoreId();
    if (storeId == null) return;
    final doc = await FirebaseFirestore.instance.collection('store').doc(storeId).get();
    if (doc.exists && mounted) {
      setState(() => _currencySymbol = CurrencyService.getSymbolWithSpace(doc.data()?['currency']));
    }
  }

  @override
  void dispose() { _supplierNameController.dispose(); _supplierPhoneController.dispose(); _supplierGstinController.dispose(); _invoiceNumberController.dispose(); _totalAmountController.dispose(); _paidAmountController.dispose(); _taxAmountController.dispose(); _notesController.dispose(); super.dispose(); }

  Future<void> _loadVendors() async {
    try {
      final vendorsCollection = await FirestoreService().getStoreCollection('vendors');
      final snapshot = await vendorsCollection.get();
      if (mounted) setState(() => _vendors = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>}).toList());
    } catch (e) { debugPrint(e.toString()); }
  }

  void _selectVendor(Map<String, dynamic> v) => setState(() {
    _selectedVendorId = v['id'];
    _supplierNameController.text = v['name'] ?? '';
    _supplierPhoneController.text = v['phone'] ?? '';
    _supplierGstinController.text = v['gstin'] ?? '';
  });

  Future<void> _addOrUpdateVendor(double amt) async {
    final sName = _supplierNameController.text.trim();
    final sPhone = _supplierPhoneController.text.trim();
    final sGstin = _supplierGstinController.text.trim();
    if (sName.isEmpty) return;
    try {
      final vendorsCol = await FirestoreService().getStoreCollection('vendors');
      if (_selectedVendorId != null) {
        await vendorsCol.doc(_selectedVendorId).update({
          'totalPurchases': FieldValue.increment(amt),
          'purchaseCount': FieldValue.increment(1),
          'lastPurchaseDate': Timestamp.now(),
          'lastUpdated': FieldValue.serverTimestamp(),
          if (sGstin.isNotEmpty) 'gstin': sGstin,
        });
      } else {
        final existing = await vendorsCol.where('name', isEqualTo: sName).get();
        if (existing.docs.isNotEmpty) {
          await vendorsCol.doc(existing.docs.first.id).update({
            'totalPurchases': FieldValue.increment(amt),
            'purchaseCount': FieldValue.increment(1),
            'lastPurchaseDate': Timestamp.now(),
            'lastUpdated': FieldValue.serverTimestamp(),
            if (sPhone.isNotEmpty) 'phone': sPhone,
            if (sGstin.isNotEmpty) 'gstin': sGstin,
          });
        } else {
          await vendorsCol.add({
            'name': sName,
            'phone': sPhone,
            'gstin': sGstin.isEmpty ? null : sGstin,
            'totalPurchases': amt,
            'purchaseCount': 1,
            'createdAt': FieldValue.serverTimestamp(),
            'lastPurchaseDate': Timestamp.now(),
            'source': 'stock_purchase'
          });
        }
      }
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> _savePurchase() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final amt = double.parse(_totalAmountController.text);
      final tax = double.tryParse(_taxAmountController.text) ?? 0.0;
      final paid = double.tryParse(_paidAmountController.text) ?? (_paymentMode == 'Credit' ? 0.0 : amt);
      final credit = _paymentMode == 'Credit' ? _creditAmount : 0.0;

      // Use user-entered reference invoice number if provided, otherwise generate from settings
      String inv;
      if (_invoiceNumberController.text.trim().isNotEmpty) {
        inv = _invoiceNumberController.text.trim();
      } else {
        final prefix = await NumberGeneratorService.getPurchasePrefix();
        final number = await NumberGeneratorService.generatePurchaseNumber();
        inv = prefix.isNotEmpty ? '$prefix$number' : number;
      }

      await _addOrUpdateVendor(amt);
      await FirestoreService().addDocument('stockPurchases', {
        'supplierName': _supplierNameController.text.trim(),
        'supplierPhone': _supplierPhoneController.text.trim(),
        'supplierGstin': _supplierGstinController.text.trim().isEmpty ? null : _supplierGstinController.text.trim(),
        'invoiceNumber': inv,
        'totalAmount': amt,
        'paidAmount': paid,
        'creditAmount': credit,
        'taxAmount': tax,
        'paymentMode': _paymentMode,
        'notes': _notesController.text,
        'timestamp': Timestamp.fromDate(_selectedDate),
        'uid': widget.uid,
        'vendorId': _selectedVendorId,
      });

      if (_paymentMode == 'Credit' && credit > 0) {
        final cn = await NumberGeneratorService.generatePurchaseCreditNoteNumber();
        await FirestoreService().addDocument('purchaseCreditNotes', {'creditNoteNumber': cn, 'invoiceNumber': inv, 'purchaseNumber': inv, 'supplierName': _supplierNameController.text.trim(), 'supplierPhone': _supplierPhoneController.text.trim(), 'amount': credit, 'paidAmount': paid, 'timestamp': Timestamp.fromDate(_selectedDate), 'status': 'Available', 'notes': _notesController.text, 'uid': widget.uid, 'type': 'Purchase Credit', 'items': []});
      }
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase recorded successfully'), backgroundColor: kGoogleGreen)); widget.onBack(); }
    } catch (e) { debugPrint(e.toString()); } finally { if (mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),title: const Text('New Stock Purchase', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)), backgroundColor: kPrimaryColor, centerTitle: true, elevation: 0, leading: IconButton(icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 20), onPressed: widget.onBack)),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildSectionLabel("SUPPLIER DETAILS"),
                  _buildSupplierAutocomplete(),
                  const SizedBox(height: 16),
                  _buildModernField(_supplierPhoneController, 'Phone Number', HeroIcons.devicePhoneMobile, type: TextInputType.phone),
                  const SizedBox(height: 16),
                  _buildModernField(_supplierGstinController, 'Tax Number', HeroIcons.documentText),

                  const SizedBox(height: 24),
                  _buildSectionLabel("INVOICE DETAILS"),
                  _buildModernField(_totalAmountController, 'Total Amount *', HeroIcons.banknotes, type: const TextInputType.numberWithOptions(decimal: true), isMandatory: true, onChanged: () => setState(() {})),
                  const SizedBox(height: 16),
                  _buildModernField(_invoiceNumberController, 'Reference Invoice No (Optional)', HeroIcons.documentText),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _buildDateSelector()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildPaymentDropdown()),
                  ]),
                  if (_paymentMode == 'Credit') ...[
                    const SizedBox(height: 16),
                    _buildModernField(_paidAmountController, 'Paid Amount', HeroIcons.creditCard, type: const TextInputType.numberWithOptions(decimal: true), onChanged: () => setState(() {})),
                    const SizedBox(height: 12),
                    // Credit Amount Display (auto-calculated)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _creditAmount > 0 ? Colors.orange.shade50 : kGoogleGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _creditAmount > 0 ? Colors.orange : kGoogleGreen),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              HeroIcon(HeroIcons.wallet, size: 20, color: _creditAmount > 0 ? Colors.orange.shade700 : kGoogleGreen),
                              const SizedBox(width: 8),
                              Text('Credit Amount:', style: TextStyle(fontWeight: FontWeight.w600, color: _creditAmount > 0 ? Colors.orange.shade700 : kGoogleGreen)),
                            ],
                          ),
                          Text('$_currencySymbol${_creditAmount.toStringAsFixed(2)}', style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold, color: _creditAmount > 0 ? Colors.orange.shade700 : kGoogleGreen)),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: _buildSectionLabel("ADDITIONAL INFORMATION"),
                      children: [
                        _buildModernField(_taxAmountController, 'Tax Component (Amount)', HeroIcons.percentBadge, type: const TextInputType.numberWithOptions(decimal: true)),
                        const SizedBox(height: 16),
                        _buildModernField(_notesController, 'Internal Notes', HeroIcons.documentText, maxLines: 3),
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

  Widget _buildModernField(TextEditingController ctrl, String label, HeroIcons icon, {TextInputType type = TextInputType.text, int maxLines = 1, bool isMandatory = false, VoidCallback? onChanged}) {
    return ValueListenableBuilder(
      valueListenable: ctrl,
      builder: (context, val, child) {
        bool filled = ctrl.text.isNotEmpty;
        return TextFormField(
          controller: ctrl, keyboardType: type, maxLines: maxLines,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack87),
          onChanged: (v) { if (onChanged != null) onChanged(); setState(() {}); },
          decoration: InputDecoration(
            labelText: label, prefixIcon: HeroIcon(icon, color: filled ? kPrimaryColor : kBlack54, size: 20),
            filled: true, fillColor: kWhite, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: filled ? kPrimaryColor : kGrey200, width: filled ? 1.5 : 1.0)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kErrorColor)),
          ),
          validator: isMandatory ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
        );
      },
    );
  }

  Widget _buildSupplierAutocomplete() {
    return Autocomplete<Map<String, dynamic>>(
      optionsBuilder: (v) => v.text.isEmpty ? _vendors : _vendors.where((ven) => ven['name'].toString().toLowerCase().contains(v.text.toLowerCase())),
      displayStringForOption: (o) => o['name'] ?? '',
      onSelected: _selectVendor,
      fieldViewBuilder: (ctx, ctrl, focus, onSub) {
        if (_supplierNameController.text.isNotEmpty && ctrl.text.isEmpty) ctrl.text = _supplierNameController.text;
        ctrl.addListener(() => _supplierNameController.text = ctrl.text);
        return _buildModernField(ctrl, 'Supplier Name *', HeroIcons.buildingStorefront, isMandatory: true);
      },
      optionsViewBuilder: (ctx, onSel, options) => Align(alignment: Alignment.topLeft, child: Material(elevation: 4, borderRadius: BorderRadius.circular(12), child: Container(width: MediaQuery.of(context).size.width - 40, constraints: const BoxConstraints(maxHeight: 250), decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)), child: ListView.separated(padding: EdgeInsets.zero, shrinkWrap: true, itemCount: options.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (ctx, i) { final v = options.elementAt(i); return ListTile(dense: true, leading: CircleAvatar(backgroundColor: kPrimaryColor.withOpacity(0.1), radius: 16, child: Text(v['name'][0].toUpperCase(), style: const TextStyle(color: kPrimaryColor,fontWeight: FontWeight.bold, fontSize: 12))), title: Text(v['name'], style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text(v['phone'] ?? '--', style: const TextStyle(fontSize: 10)), onTap: () => onSel(v)); })))),
    );
  }

  Widget _buildDateSelector() => GestureDetector(onTap: () async { final p = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030)); if(p != null) setState(() => _selectedDate = p); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)), child: Row(children: [const HeroIcon(HeroIcons.calendar, size: 16, color: kPrimaryColor), const SizedBox(width: 10), Text(DateFormat('dd MMM yyyy').format(_selectedDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))])));

  Widget _buildPaymentDropdown() => Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _paymentMode, isExpanded: true, icon: const HeroIcon(HeroIcons.chevronDown, color: kBlack54), items: ['Cash', 'Online', 'Credit'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)))).toList(), onChanged: (v) => setState(() => _paymentMode = v!))));

  Widget _buildBottomAction() => SafeArea(child: Container(padding: const EdgeInsets.fromLTRB(20, 12, 20, 12), decoration: const BoxDecoration(color: kWhite, border: Border(top: BorderSide(color: kGrey200))), child: SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: _isLoading ? null : _savePurchase, style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _isLoading ? const CircularProgressIndicator(color: kWhite) : const Text('Save purchase', style: TextStyle(color: kWhite, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.5))))));
}

// ---------------- StockPurchaseDetailsPage ----------------
class StockPurchaseDetailsPage extends StatelessWidget {
  final String purchaseId;
  final Map<String, dynamic> purchaseData;
  final String currencySymbol;

  const StockPurchaseDetailsPage({super.key, required this.purchaseId, required this.purchaseData, required this.currencySymbol});

  @override
  Widget build(BuildContext context) {
    final date = (purchaseData['timestamp'] as Timestamp?)?.toDate();
    final dateStr = date != null ? DateFormat('dd MMM yyyy, hh:mm a').format(date) : 'N/A';
    final total = (purchaseData['totalAmount'] ?? 0.0).toDouble();

    return Scaffold(
      backgroundColor: kPrimaryColor,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: const Text('Purchase Info', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: kPrimaryColor, centerTitle: true, elevation: 0,
        leading: IconButton(icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 20), onPressed: () => Navigator.pop(context)),
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
                  CircleAvatar(backgroundColor: kOrange.withOpacity(0.1), radius: 18, child: const HeroIcon(HeroIcons.buildingStorefront, color: kOrange, size: 18)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(purchaseData['supplierName'] ?? 'Unknown Supplier', style: const TextStyle(color: kOrange, fontSize: 15, fontWeight: FontWeight.w700)),
                      Text(purchaseData['supplierPhone'] ?? '--', style: const TextStyle(color: kBlack54, fontSize: 11)),
                    ]),
                  ),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text((purchaseData['paymentMode'] ?? 'Cash').toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kPrimaryColor))),
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
                    const Text('LOGISTICS INFORMATION', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: kBlack54, letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    _buildRow(HeroIcons.documentText, 'Ref Invoice', purchaseData['invoiceNumber'] ?? 'N/A'),
                    if (purchaseData['supplierGstin'] != null && purchaseData['supplierGstin'].toString().isNotEmpty)
                      _buildRow(HeroIcons.buildingOffice2, 'Tax No', purchaseData['supplierGstin']),
                    _buildRow(HeroIcons.calendar, 'Date Recorded', dateStr),
                    _buildRow(HeroIcons.documentText, 'Note', purchaseData['notes'] ?? '--'),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: kGrey100)),

                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('TOTAL PAYABLE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: kBlack54)),
                      Text('$currencySymbol${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kPrimaryColor)),
                    ]),

                    if (purchaseData['taxAmount'] != null) ...[
                      const SizedBox(height: 8),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Includes Tax (EST)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kBlack54)),
                        Text('$currencySymbol${purchaseData['taxAmount']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kBlack87)),
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

  Widget _buildRow(HeroIcons i, String l, String v) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [HeroIcon(i, size: 14, color: kGrey400), const SizedBox(width: 10), Text('$l: ', style: const TextStyle(color: kBlack54, fontSize: 11, fontWeight: FontWeight.w500)), Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: kBlack87), overflow: TextOverflow.ellipsis))]));
}