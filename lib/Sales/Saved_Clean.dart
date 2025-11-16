import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/Sales/NewSale.dart';

class SavedOrdersPage extends StatefulWidget {
  final String uid;
  final String? userEmail;

  const SavedOrdersPage({
    super.key,
    required this.uid,
    this.userEmail,
  });

  @override
  State<SavedOrdersPage> createState() => _SavedOrdersPageState();
}

class _SavedOrdersPageState extends State<SavedOrdersPage> {
  late String _uid;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _uid = widget.uid;
    _userEmail = widget.userEmail;
  }

  double get _totalBill {
    // Calculate total from saved orders if needed
    return 0.0;
  }

  void _loadSavedOrder(Map<String, dynamic> orderData) {
    // Navigate to NewSale with the saved order items
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => NewSalePage(
          uid: _uid,
          userEmail: _userEmail,
          savedOrderData: orderData,
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Saved Orders',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Saved Orders List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(_uid)
                    .collection('savedOrders')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bookmark_border, size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            'No saved orders',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final orderData = doc.data() as Map<String, dynamic>;
                      final customerName = orderData['customerName'] ?? 'Unknown';
                      final customerPhone = orderData['customerPhone'] ?? '';
                      final total = (orderData['total'] ?? 0).toDouble();
                      final timestamp = orderData['timestamp'] as Timestamp?;
                      final items = orderData['items'] as List<dynamic>? ?? [];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(customerName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(customerPhone),
                              Text('${items.length} items • ₹${total.toStringAsFixed(2)}'),
                              if (timestamp != null) Text(_formatTimestamp(timestamp)),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.arrow_forward),
                            onPressed: () => _loadSavedOrder(orderData),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

