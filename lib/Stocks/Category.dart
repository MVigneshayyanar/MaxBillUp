import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:maxbillup/Stocks/Products.dart' hide AddProductPage;
import 'package:maxbillup/Stocks/AddProduct.dart';
import 'package:maxbillup/Stocks/AddCategoryPopup.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/utils/permission_helper.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';

// UI Color Palette
const Color _primaryColor = Color(0xFF2196F3);
const Color _navyColor = Color(0xFF0F172A);
const Color _secondaryColor = Color(0xFF64748B);
const Color _backgroundColor = Colors.white;
const Color _cardBorder = Color(0xFFE3F2FD);
const Color _successColor = Color(0xFF4CAF50);
const Color _errorColor = Color(0xFFFF5252);

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

  Map<String, dynamic> _permissions = {};
  String _role = 'staff';
  CollectionReference? _productsRef;

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
      debugPrint("Error initializing product collection: $e");
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

  bool _hasPermission(String permission) => _permissions[permission] == true;
  bool get isAdmin => _role.toLowerCase().contains('admin');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      floatingActionButton: (_hasPermission('addCategory') || isAdmin)
          ? FloatingActionButton.extended(
        onPressed: () => _showAddCategoryDialog(context),
        backgroundColor: _successColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          context.tr('add_category'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      )
          : null,
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: _primaryColor.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _cardBorder),
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: context.tr('search_categories'),
            hintStyle: const TextStyle(color: _secondaryColor, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: _primaryColor, size: 22),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryList() {
    if (_productsRef == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<Stream<QuerySnapshot>>(
      future: FirestoreService().getCollectionStream('categories'),
      builder: (context, streamSnapshot) {
        if (!streamSnapshot.hasData) return const Center(child: CircularProgressIndicator());

        return StreamBuilder<QuerySnapshot>(
          stream: streamSnapshot.data,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState();
            }

            final filteredCategories = snapshot.data!.docs.where((doc) {
              final categoryName = (doc.data() as Map<String, dynamic>)['name'] ?? '';
              return categoryName.toString().toLowerCase().contains(_searchQuery);
            }).toList();

            if (filteredCategories.isEmpty && _searchQuery.isNotEmpty) {
              return _buildNoSearchResultsState();
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: filteredCategories.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) => _buildCategoryCard(filteredCategories[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryCard(QueryDocumentSnapshot categoryDoc) {
    final data = categoryDoc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unknown';

    return FutureBuilder<AggregateQuerySnapshot>(
      future: _productsRef!.where('category', isEqualTo: name).count().get(),
      builder: (context, countSnapshot) {
        final count = countSnapshot.hasData ? countSnapshot.data!.count : 0;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _cardBorder),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.all(16),
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => CategoryDetailsPage(
                        uid: _uid,
                        userEmail: _userEmail,
                        categoryName: name,
                      ),
                    ),
                  );
                },
                leading: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(color: _primaryColor, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text('$count ${count == 1 ? "Product" : "Products"}', style: const TextStyle(color: _secondaryColor, fontSize: 13)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20, color: _secondaryColor),
                      onPressed: () => _showEditCategoryDialog(context, categoryDoc.id, name),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: _errorColor),
                      onPressed: () => _showDeleteConfirmation(context, categoryDoc.id, name),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _cardBorder),
              Container(
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.02),
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _showAddExistingProductDialog(context, name),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_box_outlined, size: 16, color: _primaryColor),
                              const SizedBox(width: 8),
                              Text(context.tr('add_existing'), style: const TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(width: 1, height: 20, color: _cardBorder),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.push(context, CupertinoPageRoute(builder: (c) => AddProductPage(uid: _uid, userEmail: _userEmail, preSelectedCategory: name)));
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_circle_outline, size: 16, color: _successColor),
                              const SizedBox(width: 8),
                              Text(context.tr('create_new'), style: const TextStyle(color: _successColor, fontWeight: FontWeight.bold, fontSize: 12)),
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

  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.category_outlined, size: 80, color: _primaryColor.withOpacity(0.1)), const SizedBox(height: 16), Text(context.tr('no_categories_yet'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))]));

  Widget _buildNoSearchResultsState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.search_off, size: 60, color: Colors.grey), const SizedBox(height: 16), Text(context.tr('no_categories_found'), style: const TextStyle(color: Colors.grey))]));

  // --- Dialog Implementation (Logic Unchanged) ---

  void _showAddCategoryDialog(BuildContext context) {
    if (!_hasPermission('addCategory') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }
    showDialog(context: context, builder: (c) => AddCategoryPopup(uid: _uid, userEmail: _userEmail));
  }

  void _showEditCategoryDialog(BuildContext context, String id, String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(context.tr('edit_category'), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            filled: true, fillColor: _primaryColor.withOpacity(0.04),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(context.tr('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                await FirestoreService().updateDocument('categories', id, {'name': ctrl.text.trim()});
                Navigator.pop(c);
              }
            },
            child: Text(context.tr('save')),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(context.tr('delete_category')),
        content: Text('${context.tr('are_you_sure_delete')} "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(context.tr('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _errorColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              await FirestoreService().deleteDocument('categories', id);
              Navigator.pop(c);
            },
            child: Text(context.tr('delete')),
          ),
        ],
      ),
    );
  }

  void _showAddExistingProductDialog(BuildContext context, String categoryName) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.tr('add_existing_product'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Expanded(
                child: FutureBuilder<Stream<QuerySnapshot>>(
                  future: FirestoreService().getCollectionStream('Products'),
                  builder: (context, streamSnapshot) {
                    if (!streamSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                    return StreamBuilder<QuerySnapshot>(
                      stream: streamSnapshot.data,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No products available"));
                        final products = snapshot.data!.docs.where((doc) => (doc.data() as Map)['category'] != categoryName).toList();
                        return ListView.separated(
                          itemCount: products.length,
                          separatorBuilder: (c, i) => const Divider(),
                          itemBuilder: (c, i) {
                            final data = products[i].data() as Map<String, dynamic>;
                            return ListTile(
                              title: Text(data['itemName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('Current: ${data['category'] ?? 'Uncategorized'}', style: const TextStyle(fontSize: 11)),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, elevation: 0),
                                onPressed: () async {
                                  await FirestoreService().updateDocument('Products', products[i].id, {'category': categoryName});
                                  Navigator.pop(context);
                                },
                                child: Text(context.tr('add')),
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
}

// ==========================================
// Category Details Page (List Style)
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

  @override
  void initState() {
    super.initState();
    _initProductCollection();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  Future<void> _initProductCollection() async {
    final ref = await FirestoreService().getStoreCollection('Products');
    if (mounted) setState(() => _productsRef = ref);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(widget.categoryName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _primaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOptions(context),
        backgroundColor: _successColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Item", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildSearchHeader(),
          Expanded(child: _buildProductList()),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Container(
        height: 48,
        decoration: BoxDecoration(color: _primaryColor.withOpacity(0.04), borderRadius: BorderRadius.circular(12), border: Border.all(color: _cardBorder)),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search in ${widget.categoryName}',
            prefixIcon: const Icon(Icons.search, color: _primaryColor),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildProductList() {
    if (_productsRef == null) return const Center(child: CircularProgressIndicator());
    return StreamBuilder<QuerySnapshot>(
      stream: _productsRef!.where('category', isEqualTo: widget.categoryName).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final products = snapshot.data!.docs.where((doc) => (doc.data() as Map)['itemName'].toString().toLowerCase().contains(_searchQuery)).toList();
        if (products.isEmpty) return const Center(child: Text("No products found", style: TextStyle(color: Colors.grey)));

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: products.length,
          separatorBuilder: (c, i) => const SizedBox(height: 12),
          itemBuilder: (c, i) => _buildProductRow(products[i]),
        );
      },
    );
  }

  Widget _buildProductRow(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['itemName'] ?? 'Unknown';
    final price = (data['price'] ?? 0.0).toDouble();
    final stock = (data['currentStock'] ?? 0.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _cardBorder), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)]),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _primaryColor.withOpacity(0.05), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.inventory_2_outlined, color: _primaryColor, size: 24)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text("Rs ${price.toStringAsFixed(2)}", style: const TextStyle(color: _secondaryColor, fontSize: 13, fontWeight: FontWeight.w600)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: (stock > 0 ? _successColor : _errorColor).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text("${stock.toStringAsFixed(0)} Stock", style: TextStyle(color: stock > 0 ? _successColor : _errorColor, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFE3F2FD), child: Icon(Icons.add_box_outlined, color: _primaryColor)),
            title: const Text("Add Existing Product", style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () { Navigator.pop(c); _showAddExistingProductDialog(context); },
          ),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.add_circle_outline, color: _successColor)),
            title: const Text("Create New Product", style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () { Navigator.pop(c); Navigator.push(context, CupertinoPageRoute(builder: (c) => AddProductPage(uid: widget.uid, userEmail: widget.userEmail, preSelectedCategory: widget.categoryName))); },
          ),
        ]),
      ),
    );
  }

  void _showAddExistingProductDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add Product', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Expanded(
                child: FutureBuilder<Stream<QuerySnapshot>>(
                  future: FirestoreService().getCollectionStream('Products'),
                  builder: (context, streamSnapshot) {
                    if (!streamSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                    return StreamBuilder<QuerySnapshot>(
                      stream: streamSnapshot.data,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: Text("No products found"));
                        final products = snapshot.data!.docs.where((doc) => (doc.data() as Map)['category'] != widget.categoryName).toList();
                        return ListView.separated(
                          itemCount: products.length,
                          separatorBuilder: (c, i) => const Divider(),
                          itemBuilder: (c, i) {
                            final data = products[i].data() as Map<String, dynamic>;
                            return ListTile(
                              title: Text(data['itemName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600)),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, elevation: 0),
                                onPressed: () async {
                                  await FirestoreService().updateDocument('Products', products[i].id, {'category': widget.categoryName});
                                  Navigator.pop(context);
                                },
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
}