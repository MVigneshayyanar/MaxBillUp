import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maxbillup/Stocks/Category.dart';
import 'package:maxbillup/Stocks/AddProduct.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/components/common_bottom_nav.dart';

class ProductsPage extends StatefulWidget {
  final String uid;
  final String? userEmail;

  const ProductsPage({
    super.key,
    required this.uid,
    this.userEmail,
  });

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedTabIndex = 0;

  late String _uid;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _uid = widget.uid;
    _userEmail = widget.userEmail;
    print('ProductsPage initialized with UID: $_uid');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Stock',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
            letterSpacing: 0.5,
          ),
        ),
        automaticallyImplyLeading: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: Column(
        children: [
          // Fixed header section
          Container(
            color: Colors.white,
            child: Column(
              children: [
                // Tabs
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(_uid)
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
                            .doc(_uid)
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
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddProductPage(uid: _uid, userEmail: _userEmail),
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
          ),

          // Product grid
          Expanded(
            child: Container(
              color: const Color(0xFFF5F5F5),
              child: _buildProductGrid(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CommonBottomNav(
        uid: _uid,
        userEmail: _userEmail,
        currentIndex: 3,
        screenWidth: MediaQuery.of(context).size.width,
      ),
    );
  }

  Widget _buildTab(String text, int index) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => CategoryPage(uid: _uid, userEmail: _userEmail),
              ),
            );
          } else {
            setState(() {
              _selectedTabIndex = index;
            });
          }
        },
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

  Widget _buildActionButton(IconData icon, Color color) {
    return Container(
      height: 48,
      width: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildProductGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('Products')
          .orderBy('createdAt', descending: false)
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
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 80,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'No products yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add your first product to get started',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          );
        }

        final products = snapshot.data!.docs;

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.15,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final productData = products[index].data() as Map<String, dynamic>;

            final itemName = productData['itemName'] ?? 'Unnamed Product';
            final price = productData['price'];
            final stockEnabled = productData['stockEnabled'] ?? false;
            final currentStock = productData['currentStock'] ?? 0.0;

            // Determine if stock is low (less than 10) or out of stock
            final isOutOfStock = stockEnabled && currentStock <= 0;
            final isLowStock = stockEnabled && currentStock > 0 && currentStock < 10;

            return GestureDetector(
              onTap: () {
                _showUpdateQuantityDialog(
                  context,
                  products[index].id,
                  itemName,
                  currentStock,
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isOutOfStock ? const Color(0xFFFFF3F3) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isOutOfStock
                        ? const Color(0xFFFF5252).withOpacity(0.3)
                        : Colors.grey[200]!,
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Product name
                        Text(
                          itemName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        // Price
                        Text(
                          price != null ? '${price.toStringAsFixed(0)}' : 'Price on sale',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),

                        // Stock info
                        if (stockEnabled)
                          Text(
                            isOutOfStock
                                ? '-${currentStock.abs().toStringAsFixed(0)} box'
                                : '${currentStock.toStringAsFixed(0)} box',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isOutOfStock
                                  ? const Color(0xFFFF5252)
                                  : isLowStock
                                  ? const Color(0xFFFF9800)
                                  : const Color(0xFF4CAF50),
                            ),
                          ),
                      ],
                    ),

                    // Out of Stock badge
                    if (isOutOfStock)
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Transform.rotate(
                            angle: -1.5708, // -90 degrees in radians
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5252),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Out Of Stock',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
  }

  void _showUpdateQuantityDialog(
      BuildContext context,
      String productId,
      String productName,
      double currentStock,
      ) {
    final TextEditingController quantityController = TextEditingController();
    bool isAdding = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Update Stock - $productName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Current Stock: ${currentStock.toStringAsFixed(1)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2196F3),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          isAdding = true;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAdding ? const Color(0xFF4CAF50) : Colors.grey[300],
                        foregroundColor: isAdding ? Colors.white : Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Add'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          isAdding = false;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: !isAdding ? const Color(0xFFFF5252) : Colors.grey[300],
                        foregroundColor: !isAdding ? Colors.white : Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Remove'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isAdding ? 'Quantity to Add' : 'Quantity to Remove',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  prefixIcon: Icon(
                    isAdding ? Icons.add : Icons.remove,
                    color: isAdding ? const Color(0xFF4CAF50) : const Color(0xFFFF5252),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () async {
                final quantity = double.tryParse(quantityController.text.trim());
                if (quantity == null || quantity <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please enter a valid quantity'),
                      backgroundColor: Colors.red[400],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                  return;
                }

                try {
                  final newStock = isAdding
                      ? currentStock + quantity
                      : currentStock - quantity;

                  if (newStock < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Stock cannot be negative'),
                        backgroundColor: Colors.red[400],
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    );
                    return;
                  }

                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(_uid)
                      .collection('Products')
                      .doc(productId)
                      .update({'currentStock': newStock});

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Stock updated to ${newStock.toStringAsFixed(1)}'),
                      backgroundColor: Colors.green[600],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red[400],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Update', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}