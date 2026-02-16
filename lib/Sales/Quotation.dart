import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:heroicons/heroicons.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/Sales/QuotationPreview.dart';
import 'package:maxbillup/Sales/Invoice.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/amount_formatter.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/services/number_generator_service.dart';
import 'package:maxbillup/services/currency_service.dart';

class QuotationPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final List<CartItem> cartItems;
  final double totalAmount;
  final String? customerPhone;
  final String? customerName;
  final String? customerGST;

  const QuotationPage({
    super.key,
    required this.uid,
    this.userEmail,
    required this.cartItems,
    required this.totalAmount,
    this.customerPhone,
    this.customerName,
    this.customerGST,
  });

  @override
  State<QuotationPage> createState() => _QuotationPageState();
}

class _QuotationPageState extends State<QuotationPage> {
  late String _uid;
  String? _selectedCustomerPhone;
  String? _selectedCustomerName;
  String? _selectedCustomerGST;

  bool _isBillWise = true;

  // Bill Wise state
  double _cashDiscountAmount = 0.0;
  double _percentageDiscount = 0.0;
  final TextEditingController _cashDiscountController = TextEditingController();
  final TextEditingController _percentageController = TextEditingController();

  // Item Wise state
  late List<TextEditingController> _itemDiscountControllers;
  late List<double> _itemDiscounts;
  late List<bool> _isItemDiscountPercentage;
  String _currencySymbol = '';

  @override
  void initState() {
    super.initState();
    _uid = widget.uid;
    _selectedCustomerPhone = widget.customerPhone;
    _selectedCustomerName = widget.customerName;
    _selectedCustomerGST = widget.customerGST;
    _loadCurrency();

    _itemDiscountControllers = List.generate(
      widget.cartItems.length,
          (_) => TextEditingController(),
    );
    _itemDiscounts = List.filled(widget.cartItems.length, 0.0);
    _isItemDiscountPercentage = List.filled(widget.cartItems.length, false);
  }

  void _loadCurrency() async {
    final store = await FirestoreService().getCurrentStoreDoc();
    if (store != null && store.exists && mounted) {
      final data = store.data() as Map<String, dynamic>;
      setState(() => _currencySymbol = CurrencyService.getSymbolWithSpace(data['currency']));
    }
  }

