import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/Colors.dart';
import 'package:provider/provider.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/Sales/Bill.dart' hide kPrimaryColor;
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
  final bool isQuotationMode;

  const SaleAllPage({
    super.key,
    required this.uid,
    this.userEmail,
    this.savedOrderData,
    this.initialCartItems,
    this.onCartChanged,
    this.savedOrderId,
    this.isQuotationMode = false,
  });

  @override
  State<SaleAllPage> createState() => _SaleAllPageState();
}

class _SaleAllPageState extends State<SaleAllPage> {
  final _searchCtrl = TextEditingController();
  final List<CartItem> _cart = [];
  String _query = '';
  String _selectedCategory = '';

  Stream<QuerySnapshot>? _productsStream;
  bool _isLoadingStream = true;
  final List<String> _categories = [];
  bool _isLoadingCategories = true;

  double _cartHeight = 180.0;
  final double _minCartHeight = 120;
  final double _maxCartHeight = 400.0;

  String? _newlyAddedItemId;

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
        final cat = data['category'] ?? 'General';
        if (cat.toString().isNotEmpty) {
          categorySet.add(cat.toString());
        }
      }

      if (mounted) {
        setState(() {
          _categories.clear();
          _categories.add('All');
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

    setState(() => _newlyAddedItemId = id);
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _newlyAddedItemId = null);
    });

    widget.onCartChanged?.call(_cart);
  }

  void _showEditDialog(int idx) {
    final item = _cart[idx];
    final qtyCtrl = TextEditingController(text: item.quantity.toString());
    final priceCtrl = TextEditingController(text: item.price.toStringAsFixed(0));

    showDialog(
      context: context,
      barrierColor: kBlack87.withOpacity(0.8),
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
                prefixIcon: const Icon(Icons.currency_rupee, color: kPrimaryColor),
                filled: true,
                fillColor: kGreyBg,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.tr('quantity'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.numbers, color: kPrimaryColor),
                filled: true,
                fillColor: kGreyBg,
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
            child: Text(context.tr('delete'), style: const TextStyle(color: kErrorColor)),
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
              backgroundColor: kPrimaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(context.tr('update'), style: const TextStyle(color: kWhite)),
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

    return Scaffold(
      backgroundColor: kGreyBg,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          _buildHeader(w),
          Expanded(
            child: Column(
              children: [
                _buildCategorySelector(w),
                Expanded(child: _buildProductGrid(w)),
              ],
            ),
          ),
          CommonWidgets.buildActionButtons(
            context: context,
            isQuotationMode: widget.isQuotationMode,
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
                Navigator.push(context, CupertinoPageRoute(builder: (ctx) => QuotationPage(uid: widget.uid, userEmail: widget.userEmail, cartItems: _cart, totalAmount: _total)));
              }
            },
            onBill: () {
              if (_cart.isNotEmpty) {
                Navigator.push(context, CupertinoPageRoute(builder: (ctx) => BillPage(uid: widget.uid, userEmail: widget.userEmail, cartItems: _cart, totalAmount: _total, savedOrderId: widget.savedOrderId)));
              }
            },
            totalBill: _total,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(double w) {
    return Container(
      color: kWhite,
      padding: EdgeInsets.fromLTRB(w * 0.04, 10, w * 0.04, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: kGreyBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorderColor),
              ),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: context.tr('search'),
                  hintStyle: const TextStyle(color: kBlack54, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: kPrimaryColor, size: 22),
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
                color: kPrimaryColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: kPrimaryColor.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.qr_code_scanner, color: kWhite),
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
      padding: EdgeInsets.fromLTRB(w * 0.04, 8, 0, 8),
      child: SizedBox(
        height: 38,
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
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: isSelected ? kPrimaryColor : kWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isSelected ? kPrimaryColor : kGrey200),
                  boxShadow: isSelected ? [BoxShadow(color: kPrimaryColor.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 3))] : null,
                ),
                child: Center(
                  child: cat == 'Favorite'
                      ? Icon(
                    Icons.favorite,
                    size: 18,
                    color: isSelected ? kWhite : kPrimaryColor,
                  )
                      : Text(
                    cat,
                    style: TextStyle(
                      color: isSelected ? kWhite : kBlack54,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
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
    if (_isLoadingStream || _productsStream == null) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));

    return StreamBuilder<QuerySnapshot>(
      stream: _productsStream,
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) return Center(child: Text(context.tr('no_products'), style: const TextStyle(color: kBlack54)));

        final filtered = snap.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['itemName'] ?? '').toString().toLowerCase();
          final barcode = (data['barcode'] ?? '').toString().toLowerCase();
          final matchesSearch = name.contains(_query) || barcode.contains(_query);
          if (!matchesSearch) return false;
          if (_selectedCategory == 'Favorite') return data['isFavorite'] == true;
          if (_selectedCategory == context.tr('all')) return true;
          return (data['category'] ?? 'General').toString() == _selectedCategory;
        }).toList();

        if (filtered.isEmpty) return Center(child: Text(context.tr('no_results'), style: const TextStyle(color: kBlack54)));

        // Always show favorite items at the top, regardless of category
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
          padding: EdgeInsets.fromLTRB(w * 0.04, 8, w * 0.04, 80),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: w > 600 ? 200 : 150,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.95,
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
    final isFavorite = data['isFavorite'] ?? false;

    return Consumer<LocalStockService>(
      builder: (context, localStockService, child) {
        localStockService.cacheStock(id, firestoreStock.toInt());
        final stock = localStockService.hasStock(id) ? localStockService.getStock(id).toDouble() : firestoreStock;
        final isOutOfStock = stockEnabled && stock <= 0;
        final isLowStock = stockEnabled && stock > 0 && stock < 10;

        return GestureDetector(
          onTap: () {
            if (price > 0) {
              _addToCart(id, name, price, stockEnabled, stock,
                  taxName: data['taxName'], taxPercentage: data['taxPercentage'], taxType: data['taxType']);
            }
          },
          child: AspectRatio(
            aspectRatio: 1.0, // Force square card
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorderColor),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, height: 1.2, color: kBlack87),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isFavorite)
                        const Icon(Icons.favorite, color: kPrimaryColor, size: 16),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Rs ${price.toStringAsFixed(0)}",
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: kPrimaryColor),
                      ),
                      const SizedBox(height: 4),
                      if (stockEnabled)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isOutOfStock ? kErrorColor.withOpacity(0.1) : (isLowStock ? kGoogleYellow.withOpacity(0.1) : kGoogleGreen.withOpacity(0.1)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isOutOfStock ? 'Out' : '${stock.toInt()} $unit',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: isOutOfStock ? kErrorColor : (isLowStock ? kGoogleYellow : kGoogleGreen),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

