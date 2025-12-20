import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

// Project specific imports
import 'package:maxbillup/Sales/NewSale.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';

// Updated UI Color Palette
const Color _primaryColor = Color(0xFF2196F3);     // Professional Blue
const Color _successColor = Color(0xFF4CAF50);     // Emerald Green
const Color _warningColor = Color(0xFFF59E0B);     // Amber Orange
const Color _dangerColor = Color(0xFFEF4444);      // Rose Red
const Color _secondaryColor = Color(0xFF64748B);   // Slate Grey
const Color _backgroundColor = Color(0xFFF8FAFC);
const Color _cardBorder = Color(0xFFE2E8F0);

class QuotationPreviewPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final String quotationNumber;
  final List<CartItem> items;
  final double subtotal;
  final double discount;
  final double total;
  final String? customerName;
  final String? customerPhone;
  final String? staffName;
  final String? quotationDocId;

  const QuotationPreviewPage({
    super.key,
    required this.uid,
    this.userEmail,
    required this.quotationNumber,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.total,
    this.customerName,
    this.customerPhone,
    this.staffName,
    this.quotationDocId,
  });

  @override
  State<QuotationPreviewPage> createState() => _QuotationPreviewPageState();
}

class _QuotationPreviewPageState extends State<QuotationPreviewPage> {
  bool _isLoading = true;
  String businessName = '';
  String businessLocation = '';
  String businessPhone = '';
  String? businessGSTIN;

  // Customer details from backend
  String? customerName;
  String? customerPhone;
  String? customerGSTIN;

  @override
  void initState() {
    super.initState();
    _loadBusinessAndCustomerData();
  }

