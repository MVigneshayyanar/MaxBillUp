import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StockAppBar extends StatelessWidget {
  final String uid;
  final String? userEmail;
  final TextEditingController searchController;
  final int selectedTabIndex;
  final Function(int) onTabChanged;
  final VoidCallback onAddProduct;
  final Widget Function(IconData, Color) buildActionButton;

  const StockAppBar({
    super.key,
    required this.uid,
    this.userEmail,
    required this.searchController,
    required this.selectedTabIndex,
    required this.onTabChanged,
    required this.onAddProduct,
    required this.buildActionButton,

  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Tabs

          Container(
            padding: const EdgeInsets.fromLTRB(16, 55, 16, 12),
            child: Row(
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('Products')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final productCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                    return _buildTab('Products ($productCount)', 0);
                  },
                ),
                const SizedBox(width: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('categories')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final categoryCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                    return _buildTab('Category ($categoryCount)', 1);
                  },
                ),
              ],
            ),
          ),

          // Search bar and action buttons

        ],
      ),
    );
  }

  Widget _buildTab(String text, int index) {
    final isSelected = selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTabChanged(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2196F3) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

