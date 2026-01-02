import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:maxbillup/Sales/QuickSale.dart';
import 'package:maxbillup/Sales/Saved.dart';
import 'package:maxbillup/Sales/components/sale_app_bar.dart';
import 'package:maxbillup/Sales/saleall.dart';
import 'package:maxbillup/components/common_bottom_nav.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/services/cart_service.dart';

class NewSalePage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final Map<String, dynamic>? savedOrderData;
  final String? savedOrderId;

  const NewSalePage({
    super.key,
    required this.uid,
    this.userEmail,
    this.savedOrderData,
    this.savedOrderId,
  });

  @override
  State<NewSalePage> createState() => _NewSalePageState();
}

class _NewSalePageState extends State<NewSalePage> with SingleTickerProviderStateMixin {
  int _selectedTabIndex = 1;
  List<CartItem>? _sharedCartItems;
  String? _loadedSavedOrderId;
  bool _isSearchFocused = false; // Track search focus state

  // Track specific highlighted product ID
  String? _highlightedProductId;

  // Animation counter to force re-animation of same product
  int _animationCounter = 0;

  // Animation controller for smooth highlight effect
  AnimationController? _highlightController;
  Animation<Color?>? _highlightAnimation;

  int _cartVersion = 0;

  late String _uid;
  String? _userEmail;

  double _cartHeight = 200;
  final double _minCartHeight = 200;
  double _maxCartHeight = 600;

  String? _selectedCustomerPhone;
  String? _selectedCustomerName;
  String? _selectedCustomerGST;

  // Saved ordecount
  int _savedOrderCount = 0;

