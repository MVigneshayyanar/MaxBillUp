import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Sales/Bill.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';

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
    final customerName = quotationData['customerName'] ?? 'Sam';
    final staffName = quotationData['staffName'] ?? 'Admin';
    final timestamp = quotationData['timestamp'] as Timestamp?;
    final formattedDate = timestamp != null
        ? DateFormat('dd MMM yyyy hh:mm a').format(timestamp.toDate())
        : '';
    final items = quotationData['items'] as List<dynamic>? ?? [];
    final total = (quotationData['total'] ?? 0.0).toDouble();
    final status = quotationData['status'] ?? 'active';
    final billed = quotationData['billed'] ?? false;

    // Check if quotation is still active (not yet billed/settled)
    final isActive = status == 'active' && billed != true;

    return Scaffold(
      backgroundColor: const Color(0xFF2196F3),
      appBar: AppBar(
        title: const Text(
          'Quotation',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quotation Number and Total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Quotation',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Customer : $customerName',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Created by : $staffName',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Date & Time : $formattedDate',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Items : ${items.length}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                              const Text(
                                '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                              const Text(
                                'Total Amount',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                              Text(
                                'Rs ${total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2196F3),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Generate Invoice Button
                      if (isActive)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _generateInvoice(context),
                            icon: const Icon(Icons.receipt_long),
                            label: const Text(
                              'Generate Invoice',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2196F3),
                              side: const BorderSide(
                                color: Color(0xFF2196F3),
                                width: 2,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: Colors.grey),
                              SizedBox(width: 8),
                              Text(
                                'Quotation Settled',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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

  void _generateInvoice(BuildContext context) async {
    // Convert quotation items to CartItems
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

    // Navigate to Bill Page and wait for result
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

    // Only update quotation status if invoice was actually created
    if (result == true) {
      try {
        await FirestoreService().updateDocument('quotations', quotationId, {
          'status': 'settled',
          'billed': true,
          'settledAt': FieldValue.serverTimestamp(),
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quotation settled successfully'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Pop back to quotation list so it refreshes with updated status
          Navigator.pop(context);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating quotation: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

