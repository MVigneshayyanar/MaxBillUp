import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/Colors.dart';
import 'package:provider/provider.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/models/sale.dart';
import 'package:maxbillup/Sales/Bill.dart' hide kPrimaryColor;
import 'package:maxbillup/Sales/Quotation.dart';
import 'package:maxbillup/Sales/Invoice.dart';
import 'package:maxbillup/components/barcode_scanner.dart';
import 'package:maxbillup/Sales/components/common_widgets.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/services/local_stock_service.dart';
import 'package:maxbillup/services/number_generator_service.dart';
import 'package:maxbillup/services/sale_sync_service.dart';
import 'package:maxbillup/services/cart_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:maxbillup/Stocks/Products.dart';

import '../Stocks/Stock.dart';

class SaleAllPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final Map<String, dynamic>? savedOrderData;
  final List<CartItem>? initialCartItems;
  final Function(List<CartItem>)? onCartChanged;
  final String? savedOrderId;
  final bool isQuotationMode;
  final Function(bool)? onSearchFocusChanged;
  final String? customerPhone;
  final String? customerName;
  final String? customerGST;
  final void Function(String?, String?, String?)? onCustomerChanged;

  const SaleAllPage({
    super.key,
    required this.uid,
    this.userEmail,
    this.savedOrderData,
    this.initialCartItems,
    this.onCartChanged,
    this.savedOrderId,
    this.isQuotationMode = false,
    this.onSearchFocusChanged,
    this.customerPhone,
    this.customerName,
    this.customerGST,
    this.onCustomerChanged,
  });

  @override
  State<SaleAllPage> createState() => _SaleAllPageState();
}

class _SaleAllPageState extends State<SaleAllPage> {
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  final List<CartItem> _cart = [];
  String _query = '';
  String _selectedCategory = '';
  bool _isSearchFocused = false;

  Stream<QuerySnapshot>? _productsStream;
  bool _isLoadingStream = true;
  final List<String> _categories = [];
  bool _isLoadingCategories = true;
  bool _showFavoritesOnly = false;

  // Customer selection
  String? _selectedCustomerPhone;
  String? _selectedCustomerName;
  String? _selectedCustomerGST;

