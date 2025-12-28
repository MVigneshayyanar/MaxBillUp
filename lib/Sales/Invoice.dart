import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:maxbillup/Sales/components/common_widgets.dart';
import 'package:maxbillup/Sales/NewSale.dart';
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
const Color _textSub = Color(0xFF424242); // Grey 800
const Color _dividerColor = Color(0xFFE0E0E0); // Grey 300
const Color _headerBg = Color(0xFFF5F5F5); // Grey 100

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

  // Receipt customization settings
  bool _showLogo = true;
  bool _showEmail = false;
  bool _showPhone = true;
  bool _showGST = true;

  // Template selection
  InvoiceTemplate _selectedTemplate = InvoiceTemplate.classic;
  bool _showTemplateSelector = false;

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

    // Listen for store data changes (e.g., logo updates)
    _storeDataSubscription = FirestoreService().storeDataStream.listen((storeData) {
      debugPrint('Invoice: Received store data update notification');
      if (mounted) {
        setState(() {
          businessLogoUrl = storeData['logoUrl'];
          businessName = storeData['businessName'] ?? businessName;
          businessPhone = storeData['businessPhone'] ?? businessPhone;
          businessLocation = storeData['businessAddress'] ?? businessLocation;
          businessGSTIN = storeData['gstin'];
          businessEmail = storeData['email'];
        });
        debugPrint('Invoice: Logo updated instantly - URL: $businessLogoUrl');
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

  Future<void> _saveTemplatePreference(InvoiceTemplate template) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('invoice_template', template.index);
      setState(() {
        _selectedTemplate = template;
        _showTemplateSelector = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Template saved!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error saving template preference: $e');
    }
  }

  Future<void> _loadReceiptSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _showLogo = prefs.getBool('receipt_show_logo') ?? true;
        _showEmail = prefs.getBool('receipt_show_email') ?? false;
        _showPhone = prefs.getBool('receipt_show_phone') ?? true;
        _showGST = prefs.getBool('receipt_show_gst') ?? true;
      });
    } catch (e) {
      debugPrint('Error loading receipt settings: $e');
    }
  }

  Future<void> _loadStoreData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .get();

      if (userDoc.exists) {
        _storeId = userDoc.data()?['storeId'];
        if (_storeId != null) {
          final storeDoc = await FirebaseFirestore.instance
              .collection('store')  // FIXED: Changed from 'stores' to 'store' to match Profile.dart
              .doc(_storeId)
              .get();

          if (storeDoc.exists) {
            final storeData = storeDoc.data()!;
            debugPrint('Invoice: Loaded store data - logoUrl: ${storeData['logoUrl']}'); // Debug log
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
      debugPrint('Error loading store data: $e');
      setState(() { _isLoading = false; });
    }
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('dd MMM yyyy, h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    // Get template colors
    final templateColors = _getTemplateColors(_selectedTemplate);

    return Scaffold(
      backgroundColor: templateColors['bg'],
      appBar: AppBar(
        backgroundColor: templateColors['bg'],
        elevation: 0,
        centerTitle: true,
        title: Text(
          context.tr('invoice details').toUpperCase(),
          style: TextStyle(
            color: templateColors['primary'],
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 2,
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
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: templateColors['primary']))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildInvoiceByTemplate(_selectedTemplate, templateColors),
            ),
      bottomNavigationBar: _buildBottomActionBar(),
    );
  }

  // Get template-specific colors
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
          'textSub': _modernAccent,
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

  // Show Invoice Settings Bottom Sheet
  void _showInvoiceSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _getTemplateColors(_selectedTemplate)['primary'],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.settings, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Invoice Settings',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Template Selection
                      const Text('Choose Template', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ..._buildTemplateOptions(setModalState),
                      const SizedBox(height: 24),

                      // Header Info
                      const Text('Header Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildSettingTile('Show Logo', _showLogo, (v) {
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
                      _buildSettingTile('Show GSTIN', _showGST, (v) {
                        setState(() => _showGST = v);
                        setModalState(() => _showGST = v);
                      }),

                      const SizedBox(height: 24),
                      // Save Button
                      ElevatedButton(
                        onPressed: () async {
                          await _saveInvoiceSettings();
                          if (mounted) Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getTemplateColors(_selectedTemplate)['primary'],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Save Settings', style: TextStyle(fontSize: 16, color: Colors.white)),
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

  List<Widget> _buildTemplateOptions(StateSetter setModalState) {
    final templates = [
      {'index': 0, 'title': 'Classic Professional', 'icon': Icons.article_outlined, 'color': Colors.black},
      {'index': 1, 'title': 'Modern Business', 'icon': Icons.receipt_long, 'color': const Color(0xFF2F7CF6)},
      {'index': 2, 'title': 'Compact Invoice', 'icon': Icons.description_outlined, 'color': const Color(0xFF37474F)},
      {'index': 3, 'title': 'Detailed Statement', 'icon': Icons.summarize, 'color': const Color(0xFF6A1B9A)},
    ];

    return templates.map((template) {
      final isSelected = _selectedTemplate.index == template['index'];
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () {
            setState(() => _selectedTemplate = InvoiceTemplate.values[template['index'] as int]);
            setModalState(() => _selectedTemplate = InvoiceTemplate.values[template['index'] as int]);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? (template['color'] as Color).withValues(alpha: 0.05) : Colors.grey[100],
              border: Border.all(
                color: isSelected ? template['color'] as Color : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(template['icon'] as IconData, color: template['color'] as Color, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    template['title'] as String,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? template['color'] as Color : Colors.black,
                    ),
                  ),
                ),
                if (isSelected) Icon(Icons.check_circle, color: template['color'] as Color),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildSettingTile(String title, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _getTemplateColors(_selectedTemplate)['primary'],
          ),
        ],
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
          const SnackBar(content: Text('Settings saved!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  // Build different invoice layouts based on template
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
        border: Border.all(color: colors['primary']!, width: 2),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with centered business info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors['primary']!, width: 2)),
            ),
            child: Column(
              children: [
                if (_showLogo && businessLogoUrl != null && businessLogoUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Image.network(businessLogoUrl!, height: 60, width: 60),
                  ),
                Text(
                  businessName.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: colors['primary'], letterSpacing: 2),
                ),
                const SizedBox(height: 8),
                Text(businessLocation, textAlign: TextAlign.center, style: TextStyle(color: colors['textSub'], fontSize: 12)),
                if (_showPhone) Text("Tel: $businessPhone", textAlign: TextAlign.center, style: TextStyle(color: colors['textSub'], fontSize: 12)),
                if (_showEmail && businessEmail != null) Text("Email: $businessEmail", textAlign: TextAlign.center, style: TextStyle(color: colors['textSub'], fontSize: 12)),
                if (_showGST && businessGSTIN != null) Text("GSTIN: $businessGSTIN", textAlign: TextAlign.center, style: TextStyle(color: colors['primary'], fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          // Invoice details and table
          _buildClassicBody(colors),
        ],
      ),
    );
  }

  Widget _buildClassicBody(Map<String, Color> colors) {
    return Column(
      children: [
        // Invoice number and date
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Invoice #${widget.invoiceNumber}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colors['text'])),
              Text(DateFormat('dd MMM yyyy').format(widget.dateTime), style: TextStyle(fontSize: 13, color: colors['textSub'])),
            ],
          ),
        ),
        // Customer
        if (widget.customerName != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors['headerBg'],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Bill To: ${widget.customerName}", style: TextStyle(fontWeight: FontWeight.bold, color: colors['text'])),
                if (widget.customerPhone != null) Text(widget.customerPhone!, style: TextStyle(color: colors['textSub'])),
              ],
            ),
          ),
        const SizedBox(height: 16),
        // Items table
        _buildItemsTable(colors),
        // Summary
        _buildSummary(colors),
        // Footer
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors['headerBg'],
            border: Border(top: BorderSide(color: colors['primary']!, width: 1)),
          ),
          child: Text(
            "Thank you for your business!",
            textAlign: TextAlign.center,
            style: TextStyle(color: colors['text'], fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // Template 2: Modern Business Layout
  Widget _buildModernLayout(Map<String, Color> colors) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [BoxShadow(color: colors['primary']!.withValues(alpha: 0.1), blurRadius: 20, spreadRadius: 5)],
      ),
      child: Column(
        children: [
          // Modern header with gradient
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors['primary']!, colors['primary']!.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(businessName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(businessLocation, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        if (_showPhone) Text("Tel: $businessPhone", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        if (_showEmail && businessEmail != null && businessEmail!.isNotEmpty) Text("Email: $businessEmail", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        if (_showGST && businessGSTIN != null) Text("GSTIN: $businessGSTIN", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    if (_showLogo && businessLogoUrl != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                        child: Image.network(businessLogoUrl!, height: 40, width: 40),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Invoice Number", style: TextStyle(color: Colors.white70, fontSize: 11)),
                          Text("#${widget.invoiceNumber}", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text("Date", style: TextStyle(color: Colors.white70, fontSize: 11)),
                          Text(DateFormat('dd MMM yyyy').format(widget.dateTime), style: const TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Modern body
          _buildModernBody(colors),
        ],
      ),
    );
  }

  Widget _buildModernBody(Map<String, Color> colors) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer card
          if (widget.customerName != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors['headerBg'],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors['primary']!.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, color: colors['primary'], size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Bill To", style: TextStyle(color: colors['textSub'], fontSize: 11)),
                        Text(widget.customerName!, style: TextStyle(color: colors['text'], fontSize: 16, fontWeight: FontWeight.bold)),
                        if (widget.customerPhone != null) Text(widget.customerPhone!, style: TextStyle(color: colors['textSub'], fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          // Items
          _buildItemsTable(colors),
          // Summary
          _buildSummary(colors),
        ],
      ),
    );
  }

  // Template 3: Compact Layout
  Widget _buildCompactLayout(Map<String, Color> colors) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors['primary']!, width: 1),
        color: Colors.white,
      ),
      child: Column(
        children: [
          // Compact header
          Container(
            padding: const EdgeInsets.all(16),
            color: colors['headerBg'],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(businessName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors['text'])),
                    Text(businessLocation, style: TextStyle(fontSize: 10, color: colors['textSub'])),
                    if (_showPhone) Text("Tel: $businessPhone", style: TextStyle(fontSize: 9, color: colors['textSub'])),
                    if (_showEmail && businessEmail != null && businessEmail!.isNotEmpty) Text("$businessEmail", style: TextStyle(fontSize: 9, color: colors['textSub'])),
                    if (_showGST && businessGSTIN != null) Text("GSTIN: $businessGSTIN", style: TextStyle(fontSize: 9, color: colors['text'], fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("#${widget.invoiceNumber}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors['primary'])),
                    Text(DateFormat('dd/MM/yy').format(widget.dateTime), style: TextStyle(fontSize: 11, color: colors['textSub'])),
                  ],
                ),
              ],
            ),
          ),
          // Compact body
          _buildCompactBody(colors),
        ],
      ),
    );
  }

  Widget _buildCompactBody(Map<String, Color> colors) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          if (widget.customerName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text("To: ", style: TextStyle(color: colors['textSub'], fontSize: 12)),
                  Text(widget.customerName!, style: TextStyle(color: colors['text'], fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          _buildCompactItemsList(colors),
          _buildSummary(colors),
        ],
      ),
    );
  }

  Widget _buildCompactItemsList(Map<String, Color> colors) {
    return Column(
      children: widget.items.map((item) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text(item['name'], style: TextStyle(fontSize: 11, color: colors['text']))),
              Expanded(child: Text("${item['quantity']} x ${item['price']}", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: colors['textSub']))),
              Expanded(child: Text("${item['total']}", textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors['primary']))),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Template 4: Detailed Statement Layout
  Widget _buildDetailedLayout(Map<String, Color> colors) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors['primary']!, width: 3),
        color: Colors.white,
      ),
      child: Column(
        children: [
          // Detailed header with all info
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors['primary'],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_showLogo && businessLogoUrl != null)
                      Image.network(businessLogoUrl!, height: 50, width: 50, color: Colors.white),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text("TAX INVOICE", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
                        Text("#${widget.invoiceNumber}", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.white.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("FROM", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(businessName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          Text(businessLocation, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          if (_showPhone) Text("Ph: $businessPhone", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          if (_showEmail && businessEmail != null && businessEmail!.isNotEmpty) Text("Email: $businessEmail", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          if (_showGST && businessGSTIN != null) Text("GSTIN: $businessGSTIN", style: const TextStyle(color: Colors.white, fontSize: 11)),
                        ],
                      ),
                    ),
                    if (widget.customerName != null)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("TO", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(widget.customerName!, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                            if (widget.customerPhone != null) Text("Ph: ${widget.customerPhone}", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            if (widget.customerGSTIN != null) Text("GSTIN: ${widget.customerGSTIN}", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Detailed body
          _buildDetailedBody(colors),
        ],
      ),
    );
  }

  Widget _buildDetailedBody(Map<String, Color> colors) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Detailed items table
          _buildDetailedItemsTable(colors),
          const SizedBox(height: 20),
          // Summary
          _buildSummary(colors),
          const SizedBox(height: 20),
          // Footer with payment info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors['headerBg'],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.payment, color: colors['primary']),
                const SizedBox(width: 12),
                Text("Payment Mode: ${widget.paymentMode.toUpperCase()}", style: TextStyle(color: colors['text'], fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedItemsTable(Map<String, Color> colors) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors['primary']!),
      ),
      child: Column(
        children: [
          // Table header
          Container(
            color: colors['headerBg'],
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text("DESCRIPTION", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: colors['text']))),
                SizedBox(width: 50, child: Text("QTY", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: colors['text']))),
                SizedBox(width: 65, child: Text("RATE", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: colors['text']))),
                SizedBox(width: 55, child: Text("TAX", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: colors['text']))),
                SizedBox(width: 75, child: Text("AMOUNT", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: colors['text']))),
              ],
            ),
          ),
          // Items
          ...widget.items.map((item) {
            final taxAmount = (item['taxAmount'] ?? 0.0) as double;
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors['primary']!.withValues(alpha: 0.2))),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      item['name'],
                      style: TextStyle(fontSize: 11, color: colors['text']),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text(
                      "${item['quantity']}",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: colors['text']),
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                  SizedBox(
                    width: 65,
                    child: Text(
                      "${item['price']}",
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 11, color: colors['text']),
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                  SizedBox(
                    width: 55,
                    child: Text(
                      taxAmount.toStringAsFixed(2),
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 11, color: colors['text']),
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                  SizedBox(
                    width: 75,
                    child: Text(
                      "${item['total']}",
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors['primary']),
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildItemsTable(Map<String, Color> colors) {
    return Column(
      children: [
        // Table header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: colors['headerBg'],
            border: Border(bottom: BorderSide(color: colors['primary']!, width: 1)),
          ),
          child: Row(
            children: [
              Expanded(flex: 2, child: Text("ITEM", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: colors['text']))),
              SizedBox(width: 50, child: Text("QTY", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: colors['text']))),
              SizedBox(width: 70, child: Text("PRICE", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: colors['text']))),
              SizedBox(width: 80, child: Text("TOTAL", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: colors['text']))),
            ],
          ),
        ),
        // Items
        ...widget.items.map((item) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    item['name'],
                    style: TextStyle(fontSize: 11, color: colors['text']),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    "${item['quantity']}",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: colors['text']),
                    maxLines: 1,
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    "${item['price']}",
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 11, color: colors['text']),
                    maxLines: 1,
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    "${item['total']}",
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors['primary']),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildSummary(Map<String, Color> colors) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors['primary']!, width: 1)),
      ),
      child: Column(
        children: [
          _summaryRow("Subtotal", widget.subtotal, colors),
          if (widget.discount > 0) _summaryRow("Discount", widget.discount, colors, isNegative: true),
          if (widget.taxes != null)
            ...widget.taxes!.map((tax) => _summaryRow(
              tax['name'].toString(),
              (tax['amount'] ?? 0.0) as double,
              colors,
            )),
          Divider(color: colors['primary'], thickness: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "TOTAL",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors['primary'],
                ),
              ),
              Text(
                "Rs ${widget.total.toStringAsFixed(2)}",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colors['primary'],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double amount, Map<String, Color> colors, {bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: colors['textSub'])),
          Text(
            "${isNegative ? '-' : ''}Rs ${amount.toStringAsFixed(2)}",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isNegative ? Colors.red : colors['text'],
            ),
          ),
        ],
      ),
    );
  }

  // Old methods that were used before - keeping for backward compatibility if needed
  Widget _buildMeta(Map<String, Color> colors) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors['primary']!, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("INVOICE NO: #${widget.invoiceNumber}",
              style: TextStyle(color: colors['text'], fontWeight: FontWeight.bold, fontSize: 13)),
          Text("DATE: ${DateFormat('dd-MM-yyyy').format(widget.dateTime)}",
              style: TextStyle(color: colors['text'], fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo(Map<String, Color> colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors['primary']!, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.customerName != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.customerName!.toUpperCase(),
                    style: TextStyle(color: colors['text'], fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 10),
                if (widget.customerPhone != null)
                  Text(
                    widget.customerPhone!,
                    style: TextStyle(color: colors['text'], fontWeight: FontWeight.w900, fontSize: 14),
                  ),
              ],
            ),
          if (widget.customerGSTIN != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text("GSTIN: ${widget.customerGSTIN}", style: TextStyle(color: colors['textSub'], fontSize: 11, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildTable(Map<String, Color> colors) {
    final TextStyle headerStyle = TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: 12,
      color: colors['text'],
    );

    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: colors['headerBg'],
            border: Border(bottom: BorderSide(color: colors['primary']!, width: 1)),
          ),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text("DESCRIPTION", style: headerStyle)),
              SizedBox(width: 60, child: Text("RATE", textAlign: TextAlign.right, style: headerStyle)),
              SizedBox(width: 35, child: Text("QTY", textAlign: TextAlign.center, style: headerStyle)),
              SizedBox(width: 55, child: Text("TAX", textAlign: TextAlign.center, style: headerStyle)),
              SizedBox(width: 70, child: Text("TOTAL", textAlign: TextAlign.right, style: headerStyle)),
            ],
          ),
        ),
        // Item List
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.items.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: colors['primary']!.withValues(alpha: 0.1),
            indent: 16,
            endIndent: 16,
          ),
          itemBuilder: (context, index) {
            final item = widget.items[index];
            final taxAmount = (item['taxAmount'] ?? 0.0) as double;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      item['name'].toString().toUpperCase(),
                      style: TextStyle(color: colors['text'], fontSize: 11, fontWeight: FontWeight.bold),
                      softWrap: true,
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      "${item['price']}",
                      textAlign: TextAlign.right,
                      style: TextStyle(color: colors['text'], fontSize: 11),
                      softWrap: false,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                  SizedBox(
                    width: 35,
                    child: Text(
                      "${item['quantity']}",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors['text'], fontSize: 11),
                      softWrap: false,
                    ),
                  ),
                  SizedBox(
                    width: 55,
                    child: Text(
                      taxAmount.toStringAsFixed(2),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors['text'], fontSize: 11),
                      softWrap: false,
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text(
                      "${item['total'].toStringAsFixed(2)}",
                      textAlign: TextAlign.right,
                      style: TextStyle(color: colors['primary'], fontWeight: FontWeight.w900, fontSize: 11),
                      softWrap: false,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // Bottom Action Bar
  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      decoration: const BoxDecoration(
        color: _bwBg,
        border: Border(top: BorderSide(color: _bwPrimary, width: 1)),
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
    );
  }

  Widget _buildBtn(IconData icon, String label, VoidCallback onTap, bool isSec) {
    return Expanded(
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isSec ? _bwBg : _bwPrimary,
          foregroundColor: isSec ? _bwPrimary : _bwBg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: _bwPrimary, width: 1.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  // Logic Implementations
  Future<void> _handlePrint(BuildContext context) async {
    try {
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
                  CircularProgressIndicator(color: _bwPrimary),
                  const SizedBox(height: 16),
                  Text('COMMUNICATING WITH PRINTER...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _bwPrimary)),
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
        CommonWidgets.showSnackBar(context, "NO PRINTER SELECTED.", bgColor: _bwPrimary);
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

      // Initialize printer
      bytes.addAll([esc, 0x40]);

      // Center align and bold for business name
      bytes.addAll([esc, 0x61, 0x01, esc, 0x21, 0x30]);
      bytes.addAll(utf8.encode(businessName.toUpperCase()));
      bytes.add(lf);

      // Reset to normal text
      bytes.addAll([esc, 0x21, 0x00]);

      // Business location
      bytes.addAll(utf8.encode(businessLocation));
      bytes.add(lf);

      // Conditional phone (based on settings)
      if (_showPhone) {
        bytes.addAll(utf8.encode('PH: $businessPhone'));
        bytes.add(lf);
      }

      // Conditional email (based on settings)
      if (_showEmail && businessEmail != null && businessEmail!.isNotEmpty) {
        bytes.addAll(utf8.encode('EMAIL: $businessEmail'));
        bytes.add(lf);
      }

      // Conditional GSTIN (based on settings)
      if (_showGST && businessGSTIN != null) {
        bytes.addAll(utf8.encode('GSTIN: $businessGSTIN'));
        bytes.add(lf);
      }

      // Separator line (flexible width)
      bytes.addAll(utf8.encode('--------------------------------'));
      bytes.add(lf);

      // Left align for invoice details
      bytes.addAll([esc, 0x61, 0x00]);
      bytes.addAll(utf8.encode('INV: #${widget.invoiceNumber}'));
      bytes.add(lf);
      bytes.addAll(utf8.encode('DATE: ${DateFormat('dd-MM-yyyy HH:mm').format(widget.dateTime)}'));
      bytes.add(lf);

      // Customer info
      if (widget.customerName != null) {
        bytes.addAll(utf8.encode('CUST: ${widget.customerName}'));
        bytes.add(lf);
      }
      if (widget.customerPhone != null) {
        bytes.addAll(utf8.encode('PH: ${widget.customerPhone}'));
        bytes.add(lf);
      }

      bytes.addAll(utf8.encode('--------------------------------'));
      bytes.add(lf);

      // Items with flexible formatting
      for (var item in widget.items) {
        final taxAmount = (item['taxAmount'] ?? 0.0) as double;
        // Item name (can wrap if needed)
        bytes.addAll(utf8.encode('${item['name']}'));
        bytes.add(lf);
        // Item details on next line
        bytes.addAll(utf8.encode('  ${item['quantity']} x ${item['price']} | Tax: ${taxAmount.toStringAsFixed(2)} = ${item['total']}'));
        bytes.add(lf);
      }

      bytes.addAll(utf8.encode('--------------------------------'));
      bytes.add(lf);

      // Summary section
      bytes.addAll([esc, 0x61, 0x00]); // Left align
      bytes.addAll(utf8.encode('SUBTOTAL: ${widget.subtotal.toStringAsFixed(2)}'));
      bytes.add(lf);

      if (widget.discount > 0) {
        bytes.addAll(utf8.encode('DISCOUNT: ${widget.discount.toStringAsFixed(2)}'));
        bytes.add(lf);
      }

      if (widget.taxes != null) {
        for (var tax in widget.taxes!) {
          bytes.addAll(utf8.encode('${tax['name']}: ${(tax['amount'] ?? 0.0).toStringAsFixed(2)}'));
          bytes.add(lf);
        }
      }

      bytes.addAll(utf8.encode('--------------------------------'));
      bytes.add(lf);

      // Right align and bold for total
      bytes.addAll([esc, 0x61, 0x02, esc, 0x21, 0x20]);
      bytes.addAll(utf8.encode('TOTAL: ${widget.total.toStringAsFixed(2)}'));
      bytes.add(lf);

      // Reset formatting
      bytes.addAll([esc, 0x21, 0x00]);

      // Payment mode
      bytes.addAll([esc, 0x61, 0x01]); // Center
      bytes.addAll(utf8.encode('PAID: ${widget.paymentMode.toUpperCase()}'));
      bytes.add(lf);
      bytes.add(lf);

      // Thank you message
      bytes.addAll(utf8.encode('THANK YOU!'));
      bytes.add(lf);
      bytes.add(lf);
      bytes.add(lf);

      // Cut paper
      bytes.addAll([gs, 0x56, 0x00]);

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
      CommonWidgets.showSnackBar(context, 'RECEIPT PRINTED.', bgColor: _bwPrimary);
    } catch (e) {
      Navigator.pop(context);
      CommonWidgets.showSnackBar(context, 'PRINTING FAILED.', bgColor: _bwPrimary);
    }
  }

  Future<void> _handleShare(BuildContext context) async {
    try {
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: _bwPrimary)));

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

  // Build PDF content based on selected template
  pw.Widget _buildPdfByTemplate(InvoiceTemplate template) {
    switch (template) {
      case InvoiceTemplate.classic:
        return _buildClassicPdf();
      case InvoiceTemplate.modern:
        return _buildModernPdf();
      case InvoiceTemplate.minimal:
        return _buildCompactPdf();
      case InvoiceTemplate.colorful:
        return _buildDetailedPdf();
    }
  }

  // Classic Template PDF
  pw.Widget _buildClassicPdf() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(30),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 2),
      ),
      child: pw.Column(
        children: [
          // Header
          pw.Center(child: pw.Text(businessName.toUpperCase(), style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 8),
          pw.Center(child: pw.Text(businessLocation, style: const pw.TextStyle(fontSize: 12))),
          if (_showPhone) pw.Center(child: pw.Text("Tel: $businessPhone", style: const pw.TextStyle(fontSize: 12))),
          if (_showEmail && businessEmail != null) pw.Center(child: pw.Text("Email: $businessEmail", style: const pw.TextStyle(fontSize: 12))),
          if (_showGST && businessGSTIN != null) pw.Center(child: pw.Text("GSTIN: $businessGSTIN", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),

          pw.Divider(color: PdfColors.black, height: 30),

          // Invoice details
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text("INVOICE #${widget.invoiceNumber}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text("DATE: ${DateFormat('dd-MM-yyyy').format(widget.dateTime)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ]),

          pw.SizedBox(height: 16),

          // Customer info
          if (widget.customerName != null) ...[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(widget.customerName!.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                if (widget.customerPhone != null) pw.Text(widget.customerPhone!, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
            if (widget.customerGSTIN != null) pw.Text("GSTIN: ${widget.customerGSTIN}", style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 16),
          ],

          // Items table
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.black),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FixedColumnWidth(50),
              2: const pw.FixedColumnWidth(70),
              3: const pw.FixedColumnWidth(80),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("ITEM", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("QTY", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("PRICE", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("TOTAL", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ],
              ),
              ...widget.items.map((item) => pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(item['name'])),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("${item['quantity']}", textAlign: pw.TextAlign.center)),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("${item['price']}", textAlign: pw.TextAlign.right)),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("${item['total']}", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ],
              )),
            ],
          ),

          pw.SizedBox(height: 20),

          // Summary
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text("Subtotal: Rs ${widget.subtotal.toStringAsFixed(2)}"),
                if (widget.discount > 0) pw.Text("Discount: Rs ${widget.discount.toStringAsFixed(2)}"),
                if (widget.taxes != null)
                  ...widget.taxes!.map((tax) => pw.Text("${tax['name']}: Rs ${(tax['amount'] ?? 0.0).toStringAsFixed(2)}")),
                pw.Divider(),
                pw.Text("TOTAL: Rs ${widget.total.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),

          pw.SizedBox(height: 20),
          pw.Center(child: pw.Text("Thank you for your business!", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        ],
      ),
    );
  }

  // Modern Template PDF
  pw.Widget _buildModernPdf() {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blue, width: 3),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        children: [
          // Modern header with blue background
          pw.Container(
            padding: const pw.EdgeInsets.all(24),
            decoration: const pw.BoxDecoration(
              color: PdfColors.blue,
              borderRadius: pw.BorderRadius.only(topLeft: pw.Radius.circular(10), topRight: pw.Radius.circular(10)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(businessName, style: pw.TextStyle(color: PdfColors.white, fontSize: 22, fontWeight: pw.FontWeight.bold)),
                        pw.Text(businessLocation, style: const pw.TextStyle(color: PdfColors.white, fontSize: 12)),
                        if (_showPhone) pw.Text("Tel: $businessPhone", style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
                        if (_showEmail && businessEmail != null) pw.Text("Email: $businessEmail", style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
                        if (_showGST && businessGSTIN != null) pw.Text("GSTIN: $businessGSTIN", style: pw.TextStyle(color: PdfColors.white, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white.shade(0.2),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("Invoice Number", style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
                          pw.Text("#${widget.invoiceNumber}", style: pw.TextStyle(color: PdfColors.white, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text("Date", style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
                          pw.Text(DateFormat('dd MMM yyyy').format(widget.dateTime), style: const pw.TextStyle(color: PdfColors.white, fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body
          pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              children: [
                // Customer card
                if (widget.customerName != null) ...[
                  pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text("CUSTOMER", style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10)),
                            pw.Text(widget.customerName!, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                            if (widget.customerGSTIN != null) pw.Text("GSTIN: ${widget.customerGSTIN}", style: const pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                        if (widget.customerPhone != null) pw.Text(widget.customerPhone!, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                ],

                // Items table (same as classic)
                ..._buildPdfItemsTable(),

                pw.SizedBox(height: 20),

                // Summary
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Subtotal: Rs ${widget.subtotal.toStringAsFixed(2)}"),
                      if (widget.discount > 0) pw.Text("Discount: Rs ${widget.discount.toStringAsFixed(2)}"),
                      if (widget.taxes != null)
                        ...widget.taxes!.map((tax) => pw.Text("${tax['name']}: Rs ${(tax['amount'] ?? 0.0).toStringAsFixed(2)}")),
                      pw.Container(
                        margin: const pw.EdgeInsets.only(top: 10),
                        padding: const pw.EdgeInsets.all(16),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue,
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Text("TOTAL: Rs ${widget.total.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                      ),
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
          // Compact header
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            color: PdfColors.grey300,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(businessName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.Text(businessLocation, style: const pw.TextStyle(fontSize: 10)),
                    if (_showPhone) pw.Text("Tel: $businessPhone", style: const pw.TextStyle(fontSize: 9)),
                    if (_showEmail && businessEmail != null) pw.Text("$businessEmail", style: const pw.TextStyle(fontSize: 9)),
                    if (_showGST && businessGSTIN != null) pw.Text("GSTIN: $businessGSTIN", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("INV: #${widget.invoiceNumber}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(DateFormat('dd/MM/yyyy').format(widget.dateTime), style: const pw.TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),

          pw.Padding(
            padding: const pw.EdgeInsets.all(16),
            child: pw.Column(
              children: [
                // Customer (if exists)
                if (widget.customerName != null) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(widget.customerName!, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      if (widget.customerPhone != null) pw.Text(widget.customerPhone!),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                ],

                // Items
                ..._buildPdfItemsTable(),

                pw.SizedBox(height: 16),

                // Summary
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Subtotal: Rs ${widget.subtotal.toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 11)),
                      if (widget.discount > 0) pw.Text("Discount: Rs ${widget.discount.toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 11)),
                      if (widget.taxes != null)
                        ...widget.taxes!.map((tax) => pw.Text("${tax['name']}: Rs ${(tax['amount'] ?? 0.0).toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 11))),
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

  // Detailed Template PDF
  pw.Widget _buildDetailedPdf() {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.purple, width: 3)),
      child: pw.Column(
        children: [
          // Purple header with FROM/TO
          pw.Container(
            padding: const pw.EdgeInsets.all(24),
            color: PdfColors.purple,
            child: pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("TAX INVOICE", style: pw.TextStyle(color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold, letterSpacing: 2)),
                    pw.Text("#${widget.invoiceNumber}", style: const pw.TextStyle(color: PdfColors.white, fontSize: 14)),
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
                          pw.Text("FROM", style: pw.TextStyle(color: PdfColors.white, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 4),
                          pw.Text(businessName, style: pw.TextStyle(color: PdfColors.white, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                          pw.Text(businessLocation, style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
                          if (_showPhone) pw.Text("Ph: $businessPhone", style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
                          if (_showEmail && businessEmail != null) pw.Text("Email: $businessEmail", style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
                          if (_showGST && businessGSTIN != null) pw.Text("GSTIN: $businessGSTIN", style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
                        ],
                      ),
                    ),
                    if (widget.customerName != null)
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text("TO", style: pw.TextStyle(color: PdfColors.white, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 4),
                            pw.Text(widget.customerName!, style: pw.TextStyle(color: PdfColors.white, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                            if (widget.customerPhone != null) pw.Text("Ph: ${widget.customerPhone}", style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
                            if (widget.customerGSTIN != null) pw.Text("GSTIN: ${widget.customerGSTIN}", style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
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
                // 5-column table with tax
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.purple),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FixedColumnWidth(50),
                    2: const pw.FixedColumnWidth(65),
                    3: const pw.FixedColumnWidth(55),
                    4: const pw.FixedColumnWidth(75),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.purple50),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("DESCRIPTION", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("QTY", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("RATE", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("TAX", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("AMOUNT", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      ],
                    ),
                    ...widget.items.map((item) {
                      final taxAmount = (item['taxAmount'] ?? 0.0) as double;
                      return pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(item['name'])),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("${item['quantity']}", textAlign: pw.TextAlign.center)),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("${item['price']}", textAlign: pw.TextAlign.right)),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(taxAmount.toStringAsFixed(2), textAlign: pw.TextAlign.right)),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("${item['total']}", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        ],
                      );
                    }),
                  ],
                ),

                pw.SizedBox(height: 20),

                // Summary with purple accent
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Subtotal: Rs ${widget.subtotal.toStringAsFixed(2)}"),
                      if (widget.discount > 0) pw.Text("Discount: Rs ${widget.discount.toStringAsFixed(2)}"),
                      if (widget.taxes != null)
                        ...widget.taxes!.map((tax) => pw.Text("${tax['name']}: Rs ${(tax['amount'] ?? 0.0).toStringAsFixed(2)}")),
                      pw.Container(
                        margin: const pw.EdgeInsets.only(top: 10),
                        padding: const pw.EdgeInsets.all(16),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.purple,
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Text("TOTAL: Rs ${widget.total.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                      ),
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

  // Helper method to build items table for PDF
  List<pw.Widget> _buildPdfItemsTable() {
    return [
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.black),
        columnWidths: {
          0: const pw.FlexColumnWidth(2),
          1: const pw.FixedColumnWidth(50),
          2: const pw.FixedColumnWidth(70),
          3: const pw.FixedColumnWidth(80),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey300),
            children: [
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("ITEM", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("QTY", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("PRICE", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("TOTAL", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            ],
          ),
          ...widget.items.map((item) => pw.TableRow(
            children: [
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(item['name'])),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("${item['quantity']}", textAlign: pw.TextAlign.center)),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("${item['price']}", textAlign: pw.TextAlign.right)),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("${item['total']}", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            ],
          )),
        ],
      ),
    ];
  }
}