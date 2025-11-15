import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/Sales/saleall.dart';
import 'package:maxbillup/Sales/QuickSale.dart';
import 'package:maxbillup/Stocks/Products.dart';
import 'package:maxbillup/Stocks/Category.dart';

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
  int _selectedTabIndex = 2;
  late String _uid;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _uid = widget.uid;
    _userEmail = widget.userEmail;
  }

  void _loadSavedOrder(Map<String, dynamic> orderData) {
    // Navigate back to SaleAll with the saved order items
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SaleAllPage(
          uid: _uid,
          userEmail: _userEmail,
          savedOrderData: orderData,
        ),
      ),
    );
  }

  void _deleteSavedOrder(String orderId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('savedOrders')
          .doc(orderId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order deleted successfully'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting order: $e'),
            backgroundColor: const Color(0xFFFF5252),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final tabPadding = screenWidth * 0.04;
    final tabHeight = screenHeight * 0.06;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // Tabs
            Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(tabPadding, tabPadding, tabPadding, tabPadding * 0.5),
              child: Row(
                children: [
                  _buildTab('Sale / All', 0, screenWidth, tabHeight),
                  SizedBox(width: screenWidth * 0.02),
                  _buildTab('Quick Sale', 1, screenWidth, tabHeight),
                  SizedBox(width: screenWidth * 0.02),
                  _buildTab('Saved Orders', 2, screenWidth, tabHeight),
                ],
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
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF2196F3),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bookmark_border,
                            size: screenWidth * 0.2,
                            color: Colors.grey[300],
                          ),
                          SizedBox(height: screenHeight * 0.02),
                          Text(
                            'No Saved Orders',
                            style: TextStyle(
                              fontSize: screenWidth * 0.045,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.01),
                          Text(
                            'Save orders to access them later',
                            style: TextStyle(
                              fontSize: screenWidth * 0.035,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final orders = snapshot.data!.docs;

                  return ListView.builder(
                    padding: EdgeInsets.all(screenWidth * 0.04),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final orderDoc = orders[index];
                      final orderData = orderDoc.data() as Map<String, dynamic>;
                      final orderId = orderDoc.id;

                      final customerName = orderData['customerName'] ?? 'Unknown';
                      final customerPhone = orderData['customerPhone'] ?? '';
                      final total = orderData['total'] ?? 0.0;
                      final itemCount = (orderData['items'] as List?)?.length ?? 0;
                      final timestamp = orderData['timestamp'] as Timestamp?;

                      return Card(
                        margin: EdgeInsets.only(bottom: screenHeight * 0.015),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () => _loadSavedOrder(orderData),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: EdgeInsets.all(screenWidth * 0.04),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            customerName,
                                            style: TextStyle(
                                              fontSize: screenWidth * 0.045,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          if (customerPhone.isNotEmpty)
                                            Text(
                                              customerPhone,
                                              style: TextStyle(
                                                fontSize: screenWidth * 0.035,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Delete Order'),
                                            content: const Text('Are you sure you want to delete this saved order?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  _deleteSavedOrder(orderId);
                                                },
                                                child: const Text(
                                                  'Delete',
                                                  style: TextStyle(color: Color(0xFFFF5252)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.delete_outline, color: Color(0xFFFF5252)),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                                SizedBox(height: screenHeight * 0.01),
                                Row(
                                  children: [
                                    Icon(Icons.shopping_cart, size: screenWidth * 0.04, color: Colors.grey[600]),
                                    SizedBox(width: screenWidth * 0.02),
                                    Text(
                                      '$itemCount items',
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.035,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '₹${total.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.045,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF2196F3),
                                      ),
                                    ),
                                  ],
                                ),
                                if (timestamp != null) ...[
                                  SizedBox(height: screenHeight * 0.005),
                                  Text(
                                    _formatTimestamp(timestamp),
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.03,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ],
                            ),
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF2196F3),
          unselectedItemColor: Colors.grey[400],
          currentIndex: 2,
          selectedFontSize: screenWidth * 0.03,
          unselectedFontSize: screenWidth * 0.03,
          elevation: 0,
          iconSize: screenWidth * 0.06,
          onTap: (index) {
            switch (index) {
              case 0:
                break;
              case 1:
                break;
              case 2:
                break;
              case 3:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductsPage(uid: _uid, userEmail: _userEmail),
                  ),
                );
                break;
              case 4:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CategoryPage(uid: _uid, userEmail: _userEmail),
                  ),
                );
                break;
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.menu),
              label: 'Menu',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: 'Reports',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag),
              label: 'New Sale',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              label: 'Stock',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String text, int index, double screenWidth, double tabHeight) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => SaleAllPage(uid: _uid, userEmail: _userEmail),
              ),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => QuickSalePage(uid: _uid, userEmail: _userEmail),
              ),
            );
          }
        },
        child: Container(
          height: tabHeight,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2196F3) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontSize: screenWidth * 0.035,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}

