import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:maxbillup/Stocks/AddProduct.dart';
import 'package:maxbillup/utils/firestore_service.dart';

class SaleAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String uid;
  final String? userEmail;
  final int currentTab;
  final ValueChanged<int>? onTabChanged;
  final VoidCallback? onAddProduct;
  final TextEditingController? searchController;

  const SaleAppBar({
    Key? key,
    required this.uid,
    this.userEmail,
    this.currentTab = 0,
    this.onTabChanged,
    this.onAddProduct,
    this.searchController,
  }) : super(key: key);

  @override
  State<SaleAppBar> createState() => _SaleAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(160);
}

class _SaleAppBarState extends State<SaleAppBar> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = widget.searchController ?? TextEditingController();
  }

  Widget _buildTab(String title, int index) {
    final selected = widget.currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => widget.onTabChanged?.call(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE8F3FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? const Color(0xFF2196F3) : Colors.black,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color) {
    return Container(
      height: 40,
      width: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.uid;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        children: [
          // Tabs
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
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
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Search',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.grey[400],
                          size: 24,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildActionButton(Icons.swap_vert, const Color(0xFF2196F3)),
                const SizedBox(width: 8),
                _buildActionButton(Icons.tune, const Color(0xFF2196F3)),
                const SizedBox(width: 8),
                _buildActionButton(Icons.more_vert, const Color(0xFF2196F3)),
              ],
            ),
          ),

          // Add Product button
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: widget.onAddProduct ?? () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => AddProductPage(uid: uid, userEmail: widget.userEmail),
                    ),
                  );
                },
                icon: const Icon(Icons.add, color: Color(0xFF4CAF50), size: 20),
                label: const Text(
                  'Add Product',
                  style: TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

