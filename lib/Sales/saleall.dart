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
import 'package:connectivity_plus/connectivity_plus.dart';

class SaleAllPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final Map<String, dynamic>? savedOrderData;
  final List<CartItem>? initialCartItems;
  final Function(List<CartItem>)? onCartChanged;
  final String? savedOrderId;
  final bool isQuotationMode;
  final Function(bool)? onSearchFocusChanged; // Callback to notify parent when search focus changes
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

    // Sync local customer state with parent
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
    // Sync cart changes from parent when initialCartItems changes
    if (widget.initialCartItems != oldWidget.initialCartItems) {
      if (widget.initialCartItems != null) {
        setState(() {
          _cart.clear();
          _cart.addAll(widget.initialCartItems!);
        });
      }
    }
    // Sync local customer state with parent on update
    if (widget.customerPhone != oldWidget.customerPhone ||
        widget.customerName != oldWidget.customerName ||
        widget.customerGST != oldWidget.customerGST) {
      setState(() {
        _selectedCustomerPhone = widget.customerPhone;
        _selectedCustomerName = widget.customerName;
        _selectedCustomerGST = widget.customerGST;
      });
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
      bool hasLowStockProducts = false;

      for (var doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final cat = data['category'] ?? 'General';
        if (cat.toString().isNotEmpty) {
          categorySet.add(cat.toString());
        }

        // Check if product has low stock
        final stockEnabled = data['stockEnabled'] ?? false;
        if (stockEnabled) {
          final currentStock = (data['currentStock'] ?? 0.0).toDouble();
          final lowStockAlert = (data['lowStockAlert'] ?? 0.0).toDouble();
          final lowStockAlertType = data['lowStockAlertType'] ?? 'Count';

          if (lowStockAlert > 0) {
            bool isLowStock = false;
            if (lowStockAlertType == 'Count') {
              isLowStock = currentStock <= lowStockAlert;
            } else if (lowStockAlertType == 'Percentage') {
              // Assuming initial stock was stored or we use a reasonable estimate
              // For simplicity, we'll use current stock vs alert percentage
              isLowStock = currentStock <= lowStockAlert;
            }

            if (isLowStock) {
              hasLowStockProducts = true;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _categories.clear();
          _categories.add('All');
          if (hasLowStockProducts) {
            _categories.add('Low Stock');
          }
          _categories.add('Favorite'); // Heart icon tab
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

    setState(() {});
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() {});
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

  Future<void> _directPrintWithCash() async {
    if (_cart.isEmpty) {
      CommonWidgets.showSnackBar(context, 'Cart is empty!', bgColor: kOrange);
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // Generate invoice number
      final invoiceNumber = await NumberGeneratorService.generateInvoiceNumber();

      // Check connectivity
      bool isOnline = false;
      try {
        final connectivityResult = await Connectivity().checkConnectivity().timeout(
          const Duration(seconds: 2),
          onTimeout: () => [ConnectivityResult.none],
        );
        isOnline = !connectivityResult.contains(ConnectivityResult.none);
      } catch (e) {
        isOnline = false;
      }

      // Fetch business details
      final businessDetails = await _fetchBusinessDetails();
      final staffName = await _fetchStaffName(widget.uid);
      final businessName = businessDetails['businessName'];
      final businessLocation = businessDetails['location'];
      final businessPhone = businessDetails['businessPhone'];

      debugPrint('✅ Using Business Name: $businessName');
      debugPrint('✅ Using Location: $businessLocation');
      debugPrint('✅ Using Phone: $businessPhone');
      debugPrint('✅ Staff Name: $staffName');

      // Calculate tax information
      final Map<String, double> taxMap = {};
      for (var item in _cart) {
        if (item.taxAmount > 0 && item.taxName != null) {
          taxMap[item.taxName!] = (taxMap[item.taxName!] ?? 0.0) + item.taxAmount;
        }
      }
      final taxList = taxMap.entries.map((e) => {'name': e.key, 'amount': e.value}).toList();
      final totalTax = taxMap.values.fold(0.0, (a, b) => a + b);

      final subtotalAmount = _cart.fold(0.0, (sum, item) {
        if (item.taxType == 'Price includes Tax') {
          return sum + (item.basePrice * item.quantity);
        } else {
          return sum + item.total;
        }
      });
      final totalWithTax = _cart.fold(0.0, (sum, item) => sum + item.totalWithTax);

      // Base sale data
      final baseSaleData = {
        'invoiceNumber': invoiceNumber,
        'items': _cart.map((e) => {
          'productId': e.productId,
          'name': e.name,
          'quantity': e.quantity,
          'price': e.price,
          'total': e.total
        }).toList(),
        'subtotal': _total,
        'discount': 0.0,
        'total': _total,
        'taxes': taxList,
        'totalTax': totalTax,
        'paymentMode': 'Cash',
        'cashReceived': _total,
        'change': 0.0,
        'creditAmount': 0.0,
        'date': DateTime.now().toIso8601String(),
        'staffId': widget.uid,
        'staffName': staffName ?? 'Staff',
        'businessLocation': businessLocation ?? 'Location',
        'businessPhone': businessPhone ?? '',
        'businessName': businessName ?? 'Business',
      };

      if (isOnline) {
        // Save online
        final saleData = {...baseSaleData, 'timestamp': FieldValue.serverTimestamp()};
        await FirestoreService().addDocument('sales', saleData).timeout(const Duration(seconds: 10));
        await _updateProductStock();
      } else {
        // Save offline
        final saleSyncService = context.read<SaleSyncService>();
        final sale = Sale(
          id: invoiceNumber,
          data: baseSaleData,
          isSynced: false,
        );
        await saleSyncService.saveSale(sale);
        final localStockService = context.read<LocalStockService>();
        for (var item in _cart) {
          if (item.productId.isNotEmpty) {
            final currentStock = localStockService.getStock(item.productId);
            final newStock = currentStock - item.quantity;
            localStockService.cacheStock(item.productId, newStock);
          }
        }
      }

      // Close loading dialog
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      // Navigate to Invoice
      if (mounted) {
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(
            builder: (_) => InvoicePage(
              uid: widget.uid,
              userEmail: widget.userEmail,
              businessName: businessName ?? 'Business',
              businessLocation: businessLocation ?? 'Location',
              businessPhone: businessPhone ?? '',
              invoiceNumber: invoiceNumber,
              dateTime: DateTime.now(),
              items: _cart.map((e) => {
                'name': e.name,
                'quantity': e.quantity,
                'price': e.price,
                'total': e.totalWithTax,
                'taxPercentage': e.taxPercentage ?? 0,
                'taxAmount': e.taxAmount,
              }).toList(),
              subtotal: subtotalAmount,
              discount: 0.0,
              taxes: taxList,
              total: totalWithTax,
              paymentMode: 'Cash',
              cashReceived: _total,
            ),
          ),
        ).then((_) {
          // Clear cart after invoice
          _cart.clear();
          widget.onCartChanged?.call(_cart);
          if (mounted) setState(() {});
        });
      }
    } catch (e) {
      debugPrint('Error in direct print: $e');
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        CommonWidgets.showSnackBar(context, 'Error: ${e.toString()}', bgColor: kErrorColor);
      }
    }
  }

  Future<Map<String, String?>> _fetchBusinessDetails() async {
    try {
      debugPrint('🔍 Fetching business details for uid: ${widget.uid}');

      // Use FirestoreService to get current store document
      final firestoreService = FirestoreService();
      final storeDoc = await firestoreService.getCurrentStoreDoc();

      debugPrint('📄 Store doc exists: ${storeDoc?.exists}');

      if (storeDoc != null && storeDoc.exists) {
        final data = storeDoc.data() as Map<String, dynamic>?;
        debugPrint('📦 Store data: $data');
        debugPrint('🏢 Business Name: ${data?['businessName']}');
        debugPrint('📍 Location: ${data?['location']} or ${data?['businessLocation']}');
        debugPrint('📞 Phone: ${data?['businessPhone']}');

        return {
          'businessName': data?['businessName'] as String?,
          'location': data?['location'] as String? ?? data?['businessLocation'] as String?,
          'businessPhone': data?['businessPhone'] as String?,
        };
      }

      debugPrint('⚠️ Returning null business details - store doc not found');
      return {'businessName': null, 'location': null, 'businessPhone': null};
    } catch (e) {
      debugPrint('❌ Error fetching business details: $e');
      return {'businessName': null, 'location': null, 'businessPhone': null};
    }
  }

  Future<String?> _fetchStaffName(String uid) async {
    try {
      debugPrint('👤 Fetching staff name for uid: $uid');
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final staffName = userDoc.data()?['name'];
      debugPrint('👤 Staff name: $staffName');
      return staffName;
    } catch (e) {
      debugPrint('❌ Error fetching staff name: $e');
      return null;
    }
  }

  Future<void> _updateProductStock() async {
    final localStockService = context.read<LocalStockService>();
    for (var item in _cart) {
      if (item.productId.isNotEmpty) {
        try {
          final productRef = await FirestoreService().getStoreCollection('Products');
          final doc = await productRef.doc(item.productId).get();
          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            final currentStock = (data['currentStock'] ?? 0.0).toDouble();
            final newStock = currentStock - item.quantity;
            await productRef.doc(item.productId).update({'currentStock': newStock});
            localStockService.cacheStock(item.productId, newStock.toInt());
          }
        } catch (e) {
          debugPrint('Error updating stock for ${item.productId}: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: () {
        // Unfocus the search field when tapping anywhere on the screen
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
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
            // Build action buttons with customer selection
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
            onCustomer: () {
              CommonWidgets.showCustomerSelectionDialog(
                context: context,
                onCustomerSelected: (phone, name, gst) {
                  setState(() {
                    _selectedCustomerPhone = phone;
                    _selectedCustomerName = name;
                    _selectedCustomerGST = gst;
                  });
                  // Notify parent about customer selection
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
                focusNode: _searchFocusNode,
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
                boxShadow: [BoxShadow(color: kPrimaryColor.withAlpha((0.2 * 255).toInt()), blurRadius: 8, offset: const Offset(0, 4))],
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
            final isSelected = _selectedCategory == (cat == 'All' ? context.tr('all') : cat) || (_showFavoritesOnly && cat == 'Favorite');
            final isLowStock = cat == 'Low Stock';

            return GestureDetector(
              onTap: () {
                if (cat == 'Favorite') {
                  setState(() {
                    _showFavoritesOnly = true;
                    _selectedCategory = cat;
                  });
                } else {
                  setState(() {
                    _showFavoritesOnly = false;
                    _selectedCategory = (cat == 'All' ? context.tr('all') : cat);
                  });
                }
              },
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: isSelected ? (isLowStock ? kOrange : kPrimaryColor) : kWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isSelected ? (isLowStock ? kOrange : kPrimaryColor) : kGrey200),
                  boxShadow: isSelected ? [BoxShadow(color: (isLowStock ? kOrange : kPrimaryColor).withAlpha((0.2 * 255).toInt()), blurRadius: 6, offset: const Offset(0, 3))] : null,
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
                            color: isSelected ? kWhite : (isLowStock ? kOrange : kBlack54),
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
          final productCode = (data['productCode'] ?? '').toString().toLowerCase();
          final matchesSearch = name.contains(_query) || barcode.contains(_query) || productCode.contains(_query);
          if (!matchesSearch) return false;

          if (_showFavoritesOnly) return data['isFavorite'] == true;

          if (_selectedCategory == 'Low Stock') {
            // Check if product has low stock
            final stockEnabled = data['stockEnabled'] ?? false;
            if (!stockEnabled) return false;

            final currentStock = (data['currentStock'] ?? 0.0).toDouble();
            final lowStockAlert = (data['lowStockAlert'] ?? 0.0).toDouble();
            final lowStockAlertType = data['lowStockAlertType'] ?? 'Count';

            if (lowStockAlert <= 0) return false;

            if (lowStockAlertType == 'Count') {
              return currentStock <= lowStockAlert;
            } else if (lowStockAlertType == 'Percentage') {
              return currentStock <= lowStockAlert;
            }
            return false;
          }

          if (_selectedCategory == context.tr('all')) return true;
          return (data['category'] ?? 'General').toString() == _selectedCategory;
        }).toList();

        if (filtered.isEmpty) return Center(child: Text(context.tr('no_results'), style: const TextStyle(color: kBlack54)));

        // Sort favorite products to the top
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
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, height: 1.2, color: kBlack87),
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
                        "${price.toStringAsFixed(0)}",
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: kPrimaryColor),
                      ),
                      const SizedBox(height: 4),
                      if (stockEnabled)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isOutOfStock ? kErrorColor.withAlpha((0.1 * 255).toInt()) : (isLowStock ? kGoogleYellow.withAlpha((0.1 * 255).toInt()) : kGoogleGreen.withAlpha((0.1 * 255).toInt())),
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









