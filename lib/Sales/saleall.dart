import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:heroicons/heroicons.dart';
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
import 'package:maxbillup/utils/amount_formatter.dart';
import 'package:maxbillup/utils/responsive_helper.dart';
import 'package:maxbillup/services/local_stock_service.dart';
import 'package:maxbillup/services/number_generator_service.dart';
import 'package:maxbillup/services/sale_sync_service.dart';
import 'package:maxbillup/services/cart_service.dart';
import 'package:maxbillup/services/currency_service.dart';
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

  // Saved order tracking
  String? _savedOrderName;

  // +1 animation tracking
  String? _animatingProductId;
  int _animationCounter = 0;

  // Currency symbol
  String _currencySymbol = '';

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

    // Always extract orderName from savedOrderData if available
    if (widget.savedOrderData != null) {
      _savedOrderName = widget.savedOrderData!['orderName'] as String?;
    }

    // Load cart items
    if (widget.initialCartItems != null) {
      _cart.addAll(widget.initialCartItems!);
    } else if (widget.savedOrderData != null) {
      // Only load items from savedOrderData if initialCartItems not provided
      final items = widget.savedOrderData!['items'] as List?;
      if (items != null) {
        for (var item in items) {
          _cart.add(CartItem(
            productId: item['productId'] ?? '',
            name: item['name'] ?? '',
            price: (item['price'] ?? 0.0).toDouble(),
            cost: (item['cost'] ?? 0.0).toDouble(),
            quantity: (item['quantity'] ?? 1).toDouble(),
            taxName: item['taxName'] as String?,
            taxPercentage: item['taxPercentage'] != null ? (item['taxPercentage'] as num).toDouble() : null,
            taxType: item['taxType'] as String?,
          ));
        }
      }
    }

    _selectedCustomerPhone = widget.customerPhone;
    _selectedCustomerName = widget.customerName;
    _selectedCustomerGST = widget.customerGST;

    // Load currency symbol
    _currencySymbol = CurrencyService().symbolWithSpace;
    _loadCurrencySymbol();

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
        _savedOrderName = null; // Clear saved order name when cart is cleared
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


  Future<void> _loadCurrencySymbol() async {
    try {
      final doc = await FirestoreService().getCurrentStoreDoc();
      if (doc != null && doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>?;
        setState(() {
          _currencySymbol = CurrencyService.getSymbolWithSpace(data?['currency']);
        });
      }
    } catch (e) {
      debugPrint('Error loading currency: $e');
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
    setState(() {
      // Extract order name if available
      _savedOrderName = data['orderName'] as String?;

      final items = data['items'] as List?;
      if (items != null) {
        for (var item in items) {
          _cart.add(CartItem(
            productId: item['productId'] ?? '',
            name: item['name'] ?? '',
            price: (item['price'] ?? 0.0).toDouble(),
            cost: (item['cost'] ?? 0.0).toDouble(),
            quantity: (item['quantity'] ?? 1).toDouble(),
          ));
        }
      }
    });
  }

  double get _total => _cart.fold(0.0, (sum, item) => sum + item.totalWithTax);

  // Helper function to format category names: First letter uppercase, rest lowercase
  String _formatCategoryName(String name) {
    if (name.isEmpty) return name;
    return name[0].toUpperCase() + name.substring(1).toLowerCase();
  }

  void _showWeightInputDialog(String id, String name, double price, double cost, bool stockEnabled, double stock,
      {String? taxName, double? taxPercentage, String? taxType}) {
    final gramController = TextEditingController();
    final kgController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: R.all(context, 8),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: HeroIcon(HeroIcons.scale, color: kPrimaryColor, size: R.sp(context, 24)),
            ),
            SizedBox(width: R.sp(context, 12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter Weight',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: R.sp(context, 18)),
                  ),
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: R.sp(context, 14),
                      color: kPrimaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gram input
            Container(
              decoration: BoxDecoration(
                color: kGreyBg,
                borderRadius: R.radius(context, 12),
                border: Border.all(color: kGrey200),
              ),
              child: ValueListenableBuilder<TextEditingValue>(
      valueListenable: gramController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
                controller: gramController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: R.sp(context, 16)),
                decoration: InputDecoration(
                  labelText: 'Grams',
                  
                  suffixText: 'g',
                  suffixStyle: TextStyle(
                    color: kPrimaryColor,
                    fontWeight: FontWeight.w700,
                    fontSize: R.sp(context, 14),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  contentPadding: EdgeInsets.symmetric(horizontal: R.sp(context, 16), vertical: R.sp(context, 14)),
                  border: OutlineInputBorder(
                    borderRadius: R.radius(context, 12),
                    borderSide: BorderSide(color: hasText ? kPrimaryColor : kGrey200, width: hasText ? 1.5 : 1.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: R.radius(context, 12),
                    borderSide: BorderSide(color: hasText ? kPrimaryColor : kGrey200, width: hasText ? 1.5 : 1.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: R.radius(context, 12),
                    borderSide: const BorderSide(color: kPrimaryColor, width: 2.0),
                  ),
                  labelStyle: TextStyle(color: hasText ? kPrimaryColor : kBlack54, fontSize: R.sp(context, 13), fontWeight: FontWeight.w600),
                  floatingLabelStyle: TextStyle(color: hasText ? kPrimaryColor : kPrimaryColor, fontSize: R.sp(context, 11), fontWeight: FontWeight.w900),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && kgController.text.isNotEmpty) {
                    kgController.clear();
                  }
                },
              
);
      },
    ),
            ),
            SizedBox(height: R.sp(context, 12)),
            // OR text
            Text(
              'OR',
              style: TextStyle(
                color: kBlack54,
                fontWeight: FontWeight.w700,
                fontSize: R.sp(context, 12),
              ),
            ),
            SizedBox(height: R.sp(context, 12)),
            // Kilogram input
            Container(
              decoration: BoxDecoration(
                color: kGreyBg,
                borderRadius: R.radius(context, 12),
                border: Border.all(color: kGrey200),
              ),
              child: ValueListenableBuilder<TextEditingValue>(
      valueListenable: kgController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
                controller: kgController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: R.sp(context, 16)),
                decoration: InputDecoration(
                  labelText: 'Kilograms',
                  
                  suffixText: 'kg',
                  suffixStyle: TextStyle(
                    color: kPrimaryColor,
                    fontWeight: FontWeight.w700,
                    fontSize: R.sp(context, 14),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  contentPadding: EdgeInsets.symmetric(horizontal: R.sp(context, 16), vertical: R.sp(context, 14)),
                  border: OutlineInputBorder(
                    borderRadius: R.radius(context, 12),
                    borderSide: BorderSide(color: hasText ? kPrimaryColor : kGrey200, width: hasText ? 1.5 : 1.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: R.radius(context, 12),
                    borderSide: BorderSide(color: hasText ? kPrimaryColor : kGrey200, width: hasText ? 1.5 : 1.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: R.radius(context, 12),
                    borderSide: const BorderSide(color: kPrimaryColor, width: 2.0),
                  ),
                  labelStyle: TextStyle(color: hasText ? kPrimaryColor : kBlack54, fontSize: R.sp(context, 13), fontWeight: FontWeight.w600),
                  floatingLabelStyle: TextStyle(color: hasText ? kPrimaryColor : kPrimaryColor, fontSize: R.sp(context, 11), fontWeight: FontWeight.w900),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && gramController.text.isNotEmpty) {
                    gramController.clear();
                  }
                },
              
);
      },
    ),
            ),
            SizedBox(height: R.sp(context, 16)),
            // Price info
            Container(
              padding: R.all(context, 12),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.05),
                borderRadius: R.radius(context, 8),
                border: Border.all(color: kPrimaryColor.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Price per kg: ',
                    style: TextStyle(
                      color: kBlack54,
                      fontSize: R.sp(context, 13),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${CurrencyService().symbol}${AmountFormatter.format(price)}',
                    style: TextStyle(
                      color: kPrimaryColor,
                      fontSize: R.sp(context, 15),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: kBlack54,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              double finalQuantity = 0.0;

              // Check if gram is entered
              if (gramController.text.isNotEmpty) {
                try {
                  final grams = double.parse(gramController.text);
                  finalQuantity = grams / 1000; // Convert grams to kg
                } catch (e) {
                  CommonWidgets.showSnackBar(
                    context,
                    'Please enter a valid number',
                    bgColor: kErrorColor,
                  );
                  return;
                }
              }
              // Check if kg is entered
              else if (kgController.text.isNotEmpty) {
                try {
                  finalQuantity = double.parse(kgController.text);
                } catch (e) {
                  CommonWidgets.showSnackBar(
                    context,
                    'Please enter a valid number',
                    bgColor: kErrorColor,
                  );
                  return;
                }
              }
              // No input
              else {
                CommonWidgets.showSnackBar(
                  context,
                  'Please enter weight in grams or kilograms',
                  bgColor: kOrange,
                );
                return;
              }

              // Validate quantity
              if (finalQuantity <= 0) {
                CommonWidgets.showSnackBar(
                  context,
                  'Weight must be greater than 0',
                  bgColor: kErrorColor,
                );
                return;
              }

              Navigator.pop(ctx);
              _addToCart(id, name, price, cost, stockEnabled, stock, finalQuantity,
                  taxName: taxName, taxPercentage: taxPercentage, taxType: taxType);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Add to Cart',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: kWhite,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addToCart(String id, String name, double price, double cost, bool stockEnabled, double stock, double quantity,
      {String? taxName, double? taxPercentage, String? taxType}) {
    final idx = _cart.indexWhere((item) => item.productId == id);

    if (idx != -1) {
      if (stockEnabled && _cart[idx].quantity + quantity > stock) {
        CommonWidgets.showSnackBar(
          context,
          context.tr('max_stock_reached').replaceFirst('{0}', stock.toInt().toString()),
          bgColor: kErrorColor,
        );
        return;
      }
      _cart[idx].quantity += quantity;
      final item = _cart.removeAt(idx);
      _cart.insert(0, item);
    } else {
      if (stockEnabled && stock < quantity) {
        CommonWidgets.showSnackBar(context, context.tr('out_of_stock'), bgColor: kErrorColor);
        return;
      }
      _cart.insert(0, CartItem(
        productId: id,
        name: name,
        price: price,
        cost: cost,
        quantity: quantity,
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
      final cost = (data['costPrice'] ?? 0.0).toDouble();
      final stockEnabled = data['stockEnabled'] ?? false;
      final firestoreStock = (data['currentStock'] ?? 0.0).toDouble();
      final unit = data['stockUnit'] ?? '';

      final localStockService = context.read<LocalStockService>();
      localStockService.cacheStock(id, firestoreStock.toInt());

      final stock = localStockService.hasStock(id)
          ? localStockService.getStock(id).toDouble()
          : firestoreStock;

      if (price > 0) {
        // Only show weight dialog for kg unit items
        if (unit.toLowerCase() == 'kg' || unit.toLowerCase() == 'kilogram') {
          _showWeightInputDialog(
            id,
            name,
            price,
            cost,
            stockEnabled,
            stock,
            taxName: data['taxName'],
            taxPercentage: data['taxPercentage'],
            taxType: data['taxType'],
          );
        } else {
          // For non-kg items, add directly with quantity 1
          _addToCart(
            id,
            name,
            price,
            cost,
            stockEnabled,
            stock,
            1.0,
            taxName: data['taxName'],
            taxPercentage: data['taxPercentage'],
            taxType: data['taxType'],
          );
        }
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
                savedOrderName: _savedOrderName,
                onSaveOrder: () {
                  if (_cart.isEmpty) return;
                  // Get savedOrderId from widget or CartService
                  final savedOrderId = widget.savedOrderId ?? context.read<CartService>().savedOrderId;
                  CommonWidgets.showSaveOrderDialog(
                    context: context,
                    uid: widget.uid,
                    cartItems: _cart,
                    totalBill: _total,
                    savedOrderId: savedOrderId,
                    savedOrderName: _savedOrderName,
                    savedOrderPhone: _selectedCustomerPhone,
                    onSuccess: (String orderName, String? orderId) {
                      // After saving/updating, clear the cart, saved order name AND savedOrderId
                      // This allows future saves to create new orders instead of updating
                      setState(() {
                        _savedOrderName = null; // Clear order name since cart is now empty
                        _cart.clear(); // Clear the cart
                      });
                      // Notify parent that cart is now empty
                      widget.onCartChanged?.call(_cart);
                      // Update CartService with empty cart AND clear savedOrderId
                      context.read<CartService>().updateCart([]);
                      context.read<CartService>().setSavedOrderId(null); // Clear savedOrderId to allow new saves
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
                currencySymbol: _currencySymbol,
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
              height: R.sp(context, 46),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.04),
                borderRadius: R.radius(context, 12),
                border: Border.all(color: kGrey200),
              ),
              child: ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchCtrl,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
                controller: _searchCtrl,
                focusNode: _searchFocusNode,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: R.sp(context, 14), color: kBlack87),
                decoration: InputDecoration(
                  hintText: context.tr('search'),
                  hintStyle: TextStyle(color: kBlack54, fontSize: R.sp(context, 14)),
                  prefixIcon: Padding(
                    padding: R.all(context, 12),
                    child: HeroIcon(HeroIcons.magnifyingGlass, color: kPrimaryColor, size: R.sp(context, 20)),
                  ),
                  suffixIcon: _searchFocusNode.hasFocus
                      ? IconButton(
                    icon: HeroIcon(HeroIcons.xMark, color: kPrimaryColor, size: R.sp(context, 20)),
                    onPressed: () {
                      _searchCtrl.clear();
                      _searchFocusNode.unfocus();
                    },
                  )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  contentPadding: EdgeInsets.symmetric(horizontal: R.sp(context, 16), vertical: R.sp(context, 14)),
                  border: OutlineInputBorder(
                    borderRadius: R.radius(context, 12),
                    borderSide: BorderSide(color: hasText ? kPrimaryColor : kGrey200, width: hasText ? 1.5 : 1.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: R.radius(context, 12),
                    borderSide: BorderSide(color: hasText ? kPrimaryColor : kGrey200, width: hasText ? 1.5 : 1.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: R.radius(context, 12),
                    borderSide: const BorderSide(color: kPrimaryColor, width: 2.0),
                  ),
                  labelStyle: TextStyle(color: hasText ? kPrimaryColor : kBlack54, fontSize: R.sp(context, 13), fontWeight: FontWeight.w600),
                  floatingLabelStyle: TextStyle(color: hasText ? kPrimaryColor : kPrimaryColor, fontSize: R.sp(context, 11), fontWeight: FontWeight.w900),
                ),
              
);
      },
    ),
            ),
          ),
          SizedBox(width: R.sp(context, 12)),
          GestureDetector(
            onTap: _openScanner,
            child: Container(
              height: R.sp(context, 46),
              width: R.sp(context, 46),
              decoration: BoxDecoration(
                color: kPrimaryColor,
                borderRadius: R.radius(context, 12),
              ),
              child: const HeroIcon(HeroIcons.qrCode, color: kWhite, size: 22),
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
                margin: EdgeInsets.only(right: R.sp(context, 10)),
                padding: EdgeInsets.symmetric(horizontal: R.sp(context, 16)),
                decoration: BoxDecoration(
                  color: isSelected ? kPrimaryColor : kGreyBg,
                  borderRadius: R.radius(context, 10),
                  border: Border.all(color: isSelected ? kPrimaryColor : kGrey200),
                ),
                child: Center(
                  child: cat == 'Favorite'
                      ? HeroIcon(
                    HeroIcons.heart,
                    size: R.sp(context, 16),
                    color: isSelected ? kWhite : kPrimaryColor,
                    style: isSelected ? HeroIconStyle.solid : HeroIconStyle.outline,
                  )
                      : Text(
                    _formatCategoryName(cat),
                    style: TextStyle(
                      color: isSelected ? kWhite : kBlack54,
                      fontWeight: FontWeight.w700,
                      fontSize: R.sp(context, 12),
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
          padding: EdgeInsets.fromLTRB(R.sp(context, 16), R.sp(context, 8), R.sp(context, 16), R.sp(context, 100)),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: w > 600 ? 220 : (w > 400 ? R.sp(context, 130) : R.sp(context, 115)),
            crossAxisSpacing: R.sp(context, 8),
            mainAxisSpacing: R.sp(context, 10),
            childAspectRatio: 1.0,
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
        padding: R.all(context, 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: R.sp(context, 120),
              height: R.sp(context, 120),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: HeroIcon(
                HeroIcons.archiveBox,
                size: R.sp(context, 60),
                color: kPrimaryColor,
              ),
            ),
            SizedBox(height: R.sp(context, 24)),
            Text(
              "No Products Yet",
              style: TextStyle(
                fontSize: R.sp(context, 22),
                fontWeight: FontWeight.w800,
                color: kBlack87,
              ),
            ),
            SizedBox(height: R.sp(context, 12)),
            Text(
              "Add your first product and\ngrow your business",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: R.sp(context, 15),
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
              icon: const HeroIcon(HeroIcons.plus, color: kWhite, size: 24),
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

    // Low stock color
    const Color lowStockColor = kOrange;

    // Expiry check
    final expiryDateStr = data['expiryDate'] as String?;
    bool isExpired = false;
    if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
      try {
        final expiryDate = DateTime.parse(expiryDateStr);
        isExpired = expiryDate.isBefore(DateTime.now());
      } catch (_) {}
    }

    return Consumer<LocalStockService>(
      builder: (context, localStockService, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (localStockService.hasStock(id)) {
            final cachedStock = localStockService.getStock(id);
            if (cachedStock != firestoreStock.toInt()) {
              localStockService.cacheStock(id, firestoreStock.toInt());
            }
          } else {
            localStockService.cacheStock(id, firestoreStock.toInt());
          }
        });

        final stock = firestoreStock;
        final isOutOfStock = stockEnabled && stock <= 0;
        final isLowStock =
            stockEnabled && lowStockAlert > 0 && stock > 0 && stock <= lowStockAlert;

        return GestureDetector(
          onTap: () {
            if (isExpired) {
              _showExpiredProductDialog(name);
              return;
            }
            if (isOutOfStock) {
              _showOutOfStockDialog(name);
              return;
            }
            if (price > 0) {
              final cost = (data['costPrice'] ?? 0.0).toDouble();
              // Only show weight dialog for kg unit items
              if (unit.toLowerCase() == 'kg' || unit.toLowerCase() == 'kilogram') {
                _showWeightInputDialog(
                  id,
                  name,
                  price,
                  cost,
                  stockEnabled,
                  stock,
                  taxName: data['taxName'],
                  taxPercentage: data['taxPercentage'],
                  taxType: data['taxType'],
                );
              } else {
                // For non-kg items, add directly with quantity 1
                _addToCart(
                  id,
                  name,
                  price,
                  cost,
                  stockEnabled,
                  stock,
                  1.0,
                  taxName: data['taxName'],
                  taxPercentage: data['taxPercentage'],
                  taxType: data['taxType'],
                );
              }
            }
          },
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: R.all(context, 8),
                decoration: BoxDecoration(
                  color: isExpired
                      ? Colors.black.withOpacity(0.05)
                      : isOutOfStock
                          ? kErrorColor.withOpacity(0.05)
                          : isLowStock
                              ? lowStockColor.withOpacity(0.05)
                              : (isAnimating ? kGoogleGreen.withOpacity(0.1) : kWhite),
                  borderRadius: R.radius(context, 12),
                  border: Border.all(
                    color: isExpired
                        ? Colors.black.withOpacity(0.5)
                        : isOutOfStock
                            ? kErrorColor.withOpacity(0.5)
                            : isLowStock
                                ? lowStockColor.withOpacity(0.5)
                                : (isAnimating ? kGoogleGreen : kGrey200),
                    width: isAnimating ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    /// NAME + FAVORITE
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: R.sp(context, 13),
                              height: 1.1,
                              color: kBlack87,
                            ),
                          ),
                        ),
                        if (isFavorite)
                          HeroIcon(
                            HeroIcons.heart,
                            color: kPrimaryColor,
                            size: R.sp(context, 13),
                            style: HeroIconStyle.outline,
                          ),
                      ],
                    ),

                    /// CATEGORY + PRICE + STOCK in bottom section
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                formatCategory(category),
                                style: TextStyle(
                                  fontSize: R.sp(context, 9),
                                  fontWeight: FontWeight.w700,
                                  color: kOrange,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              SizedBox(height: R.sp(context, 3)),
                              Text(
                                '$_currencySymbol${AmountFormatter.format(price)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: R.sp(context, 12),
                                  color: kPrimaryColor,
                                ),
                              ),
                              if (stockEnabled) ...[
                                SizedBox(height: R.sp(context, 2)),
                                Text(
                                  '${AmountFormatter.format(stock)} $unit',
                                  style: TextStyle(
                                    fontSize: R.sp(context, 8),
                                    fontWeight: FontWeight.w900,
                                    color: isOutOfStock
                                        ? kErrorColor
                                        : isLowStock
                                            ? lowStockColor
                                            : kGoogleGreen,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (isLowStock && !isOutOfStock)
                          HeroIcon(HeroIcons.exclamationTriangle, size: R.sp(context, 16), color: lowStockColor),
                      ],
                    ),
                  ],
                ),
              ),

              /// +1 animation
              if (isAnimating)
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(_animationCounter),
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: 1 - value,
                        child: Transform.translate(
                          offset: Offset(0, -30 * value),
                          child: Transform.scale(
                            scale: 1 + (value * 0.5),
                            child: Center(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: R.sp(context, 10), vertical: R.sp(context, 4)),
                                decoration: BoxDecoration(
                                  color: kOrange,
                                  borderRadius: R.radius(context, 20),
                                ),
                                child: Text(
                                  '+1',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: R.sp(context, 20),
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

              /// LOW STOCK badge - bottom right
              if (isLowStock && !isOutOfStock)
                Positioned(
                  bottom: R.sp(context, 4),
                  right: R.sp(context, 4),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: R.sp(context, 6), vertical: R.sp(context, 3)),
                    decoration: BoxDecoration(
                      color: lowStockColor,
                      borderRadius: R.radius(context, 6),
                    ),
                    child: Text(
                      'LOW STOCK',
                      style: TextStyle(
                        fontSize: R.sp(context, 7),
                        fontWeight: FontWeight.w900,
                        color: kWhite,
                      ),
                    ),
                  ),
                ),

              /// OUT OF STOCK badge - bottom right
              if (isOutOfStock)
                Positioned(
                  bottom: R.sp(context, 4),
                  right: R.sp(context, 4),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: R.sp(context, 6), vertical: R.sp(context, 3)),
                    decoration: BoxDecoration(
                      color: kErrorColor,
                      borderRadius: R.radius(context, 6),
                    ),
                    child: Text(
                      'OUT OF STOCK',
                      style: TextStyle(
                        fontSize: R.sp(context, 7),
                        fontWeight: FontWeight.w900,
                        color: kWhite,
                      ),
                    ),
                  ),
                ),

              /// EXPIRED badge - bottom right
              if (isExpired)
                Positioned(
                  bottom: R.sp(context, 4),
                  right: R.sp(context, 4),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: R.sp(context, 6), vertical: R.sp(context, 3)),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: R.radius(context, 6),
                    ),
                    child: Text(
                      'EXPIRED',
                      style: TextStyle(
                        fontSize: R.sp(context, 7),
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
        shape: RoundedRectangleBorder(borderRadius: R.radius(context, 16)),
        title: Row(
          children: [
            Container(
              padding: R.all(context, 8),
              decoration: BoxDecoration(
                color: kOrange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: HeroIcon(HeroIcons.exclamationTriangle, color: kOrange, size: R.sp(context, 24)),
            ),
            SizedBox(width: R.sp(context, 12)),
            Expanded(
              child: Text(
                'Product Expired',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: R.sp(context, 18)),
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
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: R.sp(context, 16), color: kOrange),
            ),
            SizedBox(height: R.sp(context, 12)),
            Text(
              'This product has expired and cannot be added to the cart. Please update the product details or remove it from inventory.',
              style: TextStyle(color: kBlack54, fontSize: R.sp(context, 14)),
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


  void _showOutOfStockDialog(String productName) {
    const Color outOfStockColor = Colors.black;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: outOfStockColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const HeroIcon(HeroIcons.shoppingCart, color: outOfStockColor, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Out of Stock',
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
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: outOfStockColor),
            ),
            const SizedBox(height: 12),
            const Text(
              'This product is currently out of stock and cannot be added to the cart. Please restock this item to continue selling.',
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
