import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/Sales/NewSale.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/Colors.dart';

class SavedOrdersPage extends StatefulWidget {
  final String uid;
  final String? userEmail;

  const SavedOrdersPage({super.key, required this.uid, this.userEmail});

  @override
  State<SavedOrdersPage> createState() => _SavedOrdersPageState();
}

class _SavedOrdersPageState extends State<SavedOrdersPage> {
  void _loadOrder(String orderId, Map<String, dynamic> data) {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Icon(Icons.delete_sweep_rounded, color: kErrorColor, size: 40),
            const SizedBox(height: 12),
            Text(context.tr('delete_order'),
                style: const TextStyle(fontWeight: FontWeight.w900, color: kBlack87, fontSize: 18)),
          ],
        ),
        content: Text('Are you sure you want to discard the order for "$name"?',
            textAlign: TextAlign.center,
            style: const TextStyle(color: kBlack54, fontSize: 14)),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Keep it', style: TextStyle(color: kBlack54, fontWeight: FontWeight.bold)),
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
                  child: Text(context.tr('delete'), style: const TextStyle(color: kWhite, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(Timestamp ts) {
    final dt = ts.toDate();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
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
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                color: kPrimaryColor.withOpacity(0.05),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: kPrimaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.receipt_long_rounded, size: 48, color: kPrimaryColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Text(context.tr('no_saved_orders'),
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kBlack87)),
                        const SizedBox(height: 12),
                        Text(
                          'Your checkout queue is clear. Any orders you save as drafts will appear here for quick access.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: kBlack54.withOpacity(0.7), fontWeight: FontWeight.w500, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['customerName'] ?? 'Walking Customer';
                  final phone = data['customerPhone'] ?? '';
                  final total = (data['total'] ?? 0).toDouble();
                  final items = data['items'] as List<dynamic>? ?? [];
                  final timestamp = data['timestamp'] as Timestamp?;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: kWhite,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          // Vertical accent bar
                          Container(
                            width: 6,
                            color: kPrimaryColor,
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => _loadOrder(doc.id, data),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundColor: kPrimaryColor.withOpacity(0.1),
                                          child: Text(
                                            name.isNotEmpty ? name[0].toUpperCase() : 'W',
                                            style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900, fontSize: 18),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(name,
                                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kBlack87),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  _buildStatusBadge(),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              if (phone.isNotEmpty)
                                                Text(phone, style: const TextStyle(fontSize: 13, color: kBlack54, fontWeight: FontWeight.w600))
                                              else
                                                const Text('No contact info', style: TextStyle(fontSize: 12, color: kBlack54, fontStyle: FontStyle.italic)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                    // Middle section: Item details
                                    Row(
                                      children: [
                                        _buildDetailChip(Icons.shopping_bag_outlined, '${items.length} ${items.length == 1 ? 'Item' : 'Items'}'),
                                        const SizedBox(width: 8),
                                        if (timestamp != null)
                                          _buildDetailChip(Icons.access_time_rounded, _formatTime(timestamp)),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    // Bottom section: Price & Actions
                                    const Divider(height: 1, color: kGrey200),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Total Amount', style: TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                            Text(
                                              'Rs ${total.toStringAsFixed(2)}',
                                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kPrimaryColor),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            _buildActionCircle(Icons.delete_outline_rounded, kErrorColor, () => _confirmDelete(doc.id, name)),
                                            const SizedBox(width: 10),
                                            _buildActionCircle(Icons.arrow_forward_rounded, kPrimaryColor, () => _loadOrder(doc.id, data), isSolid: true),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kGoogleYellow.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text('DRAFT',
          style: TextStyle(color: kGoogleYellow, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }

  Widget _buildDetailChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kGrey100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: kBlack54),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: kBlack54, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildActionCircle(IconData icon, Color color, VoidCallback onTap, {bool isSolid = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSolid ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSolid ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
        ),
        child: Icon(icon, color: isSolid ? kWhite : color, size: 20),
      ),
    );
  }
}