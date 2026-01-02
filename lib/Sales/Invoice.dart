import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:maxbillup/Sales/components/common_widgets.dart';
import 'package:maxbillup/Sales/NewSale.dart';
import 'package:maxbillup/services/cart_service.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/Colors.dart';

// Invoice Template Types
enum InvoiceTemplate {
  classic,    // Black & White Professional
  modern,     // Blue Accent Modern
  minimal,    // Clean Minimal
  colorful,   // Colorful Creative
}

// Template Colors - Classic (Black & White)
const Color _bwPrimary = Colors.black;
const Color _bwBg = Colors.white;
const Color _textMain = Colors.black;
const Color _textSub = Color(0xFF424242);
const Color _headerBg = Color(0xFFF5F5F5);

// Template Colors - Modern (Blue)
const Color _modernPrimary = Color(0xFF2F7CF6);
const Color _modernBg = Colors.white;
const Color _modernAccent = Color(0xFF1565C0);
const Color _modernHeaderBg = Color(0xFFE3F2FD);

// Template Colors - Minimal (Gray)
const Color _minimalPrimary = Color(0xFF37474F);
const Color _minimalBg = Colors.white;
const Color _minimalAccent = Color(0xFF78909C);
const Color _minimalHeaderBg = Color(0xFFF5F5F5);

// Template Colors - Colorful (Multi-color)
const Color _colorfulPrimary = Color(0xFF6A1B9A);
const Color _colorfulBg = Colors.white;
const Color _colorfulAccent = Color(0xFFFF6F00);
const Color _colorfulHeaderBg = Color(0xFFF3E5F5);

