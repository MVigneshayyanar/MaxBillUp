import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/Sales/Bill.dart';
import 'package:maxbillup/Sales/Quotation.dart';
import 'package:maxbillup/components/barcode_scanner.dart';
import 'package:maxbillup/Sales/components/common_widgets.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/services/local_stock_service.dart';

class SaleAllPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final Map<String, dynamic>? savedOrderData;
  final List<CartItem>? initialCartItems;
  final Function(List<CartItem>)? onCartChanged;
  final String? savedOrderId;
  final bool isQuotationMode; // New parameter to indicate quotation mode

  const SaleAllPage({
    super.key,
    required this.uid,
    this.userEmail,
    this.savedOrderData,
    this.initialCartItems,
    this.onCartChanged,
    this.savedOrderId,
    this.isQuotationMode = false, // Default to false for normal bill mode
  });

  @override
  State<SaleAllPage> createState() => _SaleAllPageState();
}

class _SaleAllPageState extends State<SaleAllPage> {
  final _searchCtrl = TextEditingController();
  final List<CartItem> _cart = [];
  String _query = '';

  // Category Filter
  String _selectedCategory = '';

  Stream<QuerySnapshot>? _productsStream;
  bool _isLoadingStream = true;

  // List to hold dynamic categories
  final List<String> _categories = ['All'];
  bool _isLoadingCategories = true;

  // Cart expansion state
  double _cartHeight = 180.0; // Initial height for 4 items
  final double _minCartHeight = 180;
  final double _maxCartHeight = 300.0;

  // Newly added item tracking
  String? _newlyAddedItemId;

