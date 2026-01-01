import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:maxbillup/Colors.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

// --- PROJECT IMPORTS ---
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/Sales/Invoice.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/models/sale.dart';
import 'package:maxbillup/services/sale_sync_service.dart';
import 'package:maxbillup/services/local_stock_service.dart';
import 'package:maxbillup/services/number_generator_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/utils/plan_permission_helper.dart';

// ==========================================
// 1. BILL PAGE (Main State Widget)
// ==========================================
class BillPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final List<CartItem> cartItems;
  final double totalAmount;
  final String? savedOrderId;
  final double? discountAmount;
  final String? customerPhone;
  final String? customerName;
  final String? customerGST;
  final String? quotationId;
  final String? existingInvoiceNumber;
  final String? unsettledSaleId;

  const BillPage({
    super.key,
    required this.uid,
    this.userEmail,
    required this.cartItems,
    required this.totalAmount,
    this.savedOrderId,
    this.discountAmount,
    this.customerPhone,
    this.customerName,
    this.customerGST,
    this.quotationId,
    this.existingInvoiceNumber,
    this.unsettledSaleId,
  });

  @override
  State<BillPage> createState() => _BillPageState();
}

class _BillPageState extends State<BillPage> {
  late String _uid;
  String? _selectedCustomerPhone;
  String? _selectedCustomerName;
  String? _selectedCustomerGST;
  double _discountAmount = 0.0;
  String _creditNote = '';
  List<Map<String, dynamic>> _selectedCreditNotes = [];
  double _totalCreditNotesAmount = 0.0;
  String? _existingInvoiceNumber;
  String? _unsettledSaleId;

  // Fast-Fetch Variables
  String _businessName = 'Business';
  String _businessLocation = 'Location';
  String _businessPhone = '';
  String _staffName = 'Staff';
  StreamSubscription? _storeSub;

  @override
  void initState() {
    super.initState();
    _uid = widget.uid;
    if (widget.discountAmount != null) _discountAmount = widget.discountAmount!;
    if (widget.customerPhone != null) {
      _selectedCustomerPhone = widget.customerPhone;
      _selectedCustomerName = widget.customerName;
      _selectedCustomerGST = widget.customerGST;
    }
    _existingInvoiceNumber = widget.existingInvoiceNumber;
    _unsettledSaleId = widget.unsettledSaleId;

    _initFastFetch();
  }

