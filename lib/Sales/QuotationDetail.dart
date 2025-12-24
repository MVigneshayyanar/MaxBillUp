import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Sales/Bill.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';

// --- UI CONSTANTS ---
const Color _primaryColor = Color(0xFF2F7CF6);
const Color _cardBorder = Color(0xFFE3F2FD);

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
    final customerName = quotationData['customerName'] ?? 'Walk-in Customer';
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
      backgroundColor: _primaryColor,
      appBar: AppBar(
        title: const Text('Quotation Info', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _primaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderRow('QTN-$quotationNumber', isActive),
                      const SizedBox(height: 24),
                      _buildDetailRow(Icons.person_outline, 'Customer', customerName),
                      _buildDetailRow(Icons.badge_outlined, 'Created By', staffName),
                      _buildDetailRow(Icons.calendar_today_outlined, 'Date & Time', formattedDate),
                      _buildDetailRow(Icons.shopping_bag_outlined, 'Total Items', '${items.length}'),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(color: _cardBorder, thickness: 1)),
                      const Text('Financial Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      _buildPriceRow('Total Amount', total, isBold: true),
                      const SizedBox(height: 32),
                      if (isActive)
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: () => _generateInvoice(context),
                            icon: const Icon(Icons.receipt_long, color: Colors.white),
                            label: const Text('Generate Invoice', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(0.2))),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 20),
                              SizedBox(width: 12),
                              Text('Quotation Settled', style: TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ],
                  ),
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
        Text(ref, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _primaryColor)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: active ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Text(active ? 'ACTIVE' : 'BILLED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: active ? _primaryColor : Colors.grey)),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[400]),
          const SizedBox(width: 12),
          Text('$label: ', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double val, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: isBold ? 16 : 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text('Rs ${val.toStringAsFixed(2)}', style: TextStyle(fontSize: isBold ? 20 : 16, fontWeight: FontWeight.bold, color: isBold ? _primaryColor : Colors.black87)),
      ],
    );
  }

  void _generateInvoice(BuildContext context) async {
    final items = quotationData['items'] as List<dynamic>? ?? [];
    final cartItems = items.map((item) {
      return CartItem(
        productId: item['productId'] ?? '',
        name: item['name'] ?? '',
        price: (item['price'] ?? 0.0).toDouble(),
        quantity: item['quantity'] ?? 1,
      );
    }).toList();

    final total = (quotationData['total'] ?? 0.0).toDouble();
    final discount = (quotationData['discount'] ?? 0.0).toDouble();

    final result = await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => BillPage(
          uid: uid,
          userEmail: userEmail,
          cartItems: cartItems,
          totalAmount: total,
          discountAmount: discount,
          customerPhone: quotationData['customerPhone'],
          customerName: quotationData['customerName'],
          customerGST: quotationData['customerGST'],
          quotationId: quotationId,
        ),
      ),
    );

    if (result == true) {
      try {
        await FirestoreService().updateDocument('quotations', quotationId, {
          'status': 'settled',
          'billed': true,
          'settledAt': FieldValue.serverTimestamp(),
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quotation settled successfully'), backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }
}