  @override
  void initState() {
    super.initState();
    _uid = widget.uid;
    _userEmail = widget.userEmail;

    // Initialize animation controller
    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 1000),  // Increased from 600ms to 1000ms for better visibility
      vsync: this,
    );

    _highlightAnimation = ColorTween(
      begin: Colors.green.withValues(alpha: 0.6),  // More prominent green (60% opacity)
      end: Colors.green.withValues(alpha: 0.0),    // Fade to transparent
    ).animate(CurvedAnimation(
      parent: _highlightController!,
      curve: Curves.easeOut,  // Smooth fade out
    ));

    // Load cart from CartService (persisted across navigation)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cartService = context.read<CartService>();
      if (cartService.hasItems) {
        setState(() {
          _sharedCartItems = List<CartItem>.from(cartService.cartItems);
          _loadedSavedOrderId = cartService.savedOrderId;
          _selectedCustomerPhone = cartService.customerPhone;
          _selectedCustomerName = cartService.customerName;
          _selectedCustomerGST = cartService.customerGST;
        });
      }
    });

    if (widget.savedOrderData != null) {
      _loadSavedOrderData(widget.savedOrderData!);
      _loadedSavedOrderId = widget.savedOrderId;
      _selectedTabIndex = 1; // Switch to "All" tab to show the cart with items
    }

    // Listen to saved ordecount
    _listenToSavedOrdersCount();
  }

  @override
  void dispose() {
    _highlightController?.dispose();
    super.dispose();
  }

  void _listenToSavedOrdersCount() async {
    try {
      final firestoreService = FirestoreService();
      final stream = await firestoreService.getCollectionStream('savedOrders');
      stream.listen((snapshot) {
        if (mounted) {
          setState(() {
            _savedOrderCount = snapshot.docs.length;
          });
        }
      });
    } catch (e) {
      // Handle error silently
    }
  }

  void _loadSavedOrderData(Map<String, dynamic> orderData) {
    final items = orderData['items'] as List<dynamic>?;
    if (items != null && items.isNotEmpty) {
      final cartItems = items
          .map((item) => CartItem(
        productId: item['productId'] ?? '',
        name: item['name'] ?? '',
        price: (item['price'] ?? 0).toDouble(),
        quantity: item['quantity'] ?? 1,
      ))
          .toList();

      // Sync with CartService for persistence
      context.read<CartService>().updateCart(cartItems);
      context.read<CartService>().setCustomer(
        orderData['customerPhone'] as String?,
        orderData['customerName'] as String?,
        orderData['customerGST'] as String?,
      );

      setState(() {
        _sharedCartItems = cartItems;
        // Load customer information from saved order
        _selectedCustomerName = orderData['customerName'] as String?;
        _selectedCustomerPhone = orderData['customerPhone'] as String?;
        _selectedCustomerGST = orderData['customerGST'] as String?;
      });
    }
  }

  void _handleTabChange(int index) {
    setState(() {
      _selectedTabIndex = index;
    });
  }

  void _handleLoadSavedOrder(String orderId, Map<String, dynamic> data) {
    // Load the order data
    _loadSavedOrderData(data);
    _loadedSavedOrderId = orderId;

    // Switch to "View All" tab (index 1)
    setState(() {
      _selectedTabIndex = 1;
      _cartVersion++; // Increment to refresh the view
    });
  }

  void _handleSearchFocusChange(bool isFocused) {
    print('🔍 Search focus changed: $isFocused'); // Debug
    setState(() {
      _isSearchFocused = isFocused;
    });
    print('🔍 State updated - _isSearchFocused: $_isSearchFocused, shouldShowCart: ${_sharedCartItems != null && _sharedCartItems!.isNotEmpty}'); // Debug
  }

  /// Enhanced logic to detect which specific item changed and trigger its highlight.
  void _updateCartItems(List<CartItem> items) {
    print('🔄 _updateCartItems called with ${items.length} items');
    String? triggerId;
    List<CartItem> updatedItems = List<CartItem>.from(items);

    // Sync with CartService for persistence across navigation
    context.read<CartService>().updateCart(updatedItems);

    // Simple approach: The first item in the cart is always the one just added/modified
    // because saleall.dart moves it to index 0
    if (items.isNotEmpty) {
      triggerId = items[0].productId;
      print('✅ Triggering animation for first item (most recently modified): $triggerId');
    }

    print('🎯 Final triggerId: $triggerId');

    // Move the triggered item to the top (should already be there, but ensure it)
    if (triggerId != null) {
      final idx = updatedItems.indexWhere((e) => e.productId == triggerId);
      if (idx != -1 && idx != 0) {
        final item = updatedItems.removeAt(idx);
        updatedItems.insert(0, item);
      }

      // Always trigger highlight - the counter ensures animation restarts even for same item
      print('🟢 Calling _triggerHighlight for $triggerId');
      _triggerHighlight(triggerId, updatedItems);
    } else {
      print('⚠️ No trigger detected, just updating state');
      setState(() {
        _sharedCartItems = updatedItems.isNotEmpty ? updatedItems : null;
      });
    }
  }

  void _triggerHighlight(String productId, List<CartItem> updatedItems) {
    print('🎬 _triggerHighlight called for productId: $productId');
    print('   Current _highlightedProductId: $_highlightedProductId');
    print('   Current _animationCounter: $_animationCounter');

    // Always reset and restart animation, even for same product
    _highlightController?.reset();
    print('   ✓ Animation controller reset');

    setState(() {
      _highlightedProductId = productId;
      _animationCounter++; // Increment to force state change
      _sharedCartItems = updatedItems.isNotEmpty ? updatedItems : null;
      print('   ✓ State updated - new counter: $_animationCounter');
    });

    // Start the highlight animation
    _highlightController?.forward();
    print('   ✓ Animation started forward');

    // Clear highlight after animation completes + delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _highlightedProductId == productId) {
        print('   🔚 Clearing highlight for $productId');
        setState(() {
          _highlightedProductId = null;
        });
      }
    });
  }

  void _removeSingleItem(int idx) {
    if (_sharedCartItems == null) return;
    final updatedList = List<CartItem>.from(_sharedCartItems!);
    updatedList.removeAt(idx);
    setState(() {
      _cartVersion++;
    });
    _updateCartItems(updatedList);
  }

  void _showEditCartItemDialog(int idx) async {
    final item = _sharedCartItems![idx];
    final nameController = TextEditingController(text: item.name);
    final priceController = TextEditingController(text: item.price.toString());
    final qtyController = TextEditingController(text: item.quantity.toString());

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Edit Cart Item', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dialogLabel('Product Name'),
                  _dialogInput(nameController, 'Enter product name'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _dialogLabel('Price'),
                            _dialogInput(priceController, '0.00', isNumber: true),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _dialogLabel('Quantity'),
                            Container(
                              decoration: BoxDecoration(
                                color: kGreyBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: kGrey300),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      int current = int.tryParse(qtyController.text) ?? 1;
                                      if (current > 1) {
                                        setDialogState(() => qtyController.text = (current - 1).toString());
                                      } else {
                                        Navigator.of(context).pop();
                                        _removeSingleItem(idx);
                                      }
                                    },
                                    icon: Icon(
                                      (int.tryParse(qtyController.text) ?? 1) <= 1 ? Icons.delete_outline : Icons.remove,
                                      color: (int.tryParse(qtyController.text) ?? 1) <= 1 ? kErrorColor : kPrimaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: qtyController,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      onChanged: (v) => setDialogState(() {}),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      int current = int.tryParse(qtyController.text) ?? 0;
                                      setDialogState(() => qtyController.text = (current + 1).toString());
                                    },
                                    icon: const Icon(Icons.add, color: kPrimaryColor, size: 20),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _removeSingleItem(idx);
                    },
                    icon: const Icon(Icons.delete_outline, color: kErrorColor, size: 18),
                    label: const Text('Remove', style: TextStyle(color: kErrorColor,fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final newName = nameController.text.trim();
                      final newPrice = double.tryParse(priceController.text.trim()) ?? item.price;
                      final newQty = int.tryParse(qtyController.text.trim()) ?? 1;

                      if (newQty <= 0) {
                        Navigator.of(context).pop();
                        _removeSingleItem(idx);
                      } else {
                        final updatedItems = List<CartItem>.from(_sharedCartItems!);
                        updatedItems[idx] = CartItem(
                          productId: item.productId,
                          name: newName,
                          price: newPrice,
                          quantity: newQty,
                          taxName: item.taxName,
                          taxPercentage: item.taxPercentage,
                          taxType: item.taxType,
                        );
                        _updateCartItems(updatedItems);
                        Navigator.of(context).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Save Changes', style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          );
        });
      },
    );
  }

  void _handleClearCart() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Cart?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('This will remove all items from your current order and reset the page.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep Items', style: TextStyle(color: Colors.grey[600],fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Clear Total Cart', style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Clear CartService for persistence
      context.read<CartService>().clearCart();

      setState(() {
        _sharedCartItems = null;
        _loadedSavedOrderId = null;
        _cartVersion++;
        _highlightedProductId = null;
        // Reset search focus when cart is cleared to show AppBar and categories
        _isSearchFocused = false;
        // Clear customer info
        _selectedCustomerPhone = null;
        _selectedCustomerName = null;
        _selectedCustomerGST = null;
      });
      _updateCartItems([]);

      // Unfocus search field in child pages after dialog closes
      if (mounted) {
        // Use post frame callback to ensure dialog is closed first
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // Clear all focus in the entire focus tree
            FocusManager.instance.primaryFocus?.unfocus();
          }
        });
      }
    }
  }

  Widget _dialogLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6, left: 4),
    child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black54)),
  );

  Widget _dialogInput(TextEditingController ctrl, String hint, {bool isNumber = false, bool enabled = true}) {
    return TextField(
      controller: ctrl,
      enabled: enabled,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: TextStyle(
        fontSize: 15,
       fontWeight: FontWeight.bold,
        color: enabled ? Colors.black : Colors.black45,
      ),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: enabled ? const Color(0xFFF8FAFC) : Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5)),
      ),
    );
  }

  void _setSelectedCustomer(String? phone, String? name, String? gst) {
    // Sync with CartService for persistence
    context.read<CartService>().setCustomer(phone, name, gst);

    setState(() {
      _selectedCustomerPhone = phone;
      _selectedCustomerName = name;
      _selectedCustomerGST = gst;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;

    _maxCartHeight = screenHeight - topPadding - 175;

    // Listen to CartService for changes (e.g., when cart is cleared from Bill page)
    final cartService = Provider.of<CartService>(context);

    // Sync local cart state with CartService
    if (cartService.cartItems.isEmpty && _sharedCartItems != null) {
      // Cart was cleared externally (e.g., from Bill page)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _sharedCartItems = null;
            _selectedCustomerPhone = null;
            _selectedCustomerName = null;
            _selectedCustomerGST = null;
            _loadedSavedOrderId = null;
          });
        }
      });
    } else if (cartService.cartItems.isNotEmpty && (_sharedCartItems == null || _sharedCartItems!.length != cartService.cartItems.length)) {
      // Cart was updated externally, sync it
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _sharedCartItems = List<CartItem>.from(cartService.cartItems);
          });
        }
      });
    }

    // Calculate dynamic cart height based on search focus
    // 120px in search mode: enough for header(40px) + 1 item(40px) + footer(40px)
    final double dynamicCartHeight = _isSearchFocused ? 120 : _cartHeight;
    final bool shouldShowCart = _sharedCartItems != null && _sharedCartItems!.isNotEmpty;

    // Only reserve space for minimum cart height to allow overlay expansion
    final double reservedCartSpace = shouldShowCart ? (_isSearchFocused ? 120 : _minCartHeight) : 0;

    print('🎨 Building NewSale - Focus: $_isSearchFocused, ShowCart: $shouldShowCart, CartHeight: $dynamicCartHeight'); // Debug

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Column(
            children: [
              // Top spacing: only reserve space for minimum cart height
              // This allows cart to expand and overlay other content
              SizedBox(
                height: topPadding+2 + (reservedCartSpace > 0 ? reservedCartSpace + 12 : 0),
              ),

              // AppBar: Only show when search is NOT focused
              if (!_isSearchFocused)
                SaleAppBar(
                  selectedTabIndex: _selectedTabIndex,
                  onTabChanged: _handleTabChange,
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                  uid: _uid,
                  userEmail: _userEmail,
                  savedOrderCount: _savedOrderCount,
                ),

              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _selectedTabIndex == 0
                      ? SavedOrdersPage(
                        key: ValueKey('saved_$_cartVersion'),
                        uid: _uid,
                        userEmail: _userEmail,
                        onLoadOrder: _handleLoadSavedOrder,
                      )
                      : _selectedTabIndex == 1
                      ? SaleAllPage(
                        key: ValueKey('all_$_cartVersion'),
                        uid: _uid,
                        userEmail: _userEmail,
                        onCartChanged: _updateCartItems,
                        initialCartItems: _sharedCartItems,
                        savedOrderId: _loadedSavedOrderId,
                        onSearchFocusChanged: _handleSearchFocusChange,
                        customerPhone: _selectedCustomerPhone,
                        customerName: _selectedCustomerName,
                        customerGST: _selectedCustomerGST,
                        onCustomerChanged: _setSelectedCustomer,
                      )
                      : QuickSalePage(
                        key: ValueKey('quick_$_cartVersion'),
                        uid: _uid,
                        userEmail: _userEmail,
                        initialCartItems: _sharedCartItems,
                        onCartChanged: _updateCartItems,
                        savedOrderId: _loadedSavedOrderId,
                        customerPhone: _selectedCustomerPhone,
                        customerName: _selectedCustomerName,
                        customerGST: _selectedCustomerGST,
                        onCustomerChanged: _setSelectedCustomer,
                      ),
                ),
              ),
            ],
          ),

          // Cart overlay: Always show when there are items (with dynamic height)
          if (shouldShowCart)
            Positioned(
              top: topPadding + 3,
              left: 0,
              right: 0,
              child: _buildCartSection(screenWidth, dynamicCartHeight),
            ),
        ],
      ),
      bottomNavigationBar: CommonBottomNav(
        uid: _uid,
        userEmail: _userEmail,
        currentIndex: 2,
        screenWidth: screenWidth,
      ),
    );
  }

  Widget _buildCartSection(double w, double currentHeight) {
    final bool isSearchFocused = currentHeight <= 150; // Detect if in search focus mode (120px or less)

    return GestureDetector(
      // Disable drag gestures when in search focus mode
      onVerticalDragUpdate: isSearchFocused ? null : (details) {
        setState(() {
          if (details.delta.dy > 10) {
            // User pulled down quickly, expand fully
            _cartHeight = _maxCartHeight;
          } else if (details.delta.dy < -10) {
            // User pulled up quickly, collapse to minimum
            _cartHeight = _minCartHeight;
          } else {
            // Normal drag, keep smooth resizing
            _cartHeight = (_cartHeight + details.delta.dy).clamp(_minCartHeight, _maxCartHeight);
          }
        });
      },
      onDoubleTap: isSearchFocused ? null : () {
        setState(() {
          if (_cartHeight < _maxCartHeight * 0.95) {
            _cartHeight = _maxCartHeight+100;
          } else {
            _cartHeight = _minCartHeight;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        height: currentHeight,
        margin: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kOrange, width: 2),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isSearchFocused ? 6 : 12, // Reduced padding in search mode
              ),
              decoration: const BoxDecoration(
                color: kOrange,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  Expanded(flex: 4, child: Text('Product', style: TextStyle(fontWeight: FontWeight.w800, fontSize: isSearchFocused ? 11 : 12, color: Colors.black))),
                  Expanded(flex: 2, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: isSearchFocused ? 11 : 12, color: Colors.black))),
                  Expanded(flex: 2, child: Text('Price', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: isSearchFocused ? 11 : 12, color: Colors.black))),
                  Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, fontSize: isSearchFocused ? 11 : 12, color: Colors.black))),
                ],
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: _highlightAnimation!,
                builder: (context, child) {
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 0),
                    itemCount: _sharedCartItems?.length ?? 0,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
                    itemBuilder: (ctx, idx) {
                      final item = _sharedCartItems![idx];
                      final bool isHighlighted = item.productId == _highlightedProductId;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: isSearchFocused ? 4 : 8, // Reduced padding in search mode
                        ),
                        decoration: BoxDecoration(
                          // Use animated color for smooth transition
                          color: isHighlighted ? _highlightAnimation!.value : Colors.transparent,
                          borderRadius: BorderRadius.circular(0),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () => _showEditCartItemDialog(idx),
                                    child: const Icon(Icons.edit, color: kPrimaryColor, size: 16),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(flex: 2, child: Text('${item.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                            Expanded(flex: 2, child: Text(item.price.toStringAsFixed(0), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13))),
                            Expanded(
                              flex: 2,
                              child: Text(
                                item.total.toStringAsFixed(0),
                                textAlign: TextAlign.right,
                                style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isSearchFocused ? 4 : 8, // Reduced padding in search mode
              ),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.03),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                border: Border(top: BorderSide(color: kGrey300.withOpacity(0.5))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _handleClearCart,
                    child: Row(
                      children: [
                        const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 4),
                        Text('Clear', style: TextStyle(color: Colors.redAccent.withOpacity(0.8), fontWeight: FontWeight.w800, fontSize: 13)),
                      ],
                    ),
                  ),
                  const Icon(Icons.drag_handle_rounded, color: Colors.grey, size: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: kPrimaryColor, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      '${_sharedCartItems?.length ?? 0} Items',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