class InvoicePage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final String businessName;
  final String businessLocation;
  final String businessPhone;
  final String? businessGSTIN;
  final String invoiceNumber;
  final DateTime dateTime;
  final List<Map<String, dynamic>> items;
  final double subtotal;
  final double discount;
  final List<Map<String, dynamic>>? taxes;
  final double total;
  final String paymentMode;
  final double cashReceived;
  final String? customerName;
  final String? customerPhone;
  final String? customerGSTIN;
  final String? customNote;
  final String? deliveryAddress;
  final bool isQuotation;

  const InvoicePage({
    super.key,
    required this.uid,
    this.userEmail,
    required this.businessName,
    required this.businessLocation,
    required this.businessPhone,
    this.businessGSTIN,
    required this.invoiceNumber,
    required this.dateTime,
    required this.items,
    required this.subtotal,
    required this.discount,
    this.taxes,
    required this.total,
    required this.paymentMode,
    required this.cashReceived,
    this.customerName,
    this.customerPhone,
    this.customerGSTIN,
    this.customNote,
    this.deliveryAddress,
    this.isQuotation = false,
  });

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  bool _isLoading = true;
  String? _storeId;

  late String businessName;
  late String businessLocation;
  late String businessPhone;
  String? businessGSTIN;
  String? businessEmail;
  String? businessLogoUrl;

  // Header Info Settings
  String _receiptHeader = 'INVOICE';
  bool _showLogo = true;
  bool _showEmail = false;
  bool _showPhone = true;
  bool _showGST = false;

  // Item Table Settings
  bool _showCustomerDetails = true;
  bool _showCustomerCreditDetails = false;
  bool _showMeasuringUnit = true;
  bool _showMRP = false;
  bool _showPaymentMode = true;
  bool _showTotalItems = true;
  bool _showTotalQty = false;
  bool _showSaveAmountMessage = true;
  bool _showCustomNote = false;
  bool _showDeliveryAddress = false;

  // Invoice Footer Settings
  String _footerDescription = 'Thank you for your business!';
  String? _footerImageUrl;

  // Quotation Footer Settings
  String _quotationFooterDescription = 'Thank You';

  // Template selection
  InvoiceTemplate _selectedTemplate = InvoiceTemplate.classic;

  // Stream subscription for store data changes
  StreamSubscription<Map<String, dynamic>>? _storeDataSubscription;

  @override
  void initState() {
    super.initState();
    businessName = widget.businessName;
    businessLocation = widget.businessLocation;
    businessPhone = widget.businessPhone;
    businessGSTIN = widget.businessGSTIN;
    _loadStoreData();
    _loadReceiptSettings();
    _loadTemplatePreference();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CartService>().clearCart();
      }
    });

    _storeDataSubscription = FirestoreService().storeDataStream.listen((storeData) {
      if (mounted) {
        setState(() {
          businessLogoUrl = storeData['logoUrl'];
          businessName = storeData['businessName'] ?? businessName;
          businessPhone = storeData['businessPhone'] ?? businessPhone;
          businessLocation = storeData['businessAddress'] ?? businessLocation;
          businessGSTIN = storeData['gstin'];
          businessEmail = storeData['email'];
        });
      }
    });
  }

  @override
  void dispose() {
    _storeDataSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadTemplatePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final templateIndex = prefs.getInt('invoice_template') ?? 0;
      setState(() {
        _selectedTemplate = InvoiceTemplate.values[templateIndex];
      });
    } catch (e) {
      debugPrint('Error loading template preference: $e');
    }
  }

  Future<void> _loadReceiptSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        // Header Info
        _receiptHeader = prefs.getString('receipt_header') ?? 'INVOICE';
        _showLogo = prefs.getBool('receipt_show_logo') ?? true;
        _showEmail = prefs.getBool('receipt_show_email') ?? false;
        _showPhone = prefs.getBool('receipt_show_phone') ?? true;
        _showGST = prefs.getBool('receipt_show_gst') ?? false;

        // Item Table
        _showCustomerDetails = prefs.getBool('receipt_show_customer_details') ?? true;
        _showCustomerCreditDetails = prefs.getBool('receipt_show_customer_credit') ?? false;
        _showMeasuringUnit = prefs.getBool('receipt_show_measuring_unit') ?? true;
        _showMRP = prefs.getBool('receipt_show_mrp') ?? false;
        _showPaymentMode = prefs.getBool('receipt_show_payment_mode') ?? true;
        _showTotalItems = prefs.getBool('receipt_show_total_items') ?? true;
        _showTotalQty = prefs.getBool('receipt_show_total_qty') ?? false;
        _showSaveAmountMessage = prefs.getBool('receipt_show_save_amount') ?? true;
        _showCustomNote = prefs.getBool('receipt_show_custom_note') ?? false;
        _showDeliveryAddress = prefs.getBool('receipt_show_delivery_address') ?? false;

        // Invoice Footer
        _footerDescription = prefs.getString('receipt_footer_description') ?? 'Thank you for your business!';
        _footerImageUrl = prefs.getString('receipt_footer_image');

        // Quotation Footer
        _quotationFooterDescription = prefs.getString('quotation_footer_description') ?? 'Thank You';
      });
    } catch (e) {
      debugPrint('Error loading receipt settings: $e');
    }
  }

  Future<void> _loadStoreData() async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
      if (userDoc.exists) {
        _storeId = userDoc.data()?['storeId'];
        if (_storeId != null) {
          final storeDoc = await FirebaseFirestore.instance.collection('store').doc(_storeId).get();
          if (storeDoc.exists) {
            final storeData = storeDoc.data()!;
            setState(() {
              businessName = storeData['businessName'] ?? widget.businessName;
              businessPhone = storeData['businessPhone'] ?? widget.businessPhone;
              businessLocation = storeData['businessAddress'] ?? widget.businessLocation;
              businessGSTIN = storeData['gstin'] ?? widget.businessGSTIN;
              businessEmail = storeData['email'];
              businessLogoUrl = storeData['logoUrl'];
              _isLoading = false;
            });
            return;
          }
        }
      }
      setState(() { _isLoading = false; });
    } catch (e) {
      setState(() { _isLoading = false; });
    }
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('dd-MM-yyyy, h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final templateColors = _getTemplateColors(_selectedTemplate);

    return Scaffold(
      backgroundColor: templateColors['bg'],
      appBar: AppBar(
        backgroundColor: templateColors['bg'],
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.isQuotation
              ? 'QUOTATION DETAILS'
              : context.tr('invoice details').toUpperCase(),
          style: TextStyle(
            color: templateColors['primary'],
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 1.0,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: templateColors['primary']),
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            CupertinoPageRoute(builder: (context) => NewSalePage(uid: widget.uid, userEmail: widget.userEmail)),
                (route) => false,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: templateColors['primary']),
            onPressed: _showInvoiceSettings,
          )
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: templateColors['primary']))
          : SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        child: _buildInvoiceByTemplate(_selectedTemplate, templateColors),
      ),
      bottomNavigationBar: _buildBottomActionBar(),
    );
  }

  Map<String, Color> _getTemplateColors(InvoiceTemplate template) {
    switch (template) {
      case InvoiceTemplate.classic:
        return {
          'primary': _bwPrimary,
          'bg': _bwBg,
          'text': _textMain,
          'textSub': _textSub,
          'headerBg': _headerBg,
        };
      case InvoiceTemplate.modern:
        return {
          'primary': _modernPrimary,
          'bg': _modernBg,
          'text': _modernPrimary,
          'textSub': kBlack54,
          'headerBg': _modernHeaderBg,
        };
      case InvoiceTemplate.minimal:
        return {
          'primary': _minimalPrimary,
          'bg': _minimalBg,
          'text': _minimalPrimary,
          'textSub': _minimalAccent,
          'headerBg': _minimalHeaderBg,
        };
      case InvoiceTemplate.colorful:
        return {
          'primary': _colorfulPrimary,
          'bg': _colorfulBg,
          'text': _colorfulPrimary,
          'textSub': _colorfulAccent,
          'headerBg': _colorfulHeaderBg,
        };
    }
  }

  void _showInvoiceSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _getTemplateColors(_selectedTemplate)['primary'],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'INVOICE THEMES',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildSectionLabel("Layout Templates"),
                      ..._buildTemplateOptions(setModalState),
                      const SizedBox(height: 24),
                      _buildSectionLabel("Data Visibility"),
                      _buildSettingTile('Show Business Logo', _showLogo, (v) {
                        setState(() => _showLogo = v);
                        setModalState(() => _showLogo = v);
                      }),
                      _buildSettingTile('Show Email', _showEmail, (v) {
                        setState(() => _showEmail = v);
                        setModalState(() => _showEmail = v);
                      }),
                      _buildSettingTile('Show Phone', _showPhone, (v) {
                        setState(() => _showPhone = v);
                        setModalState(() => _showPhone = v);
                      }),
                      _buildSettingTile('Show Tax Number', _showGST, (v) {
                        setState(() => _showGST = v);
                        setModalState(() => _showGST = v);
                      }),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () async {
                            await _saveInvoiceSettings();
                            if (mounted) Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getTemplateColors(_selectedTemplate)['primary'],
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('SAVE PREFERENCES', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 12, left: 4), child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 1.0)));

  List<Widget> _buildTemplateOptions(StateSetter setModalState) {
    final templates = [
      {'index': 0, 'title': 'Classic Professional', 'icon': Icons.article_rounded, 'color': Colors.black},
      {'index': 1, 'title': 'Modern Business', 'icon': Icons.receipt_long_rounded, 'color': const Color(0xFF2F7CF6)},
      {'index': 2, 'title': 'Compact Receipt', 'icon': Icons.description_rounded, 'color': const Color(0xFF37474F)},
      {'index': 3, 'title': 'Detailed Creative', 'icon': Icons.summarize_rounded, 'color': const Color(0xFF6A1B9A)},
    ];

    return templates.map((template) {
      final isSelected = _selectedTemplate.index == template['index'];
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: () {
            setState(() => _selectedTemplate = InvoiceTemplate.values[template['index'] as int]);
            setModalState(() => _selectedTemplate = InvoiceTemplate.values[template['index'] as int]);
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kWhite,
              border: Border.all(
                color: isSelected ? template['color'] as Color : kGrey200,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(template['icon'] as IconData, color: isSelected ? template['color'] as Color : kBlack54, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    template['title'] as String,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? template['color'] as Color : kBlack87,
                    ),
                  ),
                ),
                if (isSelected) Icon(Icons.check_circle_rounded, color: template['color'] as Color, size: 20),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildSettingTile(String title, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kGreyBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: SwitchListTile.adaptive(
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kBlack87)),
        value: value,
        onChanged: onChanged,
        activeColor: _getTemplateColors(_selectedTemplate)['primary'],
      ),
    );
  }

  Future<void> _saveInvoiceSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('invoice_template', _selectedTemplate.index);
      await prefs.setBool('receipt_show_logo', _showLogo);
      await prefs.setBool('receipt_show_email', _showEmail);
      await prefs.setBool('receipt_show_phone', _showPhone);
      await prefs.setBool('receipt_show_gst', _showGST);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice style updated'), backgroundColor: kGoogleGreen, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  Widget _buildInvoiceByTemplate(InvoiceTemplate template, Map<String, Color> colors) {
    switch (template) {
      case InvoiceTemplate.classic:
        return _buildClassicLayout(colors);
      case InvoiceTemplate.modern:
        return _buildModernLayout(colors);
      case InvoiceTemplate.minimal:
        return _buildCompactLayout(colors);
      case InvoiceTemplate.colorful:
        return _buildDetailedLayout(colors);
    }
  }

  // Template 1: Classic Professional Layout
  Widget _buildClassicLayout(Map<String, Color> colors) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors['primary']!, width: 1.5),
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors['primary']!, width: 1.5)),
            ),
            child: Column(
              children: [
                if (_showLogo && businessLogoUrl != null && businessLogoUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Image.network(
                      businessLogoUrl!,
                      height: 64,
                      width: 64,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 64,
                        width: 64,
                        decoration: BoxDecoration(
                          color: colors['headerBg'],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.store_rounded, size: 32, color: colors['textSub']),
                      ),
                    ),
                  ),
                Text(
                  businessName.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: colors['primary'], letterSpacing: 1.5),
                ),
                const SizedBox(height: 8),
                Text(businessLocation, textAlign: TextAlign.center, style: TextStyle(color: colors['textSub'], fontSize: 11, fontWeight: FontWeight.w500)),
                if (_showPhone) Text("Tel: $businessPhone", textAlign: TextAlign.center, style: TextStyle(color: colors['textSub'], fontSize: 11, fontWeight: FontWeight.w500)),
                if (_showEmail && businessEmail != null) Text("Email: $businessEmail", textAlign: TextAlign.center, style: TextStyle(color: colors['textSub'], fontSize: 11, fontWeight: FontWeight.w500)),
                if (_showGST && businessGSTIN != null) Text("TAX ID: $businessGSTIN", textAlign: TextAlign.center, style: TextStyle(color: colors['primary'], fontSize: 11, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          _buildStandardBody(colors),
        ],
      ),
    );
  }

  Widget _buildStandardBody(Map<String, Color> colors) {
    // Use custom header or default
    final headerText = widget.isQuotation ? 'QUOTATION' : _receiptHeader;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("$headerText #${widget.invoiceNumber}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: colors['text'])),
              Text(DateFormat('dd-MM-yyyy').format(widget.dateTime), style: TextStyle(fontSize: 11, color: colors['textSub'], fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        // Customer Details - controlled by _showCustomerDetails
        if (_showCustomerDetails && widget.customerName != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors['headerBg'],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Bill To: ${widget.customerName}", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: colors['text'])),
                    if (widget.customerPhone != null) Text(widget.customerPhone!, style: TextStyle(color: colors['textSub'], fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
                // Customer GSTIN if available
                if (widget.customerGSTIN != null && widget.customerGSTIN!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text("GSTIN: ${widget.customerGSTIN}", style: TextStyle(color: colors['textSub'], fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                // Customer Credit Details - controlled by _showCustomerCreditDetails
                if (_showCustomerCreditDetails)
                  FutureBuilder<double>(
                    future: _getCustomerCredit(widget.customerPhone),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data! != 0) {
                        final credit = snapshot.data!;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: credit > 0 ? kGoogleGreen.withValues(alpha: 0.1) : kErrorColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              credit > 0 ? "Credit Balance: Rs ${credit.toStringAsFixed(2)}" : "Due: Rs ${(-credit).toStringAsFixed(2)}",
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: credit > 0 ? kGoogleGreen : kErrorColor),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
              ],
            ),
          ),
        // Delivery Address - controlled by _showDeliveryAddress
        if (_showDeliveryAddress && widget.customerName != null)
          Container(
            margin: const EdgeInsets.only(left: 16, right: 16, top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors['headerBg'],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kGrey200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined, size: 16, color: colors['textSub']),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Delivery: ${widget.deliveryAddress ?? businessLocation}",
                    style: TextStyle(fontSize: 10, color: colors['textSub'], fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        _buildTableHeader(colors),
        _buildItemsList(colors),
        _buildSummary(colors),
        // Custom Note section - controlled by _showCustomNote
        if (_showCustomNote && widget.customNote != null && widget.customNote!.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors['headerBg'],
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: colors['primary']!, width: 3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.note_alt_outlined, size: 16, color: colors['primary']),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.customNote!,
                    style: TextStyle(fontSize: 11, color: colors['text'], fontWeight: FontWeight.w500, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
        // Footer with customizable description
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: colors['headerBg'],
            border: Border(top: BorderSide(color: colors['primary']!, width: 1)),
          ),
          child: Column(
            children: [
              Text(
                widget.isQuotation ? _quotationFooterDescription.toUpperCase() : _footerDescription.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(color: colors['text'], fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.0),
              ),
              // Footer Image if available (show for both invoice and quotation)
              if (_footerImageUrl != null && _footerImageUrl!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Image.network(
                    _footerImageUrl!,
                    height: 50,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // Get customer credit balance
  Future<double> _getCustomerCredit(String? phone) async {
    if (phone == null || phone.isEmpty || _storeId == null) return 0.0;
    try {
      final customerDoc = await FirebaseFirestore.instance
          .collection('store')
          .doc(_storeId)
          .collection('customers')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      if (customerDoc.docs.isNotEmpty) {
        return (customerDoc.docs.first.data()['creditBalance'] ?? 0.0).toDouble();
      }
    } catch (e) {
      debugPrint('Error fetching customer credit: $e');
    }
    return 0.0;
  }

  // Template 2: Modern Business Layout
  Widget _buildModernLayout(Map<String, Color> colors) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        border: Border.all(color: kGrey200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors['primary'],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(businessName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text(businessLocation, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          if (_showPhone) Text("Tel: $businessPhone", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          if (_showEmail && businessEmail != null) Text("Email: $businessEmail", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          if (_showGST && businessGSTIN != null) Text("GSTIN: $businessGSTIN", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    if (_showLogo && businessLogoUrl != null && businessLogoUrl!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: Image.network(
                          businessLogoUrl!,
                          height: 48,
                          width: 48,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Icon(Icons.store_rounded, size: 32, color: colors['primary']),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.isQuotation ? "REF QUOTATION" : _receiptHeader.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w900)),
                          Text("#${widget.invoiceNumber}", style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text("DATE", style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w900)),
                          Text(DateFormat('dd-MM-yyyy').format(widget.dateTime), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                if (_showCustomerDetails && widget.customerName != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: colors['headerBg'], borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          Icon(Icons.person_rounded, color: colors['primary'], size: 24),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("BILL TO", style: TextStyle(color: kBlack54, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                Text(widget.customerName!, style: const TextStyle(color: kBlack87, fontSize: 14, fontWeight: FontWeight.w800)),
                                if (widget.customerPhone != null) Text(widget.customerPhone!, style: const TextStyle(color: kBlack54, fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                _buildTableHeader(colors),
                _buildItemsList(colors),
                _buildSummary(colors),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Template 3: Compact Layout
  Widget _buildCompactLayout(Map<String, Color> colors) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: kGrey300), color: Colors.white),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: colors['headerBg'],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(businessName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: colors['text'])),
                    Text(businessLocation, style: TextStyle(fontSize: 9, color: colors['textSub'], fontWeight: FontWeight.w500)),
                    if (_showPhone) Text("T: $businessPhone", style: TextStyle(fontSize: 9, color: colors['textSub'], fontWeight: FontWeight.w500)),
                    if (_showEmail && businessEmail != null) Text("E: $businessEmail", style: TextStyle(fontSize: 9, color: colors['textSub'], fontWeight: FontWeight.w500)),
                    if (_showGST && businessGSTIN != null) Text("TX: $businessGSTIN", style: TextStyle(fontSize: 9, color: colors['text'], fontWeight: FontWeight.w900)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("#${widget.invoiceNumber}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: colors['primary'])),
                    Text(DateFormat('dd-MM-yy').format(widget.dateTime), style: TextStyle(fontSize: 10, color: colors['textSub'], fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                if (_showCustomerDetails && widget.customerName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
                    child: Row(
                      children: [
                        const Text("TO: ", style: TextStyle(color: kBlack54, fontSize: 10, fontWeight: FontWeight.w800)),
                        Text(widget.customerName!, style: TextStyle(color: colors['text'], fontSize: 10, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                _buildTableHeader(colors),
                _buildItemsList(colors),
                _buildSummary(colors),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Template 4: Detailed Statement Layout
  Widget _buildDetailedLayout(Map<String, Color> colors) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: colors['primary']!, width: 2), color: Colors.white),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: colors['primary']),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_showLogo && businessLogoUrl != null && businessLogoUrl!.isNotEmpty)
                      Image.network(
                        businessLogoUrl!,
                        height: 44,
                        width: 44,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.store_rounded, size: 32, color: Colors.white70),
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(widget.isQuotation ? "QUOTATION" : _receiptHeader.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                        Text("#${widget.invoiceNumber}", style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("FROM", style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                          const SizedBox(height: 4),
                          Text(businessName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                          Text(businessLocation, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                          if (_showPhone) Text("Tel: $businessPhone", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                          if (_showEmail && businessEmail != null) Text("Email: $businessEmail", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                          if (_showGST && businessGSTIN != null) Text("GSTIN: $businessGSTIN", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    if (_showCustomerDetails && widget.customerName != null)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("TO", style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                            const SizedBox(height: 4),
                            Text(widget.customerName!, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                            if (widget.customerPhone != null) Text("Ph: ${widget.customerPhone}", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                            if (widget.customerGSTIN != null) Text("GSTIN: ${widget.customerGSTIN}", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          _buildDetailedBody(colors),
        ],
      ),
    );
  }

  Widget _buildDetailedBody(Map<String, Color> colors) {
    return Column(
      children: [
        const SizedBox(height: 12),
        _buildTableHeader(colors),
        _buildItemsList(colors),
        _buildSummary(colors),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: colors['headerBg']),
          child: Row(
            children: [
              Icon(Icons.payment_rounded, color: colors['primary'], size: 18),
              const SizedBox(width: 12),
              Text("Payment: ${widget.paymentMode.toUpperCase()}", style: TextStyle(color: colors['text'], fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // SHARED TABLE COMPONENTS
  // ==========================================

  Widget _buildTableHeader(Map<String, Color> colors) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: colors['headerBg'],
        border: Border.symmetric(horizontal: BorderSide(color: colors['primary']!.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          Expanded(flex: 7, child: Text('PRODUCT', softWrap: false, overflow: TextOverflow.visible, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5))),
          if (_showMeasuringUnit)
            Expanded(flex: 2, child: Text('UNIT', textAlign: TextAlign.center, softWrap: false, overflow: TextOverflow.visible, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5))),
          Expanded(flex: 3, child: Text('QTY', textAlign: TextAlign.center, softWrap: false, overflow: TextOverflow.visible, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5))),
          if (_showMRP)
            Expanded(flex: 3, child: Text('MRP', textAlign: TextAlign.center, softWrap: false, overflow: TextOverflow.visible, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5))),
          Expanded(flex: 4, child: Text('RATE', textAlign: TextAlign.center, softWrap: false, overflow: TextOverflow.visible, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5))),
          Expanded(flex: 3, child: Text('TAX %', textAlign: TextAlign.center, softWrap: false, overflow: TextOverflow.visible, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5))),
          Expanded(flex: 5, child: Text('TAX AMT', textAlign: TextAlign.center, softWrap: false, overflow: TextOverflow.visible, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5))),
          Expanded(flex: 6, child: Text('TOTAL', textAlign: TextAlign.right, softWrap: false, overflow: TextOverflow.visible, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5))),
        ],
      ),
    );
  }

  Widget _buildItemsList(Map<String, Color> colors) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        final bool isLast = index == widget.items.length - 1;
        final double taxVal = (item['taxAmount'] ?? 0.0).toDouble();
        final int taxPerc = (item['taxPercentage'] ?? 0).toInt();
        final String unit = item['unit'] ?? 'pcs';
        final double mrp = (item['mrp'] ?? item['price'] ?? 0.0).toDouble();

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            border: isLast ? null : const Border(bottom: BorderSide(color: kGrey100)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 7, child: Text(item['name'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: kBlack87), maxLines: 2, overflow: TextOverflow.ellipsis)),
              if (_showMeasuringUnit)
                Expanded(flex: 2, child: Text(unit, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, color: kBlack54, fontWeight: FontWeight.w600))),
              Expanded(flex: 3, child: Text('${item['quantity']}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w700))),
              if (_showMRP)
                Expanded(flex: 3, child: Text(mrp.toStringAsFixed(0), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w700, decoration: TextDecoration.lineThrough))),
              Expanded(flex: 4, child: Text('${item['price'].toStringAsFixed(0)}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w700))),
              Expanded(flex: 3, child: Text(taxPerc > 0 ? '$taxPerc%' : '-', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w700))),
              Expanded(flex: 5, child: Text(taxVal > 0 ? taxVal.toStringAsFixed(0) : '-', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w700))),
              Expanded(flex: 6, child: Text('${(item['total'] ?? 0.0).toStringAsFixed(0)}', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: colors['primary']))),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummary(Map<String, Color> colors) {
    // Calculate total qty
    int totalQty = 0;
    double totalMRP = 0;
    for (final item in widget.items) {
      totalQty += (item['quantity'] ?? 1) as int;
      if (_showMRP && item['mrp'] != null) {
        totalMRP += (item['mrp'] as double) * (item['quantity'] as int);
      }
    }

    // Calculate savings (MRP - actual total)
    final savings = _showSaveAmountMessage && totalMRP > widget.total ? totalMRP - widget.total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Total Items
          if (_showTotalItems)
            _summaryRow("Total Items", widget.items.length.toDouble(), colors, isCount: true),

          // Total Qty
          if (_showTotalQty)
            _summaryRow("Total Qty", totalQty.toDouble(), colors, isCount: true),

          _summaryRow("Subtotal Gross", widget.subtotal, colors),
          if (widget.discount > 0) _summaryRow("Applied Discount", widget.discount, colors, isNegative: true),
          if (widget.taxes != null)
            ...widget.taxes!.map((tax) => _summaryRow(
              tax['name'].toString(),
              (tax['amount'] ?? 0.0) as double,
              colors,
            )),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: kGrey100)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("NET PAYABLE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5)),
              Text(
                "Rs ${widget.total.toStringAsFixed(2)}",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: colors['primary']),
              ),
            ],
          ),

          // Payment Mode
          if (_showPaymentMode)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Payment Mode", style: TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w600)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kGoogleGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.paymentMode.toUpperCase(),
                      style: const TextStyle(fontSize: 10, color: kGoogleGreen, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),

          // Customer Save Amount Message
          if (_showSaveAmountMessage && savings > 0)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kGoogleGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kGoogleGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.savings_rounded, color: kGoogleGreen, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "You saved Rs ${savings.toStringAsFixed(0)} on this order!",
                    style: const TextStyle(fontSize: 12, color: kGoogleGreen, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double amount, Map<String, Color> colors, {bool isNegative = false, bool isCount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: kBlack54, fontWeight: FontWeight.w600)),
          Text(
            isCount ? amount.toInt().toString() : "${isNegative ? '-' : ''}${amount.toStringAsFixed(2)}",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isNegative ? kErrorColor : kBlack87,
            ),
          ),
        ],
      ),
    );
  }

  // Bottom Action Bar
  Widget _buildBottomActionBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: _bwBg,
          border: Border(top: BorderSide(color: kGrey200, width: 1.5)),
        ),
        child: Row(
          children: [
            _buildBtn(Icons.print_rounded, "PRINT", () => _handlePrint(context), true),
            const SizedBox(width: 12),
            _buildBtn(Icons.share_rounded, "SHARE", () => _handleShare(context), true),
            const SizedBox(width: 12),
            _buildBtn(Icons.add_rounded, "NEW SALE", () {
              Navigator.pushAndRemoveUntil(
                context,
                CupertinoPageRoute(builder: (context) => NewSalePage(uid: widget.uid, userEmail: widget.userEmail)),
                    (route) => false,
              );
            }, false),
          ],
        ),
      ),
    );
  }

  Widget _buildBtn(IconData icon, String label, VoidCallback onTap, bool isSec) {
    return Expanded(
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isSec ? kWhite : kPrimaryColor,
          foregroundColor: isSec ? kPrimaryColor : kWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSec ? const BorderSide(color: kPrimaryColor, width: 1.5) : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  // Logic Implementations
  Future<void> _handlePrint(BuildContext context) async {
    try {
      // System Bluetooth check & prompt to turn on
      BluetoothAdapterState adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState == BluetoothAdapterState.off) {
        if (Platform.isAndroid) {
          try {
            await FlutterBluePlus.turnOn();
            // Wait a moment for OS to process dialog and update state
            await Future.delayed(const Duration(seconds: 1));
            adapterState = await FlutterBluePlus.adapterState.first;
          } catch (e) {
            debugPrint('Bluetooth turnOn error: $e');
          }
        }
      }

      if (adapterState != BluetoothAdapterState.on) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: kWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('BLUETOOTH REQUIRED', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kBlack87)),
              content: const Text('Bluetooth is currently disabled. Please enable it in settings to connect with your printer.', style: TextStyle(color: kBlack54, fontWeight: FontWeight.w500)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w800, color: kPrimaryColor)),
                ),
              ],
            ),
          );
        }
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            color: _bwBg,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: kPrimaryColor),
                  const SizedBox(height: 16),
                  Text('PRINTING...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: kPrimaryColor)),
                ],
              ),
            ),
          ),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      final selectedPrinterId = prefs.getString('selected_printer_id');

      if (selectedPrinterId == null) {
        Navigator.pop(context);
        CommonWidgets.showSnackBar(context, "No printer configured", bgColor: kOrange);
        return;
      }

      final devices = await FlutterBluePlus.bondedDevices;
      final device = devices.firstWhere(
            (d) => d.remoteId.toString() == selectedPrinterId,
        orElse: () => throw Exception('Printer not found'),
      );

      if (device.isConnected == false) {
        await device.connect(timeout: const Duration(seconds: 10));
        await Future.delayed(const Duration(milliseconds: 500));
      }

      List<int> bytes = [];
      const esc = 0x1B;
      const gs = 0x1D;
      const lf = 0x0A;

      // Init Printer
      bytes.addAll([esc, 0x40]);

      // Template-Aware Header Alignment
      if (_selectedTemplate == InvoiceTemplate.classic) {
        bytes.addAll([esc, 0x61, 0x01, esc, 0x21, 0x30]); // Center Bold
      } else {
        bytes.addAll([esc, 0x61, 0x00, esc, 0x21, 0x30]); // Left Bold
      }

      bytes.addAll(utf8.encode(businessName.toUpperCase()));
      bytes.add(lf);

      bytes.addAll([esc, 0x21, 0x00]); // Reset to normal
      bytes.addAll(utf8.encode(businessLocation));
      bytes.add(lf);

      if (_showPhone) {
        bytes.addAll(utf8.encode('PH: $businessPhone'));
        bytes.add(lf);
      }

      if (_showGST && businessGSTIN != null) {
        bytes.addAll(utf8.encode('GSTIN: $businessGSTIN'));
        bytes.add(lf);
      }

      bytes.addAll(utf8.encode('--------------------------------'));
      bytes.add(lf);

      bytes.addAll([esc, 0x61, 0x00]); // Left align
      bytes.addAll(utf8.encode('${widget.isQuotation ? "QTN" : "INV"}: #${widget.invoiceNumber}'));
      bytes.add(lf);
      bytes.addAll(utf8.encode('DATE: ${DateFormat('dd-MM-yyyy HH:mm').format(widget.dateTime)}'));
      bytes.add(lf);

      if (widget.customerName != null) {
        bytes.addAll(utf8.encode('CUST: ${widget.customerName}'));
        bytes.add(lf);
      }

      bytes.addAll(utf8.encode('--------------------------------'));
      bytes.add(lf);

      // TABLE HEADERS (Structured for paper)
      bytes.addAll(utf8.encode('PRODUCT      QTY RATE TAX TOTAL'));
      bytes.add(lf);
      bytes.addAll(utf8.encode('--------------------------------'));
      bytes.add(lf);

      // ITEMS LOOP (Structured Column Output)
      for (var item in widget.items) {
        final name = item['name'] ?? 'Item';
        final qty = (item['quantity'] ?? 1).toString();
        final rate = (item['price'] ?? 0).toStringAsFixed(0);
        final tax = ((item['taxPercentage'] ?? 0)).toStringAsFixed(0);
        final total = (item['total'] ?? 0).toStringAsFixed(0);

        bytes.addAll(utf8.encode('$name'));
        bytes.add(lf);

        String colQty = qty.padRight(4);
        String colRate = rate.padRight(5);
        String colTax = '${tax}%'.padRight(5);
        String colTotal = total.padLeft(6);

        String dataRow = '            $colQty $colRate $colTax $colTotal';
        bytes.addAll(utf8.encode(dataRow));
        bytes.add(lf);
      }

      bytes.addAll(utf8.encode('--------------------------------'));
      bytes.add(lf);

      // SUMMARY
      bytes.addAll([esc, 0x61, 0x00]);
      bytes.addAll(utf8.encode('SUBTOTAL: Rs ${widget.subtotal.toStringAsFixed(2)}'));
      bytes.add(lf);

      if (widget.discount > 0) {
        bytes.addAll(utf8.encode('DISCOUNT: -Rs ${widget.discount.toStringAsFixed(2)}'));
        bytes.add(lf);
      }

      if (widget.taxes != null) {
        for (var tax in widget.taxes!) {
          bytes.addAll(utf8.encode('${tax['name']}: Rs ${(tax['amount'] ?? 0.0).toStringAsFixed(2)}'));
          bytes.add(lf);
        }
      }

      bytes.addAll(utf8.encode('--------------------------------'));
      bytes.add(lf);

      // TOTAL IN BOLD
      bytes.addAll([esc, 0x61, 0x02, esc, 0x21, 0x30]);
      bytes.addAll(utf8.encode('TOTAL: Rs ${widget.total.toStringAsFixed(2)}'));
      bytes.add(lf);

      bytes.addAll([esc, 0x21, 0x00]); // Normal
      bytes.addAll([esc, 0x61, 0x01]); // Center
      bytes.addAll(utf8.encode('PAID: ${widget.paymentMode.toUpperCase()}'));
      bytes.add(lf);
      bytes.add(lf);
      bytes.addAll(utf8.encode('THANK YOU!'));
      bytes.add(lf);
      bytes.add(lf);
      bytes.addAll([gs, 0x56, 0x00]); // Cut

      final services = await device.discoverServices();
      BluetoothCharacteristic? writeChar;
      for (var s in services) {
        for (var c in s.characteristics) {
          if (c.properties.write) { writeChar = c; break; }
        }
      }
      if (writeChar != null) {
        const chunk = 20;
        for (int i = 0; i < bytes.length; i += chunk) {
          final end = (i + chunk < bytes.length) ? i + chunk : bytes.length;
          await writeChar.write(bytes.sublist(i, end), withoutResponse: true);
          await Future.delayed(const Duration(milliseconds: 20));
        }
      }
      Navigator.pop(context);
      CommonWidgets.showSnackBar(context, 'Receipt printed successfully', bgColor: kGoogleGreen);
    } catch (e) {
      Navigator.pop(context);
      CommonWidgets.showSnackBar(context, 'Printing failed', bgColor: kErrorColor);
    }
  }

  Future<void> _handleShare(BuildContext context) async {
    try {
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: kPrimaryColor)));

      final pdf = pw.Document();

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [_buildPdfByTemplate(_selectedTemplate)];
        },
      ));

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/invoice_${widget.invoiceNumber}.pdf');
      await file.writeAsBytes(await pdf.save());
      Navigator.pop(context);
      await Share.shareXFiles([XFile(file.path)], subject: 'Invoice #${widget.invoiceNumber}');
    } catch (e) {
      Navigator.pop(context);
      debugPrint('Error generating PDF: $e');
    }
  }

  pw.Widget _buildPdfByTemplate(InvoiceTemplate template) {
    switch (template) {
      case InvoiceTemplate.classic: return _buildClassicPdf();
      case InvoiceTemplate.modern: return _buildModernPdf();
      case InvoiceTemplate.minimal: return _buildCompactPdf();
      case InvoiceTemplate.colorful: return _buildDetailedPdf();
    }
  }

  pw.Widget _buildClassicPdf() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(30),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1.5)),
      child: pw.Column(
        children: [
          pw.Center(child: pw.Text(businessName.toUpperCase(), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 8),
          pw.Center(child: pw.Text(businessLocation, style: const pw.TextStyle(fontSize: 10))),
          if (_showPhone) pw.Center(child: pw.Text("Tel: $businessPhone", style: const pw.TextStyle(fontSize: 10))),
          pw.Divider(color: PdfColors.black, height: 30),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text("${widget.isQuotation ? 'QUOTATION' : 'INVOICE'} #${widget.invoiceNumber}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.Text("DATE: ${DateFormat('dd-MM-yyyy').format(widget.dateTime)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          ]),
          pw.SizedBox(height: 16),
          if (widget.customerName != null) ...[
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text("BILL TO: ${widget.customerName!.toUpperCase()}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              if (widget.customerPhone != null) pw.Text(widget.customerPhone!, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            ]),
            pw.SizedBox(height: 16),
          ],
          ..._buildPdfItemsTable(PdfColors.black),
          pw.SizedBox(height: 20),
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text("Subtotal Gross: ${widget.subtotal.toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 10)),
                if (widget.discount > 0) pw.Text("Applied Discount: -${widget.discount.toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 10)),
                if (widget.taxes != null)
                  ...widget.taxes!.map((tax) => pw.Text("${tax['name']}: Rs ${(tax['amount'] ?? 0.0).toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 10))),
                pw.Divider(color: PdfColors.black, thickness: 1),
                pw.Text("NET TOTAL: Rs ${widget.total.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Modern Template PDF
  pw.Widget _buildModernPdf() {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blue, width: 2),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(24),
            decoration: const pw.BoxDecoration(color: PdfColors.blue, borderRadius: pw.BorderRadius.only(topLeft: pw.Radius.circular(10), topRight: pw.Radius.circular(10))),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(businessName, style: pw.TextStyle(color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text(businessLocation, style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
                    if (_showPhone) pw.Text("Tel: $businessPhone", style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(widget.isQuotation ? "QUOTATION" : "TAX INVOICE", style: pw.TextStyle(color: PdfColors.white, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text("#${widget.invoiceNumber}", style: const pw.TextStyle(color: PdfColors.white, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              children: [
                if (widget.customerName != null) ...[
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text("BILL TO", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                      pw.Text(widget.customerName!, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ]),
                    pw.Text(DateFormat('dd-MM-yyyy').format(widget.dateTime), style: const pw.TextStyle(fontSize: 10)),
                  ]),
                  pw.SizedBox(height: 20),
                ],
                ..._buildPdfItemsTable(PdfColors.blue),
                pw.SizedBox(height: 20),
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Gross Subtotal: ${widget.subtotal.toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 10)),
                      if (widget.taxes != null)
                        ...widget.taxes!.map((tax) => pw.Text("${tax['name']}: Rs ${(tax['amount'] ?? 0.0).toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 10))),
                      pw.Divider(color: PdfColors.blue),
                      pw.Text("NET TOTAL: Rs ${widget.total.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Compact Template PDF
  pw.Widget _buildCompactPdf() {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey800)),
      child: pw.Column(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            color: PdfColors.grey200,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(businessName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text(businessLocation, style: const pw.TextStyle(fontSize: 9)),
                    if (_showPhone) pw.Text("Tel: $businessPhone", style: const pw.TextStyle(fontSize: 9)),
                    if (_showGST && businessGSTIN != null) pw.Text("GSTIN: $businessGSTIN", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("INV: #${widget.invoiceNumber}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(DateFormat('dd-MM-yy').format(widget.dateTime), style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(16),
            child: pw.Column(
              children: [
                if (widget.customerName != null) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("CLIENT: ${widget.customerName!.toUpperCase()}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                ],
                ..._buildPdfItemsTable(PdfColors.black),
                pw.SizedBox(height: 16),
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Subtotal: ${widget.subtotal.toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 9)),
                      if (widget.taxes != null)
                        ...widget.taxes!.map((tax) => pw.Text("${tax['name']}: ${(tax['amount'] ?? 0.0).toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 9))),
                      pw.Divider(),
                      pw.Text("TOTAL: Rs ${widget.total.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Detailed Creative Template PDF
  pw.Widget _buildDetailedPdf() {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.purple, width: 2.5)),
      child: pw.Column(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(24),
            decoration: const pw.BoxDecoration(color: PdfColors.purple),
            child: pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(widget.isQuotation ? "QUOTATION" : "TAX INVOICE", style: pw.TextStyle(color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5)),
                    pw.Text("#${widget.invoiceNumber}", style: pw.TextStyle(color: PdfColors.white, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Divider(color: PdfColors.white),
                pw.SizedBox(height: 16),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("FROM", style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 4),
                          pw.Text(businessName, style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                          pw.Text(businessLocation, style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
                          if (_showGST && businessGSTIN != null) pw.Text("GSTIN: $businessGSTIN", style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
                        ],
                      ),
                    ),
                    if (widget.customerName != null)
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text("TO", style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 4),
                            pw.Text(widget.customerName!, style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                            if (widget.customerPhone != null) pw.Text("Ph: ${widget.customerPhone}", style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              children: [
                ..._buildPdfItemsTable(PdfColors.purple),
                pw.SizedBox(height: 20),
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Subtotal: ${widget.subtotal.toStringAsFixed(2)}"),
                      if (widget.discount > 0) pw.Text("Discount: -${widget.discount.toStringAsFixed(2)}"),
                      if (widget.taxes != null)
                        ...widget.taxes!.map((tax) => pw.Text("${tax['name']}: Rs ${(tax['amount'] ?? 0.0).toStringAsFixed(2)}")),
                      pw.Divider(color: PdfColors.purple),
                      pw.Text("TOTAL DUE: Rs ${widget.total.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.purple)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PDF SHARED COMPONENTS (6-COLUMN TABLE)
  // ==========================================

  List<pw.Widget> _buildPdfItemsTable(PdfColor primary) {
    return [
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        columnWidths: {
          0: const pw.FlexColumnWidth(7),
          1: const pw.FlexColumnWidth(3),
          2: const pw.FlexColumnWidth(4),
          3: const pw.FlexColumnWidth(3),
          4: const pw.FlexColumnWidth(5),
          5: const pw.FlexColumnWidth(6),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
            children: [
              _pdfHeaderCell("PRODUCT"),
              _pdfHeaderCell("QTY"),
              _pdfHeaderCell("RATE"),
              _pdfHeaderCell("TAX %"),
              _pdfHeaderCell("TAX AMT"),
              _pdfHeaderCell("TOTAL", align: pw.TextAlign.right),
            ],
          ),
          ...widget.items.map((item) {
            final double taxVal = (item['taxAmount'] ?? 0.0).toDouble();
            final int taxPerc = (item['taxPercentage'] ?? 0).toInt();
            return pw.TableRow(
              children: [
                _pdfDataCell(item['name'] ?? 'Item'),
                _pdfDataCell("${item['quantity']}"),
                _pdfDataCell("${(item['price'] ?? 0).toStringAsFixed(0)}"),
                _pdfDataCell(taxPerc > 0 ? "$taxPerc%" : "-"),
                _pdfDataCell(taxVal > 0 ? taxVal.toStringAsFixed(0) : "-"),
                _pdfDataCell("${(item['total'] ?? 0.0).toStringAsFixed(0)}", align: pw.TextAlign.right, isBold: true, color: primary),
              ],
            );
          }),
        ],
      ),
    ];
  }

  pw.Widget _pdfHeaderCell(String label, {pw.TextAlign align = pw.TextAlign.center}) => pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(label, textAlign: align, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)));
  pw.Widget _pdfDataCell(String label, {pw.TextAlign align = pw.TextAlign.center, bool isBold = false, PdfColor? color}) => pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(label, textAlign: align, style: pw.TextStyle(fontSize: 8, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color ?? PdfColors.black)));
}