import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Sales/Bill.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/Colors.dart';

class QuotationDetailPage extends StatelessWidget {
  final String uid;
  final String? userEmail;
  final String quotationId;
  final Map<String, dynamic> quotationData;

  const QuotationDetailPage({
    super.key,
    required this.uid,
    this.userEmail,
    required this.quotationId,
    required this.quotationData,
  });

  @override
  Widget build(BuildContext context) {
    final quotationNumber = quotationData['quotationNumber'] ?? 'N/A';
    final customerName = quotationData['customerName'] ?? 'Guest';
    final staffName = quotationData['staffName'] ?? 'Staff';
    final timestamp = quotationData['timestamp'] as Timestamp?;
    final formattedDate = timestamp != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toDate())
        : 'N/A';
    final items = quotationData['items'] as List<dynamic>? ?? [];
    final total = (quotationData['total'] ?? 0.0).toDouble();
    final status = quotationData['status'] ?? 'active';
    final billed = quotationData['billed'] ?? false;

    final isActive = status == 'active' && billed != true;

    return Scaffold(
      backgroundColor: kPrimaryColor,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: const Text('Quotation Info', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 22), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 16), // Reduced margin
              decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15)]),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20), // Reduced padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderRow('$quotationNumber', isActive),
                    const SizedBox(height: 16), // Reduced gap
                    _buildDetailRow(Icons.person_rounded, 'Customer', customerName),
                    _buildDetailRow(Icons.badge_rounded, 'Created By', staffName),
                    _buildDetailRow(Icons.calendar_month_rounded, 'Date Issued', formattedDate),
                    _buildDetailRow(Icons.shopping_bag_rounded, 'Line Items', '${items.length} units'),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: kGreyBg, thickness: 1)),
                    const Text('VALUATION SUMMARY', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: kBlack54, letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    _buildPriceRow('Subtotal (Gross)', (quotationData['subtotal'] ?? 0.0).toDouble()),
                    _buildPriceRow('Total Deductions', -(quotationData['discount'] ?? 0.0).toDouble(), valueColor: kErrorColor),
                    const Divider(height: 24, color: kGreyBg),
                    _buildPriceRow('Final Net Total', total, isBold: true),
                    const SizedBox(height: 32),
                    if (isActive)
                      SizedBox(
                        width: double.infinity, height: 54,
                        child: ElevatedButton(
                          onPressed: () => _generateInvoice(context),
                          style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                          child: const Text('CONVERT TO INVOICE', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kWhite)),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: kGoogleGreen.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: kGoogleGreen.withOpacity(0.15))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.check_circle, color: kGoogleGreen, size: 20),
                            SizedBox(width: 10),
                            Text('Quotation Settled', style: TextStyle(fontSize: 15, color: kGoogleGreen, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(String ref, bool active) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(ref, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kPrimaryColor)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: active ? kPrimaryColor.withOpacity(0.1) : kGreyBg, borderRadius: BorderRadius.circular(20)),
          child: Text(active ? 'OPEN' : 'BILLED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: active ? kPrimaryColor : kBlack54)),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: kGrey400),
          const SizedBox(width: 12),
          Text('$label: ', style: const TextStyle(color: kBlack54, fontSize: 12, fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: kBlack87), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double val, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isBold ? 14 : 13, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500, color: isBold ? kBlack87 : kBlack54)),
          Text('${val.toStringAsFixed(2)}', style: TextStyle(fontSize: isBold ? 20 : 14, fontWeight: FontWeight.w800, color: valueColor ?? (isBold ? kPrimaryColor : kBlack87))),
        ],
      ),
    );
  }

  void _generateInvoice(BuildContext context) async {
    final items = quotationData['items'] as List<dynamic>? ?? [];
    final cartItems = items.map((item) => CartItem(
      productId: item['productId'] ?? '', name: item['name'] ?? '',
      price: (item['price'] ?? 0.0).toDouble(), quantity: item['quantity'] ?? 1,
    )).toList();

    final total = (quotationData['total'] ?? 0.0).toDouble();
    final discount = (quotationData['discount'] ?? 0.0).toDouble();

    final result = await Navigator.push(
      context, CupertinoPageRoute(builder: (context) => BillPage(
      uid: uid, userEmail: userEmail, cartItems: cartItems, totalAmount: total,
      discountAmount: discount, customerPhone: quotationData['customerPhone'],
      customerName: quotationData['customerName'], customerGST: quotationData['customerGST'],
      quotationId: quotationId,
    )),
    );

    if (result == true) {
      await FirestoreService().updateDocument('quotations', quotationId, {'status': 'settled', 'billed': true, 'settledAt': FieldValue.serverTimestamp()});
      if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order Finalized Successfully'))); Navigator.pop(context); }
    }
  }
}