  @override
  void dispose() {
    _cashDiscountController.dispose();
    _percentageController.dispose();
    for (var controller in _itemDiscountControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  double get _discountAmount {
    if (_isBillWise) {
      if (_cashDiscountAmount > 0) return _cashDiscountAmount;
      if (_percentageDiscount > 0) return widget.totalAmount * (_percentageDiscount / 100);
    } else {
      double totalItemDiscount = 0;
      for (int i = 0; i < widget.cartItems.length; i++) {
        if (i >= _isItemDiscountPercentage.length) break;
        if (_isItemDiscountPercentage[i]) {
          totalItemDiscount += widget.cartItems[i].total * (_itemDiscounts[i] / 100);
        } else {
          totalItemDiscount += _itemDiscounts[i];
        }
      }
      return totalItemDiscount;
    }
    return 0.0;
  }

  double get _discountPercentage {
    if (widget.totalAmount == 0) return 0.0;
    return (_discountAmount / widget.totalAmount) * 100;
  }

  double get _newTotal => widget.totalAmount - _discountAmount;

  void _updateItemDiscount(int index, String value) {
    setState(() {
      final discount = double.tryParse(value) ?? 0.0;
      if (_isItemDiscountPercentage[index]) {
        _itemDiscounts[index] = discount.clamp(0.0, 100.0);
      } else {
        final maxDiscount = widget.cartItems[index].total;
        _itemDiscounts[index] = discount.clamp(0.0, maxDiscount);
      }
    });
  }

  void _toggleItemDiscountMode(int index) {
    setState(() {
      _isItemDiscountPercentage[index] = !_isItemDiscountPercentage[index];
      _itemDiscounts[index] = 0.0;
      _itemDiscountControllers[index].clear();
    });
  }

  void _updateCashDiscount(String v) {
    setState(() {
      _cashDiscountAmount = double.tryParse(v) ?? 0.0;
      if (_cashDiscountAmount > 0) {
        _percentageDiscount = 0.0;
        _percentageController.clear();
      }
    });
  }

  void _updatePercentageDiscount(String v) {
    setState(() {
      _percentageDiscount = double.tryParse(v) ?? 0.0;
      if (_percentageDiscount > 0) {
        _cashDiscountAmount = 0.0;
        _cashDiscountController.clear();
      }
    });
  }

  void _showCustomerDialog() {
    showDialog(
      context: context,
      builder: (context) => _CustomerSelectionDialog(
        uid: _uid,
        onCustomerSelected: (phone, name, gst) {
          setState(() {
            _selectedCustomerPhone = phone;
            _selectedCustomerName = name;
            _selectedCustomerGST = gst;
          });
        },
        onCustomerUnselected: () {
          setState(() {
            _selectedCustomerPhone = null;
            _selectedCustomerName = null;
            _selectedCustomerGST = null;
          });
        },
        selectedCustomerPhone: _selectedCustomerPhone,
      ),
    );
  }

  Future<Map<String, String?>> _fetchBusinessDetails() async {
    try {
      final firestoreService = FirestoreService();
      final storeDoc = await firestoreService.getCurrentStoreDoc();

      if (storeDoc != null && storeDoc.exists) {
        final data = storeDoc.data() as Map<String, dynamic>?;
        return {
          'businessName': data?['businessName'] as String?,
          'location': data?['location'] as String? ?? data?['businessLocation'] as String? ?? data?['businessAddress'] as String?,
          'businessPhone': data?['businessPhone'] as String?,
          'gstin': data?['gstin'] as String?,
        };
      }
      return {'businessName': null, 'location': null, 'businessPhone': null, 'gstin': null};
    } catch (e) {
      debugPrint('Error fetching business details: $e');
      return {'businessName': null, 'location': null, 'businessPhone': null, 'gstin': null};
    }
  }

  Future<void> _generateQuotation() async {
    try {
      // 1. Show Loading Indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
      );

      // 2. Identity Verification & Store Fetch
      final firestoreService = FirestoreService();
      final storeId = await firestoreService.getCurrentStoreId();

      if (storeId == null) {
        if (mounted) Navigator.pop(context); // Close loading
        throw Exception('Identity Error: Store ID not found. Please setup your profile in Settings.');
      }

      final storeDoc = await firestoreService.getCurrentStoreDoc();
      final storeData = storeDoc?.data() as Map<String, dynamic>?;
      final staffName = storeData?['ownerName'] ?? 'Staff';

      // Generate quotation number with prefix using the service
      final prefix = await NumberGeneratorService.getQuotationPrefix();
      final number = await NumberGeneratorService.generateInvoiceNumber(); // Fixed: generate quotation number if needed
      final quotationNumber = prefix.isNotEmpty ? '$prefix$number' : number;

      // Calculate tax information from cart items
      final Map<String, double> taxMap = {};
      for (var item in widget.cartItems) {
        if (item.taxAmount > 0 && item.taxName != null) {
          taxMap[item.taxName!] = (taxMap[item.taxName!] ?? 0.0) + item.taxAmount;
        }
      }
      final taxList = taxMap.entries.map((e) => {'name': e.key, 'amount': e.value}).toList();
      final totalTax = taxMap.values.fold(0.0, (a, b) => a + b);

      // Calculate subtotal (without tax) and total with tax
      final subtotalAmount = widget.cartItems.fold(0.0, (sum, item) {
        if (item.taxType == 'Tax Included in Price' || item.taxType == 'Price includes Tax') {
          return sum + (item.basePrice * item.quantity);
        } else {
          return sum + item.total;
        }
      });
      final totalWithTax = widget.cartItems.fold(0.0, (sum, item) => sum + item.totalWithTax);

      // 3. Prepare Data
      final List<Map<String, dynamic>> itemsList = widget.cartItems.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;

        double calculatedItemDiscountValue = _isBillWise
            ? 0.0
            : (_isItemDiscountPercentage[index]
            ? (item.total * (_itemDiscounts[index] / 100))
            : _itemDiscounts[index]);

        return {
          'productId': item.productId,
          'name': item.name,
          'price': item.price,
          'quantity': item.quantity,
          'total': item.total,
          'taxName': item.taxName,
          'taxPercentage': item.taxPercentage ?? 0,
          'taxAmount': item.taxAmount,
          'taxType': item.taxType,
          'totalWithTax': item.totalWithTax,
          'discount': calculatedItemDiscountValue,
          'discountInputType': _isBillWise ? 'none' : (_isItemDiscountPercentage[index] ? 'percentage' : 'cash'),
          'finalTotal': item.total - calculatedItemDiscountValue,
        };
      }).toList();

      final quotationData = {
        'quotationNumber': quotationNumber,
        'items': itemsList,
        'subtotal': subtotalAmount,
        'discount': _discountAmount,
        'discountPercentage': _discountPercentage,
        'taxes': taxList,
        'totalTax': totalTax,
        'total': totalWithTax - _discountAmount,
        'discountMode': _isBillWise ? 'billWise' : 'itemWise',
        'billWiseCashDiscount': _cashDiscountAmount,
        'billWisePercDiscount': _percentageDiscount,
        'customerPhone': _selectedCustomerPhone,
        'customerName': _selectedCustomerName ?? 'Guest',
        'customerGST': (_selectedCustomerGST?.isEmpty ?? true) ? null : _selectedCustomerGST,
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String(),
        'staffId': widget.uid,
        'staffName': staffName,
        'status': 'active',
        'billed': false,
      };

      // 4. Save to Subcollection of Store
      final docRef = await firestoreService.addDocument('quotations', quotationData);

      // Secondary update to store the generated ID inside the document
      await firestoreService.updateDocument('quotations', docRef.id, {'quotationId': docRef.id});

      if (mounted) {
        Navigator.pop(context); // Remove loading indicator

        // Fetch business details for invoice
        final businessDetails = await _fetchBusinessDetails();
        final businessName = businessDetails['businessName'] ?? 'Business';
        final businessLocation = businessDetails['location'] ?? 'Location';
        final businessPhone = businessDetails['businessPhone'] ?? '';
        final businessGSTIN = businessDetails['gstin'];

        // Navigate to Invoice page with isQuotation=true and complete tax information
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => InvoicePage(
              uid: widget.uid,
              userEmail: widget.userEmail,
              businessName: businessName,
              businessLocation: businessLocation,
              businessPhone: businessPhone,
              businessGSTIN: businessGSTIN,
              invoiceNumber: quotationNumber,
              dateTime: DateTime.now(),
              items: widget.cartItems.map((e) => {
                'name': e.name,
                'quantity': e.quantity,
                'price': e.price,
                'total': e.totalWithTax,
                'taxPercentage': e.taxPercentage ?? 0,
                'taxAmount': e.taxAmount,
              }).toList(),
              subtotal: subtotalAmount,
              discount: _discountAmount,
              taxes: taxList,
              total: totalWithTax - _discountAmount,
              paymentMode: 'Quotation',
              cashReceived: 0.0,
              customerName: _selectedCustomerName,
              customerPhone: _selectedCustomerPhone,
              customerGSTIN: _selectedCustomerGST,
              isQuotation: true, // Mark this as a quotation
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Remove loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Submission Error: ${e.toString()}'),
              backgroundColor: kErrorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasCustomer = _selectedCustomerName != null && _selectedCustomerName!.isNotEmpty;

    return Scaffold(
      backgroundColor: kGreyBg,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 22), onPressed: () => Navigator.pop(context)),
        title: const Text('New Quotation', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: InkWell(
              onTap: _showCustomerDialog,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: hasCustomer ? kPrimaryColor : kOrange, width: hasCustomer ? 1 : 1.5),
                ),
                child: Row(
                  children: [
                    HeroIcon(hasCustomer ? HeroIcons.user : HeroIcons.userPlus, color: hasCustomer ? kPrimaryColor : kOrange, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        hasCustomer ? _selectedCustomerName! : 'Assign Customer',
                        style: TextStyle(color: hasCustomer ? kPrimaryColor : kOrange, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (hasCustomer)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCustomerPhone = null;
                            _selectedCustomerName = null;
                            _selectedCustomerGST = null;
                          });
                        },
                        child: const HeroIcon(HeroIcons.xCircle, color: kErrorColor, size: 20),
                      )
                    else
                      const HeroIcon(HeroIcons.chevronRight, color: kGrey400, size: 14),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(color: kWhite, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Discounting Strategy', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kBlack54, letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildToggleBtn('Bill Wise', _isBillWise, () => setState(() => _isBillWise = true)),
                        const SizedBox(width: 10),
                        _buildToggleBtn('Item Wise', !_isBillWise, () => setState(() => _isBillWise = false)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_isBillWise) ...[
                      _buildSummaryRow('Initial Total', widget.totalAmount),
                      const SizedBox(height: 24),
                      _buildInputLabel('Fixed Cash Discount'),
                      _buildTextField(_cashDiscountController, '0.00', _updateCashDiscount, HeroIcons.banknotes),
                      const SizedBox(height: 16),
                      Center(child: Text('OR', style: TextStyle(color: kGrey400, fontWeight: FontWeight.w800, fontSize: 10))),
                      const SizedBox(height: 16),
                      _buildInputLabel('Percentage (%) Discount'),
                      _buildTextField(_percentageController, '0%', _updatePercentageDiscount, HeroIcons.receiptPercent),
                    ] else ...[
                      _buildItemWiseTable(),
                    ],
                    // Add extra padding at bottom to prevent content from being hidden under sticky bottom area
                    const SizedBox(height: 200),
                  ],
                ),
              ),
            ),
          ),
          // Sticky bottom summary area - now outside the scrollable content
          SafeArea(
            child: _buildBottomSummaryArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildItemWiseTable() {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(12)),
          child: const Row(
            children: [

              Expanded(flex: 3, child: Text('PRODUCT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kBlack54))),
              Expanded(flex: 2, child: Text('QTY/RATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kBlack54))),
              Expanded(flex: 2, child: Text('TOTAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kBlack54))),
              Expanded(flex: 3, child: Text('DISC', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kBlack54))),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Table Body
        ...widget.cartItems.asMap().entries.map((entry) => _buildItemTableRow(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildItemTableRow(int index, CartItem item) {
    final bool isPerc = _isItemDiscountPercentage[index];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kGreyBg))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Column 1: Qty / Rate
          Expanded(
            flex: 3,
            child: Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: kBlack87),
                maxLines: 2, overflow: TextOverflow.ellipsis
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
                '${item.quantity}x${AmountFormatter.format(item.price)}',
                style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w700)
            ),
          ),
          // Column 2: Product Name

          // Column 3: Total
          Expanded(
            flex: 2,
            child: Text(
                AmountFormatter.format(item.total),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kBlack87)
            ),
          ),
          // Column 4: Discount Box (Increased size)
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => _toggleItemDiscountMode(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: (0.1 * 255).toDouble()), borderRadius: BorderRadius.circular(6)),
                    child: Text(isPerc ? "%" : "Amt", style: const TextStyle(color: kPrimaryColor,fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 70,
                  height: 32,
                  child: TextField(
                    controller: _itemDiscountControllers[index],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => _updateItemDiscount(index, v),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                    decoration: InputDecoration(
                      hintText: '0',
                      filled: true,
                      fillColor: kGreyBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSummaryArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: kWhite,
        border: Border(top: BorderSide(color: kGrey200)),

      ),
      child: Column(
        children: [
          _buildFinalSummary(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton(
              onPressed: _generateQuotation,
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              child: const Text('GENERATE QUOTATION', style: TextStyle(color: kWhite, fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? kPrimaryColor : kGreyBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? kPrimaryColor : kGrey200),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? kWhite : kBlack54, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) => Padding(padding: const EdgeInsets.only(bottom: 6, left: 4), child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: kBlack87)));

  Widget _buildTextField(TextEditingController ctrl, String hint, Function(String) onChange, HeroIcons icon) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: onChange,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint, prefixIcon: Padding(
            padding: const EdgeInsets.all(12.0),
            child: HeroIcon(icon, color: kPrimaryColor, size: 18),
          ),
          filled: true, fillColor: kGreyBg,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrey200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: kBlack54, fontWeight: FontWeight.w600, fontSize: 13)),
        Text('$_currencySymbol${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kBlack87)),
      ],
    );
  }

  Widget _buildFinalSummary() {
    // Calculate tax information from cart items
    final Map<String, double> taxMap = {};
    for (var item in widget.cartItems) {
      if (item.taxAmount > 0 && item.taxName != null) {
        taxMap[item.taxName!] = (taxMap[item.taxName!] ?? 0.0) + item.taxAmount;
      }
    }
    final totalTax = taxMap.values.fold(0.0, (a, b) => a + b);

    // Calculate subtotal (without tax) and total with tax
    final subtotalAmount = widget.cartItems.fold(0.0, (sum, item) {
      if (item.taxType == 'Tax Included in Price' || item.taxType == 'Price includes Tax') {
        return sum + (item.basePrice * item.quantity);
      } else {
        return sum + item.total;
      }
    });
    final totalWithTax = widget.cartItems.fold(0.0, (sum, item) => sum + item.totalWithTax);
    final finalTotal = totalWithTax - _discountAmount;

    final perc = _discountPercentage;
    return Column(
      children: [
        // Subtotal
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Subtotal', style: TextStyle(fontWeight: FontWeight.w600, color: kBlack54, fontSize: 13)),
            Text('$_currencySymbol${subtotalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kBlack87))
          ]
        ),
        const SizedBox(height: 8),

        // Tax (if applicable)
        if (totalTax > 0) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tax', style: TextStyle(fontWeight: FontWeight.w600, color: kBlack54, fontSize: 13)),
              Text('$_currencySymbol${totalTax.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kBlack87))
            ]
          ),
          const SizedBox(height: 8),
        ],

        // Discount
        if (_discountAmount > 0) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Discount (${perc.toStringAsFixed(1)}%)', style: const TextStyle(fontWeight: FontWeight.w600, color: kBlack54, fontSize: 13)),
              Text('- $_currencySymbol${_discountAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, color: kErrorColor, fontSize: 14))
            ]
          ),
          const SizedBox(height: 8),
        ],

        const Divider(color: kGrey200, height: 16),

        // Net Total
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Net Total', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kBlack87)),
            Text('$_currencySymbol${finalTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: kPrimaryColor))
          ]
        ),
      ],
    );
  }
}