  /// FAST FETCH: Load from cache instantly and listen for updates
  void _initFastFetch() {
    final fs = FirestoreService();

    // 1. Immediate Cache Retrieval
    fs.getCurrentStoreDoc().then((doc) {
      if (doc != null && doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _businessName = data['businessName'] ?? 'Business';
          _businessLocation = data['location'] ?? data['businessLocation'] ?? 'Location';
          _businessPhone = data['businessPhone'] ?? '';
        });
      }
    });

    // 2. Staff Cache Fetch
    FirebaseFirestore.instance.collection('users').doc(_uid).get(
        const GetOptions(source: Source.cache)
    ).then((doc) {
      if (doc.exists && mounted) {
        setState(() => _staffName = doc.data()?['name'] ?? 'Staff');
      }
    });

    // 3. Reactive Sync Listener
    _storeSub = fs.storeDataStream.listen((data) {
      if (mounted) {
        setState(() {
          _businessName = data['businessName'] ?? 'Business';
          _businessLocation = data['location'] ?? data['businessLocation'] ?? 'Location';
          _businessPhone = data['businessPhone'] ?? '';
        });
      }
    });
  }

  @override
  void dispose() {
    _storeSub?.cancel();
    super.dispose();
  }

  void _deselectCustomer() {
    setState(() {
      _selectedCustomerPhone = null;
      _selectedCustomerName = null;
      _selectedCustomerGST = null;
      _selectedCreditNotes = [];
      _totalCreditNotesAmount = 0.0;
      _creditNote = '';
    });
  }

  double get _subtotal {
    return widget.cartItems.fold(0.0, (sum, item) {
      if (item.taxType == 'Price includes Tax') {
        return sum + (item.basePrice * item.quantity);
      } else {
        return sum + item.total;
      }
    });
  }

  double get _totalTax => widget.cartItems.fold(0.0, (sum, item) => sum + item.taxAmount);
  double get _totalWithTax => widget.cartItems.fold(0.0, (sum, item) => sum + item.totalWithTax);

  double get _finalAmount {
    final amountAfterDiscount = _totalWithTax - _discountAmount;
    final creditToApply = _totalCreditNotesAmount > amountAfterDiscount ? amountAfterDiscount : _totalCreditNotesAmount;
    return (amountAfterDiscount - creditToApply).clamp(0.0, double.infinity);
  }

  double get _actualCreditUsed {
    final amountAfterDiscount = _totalWithTax - _discountAmount;
    return _totalCreditNotesAmount > amountAfterDiscount ? amountAfterDiscount : _totalCreditNotesAmount;
  }

  void _proceedToPayment(String paymentMode) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => paymentMode == 'Split'
            ? SplitPaymentPage(
          uid: _uid,
          userEmail: widget.userEmail,
          cartItems: widget.cartItems,
          totalAmount: _finalAmount,
          customerPhone: _selectedCustomerPhone,
          customerName: _selectedCustomerName,
          customerGST: _selectedCustomerGST,
          discountAmount: _discountAmount,
          creditNote: _creditNote,
          savedOrderId: widget.savedOrderId,
          selectedCreditNotes: _selectedCreditNotes,
          quotationId: widget.quotationId,
          existingInvoiceNumber: _existingInvoiceNumber,
          unsettledSaleId: _unsettledSaleId,
          businessName: _businessName,
          businessLocation: _businessLocation,
          businessPhone: _businessPhone,
          staffName: _staffName,
        )
            : PaymentPage(
          uid: _uid,
          userEmail: widget.userEmail,
          cartItems: widget.cartItems,
          totalAmount: _finalAmount,
          paymentMode: paymentMode,
          customerPhone: _selectedCustomerPhone,
          customerName: _selectedCustomerName,
          customerGST: _selectedCustomerGST,
          discountAmount: _discountAmount,
          creditNote: _creditNote,
          savedOrderId: widget.savedOrderId,
          selectedCreditNotes: _selectedCreditNotes,
          quotationId: widget.quotationId,
          existingInvoiceNumber: _existingInvoiceNumber,
          unsettledSaleId: _unsettledSaleId,
          businessName: _businessName,
          businessLocation: _businessLocation,
          businessPhone: _businessPhone,
          staffName: _staffName,
        ),
      ),
    );
  }

  void _clearOrder() {
    showDialog(context: context, builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: kErrorColor, size: 40),
            const SizedBox(height: 16),
            const Text('Clear Order?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kBlack87, letterSpacing: 0.5)),
            const SizedBox(height: 12),
            const Text('Are you sure you want to discard this bill? All progress will be lost.', textAlign: TextAlign.center, style: TextStyle(color: kBlack54, fontSize: 13, height: 1.5, fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.w800, color: kBlack54, fontSize: 12)))),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: kErrorColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: () { Navigator.pop(context); Navigator.pop(context); },
                    child: const Text('DISCARD', style: TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    ));
  }

  void _showCustomerDialog() {
    showDialog(context: context, builder: (context) => _CustomerSelectionDialog(uid: _uid, onCustomerSelected: (phone, name, gst) {
      setState(() { _selectedCustomerPhone = phone; _selectedCustomerName = name; _selectedCustomerGST = gst; });
    }));
  }

  void _showDiscountDialog() {
    final double billTotal = _totalWithTax;
    final TextEditingController cashController = TextEditingController(text: _discountAmount > 0 ? _discountAmount.toStringAsFixed(2) : '');
    final double initialPerc = billTotal > 0 ? (_discountAmount / billTotal) * 100 : 0.0;
    final TextEditingController percController = TextEditingController(text: initialPerc > 0 ? initialPerc.toStringAsFixed(1) : '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: kWhite,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('APPLY DISCOUNT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kBlack87, letterSpacing: 0.5)),
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close_rounded, size: 24, color: kBlack54)),
                ]),
                const SizedBox(height: 24),
                _buildPopupTextField(
                    controller: cashController,
                    label: 'Discount in Rs',
                    hint: '0.00',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      final val = double.tryParse(v) ?? 0.0;
                      if (billTotal > 0) {
                        percController.text = ((val / billTotal) * 100).toStringAsFixed(1);
                      }
                    }
                ),
                const SizedBox(height: 12),
                const Text('OR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kGrey400)),
                const SizedBox(height: 12),
                _buildPopupTextField(
                    controller: percController,
                    label: 'Discount in %',
                    hint: '0%',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      final val = double.tryParse(v) ?? 0.0;
                      cashController.text = (billTotal * (val / 100)).toStringAsFixed(2);
                    }
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _discountAmount = double.tryParse(cashController.text) ?? 0.0;
                      });
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                    child: const Text('APPLY', style: TextStyle(color: kWhite, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCreditNotesDialog() {
    if (_selectedCustomerPhone == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a customer first')));
      return;
    }
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('CREDIT NOTES', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close_rounded)),
                ]),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 350),
                  child: FutureBuilder<Stream<QuerySnapshot>>(
                    future: FirestoreService().getCollectionStream('creditNotes'),
                    builder: (context, futureSnapshot) {
                      if (!futureSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                      return StreamBuilder<QuerySnapshot>(
                        stream: futureSnapshot.data!,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                          final creditNotes = snapshot.data?.docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return data['customerPhone'] == _selectedCustomerPhone && data['status'] == 'Available';
                          }).toList() ?? [];
                          if (creditNotes.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Text('No available notes', style: TextStyle(fontWeight: FontWeight.w600, color: kBlack54)));
                          return ListView.builder(
                            shrinkWrap: true,
                            itemCount: creditNotes.length,
                            itemBuilder: (context, index) {
                              final doc = creditNotes[index];
                              final data = doc.data() as Map<String, dynamic>;
                              final isSelected = _selectedCreditNotes.any((cn) => cn['id'] == doc.id);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? kPrimaryColor : kGrey200, width: isSelected ? 1.5 : 1)),
                                child: CheckboxListTile(
                                  activeColor: kPrimaryColor,
                                  title: Text(data['creditNoteNumber'] ?? 'CN-N/A', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: kBlack87)),
                                  subtitle: Text('Valued at Rs ${(data['amount'] ?? 0.0).toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                                  value: isSelected,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      if (val == true) { _selectedCreditNotes.add({'id': doc.id, 'amount': (data['amount'] ?? 0.0).toDouble()}); }
                                      else { _selectedCreditNotes.removeWhere((cn) => cn['id'] == doc.id); }
                                      _totalCreditNotesAmount = _selectedCreditNotes.fold(0.0, (sum, cn) => sum + (cn['amount'] as double));
                                    });
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
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: () { setState(() {}); Navigator.pop(context); },
                    style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text('APPLY SELECTED', style: TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopupTextField({required TextEditingController controller, required String label, String? hint, TextInputType keyboardType = TextInputType.text, int maxLines = 1, Function(String)? onChanged}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kBlack87),
      decoration: InputDecoration(
        labelText: label, hintText: hint, filled: true, fillColor: kGreyBg, contentPadding: const EdgeInsets.all(16),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrey200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5)),
        floatingLabelStyle: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        title: Text(context.tr('Bill Summary').toUpperCase(), style: const TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.0)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kWhite, size: 18), onPressed: () => Navigator.pop(context)),
        actions: [IconButton(icon: const Icon(Icons.delete_sweep_rounded, color: kWhite, size: 22), onPressed: _clearOrder)],
      ),
      body: Column(
        children: [
          _buildCustomerSection(),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildTableHeader(),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kGrey200),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: widget.cartItems.length,
                itemBuilder: (ctx, i) => _buildItemRow(widget.cartItems[i], isLast: i == widget.cartItems.length - 1),
              ),
            ),
          ),
          _buildBottomPanel(),
        ],
      ),
    );
  }

  Widget _buildCustomerSection() {
    final bool hasCustomer = _selectedCustomerName != null && _selectedCustomerName!.isNotEmpty;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: kWhite, border: Border(bottom: BorderSide(color: kGrey200))),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Reduced height
      child: InkWell(
        onTap: _showCustomerDialog,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), // Reduced internal padding
          decoration: BoxDecoration(
            color: hasCustomer ? kPrimaryColor.withOpacity(0.08) : kWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: hasCustomer ? kPrimaryColor.withOpacity(0.2) : kOrange, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 38, height: 38, // Compact circle
                decoration: BoxDecoration(color: hasCustomer ? kPrimaryColor : kOrange.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(hasCustomer ? Icons.person_rounded : Icons.person_add_rounded, color: hasCustomer ? kWhite : kOrange, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hasCustomer ? _selectedCustomerName! : 'Assign Customer', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: hasCustomer ? kBlack87 : kOrange)),
                    if (hasCustomer) Text(_selectedCustomerPhone ?? '', style: const TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (hasCustomer) ...[
                GestureDetector(
                  onTap: _deselectCustomer,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(6), margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: kBlack87.withOpacity(0.05)),
                    child: const Icon(Icons.close_rounded, size: 14, color: kBlack54),
                  ),
                ),
              ],
              const Icon(Icons.arrow_forward_ios_rounded, color: kGrey400, size: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: kGreyBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: const Row(
        children: [
          Expanded(flex: 7, child: Text('PRODUCT', softWrap: false, overflow: TextOverflow.visible, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5))),
          Expanded(flex: 3, child: Text('QTY', textAlign: TextAlign.center, softWrap: false, overflow: TextOverflow.visible, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5))),
          Expanded(flex: 4, child: Text('RATE', textAlign: TextAlign.center, softWrap: false, overflow: TextOverflow.visible, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5))),
          Expanded(flex: 3, child: Text('TAX %', textAlign: TextAlign.center, softWrap: false, overflow: TextOverflow.visible, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5))),
          Expanded(flex: 5, child: Text('TAX AMT', textAlign: TextAlign.center, softWrap: false, overflow: TextOverflow.visible, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5))),
          Expanded(flex: 6, child: Text('TOTAL', textAlign: TextAlign.right, softWrap: false, overflow: TextOverflow.visible, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5))),
        ],
      ),
    );
  }

  Widget _buildItemRow(CartItem item, {bool isLast = false}) {
    final double taxVal = item.taxAmount;
    final int taxPerc = (item.taxPercentage ?? 0).toInt();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: kGrey100)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 7, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: kBlack87), maxLines: 2, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 3, child: Text('${item.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w700))),
          Expanded(flex: 4, child: Text(item.price.toStringAsFixed(0), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w700))),
          Expanded(flex: 3, child: Text(taxPerc > 0 ? '$taxPerc%' : '0', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w700))),
          Expanded(flex: 5, child: Text(taxVal > 0 ? taxVal.toStringAsFixed(0) : '0', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w700))),
          Expanded(flex: 6, child: Text((item.totalWithTax).toStringAsFixed(0), textAlign: TextAlign.right, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kPrimaryColor))),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: kWhite,
        border: Border(top: BorderSide(color: kGrey200, width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                _buildSummaryRow('Subtotal (Gross)', _subtotal.toStringAsFixed(2)),
                if (_totalTax > 0) _buildSummaryRow('Total Net Tax', _totalTax.toStringAsFixed(2)),
                _buildSummaryRow('Applied Discount', '- ${_discountAmount.toStringAsFixed(2)}', color: kGoogleGreen, isClickable: true, onTap: _showDiscountDialog),
                if (_selectedCreditNotes.isNotEmpty)
                  _buildSummaryRow('Credit Deduction', '- ${_actualCreditUsed.toStringAsFixed(2)}', color: kOrange, isClickable: true, onTap: _showCreditNotesDialog),

                const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Divider(height: 1, color: kGrey100)),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Net Payable', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kBlack54)),
                    Text('Rs ${_finalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kPrimaryColor)),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPayIcon(Icons.payments_rounded, 'Cash', () => _proceedToPayment('Cash')),
                    _buildPayIcon(Icons.qr_code_scanner_rounded, 'Online', () => _proceedToPayment('Online')),
                    _buildPayIcon(Icons.menu_book_rounded, 'Credit', () => _proceedToPayment('Credit')),
                    _buildPayIcon(Icons.call_split_rounded, 'Split', () => _proceedToPayment('Split')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? color, bool isClickable = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Text(label, style: const TextStyle(color: kBlack54, fontSize: 13, fontWeight: FontWeight.w600)),
              if (isClickable) Padding(padding: const EdgeInsets.only(left: 6), child: Icon(Icons.edit_note_rounded, size: 16, color: color ?? kPrimaryColor)),
            ]),
            Text('Rs $value', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color ?? kBlack87)),
          ],
        ),
      ),
    );
  }

  Widget _buildPayIcon(IconData icon, String label, VoidCallback onTap) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
                color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200, width: 1.5)),
            child: Icon(icon, color: kPrimaryColor, size: 24),
          ),
        ),
        const SizedBox(height: 8),
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5)),
      ],
    );
  }
}

