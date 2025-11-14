  import 'package:flutter/material.dart';
  import 'package:maxbillup/Sales/saleall.dart';
  import 'package:maxbillup/Stocks/Category.dart';
  import 'package:maxbillup/Stocks/AddProduct.dart';
  import 'package:cloud_firestore/cloud_firestore.dart';

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
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'Stock',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Tabs at the top
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 2.5),
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
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(0, 0, 16, 2.5),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ),
              // Product list
              Expanded(
                child: Container(
                  color: const Color(0xFFF5F5F5),
                  child: _buildProductList(),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      );
    }

    Widget _buildTab(String text, int index) {
      final isSelected = _selectedTabIndex == index;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            if (index == 1) {
              // Navigate to Category page
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

    Widget _buildProductList() {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_uid)
            .collection('Products')
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

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final productData = products[index].data() as Map<String, dynamic>;

              final itemName = productData['itemName'] ?? 'Unnamed Product';
              final price = productData['price'];
              final category = productData['category'] ?? 'UnCategorised';
              final barcode = productData['barcode'];
              final stockEnabled = productData['stockEnabled'] ?? false;
              final currentStock = productData['currentStock'] ?? 0.0;
              final taxes = productData['taxes'] as List<dynamic>?;
              final taxRate = taxes != null && taxes.isNotEmpty ? taxes.first : 0.0;

              // Determine if stock is low (less than 10)
              final isLowStock = stockEnabled && currentStock < 10;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            itemName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2196F3),
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              price != null ? 'Rs ${price.toStringAsFixed(1)}' : 'Price on sale',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              'Tax $taxRate%',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      barcode != null && barcode.isNotEmpty
                          ? 'Barcode: $barcode'
                          : 'No barcode added',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (stockEnabled) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Current Stock : ${currentStock.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF2196F3),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isLowStock)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9800),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Low Stock',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      );
    }

    Widget _buildBottomNavigationBar() {
      return Container(
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
          currentIndex: 3,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          onTap: (index) {
            switch (index) {
              case 0:
                // Menu
                break;
              case 1:
                // Reports
                break;
              case 2:
                // New Sale
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SaleAllPage(uid: _uid, userEmail: _userEmail),
                  ),
                );
                break;
              case 3:
                // Stock - already on this page
                break;
              case 4:
                // Settings
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
              icon: Icon(Icons.inventory_2),
              label: 'Stock',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      );
    }
  }
