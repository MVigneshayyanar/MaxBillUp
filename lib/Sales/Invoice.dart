import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:maxbillup/Sales/components/common_widgets.dart';
import 'package:maxbillup/Sales/NewSale.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/utils/translation_helper.dart';

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

  // Modern Professional UI Constants (Matching Products Page)
  final Color _primaryColor = const Color(0xFF0F172A); // Slate 900 (Navy)
  final Color _accentColor = const Color(0xFF2196F3);  // Professional Blue
  final Color _secondaryColor = const Color(0xFF64748B); // Slate 500 (Grey)
  final Color _cardBorder = const Color(0xFFE2E8F0); // Slate 200
  final Color _scaffoldBg = const Color(0xFFF1F5F9); // Slate 100 (Light Grey)
  final Color _surfaceColor = Colors.white;
  final Color _successColor = const Color(0xFF4CAF50);
  final Color _errorColor = const Color(0xFFFF5252);
  final Color _warningColor = const Color(0xFFFF9800);

  @override
  void initState() {
    super.initState();
    businessName = widget.businessName;
    businessLocation = widget.businessLocation;
    businessPhone = widget.businessPhone;
    businessGSTIN = widget.businessGSTIN;
    _loadStoreData();
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
              .collection('stores')
              .doc(_storeId)
              .get();

          if (storeDoc.exists) {
            final storeData = storeDoc.data()!;
            setState(() {
              businessName = storeData['businessName'] ?? widget.businessName;
              businessPhone = storeData['businessPhone'] ?? widget.businessPhone;
              businessLocation = storeData['businessAddress'] ?? widget.businessLocation;
              businessGSTIN = storeData['gstin'] ?? widget.businessGSTIN;
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
    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: AppBar(
        backgroundColor: _surfaceColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          context.tr('invoice_details'),
          style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: _primaryColor),
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            CupertinoPageRoute(builder: (context) => NewSalePage(uid: widget.uid, userEmail: widget.userEmail)),
                (route) => false,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _accentColor))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. Header Overview Card
            _buildOverviewCard(),

            const SizedBox(height: 12),

            // 2. Contacts (From / To) Card
            _buildContactsCard(),

            const SizedBox(height: 12),

            // 3. Items & Summary Card
            _buildItemsCard(),

            const SizedBox(height: 100), // Space for bottom action bar
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActionBar(),
    );
  }

  Widget _buildOverviewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('invoice_no').toUpperCase(),
                  style: TextStyle(color: _secondaryColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text("#${widget.invoiceNumber}", style: TextStyle(color: _primaryColor, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "PAID • ${widget.paymentMode.toUpperCase()}",
                  style: TextStyle(color: _successColor, fontWeight: FontWeight.w900, fontSize: 10),
                ),
              ),
              const SizedBox(height: 8),
              Text(_formatDateTime(widget.dateTime),
                  style: TextStyle(color: _secondaryColor, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.store_mall_directory_rounded,
            label: context.tr('from'),
            title: businessName,
            sub1: businessLocation,
            sub2: businessGSTIN != null ? "GSTIN: $businessGSTIN" : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: _cardBorder),
          ),
          _buildInfoRow(
            icon: Icons.person_pin_circle_rounded,
            label: context.tr('bill_to'),
            title: widget.customerName ?? "Walk-in Customer",
            sub1: widget.customerPhone,
            sub2: widget.customerGSTIN != null ? "GSTIN: ${widget.customerGSTIN}" : null,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String label, required String title, String? sub1, String? sub2}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: _scaffoldBg, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 20, color: _primaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: TextStyle(color: _secondaryColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
              if (sub1 != null) Text(sub1, style: TextStyle(color: _secondaryColor, fontSize: 12, fontWeight: FontWeight.w500)),
              if (sub2 != null) Text(sub2, style: TextStyle(color: _secondaryColor, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemsCard() {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          // Table Header (Subtle Grey Header like Categories Chips section)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: _scaffoldBg,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(flex: 4, child: Text(context.tr('item').toUpperCase(), style: TextStyle(color: _secondaryColor, fontSize: 10, fontWeight: FontWeight.w900))),
                Expanded(flex: 1, child: Text("QTY", textAlign: TextAlign.center, style: TextStyle(color: _secondaryColor, fontSize: 10, fontWeight: FontWeight.w900))),
                Expanded(flex: 2, child: Text(context.tr('price').toUpperCase(), textAlign: TextAlign.right, style: TextStyle(color: _secondaryColor, fontSize: 10, fontWeight: FontWeight.w900))),
                Expanded(flex: 2, child: Text(context.tr('total').toUpperCase(), textAlign: TextAlign.right, style: TextStyle(color: _secondaryColor, fontSize: 10, fontWeight: FontWeight.w900))),
              ],
            ),
          ),
          // Dynamic Item List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.items.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: _cardBorder),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                child: Row(
                  children: [
                    Expanded(flex: 4, child: Text(item['name'], style: TextStyle(color: _primaryColor, fontSize: 13, fontWeight: FontWeight.w600))),
                    Expanded(flex: 1, child: Text("${item['quantity']}", textAlign: TextAlign.center, style: TextStyle(color: _primaryColor, fontSize: 13, fontWeight: FontWeight.w500))),
                    Expanded(flex: 2, child: Text("${item['price']}", textAlign: TextAlign.right, style: TextStyle(color: _primaryColor, fontSize: 13, fontWeight: FontWeight.w500))),
                    Expanded(flex: 2, child: Text("${item['total'].toStringAsFixed(2)}", textAlign: TextAlign.right, style: TextStyle(color: _primaryColor, fontSize: 13, fontWeight: FontWeight.bold))),
                  ],
                ),
              );
            },
          ),
          // Financial Summary
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _scaffoldBg.withOpacity(0.5),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
            ),
            child: Column(
              children: [
                _buildSummaryRow(context.tr('subtotal'), widget.subtotal),
                if (widget.discount > 0) _buildSummaryRow(context.tr('discount'), -widget.discount, isError: true),
                if (widget.taxes != null)
                  ...widget.taxes!.map((tax) {
                    final taxName = tax['name'] ?? 'Tax';
                    final taxAmount = (tax['amount'] ?? 0.0) as double;
                    return taxAmount > 0 ? _buildSummaryRow(taxName, taxAmount) : const SizedBox.shrink();
                  }),
                const SizedBox(height: 12),
                Divider(height: 1, color: _cardBorder, thickness: 1.5),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(context.tr('total').toUpperCase(), style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
                    Text("Rs ${widget.total.toStringAsFixed(2)}", style: TextStyle(color: _accentColor, fontWeight: FontWeight.w900, fontSize: 20)),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: _secondaryColor, fontWeight: FontWeight.w600)),
          Text(
            value < 0 ? "- ${value.abs().toStringAsFixed(2)}" : value.toStringAsFixed(2),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isError ? _errorColor : _primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      decoration: BoxDecoration(
        color: _surfaceColor,
        border: Border(top: BorderSide(color: _cardBorder)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          _buildActionButton(icon: Icons.print_rounded, label: "Print", onTap: () => _handlePrint(context), isSecondary: true),
          const SizedBox(width: 12),
          _buildActionButton(icon: Icons.share_rounded, label: "Share", onTap: () => _handleShare(context), isSecondary: true),
          const SizedBox(width: 12),
          _buildActionButton(icon: Icons.add_rounded, label: "New Sale", onTap: () {
            Navigator.pushAndRemoveUntil(
              context,
              CupertinoPageRoute(builder: (context) => NewSalePage(uid: widget.uid, userEmail: widget.userEmail)),
                  (route) => false,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap, bool isSecondary = false}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSecondary ? _surfaceColor : _primaryColor,
            borderRadius: BorderRadius.circular(12),
            border: isSecondary ? Border.all(color: _cardBorder) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSecondary ? _primaryColor : Colors.white),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: isSecondary ? _primaryColor : Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  // --- Logic Implementations (Preserved & Fixed) ---

  Future<void> _handlePrint(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Sending to Printer...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
        CommonWidgets.showSnackBar(context, "No printer selected in settings.", bgColor: _errorColor);
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

      bytes.addAll([esc, 0x40]);
      bytes.addAll([esc, 0x61, 0x01, esc, 0x21, 0x30]);
      bytes.addAll(utf8.encode(businessName.toUpperCase()));
      bytes.add(lf);
      bytes.addAll([esc, 0x21, 0x00]);
      bytes.addAll(utf8.encode(businessLocation));
      bytes.add(lf);
      bytes.addAll(utf8.encode('Ph: $businessPhone'));
      bytes.add(lf);
      if (businessGSTIN != null) {
        bytes.addAll(utf8.encode('GSTIN: $businessGSTIN'));
        bytes.add(lf);
      }
      bytes.addAll(utf8.encode('--------------------------------'));
      bytes.add(lf);
      bytes.addAll([esc, 0x61, 0x00]);
      bytes.addAll(utf8.encode('Inv No : ${widget.invoiceNumber}'));
      bytes.add(lf);
      bytes.addAll(utf8.encode('Date   : ${DateFormat('dd-MM-yyyy h:mm a').format(widget.dateTime)}'));
      bytes.add(lf);
      bytes.addAll(utf8.encode('--------------------------------'));
      bytes.add(lf);
      bytes.addAll([esc, 0x21, 0x08]);
      bytes.addAll(utf8.encode('Item       Qty    Price    Total'));
      bytes.add(lf);
      bytes.addAll([esc, 0x21, 0x00]);
      for (var item in widget.items) {
        String name = item['name'] ?? '';
        if (name.length > 32) name = name.substring(0, 32);
        bytes.addAll(utf8.encode(name));
        bytes.add(lf);
        bytes.addAll(utf8.encode('           ${item['quantity']} x ${(item['price'] ?? 0)} = ${(item['total'] ?? 0)}'));
        bytes.add(lf);
      }
      bytes.addAll(utf8.encode('--------------------------------'));
      bytes.add(lf);
      bytes.addAll([esc, 0x61, 0x02]);
      bytes.addAll(utf8.encode('Subtotal: ${widget.subtotal.toStringAsFixed(2)}'));
      bytes.add(lf);
      if (widget.taxes != null) {
        for (var tax in widget.taxes!) {
          bytes.addAll(utf8.encode('${tax['name']}: ${(tax['amount'] as double).toStringAsFixed(2)}'));
          bytes.add(lf);
        }
      }
      if (widget.discount > 0) {
        bytes.addAll(utf8.encode('Discount: -${widget.discount.toStringAsFixed(2)}'));
        bytes.add(lf);
      }
      bytes.addAll([esc, 0x21, 0x30]);
      bytes.addAll(utf8.encode('TOTAL: ${widget.total.toStringAsFixed(2)}'));
      bytes.add(lf);
      bytes.addAll([esc, 0x21, 0x00]);
      bytes.add(lf);
      bytes.addAll([esc, 0x61, 0x01]);
      bytes.addAll(utf8.encode('Thank You!'));
      bytes.add(lf);
      bytes.add(lf);
      bytes.add(lf);
      bytes.addAll([gs, 0x56, 0x00]);

      final services = await device.discoverServices();
      BluetoothCharacteristic? writeCharacteristic;
      for (var s in services) {
        for (var c in s.characteristics) {
          if (c.properties.write) { writeCharacteristic = c; break; }
        }
      }
      if (writeCharacteristic != null) {
        const chunkSize = 20;
        for (int i = 0; i < bytes.length; i += chunkSize) {
          final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
          await writeCharacteristic.write(bytes.sublist(i, end), withoutResponse: true);
          await Future.delayed(const Duration(milliseconds: 20));
        }
      }
      if (device.isConnected) await device.disconnect();
      Navigator.pop(context);
      CommonWidgets.showSnackBar(context, 'Printed successfully!', bgColor: _successColor);
    } catch (e) {
      Navigator.pop(context);
      CommonWidgets.showSnackBar(context, 'Print Error: $e', bgColor: _errorColor);
    }
  }

  Future<void> _handleShare(BuildContext context) async {
    try {
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
      final pdf = pw.Document();
      pdf.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(40), build: (pw.Context context) {
        return [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(businessName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              pw.Text(businessLocation, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              pw.Text(businessPhone, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              if (businessGSTIN != null) pw.Text("GSTIN: $businessGSTIN", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text("INVOICE", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
              pw.SizedBox(height: 5),
              pw.Text("# ${widget.invoiceNumber}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text(DateFormat('MMMM dd, yyyy').format(widget.dateTime), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ]),
          ]),
          pw.SizedBox(height: 40),
          if (widget.customerName != null) pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text("Bill To:", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            pw.Text(widget.customerName!, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            if (widget.customerPhone != null) pw.Text(widget.customerPhone!, style: const pw.TextStyle(fontSize: 10)),
          ]),
          pw.SizedBox(height: 20),
          pw.Table(border: const pw.TableBorder(bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey300)), children: [
            pw.TableRow(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1, color: PdfColors.black))), children: [
              pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text("Item", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
              pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text("Qty", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
              pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text("Price", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
              pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text("Total", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
            ]),
            ...widget.items.map((item) => pw.TableRow(children: [
              pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text(item['name'] ?? '', style: const pw.TextStyle(fontSize: 10))),
              pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text('${item['quantity']}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10))),
              pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text('${(item['price'] ?? 0).toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10))),
              pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text('${(item['total'] ?? 0).toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10))),
            ])),
          ]),
          pw.SizedBox(height: 20),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Container(width: 200, child: pw.Column(children: [
              _buildPdfTotalRow("Subtotal", widget.subtotal),
              if (widget.discount > 0) _buildPdfTotalRow("Discount", -widget.discount),
              if (widget.taxes != null) ...widget.taxes!.map((tax) => _buildPdfTotalRow(tax['name'] ?? 'Tax', (tax['amount'] ?? 0.0).toDouble())),
              pw.Divider(color: PdfColors.grey300),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text("Total", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.Text(widget.total.toStringAsFixed(2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              ])
            ]))
          ]),
          pw.Spacer(),
          pw.Divider(color: PdfColors.grey300),
          pw.Center(child: pw.Text("Thank you for your business!", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))),
        ];
      },
      ));
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/invoice_${widget.invoiceNumber}.pdf');
      await file.writeAsBytes(await pdf.save());
      Navigator.pop(context);
      await Share.shareXFiles([XFile(file.path)], subject: 'Invoice ${widget.invoiceNumber}');
    } catch (e) { Navigator.pop(context); }
  }

  pw.Widget _buildPdfTotalRow(String label, double amount) {
    return pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
      pw.Text(amount.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 10)),
    ]));
  }
}