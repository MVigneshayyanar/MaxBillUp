import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show Color;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:maxbillup/utils/translation_helper.dart';

// local primary color used in this file
const Color _primaryColor = Color(0xFF2196F3);

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
  final String? quotationDocId; // store doc id of the created quotation

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

  @override
  void initState() {
    super.initState();
    _loadBusinessData();
  }

  Future<void> _loadBusinessData() async {
    final storeDoc = await FirestoreService().getCurrentStoreDoc();
    if (storeDoc != null && storeDoc.exists) {
      final data = storeDoc.data() as Map<String, dynamic>?;
      setState(() {
        businessName = data?['businessName'] ?? 'Business';
        businessLocation = data?['businessAddress'] ?? 'Location';
        businessPhone = data?['businessPhone'] ?? '';
        businessGSTIN = data?['gstin'];
        _isLoading = false;
      });
    } else {
      setState(() {
        businessName = 'Business';
        businessLocation = 'Location';
        businessPhone = '';
        businessGSTIN = null;
        _isLoading = false;
      });
    }
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
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generating PDF...', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
        ),
      );
      final pdf = pw.Document();
      final now = DateTime.now();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(businessName.toUpperCase(), style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                      pw.SizedBox(height: 4),
                      pw.Text(businessLocation, style: const pw.TextStyle(fontSize: 12, color: PdfColors.white)),
                      pw.Text('Phone: $businessPhone', style: const pw.TextStyle(fontSize: 12, color: PdfColors.white)),
                      if (businessGSTIN != null) pw.Text('GSTIN: $businessGSTIN', style: const pw.TextStyle(fontSize: 12, color: PdfColors.white)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('QUOTATION', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
                        pw.SizedBox(height: 4),
                        pw.Text('QTN-${widget.quotationNumber}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Date', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                        pw.Text(DateFormat('dd-MM-yyyy').format(now), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.Text(DateFormat('hh:mm a').format(now), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                if (widget.customerName != null || widget.customerPhone != null) ...[
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BILL TO', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
                        pw.SizedBox(height: 4),
                        if (widget.customerName != null) pw.Text(widget.customerName!, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        if (widget.customerPhone != null) pw.Text('Phone: ${widget.customerPhone}', style: const pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                ],
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Rate', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                      ],
                    ),
                    ...widget.items.map((item) => pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(item.name)),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${item.quantity}', textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(' ${item.price.toStringAsFixed(2)}', textAlign: pw.TextAlign.right)),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(' ${item.total.toStringAsFixed(2)}', textAlign: pw.TextAlign.right)),
                      ],
                    )),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Subtotal'), pw.Text(' ${widget.subtotal.toStringAsFixed(2)}')]),
                      if (widget.discount > 0) ...[
                        pw.SizedBox(height: 4),
                        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Discount'), pw.Text('- ${widget.discount.toStringAsFixed(2)}', style: const pw.TextStyle(color: PdfColors.red))]),
                      ],
                      pw.Divider(thickness: 2),
                      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                        pw.Text('TOTAL', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                        pw.Text(' ${widget.total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      ]),
                    ],
                  ),
                ),
                pw.Spacer(),
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text('Thank You For Your Business!', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
                      pw.SizedBox(height: 4),
                      pw.Text('We appreciate your trust and look forward to serving you again', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
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
            title: const Text('Share Error'),
            content: Text('Failed to share quotation: ${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
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
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Printing...', style: TextStyle(fontSize: 16)),
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
            title: const Text('No Printer Selected'),
            content: const Text('Please select a printer from Settings > Printer Setup before printing.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
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
          throw Exception('Failed to connect to printer. Please make sure:\n1. Printer is turned on\n2. Printer is not connected to another device\n3. Bluetooth is enabled\nError: $e');
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
      bytes.addAll(utf8.encode('Cust: ${widget.customerName ?? "Walk-in"}'));
      bytes.add(lf);
      if (widget.customerPhone != null && widget.customerPhone!.isNotEmpty) {
        bytes.addAll(utf8.encode('Ph: ${widget.customerPhone}'));
        bytes.add(lf);
      }
      bytes.addAll(utf8.encode('--------------------------------'));
      bytes.add(lf);
      bytes.addAll([esc, 0x21, 0x08]);
      bytes.addAll(utf8.encode('Item      Qty  Rate    Amount'));
      bytes.add(lf);
      bytes.addAll(utf8.encode('--------------------------------'));
      bytes.add(lf);
      bytes.addAll([esc, 0x21, 0x00]);
      for (var item in widget.items) {
        final itemName = item.name;
        final quantity = item.quantity;
        final price = item.price;
        final amount = item.total;
        bytes.addAll(utf8.encode(itemName.length > 32 ? itemName.substring(0, 32) : itemName));
        bytes.add(lf);
        final qtyStr = '$quantity'.padLeft(3);
        final priceStr = price.toStringAsFixed(2).padLeft(7);
        final amountStr = amount.toStringAsFixed(2).padLeft(9);
        bytes.addAll(utf8.encode('          $qtyStr  $priceStr $amountStr'));
        bytes.add(lf);
      }
      bytes.addAll(utf8.encode('--------------------------------'));
      bytes.add(lf);
      bytes.addAll(utf8.encode('Subtotal:'.padRight(20) + widget.subtotal.toStringAsFixed(2).padLeft(12)));
      bytes.add(lf);
      if (widget.discount > 0) {
        bytes.addAll(utf8.encode('Discount:'.padRight(20) + ('-' + widget.discount.toStringAsFixed(2)).padLeft(12)));
        bytes.add(lf);
      }
      bytes.addAll(utf8.encode('--------------------------------'));
      bytes.add(lf);
      bytes.addAll([esc, 0x21, 0x30]);
      bytes.addAll(utf8.encode('TOTAL:'.padRight(15) + widget.total.toStringAsFixed(2).padLeft(17)));
      bytes.add(lf);
      bytes.addAll([esc, 0x21, 0x00]);
      bytes.addAll(utf8.encode('--------------------------------'));
      bytes.add(lf);
      bytes.addAll([esc, 0x61, 0x01]);
      bytes.addAll([esc, 0x21, 0x08]);
      bytes.addAll(utf8.encode('Thank You! Visit Again'));
      bytes.add(lf);
      bytes.add(lf);
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
      try {
        if (device.isConnected) {
          await device.disconnect();
        }
      } catch (e) {}
      Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quotation printed successfully!'), backgroundColor: Color(0xFF4CAF50)),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Print Error'),
            content: Text('Failed to print quotation: ${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final now = DateTime.now();
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F5F5),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  margin: EdgeInsets.all(screenWidth * 0.04),
                  padding: EdgeInsets.all(screenWidth * 0.05),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      Container(
                        padding: EdgeInsets.all(screenWidth * 0.04),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              businessName.toUpperCase(),
                              style: TextStyle(
                                fontSize: screenWidth * 0.055,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.01),
                            Row(
                              children: [
                                Icon(Icons.location_on, color: Colors.white70, size: screenWidth * 0.04),
                                SizedBox(width: screenWidth * 0.02),
                                Expanded(
                                  child: Text(
                                    businessLocation,
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.035,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: screenHeight * 0.005),
                            Row(
                              children: [
                                Icon(Icons.phone, color: Colors.white70, size: screenWidth * 0.04),
                                SizedBox(width: screenWidth * 0.02),
                                Text(
                                  businessPhone,
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.035,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                            if (businessGSTIN != null) ...[
                              SizedBox(height: screenHeight * 0.005),
                              Row(
                                children: [
                                  Icon(Icons.account_balance, color: Colors.white70, size: screenWidth * 0.04),
                                  SizedBox(width: screenWidth * 0.02),
                                  Text(
                                    'GSTIN: $businessGSTIN',
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.035,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.025),
                      // Quotation Title and Details
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'QUOTATION',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.055,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF2196F3),
                                  letterSpacing: 1.5,
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.008),
                              Text(
                                'QTN-${widget.quotationNumber}',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.038,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Date',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.032,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.008),
                              Text(
                                DateFormat('dd-MM-yyyy').format(now),
                                style: TextStyle(
                                  fontSize: screenWidth * 0.035,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.006),
                              Text(
                                DateFormat('hh:mm a').format(now),
                                style: TextStyle(
                                  fontSize: screenWidth * 0.035,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      // Customer Details
                      if (widget.customerName != null || widget.customerPhone != null) ...[
                        Container(
                          padding: EdgeInsets.all(screenWidth * 0.04),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BILL TO',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.035,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF2196F3),
                                  letterSpacing: 1,
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.01),
                              if (widget.customerName != null)
                                Text(
                                  widget.customerName!,
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.042,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              if (widget.customerPhone != null)
                                Text(
                                  'Phone: ${widget.customerPhone}',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.035,
                                    color: Colors.grey[700],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.02),
                      ],
                      Divider(thickness: 1.5, color: Colors.grey[300]),
                      SizedBox(height: screenHeight * 0.015),
                      // Table Header
                      Container(
                        padding: EdgeInsets.symmetric(vertical: screenHeight * 0.012, horizontal: screenWidth * 0.02),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                'Item',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.038,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1976D2),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                'Qty',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: screenWidth * 0.038,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1976D2),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Rate',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: screenWidth * 0.038,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1976D2),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Amount',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: screenWidth * 0.038,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1976D2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      // Items List
                      ...widget.items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return Container(
                          padding: EdgeInsets.symmetric(vertical: screenHeight * 0.012, horizontal: screenWidth * 0.02),
                          decoration: BoxDecoration(
                            color: index % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA),
                            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  item.name,
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.038,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  item.quantity.toString(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.038,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  ' ${item.price.toStringAsFixed(2)}',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.038,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  ' ${item.total.toStringAsFixed(2)}',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.038,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      SizedBox(height: screenHeight * 0.02),
                      // Summary Section
                      Container(
                        padding: EdgeInsets.all(screenWidth * 0.04),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          children: [
                            _buildSummaryRow('Subtotal', widget.subtotal, screenWidth, isBold: false),
                            if (widget.discount > 0) ...[
                              SizedBox(height: screenHeight * 0.008),
                              _buildSummaryRow('Discount', -widget.discount, screenWidth, isBold: false, isDiscount: true),
                            ],
                            SizedBox(height: screenHeight * 0.015),
                            Divider(thickness: 1.5, color: Colors.grey[400]),
                            SizedBox(height: screenHeight * 0.01),
                            _buildSummaryRow('Total Amount', widget.total, screenWidth, isBold: true, isTotal: true),
                          ],
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.025),
                      // Footer Message
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'Thank You For Your Business!',
                              style: TextStyle(
                                fontSize: screenWidth * 0.042,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF2196F3),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: screenHeight * 0.008),
                            Text(
                              'We appreciate your trust and look forward to serving you again',
                              style: TextStyle(
                                fontSize: screenWidth * 0.032,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom Action Buttons
            _buildActionBar(context, screenWidth),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, double screenWidth, {bool isBold = false, bool isTotal = false, bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? screenWidth * 0.048 : screenWidth * 0.038,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
            color: isTotal ? const Color(0xFF1976D2) : Colors.black87,
          ),
        ),
        Text(
          ' ${amount.abs().toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isTotal ? screenWidth * 0.048 : screenWidth * 0.038,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
            color: isDiscount
                ? const Color(0xFFFF5252)
                : isTotal
                ? const Color(0xFF1976D2)
                : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar(BuildContext context, double screenWidth) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              context: context,
              icon: Icons.home,
              label: 'New Sale',
              color: const Color(0xFF4CAF50),
              onTap: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
            ),
          ),
          SizedBox(width: screenWidth * 0.02),
          Expanded(
            child: _buildActionButton(
              context: context,
              icon: Icons.share,
              label: 'Share',
              color: const Color(0xFF2196F3),
              onTap: () => _handleShare(context),
            ),
          ),
          SizedBox(width: screenWidth * 0.02),
          Expanded(
            child: _buildActionButton(
              context: context,
              icon: Icons.print,
              label: 'Print',
              color: const Color(0xFFFF9800),
              onTap: () => _handlePrint(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: screenWidth * 0.035),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: screenWidth * 0.07),
            SizedBox(height: screenWidth * 0.01),
            Text(
              label,
              style: TextStyle(
                fontSize: screenWidth * 0.032,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