// ==========================================
// 2. CUSTOMER SELECTION DIALOG (REMASTERED)
// ==========================================
class _CustomerSelectionDialog extends StatefulWidget {
  final String uid;
  final Function(String phone, String name, String? gst) onCustomerSelected;
  const _CustomerSelectionDialog({required this.uid, required this.onCustomerSelected});
  @override
  State<_CustomerSelectionDialog> createState() => _CustomerSelectionDialogState();
}

class _CustomerSelectionDialogState extends State<_CustomerSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text.toLowerCase()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _importFromContacts() async {
    final canImport = await PlanPermissionHelper.canImportContacts();
    if (!canImport) { PlanPermissionHelper.showUpgradeDialog(context, 'Import Contacts'); return; }

    if (!await FlutterContacts.requestPermission()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contacts permission denied'), backgroundColor: Colors.red));
      return;
    }
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No contacts found'), backgroundColor: Colors.orange));
      return;
    }
    showDialog(
      context: context,
      builder: (context) {
        List<Contact> filteredContacts = contacts;
        final TextEditingController contactSearchController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: SizedBox(
                width: 350, height: 500,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Select Contact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        controller: contactSearchController,
                        decoration: const InputDecoration(hintText: 'Search contacts...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
                        onChanged: (v) => setDialogState(() => filteredContacts = contacts.where((c) => c.displayName.toLowerCase().contains(v.toLowerCase())).toList()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredContacts.length,
                        itemBuilder: (context, index) {
                          final c = filteredContacts[index];
                          final phone = c.phones.isNotEmpty ? c.phones.first.number.replaceAll(RegExp(r'[^0-9+]'), '') : '';
                          return ListTile(
                            title: Text(c.displayName),
                            subtitle: Text(phone),
                            onTap: phone.isNotEmpty ? () {
                              Navigator.pop(context);
                              _showAddCustomerDialog(prefillName: c.displayName, prefillPhone: phone);
                            } : null,
                            enabled: phone.isNotEmpty,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddCustomerDialog({String? prefillName, String? prefillPhone}) {
    final nameCtrl = TextEditingController(text: prefillName ?? '');
    final phoneCtrl = TextEditingController(text: prefillPhone ?? '');
    final gstCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('New Customer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 20),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: gstCtrl, decoration: const InputDecoration(labelText: 'GST (Optional)', border: OutlineInputBorder())),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;
                    await FirestoreService().setDocument('customers', phoneCtrl.text.trim(), {
                      'name': nameCtrl.text.trim(), 'phone': phoneCtrl.text.trim(), 'gst': gstCtrl.text.trim().isEmpty ? null : gstCtrl.text.trim(),
                      'balance': 0.0, 'totalSales': 0.0, 'timestamp': FieldValue.serverTimestamp(), 'lastUpdated': FieldValue.serverTimestamp(),
                    });
                    if (mounted) { Navigator.pop(context); widget.onCustomerSelected(phoneCtrl.text.trim(), nameCtrl.text.trim(), gstCtrl.text.trim()); }
                  },
                  child: const Text('ADD CUSTOMER', style: TextStyle(color: kWhite, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: kWhite,
      child: Container(
        height: 600,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('SELECT CUSTOMER', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kBlack87, letterSpacing: 0.5)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: kBlack54)),
            ]),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
                    child: TextFormField(
                      controller: _searchController,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: context.tr('search'),
                        prefixIcon: const Icon(Icons.search_rounded, color: kPrimaryColor),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _squareActionBtn(Icons.person_add_rounded, _showAddCustomerDialog, kPrimaryColor),
                const SizedBox(width: 8),
                _squareActionBtn(Icons.contact_phone_rounded, _importFromContacts, kGoogleGreen),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<Stream<QuerySnapshot>>(
                future: FirestoreService().getCollectionStream('customers'),
                builder: (ctx, streamSnap) {
                  if (!streamSnap.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                  return StreamBuilder<QuerySnapshot>(
                    stream: streamSnap.data,
                    builder: (ctx, snap) {
                      if (!snap.hasData) return const Center(child: Text('No records', style: TextStyle(fontWeight: FontWeight.w600, color: kBlack54)));
                      final filtered = snap.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return data['name'].toString().toLowerCase().contains(_searchQuery) || data['phone'].toString().contains(_searchQuery);
                      }).toList();
                      return ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(color: kGrey100, height: 1),
                        itemBuilder: (ctx, i) {
                          final data = filtered[i].data() as Map<String, dynamic>;
                          final balance = (data['balance'] ?? 0.0) as num;
                          return ListTile(
                            onTap: () { widget.onCustomerSelected(data['phone'], data['name'], data['gst']); Navigator.pop(context); },
                            leading: CircleAvatar(backgroundColor: kPrimaryColor.withOpacity(0.1), child: Text(data['name'][0].toUpperCase(), style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900))),
                            title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            subtitle: Text(data['phone'], style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w500)),
                            trailing: Text('Rs ${balance.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w900, color: balance > 0 ? kErrorColor : kGoogleGreen, fontSize: 13)),
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

  Widget _squareActionBtn(IconData icon, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 48, width: 48,
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.2))),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

// ==========================================
// 3. PAYMENT PAGE
// ==========================================
class PaymentPage extends StatefulWidget {
  final String uid; final String? userEmail; final List<CartItem> cartItems; final double totalAmount; final String paymentMode; final String? customerPhone; final String? customerName; final String? customerGST; final double discountAmount; final String creditNote; final String? savedOrderId; final List<Map<String, dynamic>> selectedCreditNotes; final String? quotationId; final String? existingInvoiceNumber; final String? unsettledSaleId;
  final String businessName; final String businessLocation; final String businessPhone; final String staffName;

  const PaymentPage({super.key, required this.uid, this.userEmail, required this.cartItems, required this.totalAmount, required this.paymentMode, this.customerPhone, this.customerName, this.customerGST, required this.discountAmount, required this.creditNote, this.savedOrderId, this.selectedCreditNotes = const [], this.quotationId, this.existingInvoiceNumber, this.unsettledSaleId, required this.businessName, required this.businessLocation, required this.businessPhone, required this.staffName});
  @override State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  double _cashReceived = 0.0;
  final TextEditingController _displayController = TextEditingController(text: '0.0');
  double get _change => _cashReceived - widget.totalAmount;

  @override
  void initState() {
    super.initState();
    if (widget.paymentMode != 'Credit') {
      _cashReceived = widget.totalAmount;
      _displayController.text = widget.totalAmount.toStringAsFixed(1);
    }
  }

  void _onKeyTap(String val) {
    setState(() {
      String cur = _displayController.text;
      if (val == 'back') { if (cur.length > 1) _displayController.text = cur.substring(0, cur.length - 1); else _displayController.text = '0'; }
      else if (val == '.') { if (!cur.contains('.')) _displayController.text += '.'; }
      else { if (cur == '0' || cur == '0.0') _displayController.text = val; else _displayController.text += val; }
      _cashReceived = double.tryParse(_displayController.text) ?? 0.0;
    });
  }

  Future<void> _completeSale() async {
    if (widget.paymentMode == 'Credit' && widget.customerPhone == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer required for Credit'))); return; }
    if (widget.paymentMode != 'Credit' && _cashReceived < widget.totalAmount - 0.01) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment insufficient'), backgroundColor: Colors.red)); return; }
    try {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      final invoiceNumber = widget.existingInvoiceNumber ?? await NumberGeneratorService.generateInvoiceNumber();

      final Map<String, double> taxMap = {};
      for (var item in widget.cartItems) { if (item.taxAmount > 0 && item.taxName != null) taxMap[item.taxName!] = (taxMap[item.taxName!] ?? 0.0) + item.taxAmount; }
      final taxList = taxMap.entries.map((e) => {'name': e.key, 'amount': e.value}).toList();
      final totalTax = taxMap.values.fold(0.0, (a, b) => a + b);

      final baseSaleData = {
        'invoiceNumber': invoiceNumber, 'items': widget.cartItems.map((e)=> {'productId':e.productId, 'name':e.name, 'quantity':e.quantity, 'price':e.price, 'total':e.total, 'taxPercentage': e.taxPercentage ?? 0, 'taxAmount': e.taxAmount, 'taxName': e.taxName, 'taxType': e.taxType}).toList(),
        'subtotal': widget.totalAmount + widget.discountAmount, 'discount': widget.discountAmount, 'total': widget.totalAmount, 'taxes': taxList, 'totalTax': totalTax,
        'paymentMode': widget.paymentMode, 'cashReceived': _cashReceived, 'change': _change > 0 ? _change : 0.0, 'customerPhone': widget.customerPhone, 'customerName': widget.customerName, 'customerGST': widget.customerGST, 'creditNote': widget.creditNote, 'date': DateTime.now().toIso8601String(), 'staffId': widget.uid, 'staffName': widget.staffName, 'businessName': widget.businessName, 'businessLocation': widget.businessLocation, 'businessPhone': widget.businessPhone, 'timestamp': FieldValue.serverTimestamp(),
      };

      if (widget.paymentMode == 'Credit') await _updateCustomerCredit(widget.customerPhone!, widget.totalAmount - _cashReceived, invoiceNumber);
      if (widget.unsettledSaleId != null) await FirestoreService().updateDocument('sales', widget.unsettledSaleId!, {...baseSaleData, 'paymentStatus': 'settled', 'settledAt': FieldValue.serverTimestamp()});
      else { await FirestoreService().addDocument('sales', baseSaleData); await _updateProductStock(); }
      if (widget.savedOrderId != null) await FirestoreService().deleteDocument('savedOrders', widget.savedOrderId!);
      if (widget.selectedCreditNotes.isNotEmpty) await _markCreditNotesAsUsed(invoiceNumber, widget.selectedCreditNotes);
      if (widget.quotationId != null && widget.quotationId!.isNotEmpty) {
        await FirestoreService().updateDocument('quotations', widget.quotationId!, {'status': 'settled', 'billed': true, 'settledAt': FieldValue.serverTimestamp()});
      }

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        Navigator.popUntil(context, (route) => route.isFirst);
        Navigator.push(context, CupertinoPageRoute(builder: (_) => InvoicePage(
            uid: widget.uid, userEmail: widget.userEmail, businessName: widget.businessName, businessLocation: widget.businessLocation, businessPhone: widget.businessPhone, invoiceNumber: invoiceNumber, dateTime: DateTime.now(),
            items: widget.cartItems.map((e)=> {'name':e.name, 'quantity':e.quantity, 'price':e.price, 'total':e.totalWithTax, 'taxPercentage':e.taxPercentage ?? 0, 'taxAmount':e.taxAmount}).toList(),
            subtotal: widget.totalAmount + widget.discountAmount - totalTax, discount: widget.discountAmount, taxes: taxList, total: widget.totalAmount, paymentMode: widget.paymentMode, cashReceived: _cashReceived, customerName: widget.customerName, customerPhone: widget.customerPhone)));
      }
    } catch (e) { if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)); } }
  }

  Future<void> _updateCustomerCredit(String phone, double amount, String invoiceNumber) async { final customerRef = await FirestoreService().getDocumentReference('customers', phone); await FirebaseFirestore.instance.runTransaction((transaction) async { final customerDoc = await transaction.get(customerRef); if (customerDoc.exists) { final currentBalance = (customerDoc.data() as Map<String, dynamic>?)?['balance'] as double? ?? 0.0; transaction.update(customerRef, {'balance': currentBalance + amount, 'lastUpdated': FieldValue.serverTimestamp()}); } }); }
  Future<void> _updateProductStock() async { final localStockService = context.read<LocalStockService>(); for (var cartItem in widget.cartItems) { if (cartItem.productId.startsWith('qs_')) continue; final productRef = await FirestoreService().getDocumentReference('Products', cartItem.productId); await productRef.update({'currentStock': FieldValue.increment(-(cartItem.quantity))}); await localStockService.updateLocalStock(cartItem.productId, -cartItem.quantity); } }
  Future<void> _markCreditNotesAsUsed(String invoiceNumber, List<Map<String, dynamic>> selectedCreditNotes) async { for (var creditNote in selectedCreditNotes) { await FirestoreService().updateDocument('creditNotes', creditNote['id'], {'status': 'Used', 'usedInInvoice': invoiceNumber, 'usedAt': FieldValue.serverTimestamp()}); } }

  @override
  Widget build(BuildContext context) {
    bool canPay = widget.paymentMode == 'Credit' || _cashReceived >= widget.totalAmount - 0.01;
    return Scaffold(backgroundColor: kGreyBg, appBar: AppBar(title: Text('${widget.paymentMode} Payment', style: const TextStyle(color: kWhite, fontWeight: FontWeight.w600)), backgroundColor: kPrimaryColor, elevation: 0, centerTitle: true, leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: kWhite, size: 20), onPressed: () => Navigator.pop(context))), body: Column(children: [Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24), decoration: const BoxDecoration(color: kWhite, borderRadius: BorderRadius.vertical(bottom: Radius.circular(30))), child: Column(children: [Text(context.tr('total_bill'), style: const TextStyle(color: kBlack54, fontWeight: FontWeight.w600, letterSpacing: 1)), Text('Rs ${widget.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: kBlack87)), const SizedBox(height: 24), Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: kGrey200, width: 2)), child: Column(children: [const Text('RECEIVED AMOUNT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kBlack54)), const SizedBox(height: 8), Text(_displayController.text, style: TextStyle(fontSize: 48, fontWeight: FontWeight.w600, color: canPay ? kGoogleGreen : kPrimaryColor, letterSpacing: -1))])), const SizedBox(height: 16), if (widget.paymentMode != 'Credit') Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('CHANGE: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kBlack54)), Text('Rs ${_change > 0 ? _change.toStringAsFixed(2) : "0.00"}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _change >= 0 ? kGoogleGreen : kGoogleRed))])])), const Spacer(), Container(padding: const EdgeInsets.fromLTRB(20, 20, 20, 32), decoration: const BoxDecoration(color: kWhite, borderRadius: BorderRadius.vertical(top: Radius.circular(32))), child: Column(children: [_buildKeyPad(), const SizedBox(height: 24), SizedBox(width: double.infinity, height: 60, child: ElevatedButton(onPressed: canPay ? _completeSale : null, style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0), child: const Text('COMPLETE SALE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kWhite, letterSpacing: 1))))]))]));
  }
  Widget _buildKeyPad() { final List<String> keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', 'back']; return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 1.8), itemCount: keys.length, itemBuilder: (ctx, i) => _buildKey(keys[i])); }
  Widget _buildKey(String key) { return Material(color: kGreyBg, borderRadius: BorderRadius.circular(14), child: InkWell(onTap: () => _onKeyTap(key), borderRadius: BorderRadius.circular(14), child: Center(child: key == 'back' ? const Icon(Icons.backspace_rounded, color: kBlack87, size: 22) : Text(key, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: kBlack87))))); }
}

// ==========================================
// 4. SPLIT PAYMENT PAGE (RESTORED LOGIC)
// ==========================================
class SplitPaymentPage extends StatefulWidget {
  final String uid; final String? userEmail; final List<CartItem> cartItems; final double totalAmount; final String? customerPhone; final String? customerName; final String? customerGST; final double discountAmount; final String creditNote; final String? savedOrderId; final List<Map<String, dynamic>> selectedCreditNotes; final String? quotationId; final String? existingInvoiceNumber; final String? unsettledSaleId;
  final String businessName; final String businessLocation; final String businessPhone; final String staffName;

  const SplitPaymentPage({super.key, required this.uid, this.userEmail, required this.cartItems, required this.totalAmount, this.customerPhone, this.customerName, this.customerGST, required this.discountAmount, required this.creditNote, this.savedOrderId, this.selectedCreditNotes = const [], this.quotationId, this.existingInvoiceNumber, this.unsettledSaleId, required this.businessName, required this.businessLocation, required this.businessPhone, required this.staffName});
  @override State<SplitPaymentPage> createState() => _SplitPaymentPageState();
}

class _SplitPaymentPageState extends State<SplitPaymentPage> {
  final TextEditingController _cashController = TextEditingController(text: '0.00');
  final TextEditingController _onlineController = TextEditingController(text: '0.00');
  final TextEditingController _creditController = TextEditingController(text: '0.00');

  double _cashAmount = 0.0;
  double _onlineAmount = 0.0;
  double _creditAmount = 0.0;
  double get _totalPaid => _cashAmount + _onlineAmount + _creditAmount;
  double get _dueAmount => widget.totalAmount - _totalPaid;

  @override
  void initState() {
    super.initState();
    _cashController.addListener(() => setState(() => _cashAmount = double.tryParse(_cashController.text) ?? 0.0));
    _onlineController.addListener(() => setState(() => _onlineAmount = double.tryParse(_onlineController.text) ?? 0.0));
    _creditController.addListener(() => setState(() => _creditAmount = double.tryParse(_creditController.text) ?? 0.0));
  }

  Future<void> _processSplitSale() async {
    if (_dueAmount > 0.01) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment insufficient'))); return; }
    if (_creditAmount > 0 && widget.customerPhone == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer required for Credit'))); return; }

    try {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      final invoiceNumber = widget.existingInvoiceNumber ?? await NumberGeneratorService.generateInvoiceNumber();

      final Map<String, double> taxMap = {};
      for (var item in widget.cartItems) { if (item.taxAmount > 0 && item.taxName != null) taxMap[item.taxName!] = (taxMap[item.taxName!] ?? 0.0) + item.taxAmount; }
      final taxList = taxMap.entries.map((e) => {'name': e.key, 'amount': e.value}).toList();
      final totalTax = taxMap.values.fold(0.0, (a, b) => a + b);

      final baseSaleData = {
        'invoiceNumber': invoiceNumber, 'items': widget.cartItems.map((e)=> {'productId':e.productId, 'name':e.name, 'quantity':e.quantity, 'price':e.price, 'total':e.total}).toList(),
        'subtotal': widget.totalAmount + widget.discountAmount, 'discount': widget.discountAmount, 'total': widget.totalAmount, 'taxes': taxList, 'totalTax': totalTax,
        'paymentMode': 'Split', 'cashReceived': _totalPaid - _creditAmount, 'cashReceived_split': _cashAmount, 'onlineReceived_split': _onlineAmount, 'creditIssued_split': _creditAmount, 'customerPhone': widget.customerPhone, 'customerName': widget.customerName, 'customerGST': widget.customerGST, 'creditNote': widget.creditNote, 'date': DateTime.now().toIso8601String(), 'staffId': widget.uid, 'staffName': widget.staffName, 'businessName': widget.businessName, 'businessLocation': widget.businessLocation, 'businessPhone': widget.businessPhone, 'timestamp': FieldValue.serverTimestamp(),
      };

      if (_creditAmount > 0) await _updateCustomerCredit(widget.customerPhone!, _creditAmount, invoiceNumber);

      if (widget.unsettledSaleId != null) {
        await FirestoreService().updateDocument('sales', widget.unsettledSaleId!, {...baseSaleData, 'paymentStatus': 'settled', 'settledAt': FieldValue.serverTimestamp()});
      } else {
        await FirestoreService().addDocument('sales', baseSaleData);
        await _updateProductStock();
      }

      if (widget.savedOrderId != null) await FirestoreService().deleteDocument('savedOrders', widget.savedOrderId!);
      if (widget.selectedCreditNotes.isNotEmpty) await _markCreditNotesAsUsed(invoiceNumber, widget.selectedCreditNotes);
      if (widget.quotationId != null && widget.quotationId!.isNotEmpty) {
        await FirestoreService().updateDocument('quotations', widget.quotationId!, {'status': 'settled', 'billed': true, 'settledAt': FieldValue.serverTimestamp()});
      }

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        Navigator.popUntil(context, (route) => route.isFirst);
        Navigator.push(context, CupertinoPageRoute(builder: (_) => InvoicePage(
            uid: widget.uid, userEmail: widget.userEmail, businessName: widget.businessName, businessLocation: widget.businessLocation, businessPhone: widget.businessPhone, invoiceNumber: invoiceNumber, dateTime: DateTime.now(),
            items: widget.cartItems.map((e)=> {'name':e.name, 'quantity':e.quantity, 'price':e.price, 'total':e.totalWithTax, 'taxPercentage':e.taxPercentage ?? 0, 'taxAmount':e.taxAmount}).toList(),
            subtotal: widget.totalAmount + widget.discountAmount - totalTax, discount: widget.discountAmount, taxes: taxList, total: widget.totalAmount, paymentMode: 'Split', cashReceived: _totalPaid - _creditAmount, customerName: widget.customerName, customerPhone: widget.customerPhone)));
      }
    } catch (e) { if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)); } }
  }

  Future<void> _updateCustomerCredit(String phone, double amount, String invoiceNumber) async { final customerRef = await FirestoreService().getDocumentReference('customers', phone); await FirebaseFirestore.instance.runTransaction((transaction) async { final customerDoc = await transaction.get(customerRef); if (customerDoc.exists) { final currentBalance = (customerDoc.data() as Map<String, dynamic>?)?['balance'] as double? ?? 0.0; transaction.update(customerRef, {'balance': currentBalance + amount, 'lastUpdated': FieldValue.serverTimestamp()}); } }); }
  Future<void> _updateProductStock() async { final localStockService = context.read<LocalStockService>(); for (var cartItem in widget.cartItems) { if (cartItem.productId.startsWith('qs_')) continue; final productRef = await FirestoreService().getDocumentReference('Products', cartItem.productId); await productRef.update({'currentStock': FieldValue.increment(-(cartItem.quantity))}); await localStockService.updateLocalStock(cartItem.productId, -cartItem.quantity); } }
  Future<void> _markCreditNotesAsUsed(String invoiceNumber, List<Map<String, dynamic>> selectedCreditNotes) async { for (var creditNote in selectedCreditNotes) { await FirestoreService().updateDocument('creditNotes', creditNote['id'], {'status': 'Used', 'usedInInvoice': invoiceNumber, 'usedAt': FieldValue.serverTimestamp()}); } }

  @override
  Widget build(BuildContext context) {
    bool canPay = _dueAmount <= 0.01 && _dueAmount >= -0.01;
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(title: const Text('Split Payment', style: TextStyle(color: kWhite, fontWeight: FontWeight.w600)), backgroundColor: kPrimaryColor, iconTheme: const IconThemeData(color: kWhite), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity, padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: kPrimaryColor, borderRadius: BorderRadius.circular(20)),
              child: Column(children: [
                const Text('TOTAL BILL AMOUNT', style: TextStyle(color: kWhite, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
                const SizedBox(height: 8),
                Text('Rs ${widget.totalAmount.toStringAsFixed(2)}', style: const TextStyle(color: kWhite, fontSize: 32, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 24),
            _buildInput('Cash Received', Icons.payments_rounded, _cashController),
            const SizedBox(height: 12),
            _buildInput('Online / UPI', Icons.qr_code_scanner_rounded, _onlineController),
            const SizedBox(height: 12),
            _buildInput('Credit Book', Icons.menu_book_rounded, _creditController, enabled: widget.customerPhone != null),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: kGrey200)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Remaining Due', style: TextStyle(fontWeight: FontWeight.w600)),
                Text('Rs ${_dueAmount.toStringAsFixed(2)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: canPay ? kGoogleGreen : kGoogleRed)),
              ]),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(height: 60, child: ElevatedButton(onPressed: canPay ? _processSplitSale : null, style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('SETTLE BILL', style: TextStyle(color: kWhite, fontWeight: FontWeight.w600)))),
      ),
    );
  }

  Widget _buildInput(String label, IconData icon, TextEditingController ctrl, {bool enabled = true}) {
    return TextFormField(
        controller: ctrl, enabled: enabled, keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label, prefixIcon: Icon(icon, color: enabled ? kPrimaryColor : kBlack54),
          filled: true, fillColor: kWhite,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrey200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5)),
          disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrey100)),
        )
    );
  }
}

// ==========================================
// 5. CUSTOMER SELECTION DIALOG (INTERNAL)
// ==========================================
