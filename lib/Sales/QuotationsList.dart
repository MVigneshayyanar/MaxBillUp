import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Menu/Menu.dart';
import 'package:maxbillup/Sales/QuotationDetail.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/quotation_migration_helper.dart';

class QuotationsListPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final VoidCallback onBack;

  const QuotationsListPage({
    super.key,
    required this.uid,
    this.userEmail,
    required this.onBack,
  });

  @override
  State<QuotationsListPage> createState() => _QuotationsListPageState();
}

class _QuotationsListPageState extends State<QuotationsListPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: () {
            // Hidden debug feature: Long press title to migrate old quotations
            QuotationMigrationHelper.migrateSettledQuotations(context);
          },
          child: const Text(
            'Quotations',
            style: TextStyle(color: Colors.white),
          ),
        ),
        backgroundColor: const Color(0xFF2196F3),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<Stream<QuerySnapshot>>(
        future: FirestoreService().getCollectionStream('quotations'),
        builder: (context, streamSnapshot) {
          if (!streamSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<QuerySnapshot>(
            stream: streamSnapshot.data,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No quotations found',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final quotationNumber = data['quotationNumber'] ?? 'N/A';
                  final rawCustomerName = data['customerName'];
                  final customerName = (rawCustomerName == null ||
                          rawCustomerName.toString().trim().isEmpty)
                      ? 'Walk-in Customer'
                      : rawCustomerName.toString();

                  // Safely parse total (can be int / double / string)
                  double total = 0.0;
                  final totalRaw = data['total'];
                  if (totalRaw is num) {
                    total = totalRaw.toDouble();
                  } else if (totalRaw is String) {
                    total = double.tryParse(totalRaw) ?? 0.0;
                  }

                  final status = (data['status'] ?? 'active').toString();
                  final billedField = data['billed'];

                  // Debug logging to see what we're getting from Firestore
                  debugPrint('Quotation ${doc.id}: status=$status, billed=$billedField');

                  // Check if quotation is already marked as settled/billed
                  final bool isBilled =
                      status == 'settled' || status == 'billed' || (billedField == true);
                  final timestamp = data['timestamp'] as Timestamp?;
                  final formattedDate = timestamp != null
                      ? DateFormat('dd MMM yyyy').format(timestamp.toDate())
                      : '';

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => QuotationDetailPage(
                              uid: widget.uid,
                              userEmail: widget.userEmail,
                              quotationId: doc.id,
                              quotationData: data,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Quotation #$quotationNumber',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2196F3),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isBilled
                                        ? Colors.grey.withAlpha(25)
                                        : Colors.green.withAlpha(25),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isBilled ? 'Settled' : 'Available',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isBilled ? Colors.grey : Colors.green,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              customerName,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  formattedDate,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  ' ${total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4CAF50),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