class _CustomerSelectionDialog extends StatefulWidget {
  final String uid;
  final Function(String phone, String name, String? gst) onCustomerSelected;
  final VoidCallback? onCustomerUnselected;
  final String? selectedCustomerPhone;

  const _CustomerSelectionDialog({required this.uid, required this.onCustomerSelected, this.onCustomerUnselected, this.selectedCustomerPhone});

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
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: kWhite,
      child: Container(
        height: 550, padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Select Customer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kBlack87)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const HeroIcon(HeroIcons.xMark, color: kBlack54)),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search Name or Phone...', prefixIcon: const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: HeroIcon(HeroIcons.magnifyingGlass, color: kPrimaryColor, size: 20),
                  ),
                  filled: true, fillColor: kGreyBg,
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrey200)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showAddCustomerDialog,
                    icon: const HeroIcon(HeroIcons.userPlus, size: 18),
                    label: const Text("ADD NEW", style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: kPrimaryColor), foregroundColor: kPrimaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _importFromContacts,
                    icon: const HeroIcon(HeroIcons.users, size: 18),
                    label: const Text("IMPORT", style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: kPrimaryColor), foregroundColor: kPrimaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<CollectionReference>(
                future: FirestoreService().getStoreCollection('customers'),
                builder: (context, collectionSnapshot) {
                  if (!collectionSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                  return StreamBuilder<QuerySnapshot>(
                    stream: collectionSnapshot.data!.orderBy('name').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final docs = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final n = (data['name'] ?? '').toString().toLowerCase();
                        final p = (data['phone'] ?? '').toString().toLowerCase();
                        return n.contains(_searchQuery) || p.contains(_searchQuery);
                      }).toList();
                      if (docs.isEmpty) return const Center(child: Text('No customer found'));
                      return ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (ctx, i) => const Divider(color: kGreyBg),
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            onTap: () { widget.onCustomerSelected(data['phone'] ?? '', data['name'] ?? '', data['gst']); Navigator.pop(context); },
                            leading: CircleAvatar(backgroundColor: kPrimaryColor.withValues(alpha: (0.1 * 255).toDouble()), child: Text(data['name']?[0].toUpperCase() ?? 'U', style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w700))),
                            title: Text(data['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600, color: kBlack87, fontSize: 14)),
                            subtitle: Text(data['phone'] ?? '', style: const TextStyle(fontSize: 11, color: kBlack54)),
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

  Future<void> _importFromContacts() async {
    if (!await FlutterContacts.requestPermission()) return;
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    if (contacts.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) {
        List<Contact> filtered = contacts;
        return StatefulBuilder(
          builder: (context, setDialogState) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SizedBox(
              width: 350, height: 500,
              child: Column(
                children: [
                  const Padding(padding: EdgeInsets.all(16.0), child: Text('Import Contact', style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextField(
                      decoration: const InputDecoration(hintText: 'Search...', prefixIcon: HeroIcon(HeroIcons.magnifyingGlass), border: OutlineInputBorder()),
                      onChanged: (v) => setDialogState(() => filtered = contacts.where((c) => c.displayName.toLowerCase().contains(v.toLowerCase())).toList()),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final c = filtered[index];
                        final phone = c.phones.isNotEmpty ? c.phones.first.number.replaceAll(' ', '') : '';
                        return ListTile(
                          title: Text(c.displayName), subtitle: Text(phone),
                          onTap: phone.isEmpty ? null : () { Navigator.pop(context); _showAddCustomerDialog(prefillName: c.displayName, prefillPhone: phone); },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAddCustomerDialog({String? prefillName, String? prefillPhone}) async {
    final nameCtrl = TextEditingController(text: prefillName ?? '');
    final phoneCtrl = TextEditingController(text: prefillPhone ?? '');
    final gstCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('New Customer', style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: gstCtrl, decoration: const InputDecoration(labelText: 'GST (Optional)', border: OutlineInputBorder())),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () async {
                      if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;
                      await FirestoreService().setDocument('customers', phoneCtrl.text.trim(), {
                        'name': nameCtrl.text.trim(), 'phone': phoneCtrl.text.trim(), 'gst': gstCtrl.text.trim().isEmpty ? null : gstCtrl.text.trim(),
                        'balance': 0.0, 'totalSales': 0.0, 'timestamp': FieldValue.serverTimestamp(), 'lastUpdated': FieldValue.serverTimestamp(),
                      });
                      if (mounted) { Navigator.pop(context); widget.onCustomerSelected(phoneCtrl.text.trim(), nameCtrl.text.trim(), gstCtrl.text.trim()); }
                    },
                    child: const Text('Add', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
