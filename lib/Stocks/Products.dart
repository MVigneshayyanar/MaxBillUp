import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/Stocks/AddProduct.dart';
import 'package:maxbillup/utils/permission_helper.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';

// Modern Professional UI Constants
const Color _primaryColor = Color(0xFF2196F3);
const Color _navyColor = Color(0xFF0F172A); // Deep Slate for professional text
const Color _secondaryColor = Color(0xFF64748B);
const Color _cardBorder = Color(0xFFE3F2FD);
const Color _scaffoldBg = Colors.white;
const Color _successColor = Color(0xFF4CAF50);
const Color _errorColor = Color(0xFFFF5252);
const Color _warningColor = Color(0xFFFF9800);

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
  String _sortBy = 'name';
  bool _sortAscending = true;
  String _filterStock = 'all';

  late String _uid;
  Map<String, dynamic> _permissions = {};
  String _role = 'staff';
  bool _isLoading = true;
  Stream<QuerySnapshot>? _productsStream;

  @override
  void initState() {
    super.initState();
    _uid = widget.uid;
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    _loadPermissions();
    _initProductsStream();
  }

  Future<void> _initProductsStream() async {
    try {
      final stream = await FirestoreService().getCollectionStream('Products');
      if (mounted) {
        setState(() {
          _productsStream = stream;
        });
      }
    } catch (e) {
      debugPrint("Error initializing stream: $e");
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
      backgroundColor: _scaffoldBg,
      floatingActionButton: (isAdmin || _hasPermission('addProduct'))
          ? FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (c) => AddProductPage(uid: _uid, userEmail: widget.userEmail),
          ),
        ),
        backgroundColor: _successColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          context.tr('add_product'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      )
          : null,
      body: Column(
        children: [
          _buildHeaderSection(),
          Expanded(
            child: _buildProductList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
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
                  hintText: context.tr('search'),
                  hintStyle: const TextStyle(color: _secondaryColor, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: _primaryColor, size: 22),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
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
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: _primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _cardBorder),
        ),
        child: Icon(icon, color: _primaryColor, size: 24),
      ),
    );
  }

  Widget _buildProductList() {
    if (_productsStream == null) return const Center(child: CircularProgressIndicator());

    return StreamBuilder<QuerySnapshot>(
      stream: _productsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return _buildEmptyState();

        final products = _filterAndSortProducts(snapshot.data!.docs);
        if (products.isEmpty) return _buildNoResultsState();

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), // Extra bottom padding for FAB
          itemCount: products.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = products[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildProductCard(doc.id, data, doc);
          },
        );
      },
    );
  }

  Widget _buildProductCard(String id, Map<String, dynamic> data, QueryDocumentSnapshot doc) {
    final name = data['itemName'] ?? 'Unnamed';
    final price = (data['price'] ?? 0.0).toDouble();
    final stockEnabled = data['stockEnabled'] ?? false;
    final stock = (data['currentStock'] ?? 0.0).toDouble();

    final isOutOfStock = stockEnabled && stock <= 0;
    final isLowStock = stockEnabled && stock > 0 && stock < 10;

    return GestureDetector(
      onTap: () => _showProductActionMenu(context, doc),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorder),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Product Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.inventory_2_outlined, color: _primaryColor, size: 24),
            ),
            const SizedBox(width: 16),
            // Name and Price
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _navyColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Rs ${price.toStringAsFixed(2)}",
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _secondaryColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Stock Info
            if (stockEnabled) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOutOfStock ? _errorColor.withOpacity(0.1) : (isLowStock ? _warningColor.withOpacity(0.1) : _successColor.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isOutOfStock ? 'Out of Stock' : '${stock.toStringAsFixed(0)} in stock',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isOutOfStock ? _errorColor : (isLowStock ? _warningColor : _successColor),
                      ),
                    ),
                  ),
                  if (isLowStock)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        "Low Stock",
                        style: TextStyle(fontSize: 10, color: _warningColor, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  // --- MODAL SHEETS & DIALOGS ---

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sort Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _navyColor)),
            const SizedBox(height: 20),
            _buildSortOption('Name', 'name', Icons.sort_by_alpha),
            _buildSortOption('Price', 'price', Icons.payments_outlined),
            _buildSortOption('Stock', 'stock', Icons.inventory_2_outlined),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String label, String value, IconData icon) {
    bool isSelected = _sortBy == value;
    return ListTile(
      onTap: () {
        setState(() {
          if (_sortBy == value) { _sortAscending = !_sortAscending; }
          else { _sortBy = value; _sortAscending = true; }
        });
        Navigator.pop(context);
      },
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: isSelected ? _primaryColor.withOpacity(0.1) : Colors.grey[50], borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: isSelected ? _primaryColor : _secondaryColor, size: 20),
      ),
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? _primaryColor : _navyColor)),
      trailing: isSelected ? Icon(_sortAscending ? Icons.north : Icons.south, color: _primaryColor, size: 16) : null,
    );
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Stock Filter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _navyColor)),
            const SizedBox(height: 20),
            _buildFilterOption(Icons.all_inclusive, 'All Products', 'all', _primaryColor),
            _buildFilterOption(Icons.check_circle_outline, 'In Stock', 'inStock', _successColor),
            _buildFilterOption(Icons.warning_amber_rounded, 'Low Stock', 'lowStock', _warningColor),
            _buildFilterOption(Icons.error_outline, 'Out of Stock', 'outOfStock', _errorColor),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(IconData icon, String title, String value, Color color) {
    bool isSelected = _filterStock == value;
    return ListTile(
      onTap: () {
        setState(() => _filterStock = value);
        Navigator.pop(context);
      },
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? color : _navyColor)),
      trailing: isSelected ? Icon(Icons.check_circle, color: color, size: 20) : null,
    );
  }

  void _showProductActionMenu(BuildContext context, QueryDocumentSnapshot productDoc) {
    final data = productDoc.data() as Map<String, dynamic>;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text(data['itemName'] ?? 'Product', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 20),
            _buildActionTile(Icons.edit_outlined, 'Edit Details', _primaryColor, () {
              Navigator.pop(context);
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (c) => AddProductPage(
                    uid: _uid,
                    userEmail: widget.userEmail,
                    productId: productDoc.id,
                    existingData: data,
                  ),
                ),
              );
            }),
            _buildActionTile(Icons.inventory_2_outlined, 'Update Stock', _warningColor, () {
              Navigator.pop(context);
              _showUpdateQuantityDialog(context, productDoc.id, data['itemName'], (data['currentStock'] ?? 0.0).toDouble());
            }),
            _buildActionTile(Icons.delete_outline, 'Delete Product', _errorColor, () {
              Navigator.pop(context);
              _showDeleteConfirmDialog(context, productDoc);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 20)),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
    );
  }

  // --- REFINED DIALOGS ---

  void _showUpdateQuantityDialog(BuildContext context, String id, String name, double current) {
    final ctrl = TextEditingController();
    bool isAdding = true;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _buildToggle(true, isAdding, 'ADD', () => setDialogState(() => isAdding = true)),
                const SizedBox(width: 12),
                _buildToggle(false, isAdding, 'REMOVE', () => setDialogState(() => isAdding = false)),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantity',
                filled: true, fillColor: _primaryColor.withOpacity(0.04),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              final val = double.tryParse(ctrl.text) ?? 0;
              if (val <= 0) return;
              final next = isAdding ? current + val : current - val;
              await FirestoreService().updateDocument('Products', id, {'currentStock': next});
              Navigator.pop(context);
            },
            child: const Text('UPDATE'),
          )
        ],
      )),
    );
  }

  void _showEditDetailsDialog(BuildContext context, QueryDocumentSnapshot productDoc) {
    final data = productDoc.data() as Map<String, dynamic>;
    final nameCtrl = TextEditingController(text: data['itemName']);
    final priceCtrl = TextEditingController(text: data['price']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Product', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogInput(nameCtrl, "Product Name", Icons.edit_note),
            const SizedBox(height: 12),
            _buildDialogInput(priceCtrl, "Price", Icons.currency_rupee, isNum: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              final newPrice = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
              if (newName.isNotEmpty) {
                await FirestoreService().updateDocument('Products', productDoc.id, {
                  'itemName': newName,
                  'price': newPrice,
                });
                Navigator.pop(context);
              }
            },
            child: const Text('SAVE'),
          )
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, QueryDocumentSnapshot productDoc) {
    final data = productDoc.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${data['itemName']}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _errorColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              await FirestoreService().deleteDocument('Products', productDoc.id);
              Navigator.pop(context);
            },
            child: const Text('DELETE'),
          )
        ],
      ),
    );
  }

  Widget _buildDialogInput(TextEditingController ctrl, String lbl, IconData icon, {bool isNum = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: lbl, prefixIcon: Icon(icon, color: _primaryColor),
        filled: true, fillColor: _primaryColor.withOpacity(0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildToggle(bool target, bool current, String lbl, VoidCallback onTap) {
    bool active = target == current;
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: active ? _primaryColor : Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: active ? _primaryColor : _cardBorder)),
        child: Center(child: Text(lbl, style: TextStyle(fontWeight: FontWeight.bold, color: active ? Colors.white : _secondaryColor, fontSize: 12))),
      ),
    ));
  }

  // --- LOGIC HELPERS ---

  List<QueryDocumentSnapshot> _filterAndSortProducts(List<QueryDocumentSnapshot> items) {
    var list = items.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['itemName'] ?? '').toString().toLowerCase();
      if (!name.contains(_searchQuery)) return false;
      if (_filterStock == 'all') return true;
      final stock = (data['currentStock'] ?? 0.0).toDouble();
      if (_filterStock == 'outOfStock') return stock <= 0;
      if (_filterStock == 'lowStock') return stock > 0 && stock < 10;
      if (_filterStock == 'inStock') return stock >= 10;
      return true;
    }).toList();

    list.sort((a, b) {
      final dA = a.data() as Map<String, dynamic>;
      final dB = b.data() as Map<String, dynamic>;
      int res = 0;
      if (_sortBy == 'name') res = (dA['itemName'] ?? '').toString().compareTo(dB['itemName'] ?? '');
      else if (_sortBy == 'price') res = (dA['price'] ?? 0).compareTo(dB['price'] ?? 0);
      else res = (dA['currentStock'] ?? 0).compareTo(dB['currentStock'] ?? 0);
      return _sortAscending ? res : -res;
    });
    return list;
  }

  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inventory_2_outlined, size: 80, color: _primaryColor.withOpacity(0.1)), const SizedBox(height: 16), const Text('No products available', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))]));
  Widget _buildNoResultsState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.search_off, size: 60, color: Colors.grey), const SizedBox(height: 16), Text('No results for "$_searchQuery"', style: const TextStyle(color: Colors.grey))]));
}