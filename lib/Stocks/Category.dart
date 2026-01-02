import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/Stocks/AddProduct.dart';
import 'package:maxbillup/Stocks/AddCategoryPopup.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/utils/permission_helper.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:intl/intl.dart';

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
  String _sortBy = 'name';
  bool _sortAscending = true;
  String _filterType = 'all'; // all, empty, nonEmpty

  late String _uid;
  String? _userEmail;

  Map<String, dynamic> _permissions = {};
  String _role = 'staff';
  CollectionReference? _productsRef;
  Stream<QuerySnapshot>? _categoryStream;

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
    _initCategoryStream();
    _initProductCollection();
  }

  /// FAST FETCH: Initialize the stream once in initState to hit the
  /// Firestore local cache immediately for a 0ms perceived load.
  Future<void> _initCategoryStream() async {
    try {
      final stream = await FirestoreService().getCollectionStream('categories');
      if (mounted) {
        setState(() {
          _categoryStream = stream;
        });
      }
    } catch (e) {
      debugPrint("Fast Fetch Error: $e");
    }
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

  // ==========================================
  // UI BUILD METHODS (ENTERPRISE FLAT)
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      floatingActionButton: (_hasPermission('addCategory') || isAdmin)
          ? FloatingActionButton.extended(
        onPressed: () => _showAddCategoryDialog(context),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        icon: const Icon(Icons.add_rounded, color: kWhite, size: 20),
        label: Text(
          context.tr('add_category').toUpperCase(),
          style: const TextStyle(color: kWhite, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: kWhite,
        border: Border(bottom: BorderSide(color: kGrey200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kGrey200),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kBlack87),
                decoration: InputDecoration(
                  hintText: context.tr('search_categories'),
                  hintStyle: const TextStyle(color: kBlack54, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: kPrimaryColor, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 7),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildHeaderActionBtn(Icons.sort_rounded, _showSortMenu),
          const SizedBox(width: 8),
          _buildHeaderActionBtn(Icons.tune_rounded, _showFilterMenu),
        ],
      ),
    );
  }

  Widget _buildHeaderActionBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 46,
        width: 46,
        decoration: BoxDecoration(
          color: kPrimaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kGrey200),
        ),
        child: Icon(icon, color: kPrimaryColor, size: 22),
      ),
    );
  }

  Widget _buildCategoryList() {
    // FAST FETCH: Check if stream is already initialized
    if (_categoryStream == null || _productsRef == null) {
      return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _categoryStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        var filteredCategories = snapshot.data!.docs.where((doc) {
          final categoryName = (doc.data() as Map<String, dynamic>)['name'] ?? '';
          return categoryName.toString().toLowerCase().contains(_searchQuery);
        }).toList();

        // Local Sorting logic
        filteredCategories.sort((a, b) {
          final nameA = (a.data() as Map<String, dynamic>)['name']?.toString() ?? '';
          final nameB = (b.data() as Map<String, dynamic>)['name']?.toString() ?? '';
          int res = nameA.compareTo(nameB);
          return _sortAscending ? res : -res;
        });

        if (filteredCategories.isEmpty && _searchQuery.isNotEmpty) {
          return _buildNoResults();
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: filteredCategories.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _buildCategoryCard(filteredCategories[index]),
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
        // Fix: Changed ternary to null-coalescing for robust null safety
        final int count = countSnapshot.data?.count ?? 0;

        // Filter logic
        if (_filterType == 'nonEmpty' && count == 0) return const SizedBox.shrink();
        if (_filterType == 'empty' && count > 0) return const SizedBox.shrink();

        return Container(
          decoration: BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kGrey200),
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(color: kPrimaryColor, fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kOrange)),
                subtitle: Text('$count ${count == 1 ? "Product" : "Products"}',
                    style: const TextStyle(color: kBlack54, fontSize: 12, fontWeight: FontWeight.w600)),
                trailing: (_hasPermission('addCategory') || isAdmin)
                    ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded, size: 26, color: kPrimaryColor),
                      onPressed: () => _showEditCategoryDialog(context, categoryDoc.id, name),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 22, color: kErrorColor),
                      onPressed: () => _showDeleteConfirmation(context, categoryDoc.id, name),
                    ),
                  ],
                )
                    : const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: kGrey400),
              ),
              if (_hasPermission('addCategory') || isAdmin) ...[
                const Divider(height: 1, color: kGrey100),
                Container(
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.02),
                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
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
                                const Icon(Icons.add_box_outlined, size: 16, color: kPrimaryColor),
                                const SizedBox(width: 8),
                                Text(context.tr('add_existing').toUpperCase(),
                                    style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.5)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(width: 1, height: 16, color: kGrey200),
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
                                const Icon(Icons.add_circle_outline, size: 16, color: kGoogleGreen),
                                const SizedBox(width: 8),
                                Text(context.tr('create_new').toUpperCase(),
                                    style: const TextStyle(color: kGoogleGreen, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.5)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // MODAL MENUS (SORT & FILTER)
  // ==========================================

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sort Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kBlack87)),
            const SizedBox(height: 20),
            _buildSortItem('Name (A-Z)', Icons.sort_by_alpha_rounded, true),
            _buildSortItem('Name (Z-A)', Icons.sort_by_alpha_rounded, false),
          ],
        ),
      ),
    );
  }

  Widget _buildSortItem(String label, IconData icon, bool ascending) {
    bool isSelected = _sortAscending == ascending;
    return ListTile(
      onTap: () {
        setState(() => _sortAscending = ascending);
        Navigator.pop(context);
      },
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: isSelected ? kPrimaryColor.withOpacity(0.1) : kGreyBg, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: isSelected ? kPrimaryColor : kBlack54, size: 20),
      ),
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: isSelected ? kPrimaryColor : kBlack87, fontSize: 14)),
      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: kPrimaryColor, size: 20) : null,
    );
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Category Filter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kBlack87)),
            const SizedBox(height: 20),
            _buildFilterItem('All Categories', 'all', Icons.all_inclusive_rounded, kPrimaryColor),
            _buildFilterItem('With Products', 'nonEmpty', Icons.inventory_2_rounded, kGoogleGreen),
            _buildFilterItem('Empty Categories', 'empty', Icons.layers_clear_rounded, kOrange),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterItem(String label, String value, IconData icon, Color color) {
    bool isSelected = _filterType == value;
    return ListTile(
      onTap: () {
        setState(() => _filterType = value);
        Navigator.pop(context);
      },
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: isSelected ? color : kBlack87, fontSize: 14)),
      trailing: isSelected ? Icon(Icons.check_circle_rounded, color: color, size: 20) : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.category_outlined,
                size: 60,
                color: kPrimaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.tr('no_categories_yet'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: kBlack87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Add your first category here and\norganize your products",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: kBlack54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: (isAdmin || _hasPermission('category')) ? () => _showAddCategoryDialog(context) : null,
              icon: const Icon(Icons.add_rounded, color: kWhite, size: 24),
              label: const Text(
                "Add Your First Category",
                style: TextStyle(
                  color: kWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.search_off_rounded, size: 64, color: kGrey300), const SizedBox(height: 16), Text(context.tr('no_categories_found'), style: const TextStyle(color: kBlack54, fontWeight: FontWeight.w600))]));

  // ==========================================
  // DIALOGS & POPUPS
  // ==========================================

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: kWhite,
        title: Text(context.tr('edit_category'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: Container(
          decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kPrimaryColor, width: 1.5)),
          child: TextField(
            controller: ctrl,
            style: const TextStyle(fontWeight: FontWeight.w600),
            decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(context.tr('cancel'), style: const TextStyle(fontWeight: FontWeight.bold, color: kBlack54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                await FirestoreService().updateDocument('categories', id, {'name': ctrl.text.trim()});
                Navigator.pop(c);
              }
            },
            child: Text(context.tr('save').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, color: kWhite)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: kWhite,
        title: Text(context.tr('delete_category'), style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text('${context.tr('are_you_sure_delete')} "$name"?', style: const TextStyle(color: kBlack54, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(context.tr('cancel'), style: const TextStyle(fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kErrorColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              await FirestoreService().deleteDocument('categories', id);
              Navigator.pop(c);
            },
            child: Text(context.tr('delete').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, color: kWhite)),
          ),
        ],
      ),
    );
  }

  void _showAddExistingProductDialog(BuildContext context, String categoryName) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: kWhite,
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.tr('add_existing_product'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kBlack87)),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<Stream<QuerySnapshot>>(
                  future: FirestoreService().getCollectionStream('Products'),
                  builder: (context, streamSnapshot) {
                    if (!streamSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                    return StreamBuilder<QuerySnapshot>(
                      stream: streamSnapshot.data,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                        final products = snapshot.data!.docs.where((doc) => (doc.data() as Map)['category'] != categoryName).toList();
                        if (products.isEmpty) return const Center(child: Text("No products available"));
                        return ListView.separated(
                          itemCount: products.length,
                          separatorBuilder: (c, i) => const Divider(height: 1, color: kGrey100),
                          itemBuilder: (c, i) {
                            final data = products[i].data() as Map<String, dynamic>;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(data['itemName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text('Current: ${data['category'] ?? 'Uncategorized'}', style: const TextStyle(fontSize: 11, color: kBlack54)),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                                onPressed: () async {
                                  await FirestoreService().updateDocument('Products', products[i].id, {'category': categoryName});
                                  Navigator.pop(context);
                                },
                                child: Text(context.tr('add').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: kWhite)),
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
// Category Details Page (Enterprise Flat)
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
    final canAddCategory = PermissionHelper.getUserPermissions(widget.uid).then((userData) {
      final permissions = userData['permissions'] as Map<String, dynamic>;
      final role = userData['role'] as String;
      return permissions['addCategory'] == true || role.toLowerCase().contains('admin');
    });
    return FutureBuilder<bool>(
      future: canAddCategory,
      builder: (context, snapshot) {
        final showAddButton = snapshot.data == true;
        return Scaffold(
          backgroundColor: kGreyBg,
          appBar: AppBar(
            title: Text(widget.categoryName, style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
            backgroundColor: kPrimaryColor,
            elevation: 0,
            centerTitle: true,
            iconTheme: const IconThemeData(color: kWhite),
            leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 20), onPressed: () => Navigator.pop(context)),
          ),
          floatingActionButton: showAddButton
              ? FloatingActionButton.extended(
            onPressed: () => _showAddOptions(context),
            backgroundColor: kPrimaryColor,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            icon: const Icon(Icons.add_rounded, color: kWhite, size: 20),
            label: const Text("ADD ITEM", style: TextStyle(color: kWhite, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5)),
          )
              : null,
          body: Column(
            children: [
              _buildSearchHeader(),
              Expanded(child: _buildProductList()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(color: kWhite, border: Border(bottom: BorderSide(color: kGrey200))),
      child: Container(
        height: 46,
        decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.04), borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search in ${widget.categoryName}...',
            hintStyle: const TextStyle(color: kBlack54, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: kPrimaryColor, size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 7),
          ),
        ),
      ),
    );
  }

  Widget _buildProductList() {
    if (_productsRef == null) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
    return StreamBuilder<QuerySnapshot>(
      stream: _productsRef!.where('category', isEqualTo: widget.categoryName).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
        final products = snapshot.data!.docs.where((doc) => (doc.data() as Map)['itemName'].toString().toLowerCase().contains(_searchQuery)).toList();
        if (products.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.search_off_rounded, size: 64, color: kGrey300), const SizedBox(height: 16), Text("No products found", style: TextStyle(color: kBlack54, fontWeight: FontWeight.w600))]));

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: products.length,
          separatorBuilder: (c, i) => const SizedBox(height: 10),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.inventory_2_rounded, color: kPrimaryColor, size: 20)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kBlack87), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text("Rs ${price.toStringAsFixed(2)}", style: const TextStyle(color: kPrimaryColor, fontSize: 13, fontWeight: FontWeight.w900)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: (stock > 0 ? kGoogleGreen : kErrorColor).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text("${stock.toInt()} IN STOCK", style: TextStyle(color: stock > 0 ? kGoogleGreen : kErrorColor, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 0.5)),
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
        decoration: const BoxDecoration(color: kWhite, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: kGrey300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          _buildActionTile(Icons.add_box_outlined, 'Add Existing Product', kPrimaryColor, () { Navigator.pop(c); _showAddExistingProductDialog(context); }),
          _buildActionTile(Icons.add_circle_outline_rounded, 'Create New Product', kGoogleGreen, () { Navigator.pop(c); Navigator.push(context, CupertinoPageRoute(builder: (c) => AddProductPage(uid: widget.uid, userEmail: widget.userEmail, preSelectedCategory: widget.categoryName))); }),
        ]),
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 20)),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 14)),
    );
  }

  void _showAddExistingProductDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: kWhite,
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.tr('add_existing_product'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kBlack87)),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<Stream<QuerySnapshot>>(
                  future: FirestoreService().getCollectionStream('Products'),
                  builder: (context, streamSnapshot) {
                    if (!streamSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                    return StreamBuilder<QuerySnapshot>(
                      stream: streamSnapshot.data,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                        final products = snapshot.data!.docs.where((doc) => (doc.data() as Map)['category'] != widget.categoryName).toList();
                        if (products.isEmpty) return const Center(child: Text("No products available"));
                        return ListView.separated(
                          itemCount: products.length,
                          separatorBuilder: (c, i) => const Divider(height: 1, color: kGrey100),
                          itemBuilder: (c, i) {
                            final data = products[i].data() as Map<String, dynamic>;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(data['itemName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                                onPressed: () async {
                                  await FirestoreService().updateDocument('Products', products[i].id, {'category': widget.categoryName});
                                  Navigator.pop(context);
                                },
                                child: Text(context.tr('add').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: kWhite)),
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