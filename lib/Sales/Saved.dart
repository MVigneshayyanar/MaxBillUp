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
    // Ensure orderName is included in the data
    final orderData = Map<String, dynamic>.from(data);
    if (!orderData.containsKey('orderName') && orderData.containsKey('customerName')) {
      // Backward compatibility: use customerName as orderName if orderName doesn't exist
      orderData['orderName'] = orderData['customerName'];
    }

    // Always use direct navigation to ensure orderName is properly displayed
    // Pop current screen if we're in a modal context
    if (widget.onLoadOrder != null) {
      Navigator.pop(context); // Close the saved orders page first
    }

    // Navigate to NewSalePage with saved order data
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewSalePage(
          uid: widget.uid,
          userEmail: widget.userEmail,
          savedOrderData: orderData,
          savedOrderId: orderId,
        ),
      ),
    );
  }

  Future<void> _deleteOrder(String id) async {
    try {
      await FirestoreService().deleteDocument('savedOrders', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('order_deleted'), style: const TextStyle(fontWeight: FontWeight.w600)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('DISCARD ORDER?',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: kErrorColor.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.warning_amber_rounded, color: kErrorColor, size: 32),
            ),
            const SizedBox(height: 16),
            Text('Are you sure you want to permanently discard the saved order for "$name"?',
                textAlign: TextAlign.center,
                style: const TextStyle(color: kBlack54, fontSize: 13, height: 1.5, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: kBlack54, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteOrder(id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kErrorColor,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('DISCARD', style: TextStyle(color: kWhite, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kGreyBg,
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border_rounded, size: 64, color: kGrey300),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontWeight: FontWeight.w700, color: kBlack54)),
        ],
      ),
    );
  }

  Widget _buildSavedOrderCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = (data['orderName'] ?? data['customerName'] ?? '').toString().trim().isEmpty
        ? 'Guest'
        : (data['orderName'] ?? data['customerName']).toString();
    final total = (data['total'] ?? 0.0).toDouble();
    final items = data['items'] as List<dynamic>? ?? [];
    final timestamp = data['timestamp'] as Timestamp?;
    final date = timestamp != null ? DateFormat('dd-MM-yyyy • hh:mm a').format(timestamp.toDate()) : '--';

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _loadOrder(doc.id, data),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Saved draft',
                        style: TextStyle(fontWeight: FontWeight.w900, color: kPrimaryColor, fontSize: 10, letterSpacing: 0.5)),
                    Text(date, style: const TextStyle(color: kBlack54, fontSize: 10, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: kOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.person_rounded, size: 18, color: kOrange),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kOrange),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text('${items.length} ${items.length == 1 ? 'line item' : 'line items'} total',
                              style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_forever_rounded, color: kErrorColor, size: 22),
                      onPressed: () => _confirmDelete(doc.id, name),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Discard Draft',
                    ),
                  ],
                ),
                const Divider(height: 24, color: kGrey100),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ESTIMATED TOTAL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54, letterSpacing: 0.5)),
                        const SizedBox(height: 2),
                        Text('${total.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kPrimaryColor)),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pending_actions_rounded, size: 12, color: kGoogleGreen),
          const SizedBox(width: 6),
          const Text('DRAFT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kGoogleGreen, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}