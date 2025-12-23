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

// Black & White UI Constants
const Color _bwPrimary = Colors.black;
const Color _bwBg = Colors.white;
const Color _textMain = Colors.black;
const Color _textSub = Color(0xFF424242); // Grey 800
const Color _dividerColor = Color(0xFFE0E0E0); // Grey 300
const Color _headerBg = Color(0xFFF5F5F5); // Grey 100

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
      backgroundColor: _bwBg,
      appBar: AppBar(
        backgroundColor: _bwBg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          context.tr('invoice details').toUpperCase(),
          style: const TextStyle(
            color: _bwPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: _bwPrimary),
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            CupertinoPageRoute(builder: (context) => NewSalePage(uid: widget.uid, userEmail: widget.userEmail)),
                (route) => false,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _bwPrimary))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: _bwPrimary, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBWHeader(),
              _buildBWMeta(),
              _buildBWCustomerInfo(),
              _buildBWTable(),
              _buildBWSummary(),
              _buildBWFooter(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomActionBar(),
    );
  }

  Widget _buildBWHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _bwPrimary, width: 1.5)),
      ),
      child: Column(
        children: [
          Text(businessName.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 26,
                color: _bwPrimary,
                letterSpacing: 3,
              )),
          const SizedBox(height: 8),
          Text(businessLocation.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textSub, fontSize: 11, letterSpacing: 1)),
          Text("TEL: $businessPhone",
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textSub, fontSize: 11, fontWeight: FontWeight.bold)),
          if (businessGSTIN != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text("GSTIN: $businessGSTIN",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _bwPrimary, fontSize: 11, fontWeight: FontWeight.w900)),
            ),
        ],
      ),
    );
  }

  Widget _buildBWMeta() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _bwPrimary, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("INVOICE NO: #${widget.invoiceNumber}",
              style: const TextStyle(color: _textMain, fontWeight: FontWeight.bold, fontSize: 13)),
          Text("DATE: ${DateFormat('dd-MM-yyyy').format(widget.dateTime)}",
              style: const TextStyle(color: _textMain, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildBWCustomerInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _bwPrimary, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.customerName?.toUpperCase() ?? "WALK-IN CUSTOMER",
                  style: const TextStyle(color: _textMain, fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              if (widget.customerPhone != null)
                Text(
                  widget.customerPhone!,
                  style: const TextStyle(color: _textMain, fontWeight: FontWeight.w900, fontSize: 14),
                ),
            ],
          ),
          if (widget.customerGSTIN != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text("GSTIN: ${widget.customerGSTIN}", style: const TextStyle(color: _textSub, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildBWTable() {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: const BoxDecoration(
            color: _headerBg,
            border: Border(bottom: BorderSide(color: _bwPrimary, width: 1)),
          ),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text("DESCRIPTION", style: _bwTableHeaderStyle)),
              SizedBox(width: 60, child: Text("RATE", textAlign: TextAlign.right, style: _bwTableHeaderStyle)),
              SizedBox(width: 35, child: Text("QTY", textAlign: TextAlign.center, style: _bwTableHeaderStyle)),
              SizedBox(width: 55, child: Text("TAX", textAlign: TextAlign.center, style: _bwTableHeaderStyle)),
              SizedBox(width: 70, child: Text("TOTAL", textAlign: TextAlign.right, style: _bwTableHeaderStyle)),
            ],
          ),
        ),
        // Item List
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.items.length,
          separatorBuilder: (context, index) => Divider(height: 1, color: _bwPrimary.withOpacity(0.1), indent: 16, endIndent: 16),
          itemBuilder: (context, index) {
            final item = widget.items[index];
            final taxAmount = (item['taxAmount'] ?? 0.0) as double;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description: wraps to next line if long
                  Expanded(
                    flex: 3,
                    child: Text(
                      item['name'].toString().toUpperCase(),
                      style: const TextStyle(color: _textMain, fontSize: 11, fontWeight: FontWeight.bold),
                      softWrap: true,
                    ),
                  ),
                  // Numeric Columns: strictly on one line using SizedBox and softWrap: false
                  SizedBox(
                    width: 60,
                    child: Text(
                      "${item['price']}",
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: _textMain, fontSize: 11),
                      softWrap: false,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                  SizedBox(
                    width: 35,
                    child: Text(
                      "${item['quantity']}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _textMain, fontSize: 11),
                      softWrap: false,
                    ),
                  ),
                  SizedBox(
                    width: 55,
                    child: Text(
                      taxAmount.toStringAsFixed(2),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _textMain, fontSize: 11),
                      softWrap: false,
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text(
                      "${item['total'].toStringAsFixed(2)}",
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: _textMain, fontSize: 11, fontWeight: FontWeight.w900),
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

  Widget _buildBWSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _bwPrimary, width: 1.5)),
      ),
      child: Column(
        children: [
          _summaryRow("SUBTOTAL", widget.subtotal),
          if (widget.discount > 0) _summaryRow("DISCOUNT (-)", widget.discount, isHighlight: true),
          if (widget.taxes != null)
            ...widget.taxes!.map((tax) => _summaryRow(tax['name'].toString().toUpperCase(), (tax['amount'] ?? 0.0) as double)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(color: _bwPrimary, thickness: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("GRAND TOTAL", style: TextStyle(color: _bwPrimary, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5)),
              Text("Rs ${widget.total.toStringAsFixed(2)}", style: const TextStyle(color: _bwPrimary, fontWeight: FontWeight.w900, fontSize: 24)),
            ],
          ),
          const SizedBox(height: 12),
          Text("PAYMENT MODE: ${widget.paymentMode.toUpperCase()}",
              style: const TextStyle(color: _textSub, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildBWFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        color: _headerBg,
        border: Border(top: BorderSide(color: _bwPrimary, width: 1)),
      ),
      child: Column(
        children: [
          const Text("THANK YOU FOR YOUR PATRONAGE",
              style: TextStyle(color: _bwPrimary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 4),
          Text("COMPUTER GENERATED RECEIPT",
              style: TextStyle(color: _textSub, fontSize: 8, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  TextStyle get _bwTableHeaderStyle => const TextStyle(color: _bwPrimary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1);

  Widget _summaryRow(String label, double value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: _textSub, fontWeight: FontWeight.bold)),
          Text(
            value.toStringAsFixed(2),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _textMain),
          ),
        ],
      ),
    );
  }

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

      bytes.addAll([esc, 0x40]);
      bytes.addAll([esc, 0x61, 0x01, esc, 0x21, 0x30]);
      bytes.addAll(utf8.encode(businessName.toUpperCase()));
      bytes.add(lf);
      bytes.addAll([esc, 0x21, 0x00]);
      bytes.addAll(utf8.encode(businessLocation));
      bytes.add(lf);
      bytes.addAll(utf8.encode('PH: $businessPhone'));
      bytes.add(lf);
      bytes.addAll(utf8.encode('--------------------------------'));
      bytes.add(lf);
      bytes.addAll([esc, 0x61, 0x00]);
      bytes.addAll(utf8.encode('INV: #${widget.invoiceNumber}'));
      bytes.add(lf);
      bytes.addAll(utf8.encode('DATE: ${DateFormat('dd-MM-yyyy HH:mm').format(widget.dateTime)}'));
      bytes.add(lf);
      bytes.addAll(utf8.encode('--------------------------------'));
      bytes.add(lf);
      for (var item in widget.items) {
        final taxAmount = (item['taxAmount'] ?? 0.0) as double;
        bytes.addAll(utf8.encode('${item['name']}'));
        bytes.add(lf);
        bytes.addAll(utf8.encode('  ${item['quantity']} x ${item['price']} | Tax: ${taxAmount.toStringAsFixed(2)} = ${item['total']}'));
        bytes.add(lf);
      }
      bytes.addAll(utf8.encode('--------------------------------'));
      bytes.add(lf);
      bytes.addAll([esc, 0x61, 0x02]);
      bytes.addAll(utf8.encode('TOTAL: ${widget.total.toStringAsFixed(2)}'));
      bytes.add(lf);
      bytes.add(lf);
      bytes.addAll([esc, 0x61, 0x01]);
      bytes.addAll(utf8.encode('THANK YOU!'));
      bytes.add(lf);
      bytes.add(lf);
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
          return [
            pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 2),
                ),
                child: pw.Column(
                    children: [
                      pw.Center(child: pw.Text(businessName.toUpperCase(), style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
                      pw.Center(child: pw.Text(businessLocation.toUpperCase(), style: const pw.TextStyle(fontSize: 10))),
                      pw.Center(child: pw.Text("TEL: $businessPhone", style: const pw.TextStyle(fontSize: 10))),
                      pw.Divider(color: PdfColors.black),
                      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                        pw.Text("INVOICE #${widget.invoiceNumber}"),
                        pw.Text("DATE: ${DateFormat('dd-MM-yyyy').format(widget.dateTime)}"),
                      ]),
                      pw.SizedBox(height: 20),
                      // Customer Info row
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(
                            child: pw.Text(
                              widget.customerName?.toUpperCase() ?? "WALK-IN CUSTOMER",
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                            ),
                          ),
                          if (widget.customerPhone != null)
                            pw.Text(
                              widget.customerPhone!,
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                            ),
                        ],
                      ),
                      if (widget.customerGSTIN != null)
                        pw.Align(
                          alignment: pw.Alignment.centerLeft,
                          child: pw.Text("GSTIN: ${widget.customerGSTIN}", style: const pw.TextStyle(fontSize: 9)),
                        ),
                      pw.SizedBox(height: 10),
                      // Table with strict numeric column handling
                      pw.Table(
                        columnWidths: {
                          0: const pw.FlexColumnWidth(3), // Description: allowed to wrap
                          1: const pw.FixedColumnWidth(65), // Rate: Fixed
                          2: const pw.FixedColumnWidth(35), // Qty: Fixed
                          3: const pw.FixedColumnWidth(55), // Tax: Fixed
                          4: const pw.FixedColumnWidth(75), // Total: Fixed
                        },
                        children: [
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1, color: PdfColors.black))),
                            children: [
                              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("ITEM", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("RATE", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("QTY", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("TAX", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("TOTAL", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                            ],
                          ),
                          ...widget.items.map((item) {
                            final taxAmount = (item['taxAmount'] ?? 0.0) as double;

                            return pw.TableRow(
                              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5, color: PdfColors.black))),
                              children: [
                                // Item Description: Wraps to next line
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(5),
                                  child: pw.Text(item['name'].toString().toUpperCase(), style: const pw.TextStyle(fontSize: 9)),
                                ),
                                // Numbers: Strictly one line
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(5),
                                  child: pw.Text('${item['price']}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9), softWrap: false),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(5),
                                  child: pw.Text('${item['quantity']}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9), softWrap: false),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(5),
                                  child: pw.Text(taxAmount.toStringAsFixed(2), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9), softWrap: false),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(5),
                                  child: pw.Text('${item['total'].toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9), softWrap: false),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                      pw.SizedBox(height: 20),
                      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
                        pw.Text("GRAND TOTAL: Rs ${widget.total.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      ]),
                    ]
                )
            )
          ];
        },
      ));
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/invoice_${widget.invoiceNumber}.pdf');
      await file.writeAsBytes(await pdf.save());
      Navigator.pop(context);
      await Share.shareXFiles([XFile(file.path)], subject: 'Invoice #${widget.invoiceNumber}');
    } catch (e) { Navigator.pop(context); }
  }
}