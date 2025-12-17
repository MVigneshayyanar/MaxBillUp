import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/Stocks/AddProduct.dart';
import 'package:maxbillup/utils/permission_helper.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';

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

  // Theme Colors
  final Color _primaryColor = const Color(0xFF2196F3);
  final Color _successColor = const Color(0xFF4CAF50);
  final Color _errorColor = const Color(0xFFFF5252);
  final Color _warningColor = const Color(0xFFFF9800);

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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('sort'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.sort_by_alpha, color: Colors.blue),
              ),
              title: Text(context.tr('name'), style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: _sortBy == 'name' ? const Icon(Icons.check_circle, color: Color(0xFF2196F3)) : null,
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
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.attach_money, color: Colors.green),
              ),
              title: Text(context.tr('price'), style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: _sortBy == 'price' ? const Icon(Icons.check_circle, color: Color(0xFF2196F3)) : null,
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
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.inventory, color: Colors.orange),
              ),
              title: Text(context.tr('stock'), style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: _sortBy == 'stock' ? const Icon(Icons.check_circle, color: Color(0xFF2196F3)) : null,
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
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
            ListTile(
              leading: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, color: Colors.grey),
              title: Text(_sortAscending ? 'Ascending' : 'Descending', style: const TextStyle(fontWeight: FontWeight.w600)),
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter By Stock', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildFilterOption(Icons.select_all, context.tr('all_products'), 'all', Colors.blue),
            _buildFilterOption(Icons.check_circle, context.tr('in_stock'), 'inStock', _successColor),
            _buildFilterOption(Icons.warning, context.tr('low_stock_filter'), 'lowStock', _warningColor),
            _buildFilterOption(Icons.cancel, context.tr('out_of_stock'), 'outOfStock', _errorColor),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(IconData icon, String title, String value, Color color) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: _filterStock == value ? const Icon(Icons.check_circle, color: Color(0xFF2196F3)) : null,
      onTap: () {
        setState(() {
          _filterStock = value;
        });
        Navigator.pop(context);
      },
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
          _buildHeader(),
          Expanded(
            child: _buildProductGrid(w),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: context.tr('search'),
                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 22),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey[500], size: 20),
                    onPressed: () => _searchController.clear(),
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildActionButton(Icons.swap_vert, _primaryColor, _showSortMenu),
          const SizedBox(width: 8),
          _buildActionButton(Icons.tune, _primaryColor, _showFilterMenu),
          if (_hasPermission('addProduct') || isAdmin) ...[
            const SizedBox(width: 8),
            _buildActionButton(
              Icons.add,
              Colors.white,
                  () async {
                if (!_hasPermission('addProduct') && !isAdmin) {
                  await PermissionHelper.showPermissionDeniedDialog(context);
                  return;
                }
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => AddProductPage(uid: _uid, userEmail: widget.userEmail),
                  ),
                );
              },
              backgroundColor: _successColor,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color iconColor, VoidCallback? onTap, {Color backgroundColor = const Color(0xFFF5F5F5)}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: backgroundColor == const Color(0xFFF5F5F5) ? Border.all(color: Colors.grey.shade200) : null,
          boxShadow: backgroundColor != const Color(0xFFF5F5F5) ? [
            BoxShadow(color: backgroundColor.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
          ] : null,
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }

  Widget _buildProductGrid(double w) {
    if (_productsStream == null) {
      return Center(child: CircularProgressIndicator(color: _primaryColor));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _productsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _primaryColor));
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
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey.shade300),
                ),
                const SizedBox(height: 16),
                Text('No products yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[800], fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Add your first product to get started',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500])),
              ],
            ),
          );
        }

        final products = _filterAndSortProducts(snapshot.data!.docs);

        if (products.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('No products found',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: w > 600 ? 5 : 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.9, // Adjust ratio for compact text cards
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final productDoc = products[index];
            final productData = productDoc.data() as Map<String, dynamic>;

            final itemName = productData['itemName'] ?? 'Unnamed Product';
            final price = productData['price'];
            final stockEnabled = productData['stockEnabled'] ?? false;
            final currentStock = productData['currentStock'] ?? 0.0;

            final isOutOfStock = stockEnabled && currentStock <= 0;
            final isLowStock = stockEnabled && currentStock > 0 && currentStock < 10;

            return GestureDetector(
              onTap: () {
                _showProductActionMenu(context, productDoc);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            itemName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (stockEnabled)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            margin: const EdgeInsets.only(left: 4),
                            decoration: BoxDecoration(
                              color: isOutOfStock
                                  ? _errorColor.withOpacity(0.1)
                                  : isLowStock
                                  ? _warningColor.withOpacity(0.1)
                                  : _successColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isOutOfStock ? 'Out' : (isLowStock ? 'Low' : 'In'),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isOutOfStock
                                    ? _errorColor
                                    : isLowStock
                                    ? _warningColor
                                    : _successColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          price != null ? 'Rs ${price.toStringAsFixed(0)}' : 'On Sale',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _primaryColor,
                          ),
                        ),
                        if (stockEnabled) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Qty: ${currentStock.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
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

  void _showProductActionMenu(BuildContext context, QueryDocumentSnapshot productDoc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Wrap(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.edit, color: Colors.blue),
                  ),
                  title: const Text('Edit Details'),
                  subtitle: const Text('Change name, price, etc.'),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditDetailsDialog(context, productDoc);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.inventory, color: Colors.orange),
                  ),
                  title: const Text('Update Stock'),
                  subtitle: const Text('Add or remove quantity'),
                  onTap: () {
                    Navigator.pop(context);
                    final data = productDoc.data() as Map<String, dynamic>;
                    _showUpdateQuantityDialog(
                      context,
                      productDoc.id,
                      data['itemName'] ?? 'Product',
                      (data['currentStock'] ?? 0.0).toDouble(),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                  title: const Text('Delete Product', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteConfirmDialog(context, productDoc);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditDetailsDialog(BuildContext context, QueryDocumentSnapshot productDoc) {
    final data = productDoc.data() as Map<String, dynamic>;
    final nameController = TextEditingController(text: data['itemName']);
    final priceController = TextEditingController(text: data['price']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Product Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Price',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final newName = nameController.text.trim();
                final newPrice = double.tryParse(priceController.text.trim());

                if (newName.isNotEmpty) {
                  await FirestoreService().updateDocument('Products', productDoc.id, {
                    'itemName': newName,
                    'price': newPrice,
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Product updated'), backgroundColor: _successColor),
                  );
                }
              } catch (e) {
                print(e);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, QueryDocumentSnapshot productDoc) {
    final data = productDoc.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${data['itemName']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirestoreService().deleteDocument('Products', productDoc.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Product deleted'), backgroundColor: Colors.red),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.inventory_2_outlined, color: _primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Update Stock', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(productName, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Current Stock:', style: TextStyle(fontWeight: FontWeight.w500)),
                      Text(
                        currentStock.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => isAdding = true),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isAdding ? _primaryColor : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isAdding ? _primaryColor : Colors.grey.shade300),
                          ),
                          child: Center(
                            child: Text(
                              context.tr('add'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isAdding ? Colors.white : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => isAdding = false),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !isAdding ? _primaryColor : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: !isAdding ? _primaryColor : Colors.grey.shade300),
                          ),
                          child: Center(
                            child: Text(
                              'Remove',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: !isAdding ? Colors.white : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: quantityController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('cancel'), style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () {
                final quantity = double.tryParse(quantityController.text.trim());
                if (quantity == null || quantity <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: const Text('Invalid quantity'), backgroundColor: _errorColor),
                  );
                  return;
                }

                try {
                  final newStock = isAdding ? currentStock + quantity : currentStock - quantity;
                  FirestoreService().updateDocument('Products', productId, {'currentStock': newStock})
                      .then((_) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Stock updated to $newStock'), backgroundColor: _successColor),
                    );
                  });
                } catch (e) {
                  print(e);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(context.tr('update')),
            ),
          ],
        ),
      ),
    );
  }
}