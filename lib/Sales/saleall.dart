import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/Sales/Bill.dart';
import 'package:maxbillup/Sales/Quotation.dart';
import 'package:maxbillup/components/barcode_scanner.dart';
import 'package:maxbillup/Sales/components/common_widgets.dart';
import 'package:maxbillup/utils/firestore_service.dart';

class SaleAllPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final Map<String, dynamic>? savedOrderData;
  final List<CartItem>? initialCartItems;
  final Function(List<CartItem>)? onCartChanged;
  final String? savedOrderId;

  const SaleAllPage({
    super.key,
    required this.uid,
    this.userEmail,
    this.savedOrderData,
    this.initialCartItems,
    this.onCartChanged,
    this.savedOrderId,
  });

  @override
  State<SaleAllPage> createState() => _SaleAllPageState();
}

class _SaleAllPageState extends State<SaleAllPage> {
  final _searchCtrl = TextEditingController();
  final List<CartItem> _cart = [];
  String _query = '';

  // Category Filter
  String _selectedCategory = 'All';

  Stream<QuerySnapshot>? _productsStream;
  bool _isLoadingStream = true;

  // List to hold dynamic categories
  final List<String> _categories = ['All'];
  bool _isLoadingCategories = true;

  // UI Constants
  final Color _primaryColor = const Color(0xFF2196F3);
  final Color _bgColor = const Color(0xFFF4F7FC);

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.toLowerCase()));
    _initializeProductsStream();

    if (widget.initialCartItems != null) {
      _cart.addAll(widget.initialCartItems!);
    } else if (widget.savedOrderData != null) {
      _loadOrder(widget.savedOrderData!);
    }
  }

  Future<void> _initializeProductsStream() async {
    final stream = await FirestoreService().getCollectionStream('Products');
    _loadCategories();

    if (mounted) {
      setState(() {
        _productsStream = stream;
        _isLoadingStream = false;
      });
    }
  }

  Future<void> _loadCategories() async {
    try {
      final collection = await FirestoreService().getStoreCollection('Products');
      final snap = await collection.get();

      final categorySet = <String>{};
      for (var doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final cat = data['category'] ?? 'Uncategorised';
        if (cat.toString().isNotEmpty) {
          categorySet.add(cat.toString());
        }
      }

      if (mounted) {
        setState(() {
          _categories.addAll(categorySet.toList()..sort());
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCategories = false);
        debugPrint('Error loading categories: $e');
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _loadOrder(Map<String, dynamic> data) {
    final items = data['items'] as List?;
    if (items != null) {
      for (var item in items) {
        _cart.add(CartItem(
          productId: item['productId'] ?? '',
          name: item['name'] ?? '',
          price: (item['price'] ?? 0.0).toDouble(),
          quantity: item['quantity'] ?? 1,
        ));
      }
    }
  }

  double get _total => _cart.fold(0.0, (sum, item) => sum + item.total);

  void _addToCart(String id, String name, double price, bool stockEnabled, double stock,
      {String? taxName, double? taxPercentage, String? taxType}) {
    final idx = _cart.indexWhere((item) => item.productId == id);

    if (idx != -1) {
      if (stockEnabled && _cart[idx].quantity + 1 > stock) {
        CommonWidgets.showSnackBar(
          context,
          'Max stock reached! (${stock.toInt()} available)',
          bgColor: const Color(0xFFFF5252),
        );
        return;
      }
      _cart[idx].quantity++;
      final item = _cart.removeAt(idx);
      _cart.insert(0, item);
    } else {
      if (stockEnabled && stock < 1) {
        CommonWidgets.showSnackBar(context, 'Out of stock!', bgColor: const Color(0xFFFF5252));
        return;
      }
      _cart.insert(0, CartItem(
        productId: id,
        name: name,
        price: price,
        taxName: taxName,
        taxPercentage: taxPercentage,
        taxType: taxType,
      ));
    }

    widget.onCartChanged?.call(_cart);
    setState(() {});
  }

  void _removeFromCart(int idx) {
    _cart.removeAt(idx);
    widget.onCartChanged?.call(_cart);
    setState(() {});
  }

  void _clearOrder() {
    _cart.clear();
    widget.onCartChanged?.call(_cart);
    setState(() {});
  }

  void _showEditDialog(int idx) {
    final item = _cart[idx];
    final qtyCtrl = TextEditingController(text: item.quantity.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(item.name, style: const TextStyle(fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Price: ${item.price.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryColor)),
            const SizedBox(height: 20),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.numbers),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _cart.removeAt(idx);
              widget.onCartChanged?.call(_cart);
              setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(qtyCtrl.text.trim());
              if (qty != null && qty > 0) {
                _cart[idx].quantity = qty;
                widget.onCartChanged?.call(_cart);
                setState(() {});
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _openScanner() async {
    await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (ctx) => BarcodeScannerPage(onBarcodeScanned: _searchByBarcode),
      ),
    );
  }

  void _searchByBarcode(String barcode) async {
    try {
      final collection = await FirestoreService().getStoreCollection('Products');
      final snap = await collection.where('barcode', isEqualTo: barcode).limit(1).get();

      if (snap.docs.isEmpty) {
        if (mounted) CommonWidgets.showSnackBar(context, 'Product not found', bgColor: Colors.orange);
        return;
      }

      final doc = snap.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      final id = doc.id;
      final name = data['itemName'] ?? 'Unnamed';
      final price = (data['price'] ?? 0.0).toDouble();
      final stockEnabled = data['stockEnabled'] ?? false;
      final stock = (data['currentStock'] ?? 0.0).toDouble();

      // Get tax information
      final taxName = data['taxName'] as String?;
      final taxPercentage = data['taxPercentage'] as double?;
      final taxType = data['taxType'] as String?;

      if (price > 0) {
        _addToCart(id, name, price, stockEnabled, stock,
            taxName: taxName, taxPercentage: taxPercentage, taxType: taxType);
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Column(
      children: [
        // 1. Header
        _buildHeader(w),

        // 2. Cart Preview
        if (_cart.isNotEmpty) _buildCartPreview(w),

        // 3. Category & Product Grid
        Expanded(
          child: Container(
            color: _bgColor,
            child: Column(
              children: [
                _buildCategorySelector(w),
                Expanded(child: _buildProductGrid(w)),
              ],
            ),
          ),
        ),

        // 4. Action Buttons
        CommonWidgets.buildActionButtons(
          context: context,
          onSaveOrder: () {
            CommonWidgets.showSaveOrderDialog(
              context: context,
              uid: widget.uid,
              cartItems: _cart,
              totalBill: _total,
              onSuccess: () {
                _cart.clear();
                widget.onCartChanged?.call(_cart);
                setState(() {});
              },
            );
          },
          onQuotation: () {
            if (_cart.isNotEmpty) {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (ctx) => QuotationPage(
                    uid: widget.uid,
                    userEmail: widget.userEmail,
                    cartItems: _cart,
                    totalAmount: _total,
                  ),
                ),
              );
            }
          },
          onBill: () {
            if (_cart.isNotEmpty) {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (ctx) => BillPage(
                    uid: widget.uid,
                    userEmail: widget.userEmail,
                    cartItems: _cart,
                    totalAmount: _total,
                    savedOrderId: widget.savedOrderId,
                  ),
                ),
              );
            }
          },
          totalBill: _total,
        ),
      ],
    );
  }

  Widget _buildHeader(double w) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: w * 0.04, vertical: 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                controller: _searchCtrl,
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 15),
                  prefixIcon: Icon(Icons.search, color: _primaryColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _openScanner,
            child: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: _primaryColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: const Icon(Icons.qr_code_scanner, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartPreview(double w) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: w * 0.04, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${_cart.length} Items',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _clearOrder,
                  child: Text(
                    'Clear All',
                    style: TextStyle(color: Colors.red[400], fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: w * 0.04),
              itemCount: _cart.length,
              itemBuilder: (ctx, idx) {
                final item = _cart[idx];
                return GestureDetector(
                  onTap: () => _showEditDialog(idx),
                  child: Container(
                    width: w * 0.65,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${item.quantity}',
                              style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              Text(
                                '${item.price.toStringAsFixed(0)} x ${item.quantity} = ${item.total.toStringAsFixed(0)}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector(double w) {
    if (_isLoadingCategories) return const LinearProgressIndicator(minHeight: 2);

    return Container(
      color: _bgColor,
      padding: EdgeInsets.fromLTRB(w * 0.04, 12, 0, 12),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final cat = _categories[index];
            final isSelected = _selectedCategory == cat;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? _primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected ? _primaryColor : Colors.grey[300]!,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))]
                      : null,
                ),
                child: Center(
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProductGrid(double w) {
    if (_isLoadingStream || _productsStream == null) {
      return Center(child: CircularProgressIndicator(color: _primaryColor));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _productsStream,
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Center(child: Text('No products available', style: TextStyle(color: Colors.grey[600])));
        }

        final filtered = snap.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          final name = (data['itemName'] ?? '').toString().toLowerCase();
          final barcode = (data['barcode'] ?? '').toString().toLowerCase();
          final matchesSearch = name.contains(_query) || barcode.contains(_query);

          if (!matchesSearch) return false;
          if (_selectedCategory == 'All') return true;

          final category = (data['category'] ?? 'Uncategorised').toString();
          return category == _selectedCategory;
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('No products found', style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: EdgeInsets.fromLTRB(w * 0.04, 0, w * 0.04, 80),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            // Changed aspect ratio to 1.6 (Wider cards since image is gone)
            childAspectRatio: 1.6,
          ),
          itemCount: filtered.length,
          itemBuilder: (ctx, idx) {
            final doc = filtered[idx];
            final data = doc.data() as Map<String, dynamic>;

            return _buildProductCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildProductCard(String id, Map<String, dynamic> data) {
    final name = data['itemName'] ?? 'Unnamed';
    final price = (data['price'] ?? 0.0).toDouble();
    final stockEnabled = data['stockEnabled'] ?? false;
    final stock = (data['currentStock'] ?? 0.0).toDouble();
    final unit = data['stockUnit'] ?? '';

    // Get tax information
    final taxName = data['taxName'] as String?;
    final taxPercentage = data['taxPercentage'] as double?;
    final taxType = data['taxType'] as String?;

    final isOutOfStock = stockEnabled && stock <= 0;
    final isLowStock = stockEnabled && stock > 0 && stock < 10;

    return GestureDetector(
      onTap: () {
        if (price > 0) {
          _addToCart(id, name, price, stockEnabled, stock,
              taxName: taxName, taxPercentage: taxPercentage, taxType: taxType);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Product Name (Top)
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Price and Stock (Bottom)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          price.toStringAsFixed(0),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: Colors.grey[800],
                          ),
                        ),
                        if (stockEnabled)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isOutOfStock
                                  ? Colors.red[50]
                                  : (isLowStock ? Colors.orange[50] : Colors.green[50]),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isOutOfStock ? '0' : '${stock.toInt()}$unit',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isOutOfStock
                                    ? Colors.red
                                    : (isLowStock ? Colors.orange : Colors.green),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Overlay if Out of Stock
              if (isOutOfStock)
                Container(
                  color: Colors.white.withOpacity(0.7),
                  child: Center(
                    child: Transform.rotate(
                      angle: -0.2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]
                        ),
                        child: const Text(
                          'SOLD OUT',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}