  // UI Constants
  final Color _primaryColor = const Color(0xFF2196F3);
  final Color _successColor = const Color(0xFF4CAF50);
  final Color _secondaryColor = Color(0xFF64748B);
  final Color _errorColor = const Color(0xFFFF5252);
  final Color _warningColor = const Color(0xFFFF9800);
  final Color _bgColor = Colors.white; // Changed to white
  final Color _cardBorder = Color(0xFFE3F2FD);
  final Color _cartHeaderColor = const Color(0xFFFFA726); // Orange color for header

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
    // Set default selected category to localized 'all' after first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _selectedCategory = context.tr('all');
        });
      }
    });
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
          context.tr('max_stock_reached').replaceFirst('{0}', stock.toInt().toString()),
          bgColor: const Color(0xFFFF5252),
        );
        return;
      }
      _cart[idx].quantity++;
      final item = _cart.removeAt(idx);
      _cart.insert(0, item);
    } else {
      if (stockEnabled && stock < 1) {
        CommonWidgets.showSnackBar(context, context.tr('out_of_stock'), bgColor: const Color(0xFFFF5252));
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

    // Highlight newly added item
    setState(() {
      _newlyAddedItemId = id;
    });

    // Remove highlight after 1 second
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _newlyAddedItemId = null;
        });
      }
    });

    widget.onCartChanged?.call(_cart);
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
    final priceCtrl = TextEditingController(text: item.price.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(item.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.tr('price'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.currency_rupee),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.tr('quantity'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.numbers),
                filled: true,
                fillColor: Colors.grey[50],
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
            child: Text(context.tr('delete'), style: TextStyle(color: _errorColor)),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(qtyCtrl.text.trim());
              final price = double.tryParse(priceCtrl.text.trim());
              if (qty != null && qty > 0 && price != null && price > 0) {
                _cart[idx].quantity = qty;
                _cart[idx].price = price;
                widget.onCartChanged?.call(_cart);
                setState(() {});
                Navigator.pop(ctx);
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
        if (mounted) CommonWidgets.showSnackBar(context, context.tr('product_not_found'), bgColor: Colors.orange);
        return;
      }

      final doc = snap.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      final id = doc.id;
      final name = data['itemName'] ?? context.tr('unnamed');
      final price = (data['price'] ?? 0.0).toDouble();
      final stockEnabled = data['stockEnabled'] ?? false;
      final firestoreStock = (data['currentStock'] ?? 0.0).toDouble();

      // Cache stock locally for offline use using Provider
      final localStockService = context.read<LocalStockService>();
      localStockService.cacheStock(id, firestoreStock.toInt());

      // Get effective stock (local if available, otherwise Firestore)
      final stock = localStockService.hasStock(id)
          ? localStockService.getStock(id).toDouble()
          : firestoreStock;

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

    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          // Main content layer
          Column(
            children: [
              // 1. Dynamic spacer for cart - updates with cart height
              AnimatedContainer(
                duration: const Duration(milliseconds: 0), // Instant update during drag
                height: _cart.isNotEmpty ? _cartHeight : 0,
              ),

              // 2. Header (Search bar) with fixed top padding
              Container(
                padding: EdgeInsets.only(top: _cart.isEmpty ? 3 : 0),
                child: _buildHeader(w),
              ),

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
                isQuotationMode: widget.isQuotationMode, // Pass the quotation mode flag
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
          ),

          // Cart overlay - ALWAYS on top when cart has items
          if (_cart.isNotEmpty)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildCartTable(w),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(double w) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(w * 0.04, 5, w * 0.04, 12),
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
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: context.tr('search'),
                  hintStyle: TextStyle(color: _secondaryColor, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: _primaryColor, size: 22),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildCartTable(double w) {
    return Container(
      height: _cartHeight,
      decoration: BoxDecoration(
        color: Colors.white,

      ),
      child: Column(
        children: [
          // Orange Header with column names
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            decoration: BoxDecoration(
              color: _primaryColor,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    'PRODUCT',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'QTY',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'PRICE',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'TOTAL',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Cart Items - Scrollable
          Expanded(
            child: Container(
              color: Colors.white,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _cart.length,
                itemBuilder: (ctx, idx) {
                  final item = _cart[idx];
                  final isNewlyAdded = item.productId == _newlyAddedItemId;

                  return GestureDetector(
                    onTap: () => _showEditDialog(idx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                      decoration: BoxDecoration(
                        color: isNewlyAdded
                            ? _successColor.withOpacity(0.5)
                            : Colors.white,
                        border: Border(
                          bottom: BorderSide(
                            color: _primaryColor,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.edit,
                                  color: Colors.black45,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${item.quantity}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              item.price.toStringAsFixed(0),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              item.total.toStringAsFixed(0),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: _primaryColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Bottom control bar: Clear (left), Drag handle (center), Item count (right)
          GestureDetector(
            behavior: HitTestBehavior.opaque, // Ensure the gesture detector captures all touches
            onVerticalDragUpdate: (details) {
              setState(() {
                _cartHeight = (_cartHeight + details.delta.dy).clamp(_minCartHeight, _maxCartHeight);
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              decoration: BoxDecoration(
                color: _primaryColor,
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left: Clear button
                  GestureDetector(
                    onTap: _clearOrder,
                    child: Row(
                      children: [
                        Icon(Icons.clear, color: Colors.white, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          context.tr('clear'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Center: Drag handle
                  Icon(Icons.drag_handle, color: Colors.white, size: 24),
                  // Right: Item count
                  Text(
                    '${_cart.length} ${context.tr('items')}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector(double w) {
    if (_isLoadingCategories) return LinearProgressIndicator(minHeight: 2, color: _primaryColor, backgroundColor: Colors.white);

    return Container(
      color: _bgColor,
      padding: EdgeInsets.fromLTRB(w * 0.04, 0, 0, 12),
      child: SizedBox(
        height: 36,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final cat = _categories[index];
            final isSelected = _selectedCategory == (cat == 'All' ? context.tr('all') : cat);
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = (cat == 'All' ? context.tr('all') : cat)),
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                decoration: BoxDecoration(
                  color: isSelected ? _primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? _primaryColor : _cardBorder,
                  ),
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
          if (_selectedCategory == context.tr('all')) return true;

          final category = (data['category'] ?? 'Uncategorised').toString();
          return category == _selectedCategory;
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('No products found', style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: EdgeInsets.fromLTRB(w * 0.04, 0, w * 0.04, 20),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: w > 600 ? 5 : 3, // Increased columns for compact look
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.85,
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
    final firestoreStock = (data['currentStock'] ?? 0.0).toDouble();
    final unit = data['stockUnit'] ?? '';

    // Get tax information
    final taxName = data['taxName'] as String?;
    final taxPercentage = data['taxPercentage'] as double?;
    final taxType = data['taxType'] as String?;

    // Use Consumer to listen for stock changes - this rebuilds when stock is updated!
    return Consumer<LocalStockService>(
      builder: (context, localStockService, child) {
        // Cache stock from Firestore (non-blocking)
        localStockService.cacheStock(id, firestoreStock.toInt());

        // Get local stock (this is instant from memory cache)
        final localStock = localStockService.getStock(id);

        // Use local stock if cached, otherwise use Firestore stock
        final stock = localStockService.hasStock(id)
            ? localStock.toDouble()
            : firestoreStock;

        final isOutOfStock = stockEnabled && stock <= 0;
        final isLowStock = stockEnabled && stock > 0 && stock < 10;

        return _buildProductCardUI(
          id, name, price, stockEnabled, stock, unit,
          taxName, taxPercentage, taxType,
          isOutOfStock, isLowStock,
        );
      },
    );
  }

  Widget _buildProductCardUI(
      String id, String name, double price, bool stockEnabled, double stock, String unit,
      String? taxName, double? taxPercentage, String? taxType,
      bool isOutOfStock, bool isLowStock,
      ) {

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
          border: Border.all(color: _cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top: Name
            Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.2, color: Colors.black87),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            // Bottom: Price and Stock
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  price.toStringAsFixed(0),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _primaryColor,
                  ),
                ),
                if (stockEnabled) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isOutOfStock
                          ? _errorColor.withOpacity(0.1)
                          : (isLowStock ? _warningColor.withOpacity(0.1) : _successColor.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isOutOfStock ? 'Out' : '${stock.toInt()} $unit',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isOutOfStock
                            ? _errorColor
                            : (isLowStock ? _warningColor : _successColor),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