  Future<void> _loadBusinessAndCustomerData() async {
    // Fetch store details
    final storeDoc = await FirestoreService().getCurrentStoreDoc();
    if (storeDoc != null && storeDoc.exists) {
      final data = storeDoc.data() as Map<String, dynamic>?;
      businessName = data?['businessName'] ?? 'Business';
      businessLocation = data?['businessAddress'] ?? 'Location';
      businessPhone = data?['businessPhone'] ?? '';
      businessGSTIN = data?['gstin'];
    } else {
      businessName = 'Business';
      businessLocation = 'Location';
      businessPhone = '';
      businessGSTIN = null;
    }

    // Fetch customer details from backend if customerId is available
    String? customerId = null;
    // Try to get customerId from widget.items or widget.quotationDocId if possible
    if (widget.quotationDocId != null) {
      // Try to fetch quotation doc and get customerId
      final quotationSnap = await FirebaseFirestore.instance.collection('quotations').doc(widget.quotationDocId).get();
      if (quotationSnap.exists) {
        final qData = quotationSnap.data();
        customerId = qData?['customerId'] ?? qData?['customerID'] ?? qData?['customer_id'];
        if (qData?['customerName'] != null) customerName = qData?['customerName'];
        if (qData?['customerPhone'] != null) customerPhone = qData?['customerPhone'];
        if (qData?['customerGSTIN'] != null) customerGSTIN = qData?['customerGSTIN'];
      }
    }
    if (customerId != null) {
      final customerSnap = await FirebaseFirestore.instance.collection('customers').doc(customerId).get();
      if (customerSnap.exists) {
        final cData = customerSnap.data();
        customerName = cData?['name'] ?? customerName;
        customerPhone = cData?['phone'] ?? customerPhone;
        customerGSTIN = cData?['gstin'] ?? customerGSTIN;
      }
    } else {
      // fallback to widget values
      customerName = widget.customerName;
      customerPhone = widget.customerPhone;
      customerGSTIN = null;
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _handleShare(BuildContext context) async {
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
                  CircularProgressIndicator(color: _primaryColor),
                  SizedBox(height: 16),
                  Text('Generating PDF...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ),
      );
      final pdf = pw.Document();
      final now = DateTime.now();

      // Define PDF Colors to match UI
      const pdfPrimary = PdfColor.fromInt(0xFF2196F3);
      const pdfSuccess = PdfColor.fromInt(0xFF10B981);
      const pdfWarning = PdfColor.fromInt(0xFFF59E0B);
      const pdfDanger = PdfColor.fromInt(0xFFEF4444);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Container
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: pdfPrimary,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(businessName.toUpperCase(), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                          pw.SizedBox(height: 4),
                          pw.Text(businessLocation, style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                          pw.Text('Phone: $businessPhone', style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                          if (businessGSTIN != null) pw.Text('GSTIN: $businessGSTIN', style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text("QUOTATION", style: pw.TextStyle(color: pdfSuccess, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),

                // Quote Info Row
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Quotation Number', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        pw.Text('QTN-${widget.quotationNumber}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: pdfPrimary)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Date & Time', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        pw.Text(DateFormat('dd-MM-yyyy hh:mm a').format(now), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Bill To Container (Amber Accent)
                if (customerName != null || customerPhone != null) ...[
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      // Using hex with alpha channel for transparency (0x33 is ~20%, 0x0D is ~5%)
                      border: pw.Border.all(color: const PdfColor.fromInt(0x33F59E0B)),
                      color: const PdfColor.fromInt(0x0DF59E0B),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BILL TO', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: pdfWarning)),
                        pw.SizedBox(height: 4),
                        if (customerName != null) pw.Text(customerName!, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                        if (customerPhone != null) pw.Text('Phone: ${customerPhone}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                ],

                // Table
                pw.Table(
                  border: pw.TableBorder(
                    horizontalInside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                    bottom: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  ),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Item Description', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: pdfPrimary))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Qty', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: pdfPrimary), textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Rate', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: pdfPrimary), textAlign: pw.TextAlign.right)),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Amount', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: pdfPrimary), textAlign: pw.TextAlign.right)),
                      ],
                    ),
                    ...widget.items.map((item) => pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(item.name, style: const pw.TextStyle(fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${item.quantity}', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(item.price.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(item.total.toStringAsFixed(2), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                      ],
                    )),
                  ],
                ),
                pw.SizedBox(height: 24),

                // Summary Column
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      width: 200,
                      child: pw.Column(
                        children: [
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 10)),
                              pw.Text('Rs ${widget.subtotal.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
                            ],
                          ),
                          if (widget.discount > 0) ...[
                            pw.SizedBox(height: 4),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('Discount:', style: pw.TextStyle(fontSize: 10, color: pdfDanger)),
                                pw.Text('- Rs ${widget.discount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, color: pdfDanger)),
                              ],
                            ),
                          ],
                          pw.SizedBox(height: 8),
                          pw.Divider(color: PdfColors.grey400),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('GRAND TOTAL:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                              pw.Text('Rs ${widget.total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: pdfSuccess)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.Spacer(),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text('THANK YOU FOR YOUR BUSINESS!', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: pdfPrimary)),
                      pw.SizedBox(height: 4),
                      pw.Text('This is a computer-generated quotation.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/quotation_${widget.quotationNumber}.pdf');
      await file.writeAsBytes(await pdf.save());
      Navigator.pop(context);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Quotation ${widget.quotationNumber}',
        text: 'Quotation from $businessName',
      );
    } catch (e) {
      Navigator.pop(context);
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.tr('share_error')),
            content: Text('Failed to share quotation: ${e.toString()}'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('ok'))),
            ],
          ),
        );
      }
    }
  }

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
                  CircularProgressIndicator(color: _warningColor),
                  SizedBox(height: 16),
                  Text('Printing...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
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
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.tr('no_printer_selected')),
            content: const Text('Please select a printer from Settings > Printer Setup before printing.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('ok'))),
            ],
          ),
        );
        return;
      }
      final devices = await FlutterBluePlus.bondedDevices;
      final device = devices.firstWhere(
            (d) => d.remoteId.toString() == selectedPrinterId,
        orElse: () => throw Exception('Printer not found. Please reconnect in Settings.'),
      );
      if (device.isConnected == false) {
        try {
          await device.connect(timeout: const Duration(seconds: 10));
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          throw Exception('Failed to connect to printer.');
        }
      }
      List<int> bytes = [];
      const esc = 0x1B;
      const gs = 0x1D;
      const lf = 0x0A;
      bytes.addAll([esc, 0x40]);
      bytes.addAll([esc, 0x61, 0x01]);
      bytes.addAll([esc, 0x21, 0x30]);
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
      final invoiceLine = 'QTN: ${widget.quotationNumber}';
      final dateLine = DateFormat('dd/MM/yy hh:mm a').format(DateTime.now());
      bytes.addAll(utf8.encode(invoiceLine.padRight(16) + dateLine));
      bytes.add(lf);
      bytes.addAll(utf8.encode('Cust: ${customerName ?? "Walk-in"}'));
      bytes.add(lf);
      bytes.addAll(utf8.encode('--------------------------------'));
      bytes.add(lf);
      for (var item in widget.items) {
        bytes.addAll(utf8.encode(item.name));
        bytes.add(lf);
        bytes.addAll(utf8.encode('         ${item.quantity}  ${item.price.toStringAsFixed(2)}  ${item.total.toStringAsFixed(2)}'));
        bytes.add(lf);
      }
      bytes.addAll(utf8.encode('--------------------------------'));
      bytes.add(lf);
      bytes.addAll([esc, 0x21, 0x30]);
      bytes.addAll(utf8.encode('TOTAL: ${widget.total.toStringAsFixed(2)}'));
      bytes.add(lf);
      bytes.addAll([gs, 0x56, 0x00]);
      final services = await device.discoverServices();
      BluetoothCharacteristic? writeCharacteristic;
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            writeCharacteristic = characteristic;
            break;
          }
        }
        if (writeCharacteristic != null) break;
      }
      if (writeCharacteristic != null) {
        const chunkSize = 20;
        for (int i = 0; i < bytes.length; i += chunkSize) {
          final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
          await writeCharacteristic.write(bytes.sublist(i, end), withoutResponse: true);
          await Future.delayed(const Duration(milliseconds: 20));
        }
      }
      Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quotation printed successfully!'), backgroundColor: _successColor));
      }
    } catch (e) {
      Navigator.pop(context);
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.tr('print_error')),
            content: Text('Failed to print: ${e.toString()}'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('ok'))),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: _backgroundColor, body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Quotation Preview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 1. Quotation Meta (No & Date) with Status Badge
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _cardBorder),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Quotation No", style: TextStyle(color: _secondaryColor, fontSize: 11, fontWeight: FontWeight.w500)),
                                Text("QTN-${widget.quotationNumber}", style: const TextStyle(color: _primaryColor, fontSize: 15, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            // Small Green Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _successColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _successColor.withOpacity(0.2)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, size: 12, color: _successColor),
                                  SizedBox(width: 4),
                                  Text("GENERATED", style: TextStyle(color: _successColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: _cardBorder)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Date", style: TextStyle(color: _secondaryColor, fontSize: 12)),
                            Text(DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()), style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Business & Customer Info with Colored Icons
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Business From (Green Accent)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: _successColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.storefront_rounded, size: 20, color: _successColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("FROM", style: TextStyle(color: _successColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                                  const SizedBox(height: 4),
                                  Text(businessName, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15)),
                                  Text(businessLocation, style: const TextStyle(color: _secondaryColor, fontSize: 12)),
                                  if(businessGSTIN != null) Text("GSTIN: $businessGSTIN", style: const TextStyle(color: _secondaryColor, fontSize: 11, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: _cardBorder, indent: 40)),
                        // Customer To (Orange Accent)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: _warningColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.person_pin_rounded, size: 20, color: _warningColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("BILL TO", style: TextStyle(color: _warningColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                                  const SizedBox(height: 4),
                                  Text(customerName ?? "Walk-in Customer", style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15)),
                                  if(customerPhone != null) Text(customerPhone!, style: const TextStyle(color: _secondaryColor, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Items Table
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _cardBorder),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.04),
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                            border: const Border(bottom: BorderSide(color: _cardBorder)),
                          ),
                          child: const Row(
                            children: [
                              Expanded(flex: 4, child: Text("ITEM", style: TextStyle(color: _primaryColor, fontSize: 10, fontWeight: FontWeight.w900))),
                              Expanded(flex: 1, child: Text("QTY", textAlign: TextAlign.center, style: TextStyle(color: _primaryColor, fontSize: 10, fontWeight: FontWeight.w900))),
                              Expanded(flex: 2, child: Text("AMOUNT", textAlign: TextAlign.right, style: TextStyle(color: _primaryColor, fontSize: 10, fontWeight: FontWeight.w900))),
                            ],
                          ),
                        ),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: widget.items.length,
                          separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final item = widget.items[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              child: Row(
                                children: [
                                  Expanded(
                                      flex: 4,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.name, style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600)),
                                          Text("Rate: ${item.price.toStringAsFixed(2)}", style: const TextStyle(color: _secondaryColor, fontSize: 11)),
                                        ],
                                      )
                                  ),
                                  Expanded(flex: 1, child: Text("${item.quantity}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87, fontSize: 13))),
                                  Expanded(flex: 2, child: Text(item.total.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold))),
                                ],
                              ),
                            );
                          },
                        ),
                        // Totals Section
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFDFDFD),
                            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                            border: Border(top: BorderSide(color: _cardBorder)),
                          ),
                          child: Column(
                            children: [
                              _summaryRow("Subtotal", widget.subtotal),
                              if (widget.discount > 0) ...[
                                const SizedBox(height: 8),
                                _summaryRow("Discount Applied", -widget.discount, color: _dangerColor),
                              ],
                              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: _cardBorder)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Grand Total", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 16)),
                                  // Grand Total in Green to signal revenue/success
                                  Text("Rs ${widget.total.toStringAsFixed(2)}", style: const TextStyle(color: _successColor, fontWeight: FontWeight.w900, fontSize: 22)),
                                ],
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Center(
                    child: Column(
                      children: [
                        Icon(Icons.verified_user_outlined, color: _successColor, size: 24),
                        SizedBox(height: 8),
                        Text(
                          'Thank You For Your Business!',
                          style: TextStyle(fontWeight: FontWeight.bold, color: _primaryColor, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildActionBtn(
                onPressed: () => _handlePrint(context),
                icon: Icons.print_rounded,
                label: "Print",
                accentColor: _warningColor, // Orange for printing
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionBtn(
                onPressed: () => _handleShare(context),
                icon: Icons.ios_share_rounded,
                label: "Share",
                accentColor: _primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    CupertinoPageRoute(builder: (context) => NewSalePage(uid: widget.uid, userEmail: widget.userEmail)),
                        (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: _successColor, // Green for New Sale
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text("New Sale", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn({required VoidCallback onPressed, required IconData icon, required String label, required Color accentColor}) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: accentColor.withOpacity(0.3), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        foregroundColor: accentColor,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double amount, {Color color = Colors.black87}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: _secondaryColor, fontWeight: FontWeight.w500, fontSize: 14)),
        Text(
            '${amount < 0 ? "-" : ""}Rs ${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)
        ),
      ],
    );
  }
}

