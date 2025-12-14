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
import 'package:firebase_auth/firebase_auth.dart';

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
  final double cgst; // Central GST
  final double sgst; // State GST
  final double igst; // Integrated GST
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
    this.cgst = 0.0,
    this.sgst = 0.0,
    this.igst = 0.0,
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

  // Business data from Firebase
  late String businessName;
  late String businessLocation;
  late String businessPhone;
  String? businessGSTIN;

  // Professional Corporate Palette
  final Color _primaryColor = const Color(0xFF0F172A); // Slate 900
  final Color _secondaryColor = const Color(0xFF64748B); // Slate 500
  final Color _backgroundColor = const Color(0xFFF1F5F9); // Slate 100
  final Color _surfaceColor = Colors.white;

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
      print('Error loading store data: $e');
      setState(() { _isLoading = false; });
    }
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('dd MMM yyyy').format(dt);
  }

  // --- Printing Logic (Standard ESC/POS) ---
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
                  Text('Sending to Printer...', style: TextStyle(fontSize: 14)),
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
        CommonWidgets.showSnackBar(context, "No printer selected in settings.", bgColor: Colors.red);
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

      // Init
      bytes.addAll([esc, 0x40]);

      // Header
      bytes.addAll([esc, 0x61, 0x01, esc, 0x21, 0x30]); // Center, Big
      bytes.addAll(utf8.encode(businessName.toUpperCase()));
      bytes.add(lf);
      bytes.addAll([esc, 0x21, 0x00]); // Normal
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

      // Info
      bytes.addAll([esc, 0x61, 0x00]); // Left
      bytes.addAll(utf8.encode('Inv No : ${widget.invoiceNumber}'));
      bytes.add(lf);
      bytes.addAll(utf8.encode('Date   : ${DateFormat('dd-MM-yyyy h:mm a').format(widget.dateTime)}'));
      bytes.add(lf);
      bytes.addAll(utf8.encode('--------------------------------'));
      bytes.add(lf);

      // Items
      bytes.addAll([esc, 0x21, 0x08]); // Bold
      bytes.addAll(utf8.encode('Item       Qty    Price    Total'));
      bytes.add(lf);
      bytes.addAll([esc, 0x21, 0x00]); // Normal

      for (var item in widget.items) {
        String name = item['name'] ?? '';
        if (name.length > 32) name = name.substring(0, 32);
        bytes.addAll(utf8.encode(name));
        bytes.add(lf);

        String qty = '${item['quantity']}';
        String price = '${(item['price'] ?? 0)}';
        String total = '${(item['total'] ?? 0)}';

        // Simple spacing for thermal
        bytes.addAll(utf8.encode('           $qty x $price = $total'));
        bytes.add(lf);
      }
      bytes.addAll(utf8.encode('--------------------------------'));
      bytes.add(lf);

      // Totals
      bytes.addAll([esc, 0x61, 0x02]); // Right align
      bytes.addAll(utf8.encode('Subtotal: ${widget.subtotal.toStringAsFixed(2)}'));
      bytes.add(lf);
      if (widget.discount > 0) {
        bytes.addAll(utf8.encode('Discount: -${widget.discount.toStringAsFixed(2)}'));
        bytes.add(lf);
      }
      bytes.addAll([esc, 0x21, 0x30]); // Big
      bytes.addAll(utf8.encode('TOTAL: ${widget.total.toStringAsFixed(2)}'));
      bytes.add(lf);
      bytes.addAll([esc, 0x21, 0x00]); // Normal
      bytes.add(lf);

      // Footer
      bytes.addAll([esc, 0x61, 0x01]); // Center
      bytes.addAll(utf8.encode('Thank You!'));
      bytes.add(lf);
      bytes.add(lf);
      bytes.add(lf);
      bytes.addAll([gs, 0x56, 0x00]); // Cut

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

      try { if (device.isConnected) await device.disconnect(); } catch (e) {}

      Navigator.pop(context);
      CommonWidgets.showSnackBar(context, 'Printed successfully!', bgColor: Colors.green);
    } catch (e) {
      Navigator.pop(context);
      CommonWidgets.showSnackBar(context, 'Print Error: $e', bgColor: Colors.red);
    }
  }

  // --- Clean & Crisp PDF Generation ---
  Future<void> _handleShare(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              // Header
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(businessName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 5),
                          pw.Text(businessLocation, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                          pw.Text(businessPhone, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                          if (businessGSTIN != null) pw.Text("GSTIN: $businessGSTIN", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        ]
                    ),
                    pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text("INVOICE", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                          pw.SizedBox(height: 5),
                          pw.Text("# ${widget.invoiceNumber}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.Text(DateFormat('MMMM dd, yyyy').format(widget.dateTime), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        ]
                    ),
                  ]
              ),
              pw.SizedBox(height: 40),

              // Bill To
              if (widget.customerName != null)
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Bill To:", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                      pw.Text(widget.customerName!, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      if (widget.customerPhone != null) pw.Text(widget.customerPhone!, style: const pw.TextStyle(fontSize: 10)),
                    ]
                ),
              pw.SizedBox(height: 20),

              // Items Table (Minimalist)
              pw.Table(
                  border: pw.TableBorder(
                    bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey300),
                  ),
                  children: [
                    // Header
                    pw.TableRow(
                        decoration: const pw.BoxDecoration(
                            border: pw.Border(bottom: pw.BorderSide(width: 1, color: PdfColors.black))
                        ),
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text("Item", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                          pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text("Qty", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                          pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text("Price", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                          pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text("Total", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        ]
                    ),
                    // Items
                    ...widget.items.map((item) {
                      return pw.TableRow(
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text(item['name'] ?? '', style: const pw.TextStyle(fontSize: 10))),
                            pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text('${item['quantity']}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10))),
                            pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text('${(item['price'] ?? 0).toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10))),
                            pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text('${(item['total'] ?? 0).toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10))),
                          ]
                      );
                    }),
                  ]
              ),
              pw.SizedBox(height: 20),

              // Totals
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                        width: 200,
                        child: pw.Column(
                            children: [
                              _buildPdfTotalRow("Subtotal", widget.subtotal),
                              if (widget.discount > 0) _buildPdfTotalRow("Discount", -widget.discount),
                              if (widget.cgst > 0) _buildPdfTotalRow("CGST", widget.cgst),
                              if (widget.sgst > 0) _buildPdfTotalRow("SGST", widget.sgst),
                              pw.Divider(color: PdfColors.grey300),
                              pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text("Total", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                                    pw.Text(widget.total.toStringAsFixed(2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                                  ]
                              )
                            ]
                        )
                    )
                  ]
              ),
              pw.Spacer(),
              pw.Divider(color: PdfColors.grey300),
              pw.Center(child: pw.Text("Thank you for your business!", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))),
            ];
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/invoice_${widget.invoiceNumber}.pdf');
      await file.writeAsBytes(await pdf.save());

      Navigator.pop(context);
      await Share.shareXFiles([XFile(file.path)], subject: 'Invoice ${widget.invoiceNumber}');

    } catch (e) {
      Navigator.pop(context);
    }
  }

  pw.Widget _buildPdfTotalRow(String label, double amount) {
    return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
              pw.Text(amount.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 10)),
            ]
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text("Invoice Details", style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w600, fontSize: 16)),
        leading: IconButton(
          icon: Icon(Icons.close, color: _primaryColor),
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            CupertinoPageRoute(builder: (context) => NewSalePage(uid: widget.uid, userEmail: widget.userEmail)),
                (route) => false,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. Invoice Header (Invoice No, Date, Status)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Invoice No", style: TextStyle(color: _secondaryColor, fontSize: 11)),
                      Text("#${widget.invoiceNumber}", style: TextStyle(color: _primaryColor, fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "PAID • ${widget.paymentMode.toUpperCase()}",
                      style: const TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("Date", style: TextStyle(color: _secondaryColor, fontSize: 11)),
                      Text(_formatDateTime(widget.dateTime), style: TextStyle(color: _primaryColor, fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 2. Business & Customer Info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // From
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.store_mall_directory_outlined, size: 18, color: _secondaryColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("FROM", style: TextStyle(color: _secondaryColor, fontSize: 10, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(businessName, style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(businessLocation, style: TextStyle(color: _secondaryColor, fontSize: 11)),
                            if(businessGSTIN != null) Text("GSTIN: $businessGSTIN", style: TextStyle(color: _secondaryColor, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                  // To
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.person_outline, size: 18, color: _secondaryColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("TO", style: TextStyle(color: _secondaryColor, fontSize: 10, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(widget.customerName ?? "Walk-in Customer", style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w600, fontSize: 13)),
                            if(widget.customerPhone != null) Text(widget.customerPhone!, style: TextStyle(color: _secondaryColor, fontSize: 11)),
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
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 4, child: Text("ITEM", style: TextStyle(color: _secondaryColor, fontSize: 10, fontWeight: FontWeight.bold))),
                        Expanded(flex: 1, child: Text("QTY", textAlign: TextAlign.center, style: TextStyle(color: _secondaryColor, fontSize: 10, fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text("PRICE", textAlign: TextAlign.right, style: TextStyle(color: _secondaryColor, fontSize: 10, fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text("AMOUNT", textAlign: TextAlign.right, style: TextStyle(color: _secondaryColor, fontSize: 10, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.items.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = widget.items[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(flex: 4, child: Text(item['name'], style: TextStyle(color: _primaryColor, fontSize: 12, fontWeight: FontWeight.w500))),
                            Expanded(flex: 1, child: Text("${item['quantity']}", textAlign: TextAlign.center, style: TextStyle(color: _primaryColor, fontSize: 12))),
                            Expanded(flex: 2, child: Text("${item['price']}", textAlign: TextAlign.right, style: TextStyle(color: _primaryColor, fontSize: 12))),
                            Expanded(flex: 2, child: Text("${item['total'].toStringAsFixed(2)}", textAlign: TextAlign.right, style: TextStyle(color: _primaryColor, fontSize: 12, fontWeight: FontWeight.w600))),
                          ],
                        ),
                      );
                    },
                  ),
                  // Totals Section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        _buildSummaryRow("Subtotal", widget.subtotal),
                        if (widget.discount > 0) _buildSummaryRow("Discount", -widget.discount, color: Colors.red),
                        if (widget.cgst > 0) _buildSummaryRow("CGST", widget.cgst),
                        if (widget.sgst > 0) _buildSummaryRow("SGST", widget.sgst),
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Grand Total", style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(widget.total.toStringAsFixed(2), style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 100), // Space for bottom bar
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _handlePrint(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  foregroundColor: _primaryColor,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.print_outlined, size: 16),
                    SizedBox(width: 8),
                    Text("Print", style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _handleShare(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  foregroundColor: _primaryColor,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.share_outlined, size: 16),
                    SizedBox(width: 8),
                    Text("Share", style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
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
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: const Text("New Sale", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfo(String label, String value, {CrossAxisAlignment align = CrossAxisAlignment.start}) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label, style: TextStyle(color: _secondaryColor, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: _primaryColor, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildSummaryRow(String label, double value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: _secondaryColor)),
          Text(
            value < 0 ? "-${value.abs().toStringAsFixed(2)}" : value.toStringAsFixed(2),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color ?? _primaryColor),
          ),
        ],
      ),
    );
  }
}