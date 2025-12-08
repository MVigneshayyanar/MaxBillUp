import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterService {
  static const String _selectedPrinterKey = 'selected_printer';

  // Get list of available printers
  static Future<List<Printer>> discoverPrinters() async {
    try {
      return await Printing.listPrinters();
    } catch (e) {
      print('Error discovering printers: $e');
      return [];
    }
  }

  // Save selected printer
  static Future<void> saveSelectedPrinter(String printerName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedPrinterKey, printerName);
  }

  // Get saved printer
  static Future<String?> getSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedPrinterKey);
  }

  // Clear saved printer
  static Future<void> clearSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedPrinterKey);
  }

  // Print to specific printer
  static Future<void> printToSpecificPrinter(String printerName, pw.Document pdf) async {
    try {
      final printers = await Printing.listPrinters();
      final printer = printers.firstWhere(
        (p) => p.name == printerName,
        orElse: () => throw Exception('Printer not found: $printerName'),
      );

      await Printing.directPrintPdf(
        printer: printer,
        onLayout: (format) async => pdf.save(),
      );
    } catch (e) {
      print('Error printing to specific printer: $e');
      // Fallback to default print dialog
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    }
  }

  // Print with saved printer or show dialog
  static Future<void> printPdf(pw.Document pdf) async {
    final savedPrinter = await getSavedPrinter();

    if (savedPrinter != null) {
      try {
        await printToSpecificPrinter(savedPrinter, pdf);
        return;
      } catch (e) {
        print('Failed to print to saved printer: $e');
      }
    }

    // Show print dialog if no saved printer or if printing failed
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
  // Print Invoice/Bill Receipt
  static Future<void> printInvoice({
    required String invoiceNumber,
    required String customerName,
    required String customerPhone,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double tax,
    required double total,
    required String paymentMode,
    String? businessName,
    String? businessPhone,
    String? businessAddress,
    String? gstin,
    DateTime? timestamp,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Business Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      businessName ?? 'BUSINESS NAME',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (businessPhone != null) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(businessPhone, style: const pw.TextStyle(fontSize: 10)),
                    ],
                    if (businessAddress != null) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        businessAddress,
                        style: const pw.TextStyle(fontSize: 9),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                    if (gstin != null) ...[
                      pw.SizedBox(height: 4),
                      pw.Text('GSTIN: $gstin', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 10),

              // Invoice Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Invoice: $invoiceNumber', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    timestamp != null
                        ? DateFormat('dd/MM/yyyy hh:mm a').format(timestamp)
                        : DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now()),
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Text('Customer: $customerName'),
              if (customerPhone.isNotEmpty) pw.Text('Phone: $customerPhone'),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 10),

              // Items Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(flex: 4, child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 1, child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                  pw.Expanded(flex: 2, child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                ],
              ),
              pw.Divider(),

              // Items List
              ...items.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(flex: 4, child: pw.Text(item['name'] ?? '', style: const pw.TextStyle(fontSize: 10))),
                      pw.Expanded(flex: 1, child: pw.Text('${item['quantity']}', style: const pw.TextStyle(fontSize: 10))),
                      pw.Expanded(flex: 2, child: pw.Text('₹${(item['price'] ?? 0).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
                      pw.Expanded(flex: 2, child: pw.Text('₹${((item['price'] ?? 0) * (item['quantity'] ?? 0)).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                );
              }).toList(),

              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 10),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal:'),
                  pw.Text('₹${subtotal.toStringAsFixed(2)}'),
                ],
              ),
              if (discount > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Discount:'),
                    pw.Text('- ₹${discount.toStringAsFixed(2)}'),
                  ],
                ),
              ],
              if (tax > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Tax:'),
                    pw.Text('₹${tax.toStringAsFixed(2)}'),
                  ],
                ),
              ],
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL:',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '₹${total.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 8),

              // Payment Mode
              pw.Text('Payment Mode: $paymentMode', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),

              // Footer
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('Thank You for Your Business!', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('Visit Again', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await printPdf(pdf);
  }

  // Print Quotation
  static Future<void> printQuotation({
    required String quotationNumber,
    required String customerName,
    required String customerPhone,
    required List<Map<String, dynamic>> items,
    required double total,
    String? businessName,
    String? businessPhone,
    String? validUntil,
    DateTime? timestamp,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        businessName ?? 'BUSINESS NAME',
                        style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                      ),
                      if (businessPhone != null)
                        pw.Text(businessPhone, style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'QUOTATION',
                        style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text('#$quotationNumber'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 20),

              // Customer & Date Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Customer Name: $customerName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Phone: $customerPhone'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Date: ${timestamp != null ? DateFormat('dd/MM/yyyy').format(timestamp) : DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                      ),
                      if (validUntil != null) pw.Text('Valid Until: $validUntil'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Items Table
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  // Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Quantity', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  // Items
                  ...items.map((item) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(item['name'] ?? '')),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${item['quantity']}', textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('₹${(item['price'] ?? 0).toStringAsFixed(2)}', textAlign: pw.TextAlign.right)),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('₹${((item['price'] ?? 0) * (item['quantity'] ?? 0)).toStringAsFixed(2)}', textAlign: pw.TextAlign.right)),
                      ],
                    );
                  }).toList(),
                ],
              ),
              pw.SizedBox(height: 20),

              // Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 200,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 2),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('TOTAL:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                        pw.Text('₹${total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),

              // Footer
              pw.Center(
                child: pw.Text(
                  'This is a computer-generated quotation',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                ),
              ),
            ],
          );
        },
      ),
    );

    await printPdf(pdf);
  }

  // Print Credit Note
  static Future<void> printCreditNote({
    required String creditNoteNumber,
    required String invoiceNumber,
    required String customerName,
    required String customerPhone,
    required List<Map<String, dynamic>> items,
    required double amount,
    String? businessName,
    String? businessPhone,
    DateTime? timestamp,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        businessName ?? 'BUSINESS NAME',
                        style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                      ),
                      if (businessPhone != null)
                        pw.Text(businessPhone, style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'CREDIT NOTE',
                        style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.red),
                      ),
                      pw.Text('#$creditNoteNumber'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 20),

              // Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Original Invoice: $invoiceNumber', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 10),
                      pw.Text('Customer: $customerName'),
                      pw.Text('Phone: $customerPhone'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Date: ${timestamp != null ? DateFormat('dd/MM/yyyy').format(timestamp) : DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Items
              pw.Text('Returned Items:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                  ...items.map((item) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(item['name'] ?? '')),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${item['quantity']}', textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('₹${(item['price'] ?? 0).toStringAsFixed(2)}', textAlign: pw.TextAlign.right)),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('₹${(item['total'] ?? 0).toStringAsFixed(2)}', textAlign: pw.TextAlign.right)),
                      ],
                    );
                  }).toList(),
                ],
              ),
              pw.SizedBox(height: 20),

              // Credit Amount
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 250,
                    padding: const pw.EdgeInsets.all(15),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.red50,
                      border: pw.Border.all(width: 2, color: PdfColors.red),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('CREDIT AMOUNT:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                        pw.Text('₹${amount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),

              // Footer
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Text(
                  'This credit note can be used against future purchases.',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );

    await printPdf(pdf);
  }

  // Print Purchase Order
  static Future<void> printPurchaseOrder({
    required String orderNumber,
    required String supplierName,
    required List<Map<String, dynamic>> items,
    required double total,
    String? businessName,
    DateTime? timestamp,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'PURCHASE ORDER',
                style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Order #: $orderNumber'),
              pw.Text('Date: ${timestamp != null ? DateFormat('dd/MM/yyyy').format(timestamp) : DateFormat('dd/MM/yyyy').format(DateTime.now())}'),
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 20),
              pw.Text('Supplier: $supplierName', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),

              // Items Table
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                  ...items.map((item) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(item['name'] ?? '')),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${item['quantity']}', textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('₹${(item['price'] ?? 0).toStringAsFixed(2)}', textAlign: pw.TextAlign.right)),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('₹${((item['price'] ?? 0) * (item['quantity'] ?? 0)).toStringAsFixed(2)}', textAlign: pw.TextAlign.right)),
                      ],
                    );
                  }).toList(),
                ],
              ),
              pw.SizedBox(height: 20),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 200,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(border: pw.Border.all(width: 2)),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('TOTAL:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                        pw.Text('₹${total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await printPdf(pdf);
  }

  // Simple Receipt Print (for small receipts)
  static Future<void> printSimpleReceipt({
    required String title,
    required Map<String, String> details,
    String? businessName,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  businessName ?? 'BUSINESS NAME',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  title,
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 10),
              ...details.entries.map((entry) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(entry.key),
                      pw.Text(entry.value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                );
              }).toList(),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'Thank You!',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );

    await printPdf(pdf);
  }
}

