import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:maxbillup/Stocks/Products.dart';
import 'package:maxbillup/Stocks/AddProduct.dart';
import 'package:maxbillup/Stocks/AddCategoryPopup.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/utils/permission_helper.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';

class CategoryPage extends StatefulWidget {
  final String uid;
  final String? userEmail;

  const CategoryPage({
    super.key,
    required this.uid,
    this.userEmail,
  });

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late String _uid;
  String? _userEmail;

  // Permission state
  Map<String, dynamic> _permissions = {};
  String _role = 'staff';

  // OPTIMIZATION: Store the reference here to avoid fetching it 50 times in the loop
  CollectionReference? _productsRef;

  // Theme Colors
  final Color _primaryColor = const Color(0xFF2196F3);
  final Color _backgroundColor = Colors.white;
  final Color _successColor = const Color(0xFF4CAF50);
  final Color _errorColor = const Color(0xFFFF5252);

  @override
  void initState() {
    super.initState();
    _uid = widget.uid;
    _userEmail = widget.userEmail;

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    _loadPermissions();
    _initProductCollection();
  }

  Future<void> _initProductCollection() async {
    try {
      final ref = await FirestoreService().getStoreCollection('Products');
      if (mounted) {
        setState(() {
          _productsRef = ref;
        });
      }
    } catch (e) {
      print("Error initializing product collection: $e");
    }
  }

