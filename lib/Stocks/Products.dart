import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/Stocks/AddProduct.dart';
import 'package:maxbillup/utils/permission_helper.dart';
import 'package:maxbillup/utils/firestore_service.dart';

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
  String _searchQuery = '';
  String _sortBy = 'name'; // 'name', 'price', 'stock'
  bool _sortAscending = true;
  String _filterStock = 'all'; // 'all', 'inStock', 'outOfStock', 'lowStock'

  late String _uid;

  // Permission state
  Map<String, dynamic> _permissions = {};
  String _role = 'staff';
  bool _isLoading = true;

  // OPTIMIZATION: Cache the stream to prevent re-fetching on setState
  Stream<QuerySnapshot>? _productsStream;

  @override
  void initState() {
    super.initState();
    _uid = widget.uid;

    // Search listener
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    // Load data once
    _loadPermissions();
    _initProductsStream();
  }

  // OPTIMIZATION: Unwrap the Future here so the UI builds faster
  Future<void> _initProductsStream() async {
    try {
      final stream = await FirestoreService().getCollectionStream('Products');
      if (mounted) {
        setState(() {
          _productsStream = stream;
        });
      }
    } catch (e) {
      print("Error initializing stream: $e");
    }
  }

  Future<void> _loadPermissions() async {
    final userData = await PermissionHelper.getUserPermissions(_uid);
    if (mounted) {
      setState(() {
        _permissions = userData['permissions'] as Map<String, dynamic>;
        _role = userData['role'] as String;
        _isLoading = false;
      });
    }
  }

  bool _hasPermission(String permission) {
    return _permissions[permission] == true;
  }

  bool get isAdmin =>
      _role.toLowerCase() == 'admin' || _role.toLowerCase() == 'administrator';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ... (Keep existing Sort/Filter Menu methods identical) ...
  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sort By', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.sort_by_alpha),
              title: const Text('Name'),
              trailing: _sortBy == 'name' ? const Icon(Icons.check, color: Color(0xFF2196F3)) : null,
              onTap: () {
                setState(() {
                  if (_sortBy == 'name') {
                    _sortAscending = !_sortAscending;
                  } else {
                    _sortBy = 'name';
                    _sortAscending = true;
                  }
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_money),
              title: const Text('Price'),
              trailing: _sortBy == 'price' ? const Icon(Icons.check, color: Color(0xFF2196F3)) : null,
              onTap: () {
                setState(() {
                  if (_sortBy == 'price') {
                    _sortAscending = !_sortAscending;
                  } else {
                    _sortBy = 'price';
                    _sortAscending = true;
                  }
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('Stock'),
              trailing: _sortBy == 'stock' ? const Icon(Icons.check, color: Color(0xFF2196F3)) : null,
              onTap: () {
                setState(() {
                  if (_sortBy == 'stock') {
                    _sortAscending = !_sortAscending;
                  } else {
                    _sortBy = 'stock';
                    _sortAscending = true;
                  }
                });
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
              title: Text(_sortAscending ? 'Ascending' : 'Descending'),
              onTap: () {
                setState(() {
                  _sortAscending = !_sortAscending;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter By Stock', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.select_all),
              title: const Text('All Products'),
              trailing: _filterStock == 'all' ? const Icon(Icons.check, color: Color(0xFF2196F3)) : null,
              onTap: () {
                setState(() {
                  _filterStock = 'all';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle, color: Color(0xFF4CAF50)),
              title: const Text('In Stock'),
              trailing: _filterStock == 'inStock' ? const Icon(Icons.check, color: Color(0xFF2196F3)) : null,
              onTap: () {
                setState(() {
                  _filterStock = 'inStock';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.warning, color: Color(0xFFFF9800)),
              title: const Text('Low Stock (< 10)'),
              trailing: _filterStock == 'lowStock' ? const Icon(Icons.check, color: Color(0xFF2196F3)) : null,
              onTap: () {
                setState(() {
                  _filterStock = 'lowStock';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel, color: Color(0xFFFF5252)),
              title: const Text('Out of Stock'),
              trailing: _filterStock == 'outOfStock' ? const Icon(Icons.check, color: Color(0xFF2196F3)) : null,
              onTap: () {
                setState(() {
                  _filterStock = 'outOfStock';
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  List<QueryDocumentSnapshot> _filterAndSortProducts(List<QueryDocumentSnapshot> products) {
    // Filter by search query
    var filtered = products.where((doc) {
      if (_searchQuery.isEmpty) return true;
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['itemName'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery);
    }).toList();

    // Filter by stock status
    filtered = filtered.where((doc) {
      if (_filterStock == 'all') return true;
      final data = doc.data() as Map<String, dynamic>;
      final stockEnabled = data['stockEnabled'] ?? false;
      final stock = data['currentStock'] ?? 0.0;

      if (!stockEnabled) return _filterStock == 'all';

      if (_filterStock == 'outOfStock') return stock <= 0;
      if (_filterStock == 'lowStock') return stock > 0 && stock < 10;
      if (_filterStock == 'inStock') return stock >= 10;

      return true;
    }).toList();

    // Sort products
    filtered.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;

      int comparison = 0;

      if (_sortBy == 'name') {
        final nameA = (dataA['itemName'] ?? '').toString().toLowerCase();
        final nameB = (dataB['itemName'] ?? '').toString().toLowerCase();
        comparison = nameA.compareTo(nameB);
      } else if (_sortBy == 'price') {
        final priceA = dataA['price'] ?? 0.0;
        final priceB = dataB['price'] ?? 0.0;
        comparison = priceA.compareTo(priceB);
      } else if (_sortBy == 'stock') {
        final stockA = dataA['currentStock'] ?? 0.0;
        final stockB = dataB['currentStock'] ?? 0.0;
        comparison = stockA.compareTo(stockB);
      }

      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Search bar and action buttons
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
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
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.blue,
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
                _buildActionButton(Icons.swap_vert, const Color(0xFF2196F3), _showSortMenu),
                const SizedBox(width: 8),
                _buildActionButton(Icons.tune, const Color(0xFF2196F3), _showFilterMenu),
                // Add Product button - only visible if user has permission
                if (_hasPermission('addProduct') || isAdmin) ...[
                  const SizedBox(width: 8),
                  _buildActionButton(
                    Icons.add_circle,
                    const Color(0xFF4CAF50),
                        () async {
                      if (!_hasPermission('addProduct') && !isAdmin) {
                        await PermissionHelper.showPermissionDeniedDialog(context);
                        return;
                      }
                      Navigator.pushReplacement(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => AddProductPage(uid: _uid, userEmail: widget.userEmail),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),

          // Product grid
          Expanded(
            child: Container(
              color: const Color(0xFFF5F5F5),
              child: _buildProductGrid(w),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: icon == Icons.add_circle ? 32 : 24),
      ),
    );
  }

  Widget _buildProductGrid(double w) {
    // OPTIMIZATION: Wait for stream init, don't use FutureBuilder here
    if (_productsStream == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2196F3)));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _productsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF2196F3)));
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
                Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('No products yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Text('Add your first product to get started',
                    style: TextStyle(fontSize: 14, color: Colors.grey[400])),
              ],
            ),
          );
        }

        // Filtering happens in memory on the data we received
        final products = _filterAndSortProducts(snapshot.data!.docs);

        if (products.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('No products found',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: EdgeInsets.all(w * 0.04),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: w * 0.03,
            mainAxisSpacing: w * 0.03,
            childAspectRatio: 1.5,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final productData = products[index].data() as Map<String, dynamic>;

            final itemName = productData['itemName'] ?? 'Unnamed Product';
            final price = productData['price'];
            final stockEnabled = productData['stockEnabled'] ?? false;
            final currentStock = productData['currentStock'] ?? 0.0;

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
                        ? const Color(0xFFFF5252).withValues(alpha: 0.3)
                        : Colors.grey[200]!,
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
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
                        Text(
                          price != null ? ' ${price.toStringAsFixed(0)}' : 'Price on sale',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
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
                    if (isOutOfStock)
                      Positioned(
                        right: -12,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Transform.rotate(
                            angle: -1.5708,
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

                  await FirestoreService().updateDocument(
                    'Products',
                    productId,
                    {'currentStock': newStock},
                  );

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