  // +1 animation tracking
  String? _animatingProductId;
  int _animationCounter = 0;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.toLowerCase()));
    _searchFocusNode.addListener(() {
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
      widget.onSearchFocusChanged?.call(_searchFocusNode.hasFocus);
    });
    _initializeProductsStream();

    if (widget.initialCartItems != null) {
      _cart.addAll(widget.initialCartItems!);
    } else if (widget.savedOrderData != null) {
      _loadOrder(widget.savedOrderData!);
    }

    _selectedCustomerPhone = widget.customerPhone;
    _selectedCustomerName = widget.customerName;
    _selectedCustomerGST = widget.customerGST;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _selectedCategory = context.tr('all');
        });
      }
    });
  }

  @override
  void didUpdateWidget(SaleAllPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Sync cart from parent when initialCartItems change
    // This handles edits made in NewSale.dart cart overlay
    if (widget.initialCartItems != null &&
        widget.initialCartItems != oldWidget.initialCartItems) {
      // Cart was updated from parent - sync it
      setState(() {
        _cart.clear();
        _cart.addAll(widget.initialCartItems!);
      });
    } else if (widget.initialCartItems == null && oldWidget.initialCartItems != null) {
      // Parent explicitly cleared the cart (e.g., from clear button)
      setState(() {
        _cart.clear();
      });
    }

    // Sync customer info
    if (widget.customerPhone != oldWidget.customerPhone ||
        widget.customerName != oldWidget.customerName ||
        widget.customerGST != oldWidget.customerGST) {
      _selectedCustomerPhone = widget.customerPhone;
      _selectedCustomerName = widget.customerName;
      _selectedCustomerGST = widget.customerGST;
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
        final cat = data['category'] ?? 'General';
        // Exclude 'Low Stock' from categories
        if (cat.toString().isNotEmpty && cat.toString() != 'Low Stock') {
          categorySet.add(cat.toString());
        }
      }

      if (mounted) {
        setState(() {
          _categories.clear();
          _categories.add('All');
          _categories.add('Favorite');
          _categories.addAll(categorySet.toList()..sort());
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
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

  // Helper function to format category names: First letter uppercase, rest lowercase
  String _formatCategoryName(String name) {
    if (name.isEmpty) return name;
    return name[0].toUpperCase() + name.substring(1).toLowerCase();
  }

  void _addToCart(String id, String name, double price, bool stockEnabled, double stock,
      {String? taxName, double? taxPercentage, String? taxType}) {
    final idx = _cart.indexWhere((item) => item.productId == id);

    if (idx != -1) {
      if (stockEnabled && _cart[idx].quantity + 1 > stock) {
        CommonWidgets.showSnackBar(
          context,
          context.tr('max_stock_reached').replaceFirst('{0}', stock.toInt().toString()),
          bgColor: kErrorColor,
        );
        return;
      }
      _cart[idx].quantity++;
      final item = _cart.removeAt(idx);
      _cart.insert(0, item);
    } else {
      if (stockEnabled && stock < 1) {
        CommonWidgets.showSnackBar(context, context.tr('out_of_stock'), bgColor: kErrorColor);
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

    setState(() {
      _animatingProductId = id;
      _animationCounter++;
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _animatingProductId == id) {
        setState(() {
          _animatingProductId = null;
        });
      }
    });

    widget.onCartChanged?.call(_cart);
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
        if (mounted) CommonWidgets.showSnackBar(context, context.tr('product_not_found'), bgColor: kOrange);
        return;
      }

      final doc = snap.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      final id = doc.id;
      final name = data['itemName'] ?? context.tr('unnamed');
      final price = (data['price'] ?? 0.0).toDouble();
      final stockEnabled = data['stockEnabled'] ?? false;
      final firestoreStock = (data['currentStock'] ?? 0.0).toDouble();

      final localStockService = context.read<LocalStockService>();
      localStockService.cacheStock(id, firestoreStock.toInt());

      final stock = localStockService.hasStock(id)
          ? localStockService.getStock(id).toDouble()
          : firestoreStock;

      if (price > 0) {
        _addToCart(id, name, price, stockEnabled, stock,
            taxName: data['taxName'], taxPercentage: data['taxPercentage'], taxType: data['taxType']);
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    // Listen to CartService for changes (e.g., when cart is cleared from Bill page)
    // Only sync with CartService when NOT in quotation mode
    // Quotation mode has its own separate cart managed by nq.dart
    if (!widget.isQuotationMode) {
      final cartService = Provider.of<CartService>(context);

      // Sync local cart state with CartService
      if (cartService.cartItems.isEmpty && _cart.isNotEmpty) {
        // Cart was cleared externally (e.g., from Bill page)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _cart.clear();
              widget.onCartChanged?.call(_cart);
            });
          }
        });
      }
    }

    return PopScope(
      canPop: !_searchFocusNode.hasFocus,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // If back is pressed while search is focused, unfocus it
        if (_searchFocusNode.hasFocus) {
          _searchFocusNode.unfocus();
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: kGreyBg,
          resizeToAvoidBottomInset: false,
          body: Column(
            children: [
              _buildHeader(w),
              Expanded(
                child: Column(
                  children: [
                    if (!_searchFocusNode.hasFocus)
                      _buildCategorySelector(w),
                    Expanded(child: _buildProductGrid(w)),
                  ],
                ),
              ),
              // Always show action buttons (bottom bar)
              CommonWidgets.buildActionButtons(
                context: context,
                isQuotationMode: widget.isQuotationMode,
                onSaveOrder: () {
                  if (_cart.isEmpty) return;
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
                onCustomer: () {
                  CommonWidgets.showCustomerSelectionDialog(
                    context: context,
                    onCustomerSelected: (phone, name, gst) {
                      setState(() {
                        _selectedCustomerPhone = phone;
                        _selectedCustomerName = name;
                        _selectedCustomerGST = gst;
                      });
                      widget.onCustomerChanged?.call(phone, name, gst);
                    },
                    selectedCustomerPhone: _selectedCustomerPhone,
                  );
                },
                customerName: _selectedCustomerName,
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
                          customerPhone: _selectedCustomerPhone,
                          customerName: _selectedCustomerName,
                          customerGST: _selectedCustomerGST,
                        ),
                      ),
                    );
                  }
                },
                totalBill: _total,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double w) {
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
                controller: _searchCtrl,
                focusNode: _searchFocusNode,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kBlack87),
                decoration: InputDecoration(
                  hintText: context.tr('search'),
                  hintStyle: const TextStyle(color: kBlack54, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: kPrimaryColor, size: 20),
                  suffixIcon: _searchFocusNode.hasFocus
                      ? IconButton(
                    icon: const Icon(Icons.close, color: kPrimaryColor, size: 20),
                    onPressed: () {
                      _searchCtrl.clear();
                      _searchFocusNode.unfocus();
                    },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 7),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _openScanner,
            child: Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: kPrimaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.qr_code_scanner, color: kWhite, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector(double w) {
    if (_isLoadingCategories) return const LinearProgressIndicator(minHeight: 2, color: kPrimaryColor);

    return Container(
      color: kWhite,
      padding: const EdgeInsets.fromLTRB(16, 10, 0, 10),
      child: SizedBox(
        height: 36,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final cat = _categories[index];
            final isAll = cat == 'All';
            final isSelected = _selectedCategory == (isAll ? context.tr('all') : cat) || (_showFavoritesOnly && cat == 'Favorite');

            return GestureDetector(
              onTap: () {
                setState(() {
                  if (cat == 'Favorite') {
                    _showFavoritesOnly = true;
                    _selectedCategory = cat;
                  } else {
                    _showFavoritesOnly = false;
                    _selectedCategory = (isAll ? context.tr('all') : cat);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isSelected ? kPrimaryColor : kGreyBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isSelected ? kPrimaryColor : kGrey200),
                ),
                child: Center(
                  child: cat == 'Favorite'
                      ? Icon(
                    Icons.favorite_rounded,
                    size: 16,
                    color: isSelected ? kWhite : kPrimaryColor,
                  )
                      : Text(
                    _formatCategoryName(cat),
                    style: TextStyle(
                      color: isSelected ? kWhite : kBlack54,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
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
    if (_isLoadingStream || _productsStream == null) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));

    return StreamBuilder<QuerySnapshot>(
      stream: _productsStream,
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));

        // Check if there are no products at all (empty database)
        if (snap.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final filtered = snap.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['itemName'] ?? '').toString().toLowerCase();
          final barcode = (data['barcode'] ?? '').toString().toLowerCase();
          final productCode = (data['productCode'] ?? '').toString().toLowerCase();
          final matchesSearch = name.contains(_query) || barcode.contains(_query) || productCode.contains(_query);

          // If user is searching, show all products that match the search (ignore category filter)
          if (_query.isNotEmpty) {
            return matchesSearch;
          }

          // If not searching, apply category filters
          if (!matchesSearch) return false;

          if (_showFavoritesOnly) return data['isFavorite'] == true;


          if (_selectedCategory == context.tr('all')) return true;
          return (data['category'] ?? 'General').toString() == _selectedCategory;
        }).toList();

        if (filtered.isEmpty) return Center(child: Text(context.tr('no_results'), style: const TextStyle(color: kBlack54)));

        filtered.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final favA = dataA['isFavorite'] ?? false;
          final favB = dataB['isFavorite'] ?? false;
          if (favA && !favB) return -1;
          if (!favA && favB) return 1;
          return (dataA['itemName'] ?? '').toString().compareTo((dataB['itemName'] ?? '').toString());
        });

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: w > 600 ? 220 : (w > 400 ? 130 : 115),
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
                Icons.inventory_2_outlined,
                size: 60,
                color: kPrimaryColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "No Products Yet",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: kBlack87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Add your first product and\ngrow your business",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: kBlack54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to Products page to add product
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => StockPage(uid: widget.uid, userEmail: widget.userEmail),
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded, color: kWhite, size: 24),
              label: const Text(
                "Add Your First Product",
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
  String formatCategory(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  Widget _buildProductCard(String id, Map<String, dynamic> data) {
    final name = data['itemName'] ?? 'Unnamed';
    final price = (data['price'] ?? 0.0).toDouble();
    final stockEnabled = data['stockEnabled'] ?? false;
    final firestoreStock = (data['currentStock'] ?? 0.0).toDouble();
    final unit = data['stockUnit'] ?? '';
    final isFavorite = data['isFavorite'] ?? false;
    final isAnimating = _animatingProductId == id;
    final category = data['category'] ?? 'General';
    final lowStockAlert = (data['lowStockAlert'] ?? 0.0).toDouble();

    // Check expiry date
    final expiryDateStr = data['expiryDate'] as String?;
    bool isExpired = false;
    if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
      try {
        final expiryDate = DateTime.parse(expiryDateStr);
        isExpired = expiryDate.isBefore(DateTime.now());
      } catch (e) {
        // Invalid date format, ignore
      }
    }

    return Consumer<LocalStockService>(
      builder: (context, localStockService, child) {
        // FIX: Always sync Firestore stock to local cache to ensure cache is up-to-date
        // This prevents stale cache from showing "OUT OF STOCK" when Firestore has stock
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (localStockService.hasStock(id)) {
            final cachedStock = localStockService.getStock(id);
            // If Firestore stock is different, update the cache
            if (cachedStock != firestoreStock.toInt()) {
              print('📦 Syncing stock cache for $name: cache=$cachedStock, firestore=${firestoreStock.toInt()}');
              localStockService.cacheStock(id, firestoreStock.toInt());
            }
          } else {
            // No cache yet, initialize it with Firestore value
            localStockService.cacheStock(id, firestoreStock.toInt());
          }
        });

        // Use Firestore stock as source of truth (it's fresher after each rebuild)
        final stock = firestoreStock;
        final isOutOfStock = stockEnabled && stock <= 0;
        final isLowStock = stockEnabled && lowStockAlert > 0 && stock > 0 && stock <= lowStockAlert;

        return GestureDetector(
          onTap: () {
            // Check if product is expired
            if (isExpired) {
              _showExpiredProductDialog(name);
              return;
            }
            if (price > 0) {
              _addToCart(id, name, price, stockEnabled, stock,
                  taxName: data['taxName'], taxPercentage: data['taxPercentage'], taxType: data['taxType']);
            }
          },
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: isExpired
                      ? kErrorColor.withOpacity(0.05)
                      : (isAnimating ? kGoogleGreen.withOpacity(0.1) : kWhite),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isExpired
                          ? kErrorColor.withOpacity(0.5)
                          : (isAnimating ? kGoogleGreen : kGrey200),
                      width: isAnimating ? 2 : 1
                  ),
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                             fontWeight: FontWeight.w600,
                              fontSize: 15,
                              height: 1,
                              color: isExpired ? kErrorColor : kBlack87,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isFavorite)
                          const Icon(Icons.favorite_rounded, color: kPrimaryColor, size: 14),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatCategory(category),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: kOrange,
                            letterSpacing: 0.5,
                          ),
                        ),

                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${price.toStringAsFixed(0)}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      color: isExpired ? kErrorColor : kPrimaryColor,
                                    ),
                                  ),
                                  if (stockEnabled) ...[
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isOutOfStock ? kErrorColor.withOpacity(0.08) : kGoogleGreen.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isOutOfStock ? 'OUT OF STOCK' : '${stock.toInt()} $unit',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: isOutOfStock ? kErrorColor : kGoogleGreen,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Low stock indicator at right bottom
                            if (isLowStock && !isOutOfStock)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: kOrange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: kOrange.withOpacity(0.3)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: kOrange, size: 10),
                                    SizedBox(width: 2),
                                    Text(
                                      'LOW',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                        color: kOrange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isAnimating)
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(_animationCounter),
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: 1.0 - value,
                        child: Transform.translate(
                          offset: Offset(0, -30 * value),
                          child: Transform.scale(
                            scale: 1.0 + (value * 0.5),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: kOrange,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  '+1',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              // Expired badge overlay
              if (isExpired)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: kErrorColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'EXPIRED',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: kWhite,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showExpiredProductDialog(String productName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kErrorColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_rounded, color: kErrorColor, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Product Expired',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              productName,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: kPrimaryColor),
            ),
            const SizedBox(height: 12),
            const Text(
              'This product has expired and cannot be added to the cart. Please update the product details or remove it from inventory.',
              style: TextStyle(color: kBlack54, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}