  Future<void> _loadPermissions() async {
    final userData = await PermissionHelper.getUserPermissions(_uid);
    if (mounted) {
      setState(() {
        _permissions = userData['permissions'] as Map<String, dynamic>;
        _role = userData['role'] as String;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _buildCategoryList(),
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
                decoration: InputDecoration(
                  hintText: context.tr('search_categories'),
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
          if (_hasPermission('addCategory') || isAdmin) ...[
            const SizedBox(width: 12),
            SizedBox(
              height: 48,
              width: 48,
              child: ElevatedButton(
                onPressed: () => _showAddCategoryDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _successColor,
                  padding: EdgeInsets.zero,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 26),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    if (_productsRef == null) {
      return Center(child: CircularProgressIndicator(color: _primaryColor));
    }

    return FutureBuilder<Stream<QuerySnapshot>>(
      future: FirestoreService().getCollectionStream('categories'),
      builder: (context, streamSnapshot) {
        if (!streamSnapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: _primaryColor));
        }

        return StreamBuilder<QuerySnapshot>(
          stream: streamSnapshot.data,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: _primaryColor));
            }

            if (snapshot.hasError) {
              return Center(
                  child: Text('Error: ${snapshot.error}', style: TextStyle(color: _errorColor)));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState();
            }

            final categories = snapshot.data!.docs;
            final filteredCategories = categories.where((doc) {
              final categoryData = doc.data() as Map<String, dynamic>;
              final categoryName = (categoryData['name'] ?? '').toString().toLowerCase();
              return categoryName.contains(_searchQuery);
            }).toList();

            if (filteredCategories.isEmpty && _searchQuery.isNotEmpty) {
              return _buildNoSearchResultsState();
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filteredCategories.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _buildCategoryCard(filteredCategories[index]);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryCard(QueryDocumentSnapshot categoryDoc) {
    final categoryData = categoryDoc.data() as Map<String, dynamic>;
    final categoryName = categoryData['name'] ?? 'Unknown';
    final categoryId = categoryDoc.id;

    return FutureBuilder<AggregateQuerySnapshot>(
      future: _productsRef!.where('category', isEqualTo: categoryName).count().get(),
      builder: (context, countSnapshot) {
        final productCount = countSnapshot.hasData ? countSnapshot.data!.count : 0;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top Section: Clickable Info
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => CategoryDetailsPage(
                          uid: _uid,
                          userEmail: _userEmail,
                          categoryName: categoryName,
                        ),
                      ),
                    );
                  },
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Icon Placeholder
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              categoryName.isNotEmpty ? categoryName[0].toUpperCase() : '?',
                              style: TextStyle(
                                color: _primaryColor,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                categoryName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$productCount ${productCount == 1 ? "Product" : "Products"}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Actions (Edit/Delete)
                        _buildTopActions(categoryId, categoryName),
                      ],
                    ),
                  ),
                ),
              ),

              // Divider
              Divider(height: 1, color: Colors.grey.shade200),

              // Bottom Section: Add Products
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.02),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _showAddExistingProductDialog(context, categoryName),
                        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_box_outlined, size: 18, color: _primaryColor),
                              const SizedBox(width: 8),
                              Text(
                                context.tr('add_existing'),
                                style: TextStyle(
                                  color: _primaryColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(width: 1, height: 20, color: Colors.grey.shade300),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => AddProductPage(
                                uid: _uid,
                                userEmail: _userEmail,
                                preSelectedCategory: categoryName,
                              ),
                            ),
                          );
                        },
                        borderRadius: const BorderRadius.only(bottomRight: Radius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_circle_outline, size: 18, color: _successColor),
                              const SizedBox(width: 8),
                              Text(
                                context.tr('create_new'),
                                style: TextStyle(
                                  color: _successColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopActions(String categoryId, String categoryName) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => _showEditCategoryDialog(context, categoryId, categoryName),
          child: Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.transparent, // Hit test target
            child: Icon(Icons.edit_outlined, color: Colors.grey[500], size: 20),
          ),
        ),
        GestureDetector(
          onTap: () => _showDeleteConfirmation(context, categoryId, categoryName),
          child: Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.transparent,
            child: Icon(Icons.delete_outline, color: _errorColor.withOpacity(0.8), size: 20),
          ),
        ),
        const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      ],
    );
  }

  Widget _buildEmptyState() {
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
            child: Icon(Icons.category_outlined, size: 60, color: Colors.grey.shade300),
          ),
          const SizedBox(height: 24),
          Text(
            context.tr('no_categories_yet'),
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[800],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('add_first_category'),
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSearchResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            context.tr('no_categories_found'),
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // --- Dialog Methods ---

  void _showAddExistingProductDialog(BuildContext context, String categoryName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('add_existing_product'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(Icons.close, color: Colors.grey[400]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: FutureBuilder<Stream<QuerySnapshot>>(
                  future: FirestoreService().getCollectionStream('Products'),
                  builder: (context, streamSnapshot) {
                    if (!streamSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return StreamBuilder<QuerySnapshot>(
                      stream: streamSnapshot.data,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(child: Text(context.tr('no_products_available')));
                        }
                        final products = snapshot.data!.docs;
                        return ListView.separated(
                          shrinkWrap: true,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final productDoc = products[index];
                            final productData = productDoc.data() as Map<String, dynamic>;
                            final productName = productData['itemName'] ?? 'Unknown';
                            final currentCategory = productData['category'] ?? 'UnCategorised';
                            final productId = productDoc.id;

                            if (currentCategory == categoryName) {
                              return const SizedBox.shrink();
                            }

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 4),
                              title: Text(productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                '${context.tr('current')}: $currentCategory',
                                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                              ),
                              trailing: ElevatedButton(
                                onPressed: () async {
                                  try {
                                    await FirestoreService().updateDocument(
                                      'Products',
                                      productId,
                                      {'category': categoryName},
                                    );
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('$productName ${context.tr('added_to')} $categoryName'),
                                        backgroundColor: _successColor,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('${context.tr('error')}: $e')),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryColor,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                child: Text(context.tr('add'), style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    if (!_hasPermission('addCategory') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AddCategoryPopup(
        uid: _uid,
        userEmail: _userEmail,
      ),
    );
  }

  void _showEditCategoryDialog(BuildContext context, String categoryId, String currentName) {
    final TextEditingController controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(context.tr('edit_category'), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: context.tr('category_name'),
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('cancel'), style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                try {
                  await FirestoreService().updateDocument('categories', categoryId, {'name': newName});
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${context.tr('error')}: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(context.tr('save')),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String categoryId, String categoryName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(context.tr('delete_category'), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text('${context.tr('are_you_sure_delete')} "$categoryName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('cancel'), style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirestoreService().deleteDocument('categories', categoryId);
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _errorColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(context.tr('delete')),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// Category Details Page
// ==========================================

class CategoryDetailsPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final String categoryName;

  const CategoryDetailsPage({
    super.key,
    required this.uid,
    this.userEmail,
    required this.categoryName,
  });

  @override
  State<CategoryDetailsPage> createState() => _CategoryDetailsPageState();
}

class _CategoryDetailsPageState extends State<CategoryDetailsPage> {
  CollectionReference? _productsRef;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Color _primaryColor = const Color(0xFF2196F3);
  final Color _errorColor = const Color(0xFFFF5252);

  @override
  void initState() {
    super.initState();
    _initProductCollection();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  Future<void> _initProductCollection() async {
    final ref = await FirestoreService().getStoreCollection('Products');
    if (mounted) {
      setState(() {
        _productsRef = ref;
      });
    }
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
        title: Text(
          widget.categoryName,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search in ${widget.categoryName}',
                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 22),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey[500], size: 20),
                    onPressed: () => _searchController.clear(),
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOptions(context),
        backgroundColor: _primaryColor,
        child: const Icon(Icons.add),
      ),
      body: _productsRef == null
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : StreamBuilder<QuerySnapshot>(
        stream: _productsRef!
            .where('category', isEqualTo: widget.categoryName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _primaryColor));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No products in this category',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showAddOptions(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Products'),
                  )
                ],
              ),
            );
          }

          final products = snapshot.data!.docs;
          final filteredProducts = products.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name =
            (data['itemName'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery);
          }).toList();

          if (filteredProducts.isEmpty) {
            return Center(
              child: Text("No products found matching '$_searchQuery'",
                  style: TextStyle(color: Colors.grey[600])),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filteredProducts.length,
            separatorBuilder: (context, index) =>
            const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildProductCard(filteredProducts[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildProductCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['itemName'] ?? 'Unknown';
    final price = data['price'];
    final stock = data['stock'] ?? 0;

    // You can add logic here to parse image URL if your data has it
    // final imageUrl = data['imageUrl'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Icon(Icons.shopping_bag_outlined, color: _primaryColor, size: 28),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  price != null ? 'Rs ${price.toString()}' : 'Price on Sale',
                  style: TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 1,
                  height: 12,
                  color: Colors.grey[300],
                ),
                const SizedBox(width: 8),
                Text(
                  'Stock: $stock',
                  style: TextStyle(
                    color: stock > 0 ? Colors.green[600] : Colors.red[400],
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Theme(
          data: Theme.of(context).copyWith(
            useMaterial3: true,
            popupMenuTheme: PopupMenuThemeData(
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
          ),
          child: PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.more_vert_rounded, color: Colors.grey[600], size: 20),
            ),
            splashRadius: 24,
            tooltip: 'Actions',
            offset: const Offset(0, 40),
            onSelected: (value) => _handleMenuAction(value, doc),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                height: 48,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.edit_outlined, color: _primaryColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Edit Details',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'remove_category',
                height: 48,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.folder_off_outlined, color: Colors.orange, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Remove from Category',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: 'delete',
                height: 48,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.delete_outline, color: _errorColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Delete Product',
                      style: TextStyle(
                        color: _errorColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_box_outlined, color: Colors.blue),
                ),
                title: const Text('Add Existing Product', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Select from unassigned products'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddExistingProductDialog(context);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_circle_outline, color: Colors.green),
                ),
                title: const Text('Create New Product', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Create a brand new item'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => AddProductPage(
                        uid: widget.uid,
                        userEmail: widget.userEmail,
                        preSelectedCategory: widget.categoryName,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddExistingProductDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Add Product', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(Icons.close, color: Colors.grey[400]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: FutureBuilder<Stream<QuerySnapshot>>(
                  future: FirestoreService().getCollectionStream('Products'),
                  builder: (context, streamSnapshot) {
                    if (!streamSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                    return StreamBuilder<QuerySnapshot>(
                      stream: streamSnapshot.data,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: Text("No products found"));

                        final products = snapshot.data!.docs;
                        return ListView.separated(
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final doc = products[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final name = data['itemName'] ?? 'Unknown';
                            final currentCat = data['category'] ?? 'UnCategorised';

                            if (currentCat == widget.categoryName) return const SizedBox.shrink();

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 4),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('Current: $currentCat', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              trailing: ElevatedButton(
                                onPressed: () async {
                                  await FirestoreService().updateDocument('Products', doc.id, {'category': widget.categoryName});
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product added')));
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryColor,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                child: const Text('Add'),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMenuAction(String value, QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['itemName'] ?? 'Unknown';

    if (value == 'edit') {
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => AddProductPage(
            uid: widget.uid,
            userEmail: widget.userEmail,
            preSelectedCategory: widget.categoryName,
          ),
        ),
      );
    } else if (value == 'remove_category') {
      await FirestoreService().updateDocument('Products', doc.id, {'category': 'UnCategorised'});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name removed from ${widget.categoryName}')));
    } else if (value == 'delete') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Product', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete "$name"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                await FirestoreService().deleteDocument('Products', doc.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product deleted')));
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
    }
  }
}