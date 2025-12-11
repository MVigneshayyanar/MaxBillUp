import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/utils/firestore_service.dart';

class StockAppBar extends StatelessWidget {
  final String uid;
  final String? userEmail;
  final TextEditingController searchController;
  final int selectedTabIndex;
  final Function(int) onTabChanged;
  final VoidCallback onAddProduct;
  final double screenWidth;
  final double screenHeight;
  final Widget Function(IconData, Color) buildActionButton;

  const StockAppBar({
    super.key,
    required this.uid,
    this.userEmail,
    required this.searchController,
    required this.selectedTabIndex,
    required this.onTabChanged,
    required this.onAddProduct,
    required this.screenWidth,
    required this.screenHeight,
    required this.buildActionButton,

  });

  @override
  Widget build(BuildContext context) {
    final tabPadding = screenWidth * 0.04;
    final tabHeight = screenHeight * 0.04;
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Tabs

          Container(
            padding: const EdgeInsets.fromLTRB(16, 55, 16, 12),
            child: Row(
              children: [
                // Menu Button (Drawer)
                GestureDetector(
                  onTap: () {
                    Scaffold.of(context).openDrawer();
                  },
                  child: Container(
                    width: screenWidth * 0.12,
                    height: tabHeight+17.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.menu,
                      color: const Color(0xFF2196F3),
                      size: screenWidth * 0.06,
                    ),
                  ),
                ),
                SizedBox(width: screenWidth * 0.02),
                // Product Tab
                FutureBuilder<Stream<QuerySnapshot>>(
                  future: FirestoreService().getCollectionStream('Products'),
                  builder: (context, streamSnapshot) {
                    if (!streamSnapshot.hasData) {
                      return _buildTab('Products (0)', 0);
                    }
                    return StreamBuilder<QuerySnapshot>(
                      stream: streamSnapshot.data,
                      builder: (context, snapshot) {
                        final productCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                        return _buildTab('Products ($productCount)', 0);
                      },
                    );
                  },
                ),
                const SizedBox(width: 8),
                // Category Tab
                FutureBuilder<Stream<QuerySnapshot>>(
                  future: FirestoreService().getCollectionStream('categories'),
                  builder: (context, streamSnapshot) {
                    if (!streamSnapshot.hasData) {
                      return _buildTab('Category (0)', 1);
                    }
                    return StreamBuilder<QuerySnapshot>(
                      stream: streamSnapshot.data,
                      builder: (context, snapshot) {
                        final categoryCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                        return _buildTab('Category ($categoryCount)', 1);
                      },
                    );
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
          padding: const EdgeInsets.symmetric(vertical: 16),
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
