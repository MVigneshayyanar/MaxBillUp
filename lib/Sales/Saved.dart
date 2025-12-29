import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Sales/NewSale.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/Colors.dart';

class SavedOrdersPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final Function(String orderId, Map<String, dynamic> data)? onLoadOrder;

  const SavedOrdersPage({super.key, required this.uid, this.userEmail, this.onLoadOrder});

  @override
  State<SavedOrdersPage> createState() => _SavedOrdersPageState();
}

class _SavedOrdersPageState extends State<SavedOrdersPage> {
  void _loadOrder(String orderId, Map<String, dynamic> data) {
    if (widget.onLoadOrder != null) {
      widget.onLoadOrder!(orderId, data);
    } else {
      // Fallback to old navigation behavior if no callback is provided
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => NewSalePage(
            uid: widget.uid,
            userEmail: widget.userEmail,
            savedOrderData: data,
            savedOrderId: orderId,
          ),
        ),
      );
    }
  }

  Future<void> _deleteOrder(String id) async {
    try {
      await FirestoreService().deleteDocument('savedOrders', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('order_deleted')),
            backgroundColor: kGoogleGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: kErrorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _confirmDelete(String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(Icons.warning_amber_rounded, color: kErrorColor, size: 40),
            const SizedBox(height: 12),
            Text(context.tr('delete_order'),
                style: const TextStyle(fontWeight: FontWeight.w900, color: kBlack87, fontSize: 18)),
          ],
        ),
        content: Text('This will permanently discard the saved order for "$name".',
            textAlign: TextAlign.center,
            style: const TextStyle(color: kBlack54, fontSize: 14, height: 1.4)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: kBlack54, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _deleteOrder(id);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kErrorColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Discard', style: TextStyle(color: kWhite, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kGreyBg, // Changed background color to red
      child: FutureBuilder<Stream<QuerySnapshot>>(
        future: FirestoreService().getCollectionStream('savedOrders'),
        builder: (context, streamSnapshot) {
          if (!streamSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          }
          return StreamBuilder<QuerySnapshot>(
            stream: streamSnapshot.data,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState(context.tr('no_saved_orders'));
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildSavedOrderCard(snapshot.data!.docs[index]);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.bookmark_border_rounded, size: 60, color: kPrimaryColor.withOpacity(0.1)),
      const SizedBox(height: 16),
      Text(message, style: const TextStyle(fontWeight: FontWeight.bold, color: kBlack54)),
    ]));
  }

  Widget _buildSavedOrderCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = (data['customerName'] ?? '').toString().trim().isEmpty ? 'Walk-in Customer' : data['customerName'].toString();
    final total = (data['total'] ?? 0.0).toDouble();
    final items = data['items'] as List<dynamic>? ?? [];
    final timestamp = data['timestamp'] as Timestamp?;
    final date = timestamp != null ? DateFormat('dd MMM yyyy').format(timestamp.toDate()) : 'No Date';

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _loadOrder(doc.id, data),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('DRAFT-${doc.id.substring(0, 4).toUpperCase()}',
                        style: const TextStyle(fontWeight: FontWeight.w900, color: kPrimaryColor, fontSize: 13)),
                    Text(date, style: const TextStyle(color: kBlack54, fontSize: 11, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: kGrey100, shape: BoxShape.circle),
                        child: const Icon(Icons.person_outline_rounded, size: 18, color: kBlack54)
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kBlack87),
                                overflow: TextOverflow.ellipsis
                            ),
                            Text('${items.length} ${items.length == 1 ? 'item' : 'items'}',
                                style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w600)
                            ),
                          ],
                        )
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: kErrorColor, size: 20),
                      onPressed: () => _confirmDelete(doc.id, name),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: kGrey200)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ESTIMATED TOTAL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54, letterSpacing: 0.5)),
                        Text('Rs ${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kGoogleGreen)),
                      ],
                    ),
                    _statusBadge(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: kPrimaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kPrimaryColor.withOpacity(0.15))
      ),
      child: Row(children: [
        const Icon(Icons.pending_actions_rounded, size: 12, color: kPrimaryColor),
        const SizedBox(width: 4),
        Text('DRAFT', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kPrimaryColor)),
      ]),
    );
  }
}