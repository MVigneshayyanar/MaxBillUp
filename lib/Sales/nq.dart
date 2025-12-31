import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:maxbillup/Sales/QuickSale.dart';
import 'package:maxbillup/Sales/Saved.dart';
import 'package:maxbillup/Sales/Quotation.dart';
import 'package:maxbillup/Sales/components/sale_app_bar.dart';
import 'package:maxbillup/Sales/components/common_widgets.dart';
import 'package:maxbillup/Sales/saleall.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/Colors.dart';

class NewQuotationPage extends StatefulWidget {
  final String uid;
  final String? userEmail;

  const NewQuotationPage({
    super.key,
    required this.uid,
    this.userEmail,
  });

  @override
  State<NewQuotationPage> createState() => _NewQuotationPageState();
}

class _NewQuotationPageState extends State<NewQuotationPage> with SingleTickerProviderStateMixin {
  int _selectedTabIndex = 1; // Start with View All tab (index 1)
  List<CartItem>? _sharedCartItems;
  bool _isSearchFocused = false; // Track search focus state

  // Track specific highlighted product ID
  String? _highlightedProductId;

  // Animation counter to force re-animation of same product
  int _animationCounter = 0;

  // Animation controller for smooth highlight effect
  AnimationController? _highlightController;
  Animation<Color?>? _highlightAnimation;

  double _cartHeight = 200;
  final double _minCartHeight = 200;
  double _maxCartHeight = 800;

  // Customer selection state (shared across tabs)
  String? _selectedCustomerPhone;
  String? _selectedCustomerName;
  String? _selectedCustomerGST;

  // Add a version key to force rebuild when cart is cleared
  int _cartVersion = 0;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 1000),  // Increased from 600ms to 1000ms
      vsync: this,
    );

    _highlightAnimation = ColorTween(
      begin: Colors.green.withValues(alpha: 0.6),  // More prominent green (60% opacity)
      end: Colors.green.withValues(alpha: 0.0),    // Fade to transparent
    ).animate(CurvedAnimation(
      parent: _highlightController!,
      curve: Curves.easeOut,  // Smooth fade out
    ));
  }

  @override
  void dispose() {
    _highlightController?.dispose();
    super.dispose();
  }

  void _handleTabChange(int index) {
    setState(() {
      _selectedTabIndex = index;
    });
  }

  void _updateCartItems(List<CartItem> items, {String? triggerId}) {
    print('🔄 [nq.dart] _updateCartItems called with ${items.length} items, triggerId: $triggerId');
    List<CartItem> updatedItems = List<CartItem>.from(items);

    // Simple approach: The first item in the cart is always the one just added/modified
    // because SaleAllPage and QuickSalePage move it to index 0
    if (items.isNotEmpty) {
      final firstItemId = items[0].productId;
      print('✅ [nq.dart] Triggering animation for first item: $firstItemId');
      _triggerHighlight(firstItemId, updatedItems);
    } else {
      print('⚠️ [nq.dart] Cart is empty, just updating state');
      setState(() {
        _sharedCartItems = updatedItems.isNotEmpty ? updatedItems : null;
        if (updatedItems.isEmpty) {
          _cartVersion++;
        }
      });
    }
  }

  void _triggerHighlight(String productId, List<CartItem> updatedItems) {
    print('🎬 [nq.dart] _triggerHighlight called for productId: $productId');
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
        print('   🔚 [nq.dart] Clearing highlight for $productId');
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
      barrierColor: Colors.black.withValues(alpha: 0.7),
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
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    int qty = int.tryParse(qtyController.text) ?? 1;
                                    if (qty > 1) {
                                      setDialogState(() => qtyController.text = (qty - 1).toString());
                                    }
                                  },
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                ),
                                Expanded(
                                  child: _dialogInput(qtyController, '1', isNumber: true, enabled: true),
                                ),
                                IconButton(
                                  onPressed: () {
                                    int qty = int.tryParse(qtyController.text) ?? 1;
                                    setDialogState(() => qtyController.text = (qty + 1).toString());
                                  },
                                  icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => _removeSingleItem(idx),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          final updatedList = List<CartItem>.from(_sharedCartItems!);
                          final name = nameController.text.trim();
                          final price = double.tryParse(priceController.text) ?? item.price;
                          final qty = double.tryParse(qtyController.text) ?? item.quantity;

                          if (name.isNotEmpty && price > 0 && qty > 0) {
                            updatedList[idx] = CartItem(
                              productId: item.productId,
                              name: name,
                              price: price,
                              quantity: qty.toInt(), // Convert to int
                              taxPercentage: item.taxPercentage,
                              taxName: item.taxName,
                              taxType: item.taxType,
                            );
                            _updateCartItems(updatedList);
                            Navigator.of(context).pop();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  void _handleClearCart() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Cart', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to remove all items from the cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep Items', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Clear Total Cart', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _sharedCartItems = null;
        _cartVersion++;
        _highlightedProductId = null;
        // Reset search focus when cart is cleared
        _isSearchFocused = false;
      });
      _updateCartItems([]);

      // Unfocus search field in child pages after dialog closes
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
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

  void _handleSearchFocusChange(bool isFocused) {
    setState(() {
      _isSearchFocused = isFocused;
    });
  }

  // Handle customer selection changes (shared across tabs)
  void _setSelectedCustomer(String? phone, String? name, String? gst) {
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

    // Calculate dynamic cart height based on search focus
    // 120px in search mode: enough for header(40px) + 1 item(40px) + footer(40px)
    final double dynamicCartHeight = _isSearchFocused ? 120 : _cartHeight;
    final bool shouldShowCart = _sharedCartItems != null && _sharedCartItems!.isNotEmpty;

    // Only reserve space for minimum cart height to allow overlay expansion
    final double reservedCartSpace = shouldShowCart ? (_isSearchFocused ? 105 : _minCartHeight) : 0;

    return Scaffold(
      backgroundColor: Colors.white, // Changed from Color(0xFFF5F5F5) to Colors.white
      resizeToAvoidBottomInset: false, // Prevent keyboard from pushing widgets
      body: Stack(
        children: [
          Column(
            spacing: 0,
            children: [
              // Top spacing: only reserve space for minimum cart height
              // This allows cart to expand and overlay other content
              SizedBox(
                height: topPadding + 10 + (reservedCartSpace > 0 ? reservedCartSpace + 12 : 0),
              ),

              // App Bar Component with back button and tabs (Saved tab hidden)
              // Hide AppBar when search is focused
              if (!_isSearchFocused)
                SaleAppBar(
                  selectedTabIndex: _selectedTabIndex,
                  onTabChanged: _handleTabChange,
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                  uid: widget.uid,
                  userEmail: widget.userEmail,
                  hideSavedTab: true, // Hide the Saved tab
                  showBackButton: true, // Show back button
                ),

              // Content Area - Show content based on selected tab
              Expanded(
                child: _selectedTabIndex == 0
                    ? SavedOrdersPage(
                        uid: widget.uid,
                        userEmail: widget.userEmail,
                      )
                    : _selectedTabIndex == 1
                        ? SaleAllPage(
                            key: ValueKey('sale_all_$_cartVersion'), // Force rebuild when cart is cleared
                            uid: widget.uid,
                            userEmail: widget.userEmail,
                            onCartChanged: _updateCartItems,
                            initialCartItems: _sharedCartItems,
                            isQuotationMode: true, // Quotation mode enabled
                            onSearchFocusChanged: _handleSearchFocusChange, // Pass callback
                            customerPhone: _selectedCustomerPhone,
                            customerName: _selectedCustomerName,
                            customerGST: _selectedCustomerGST,
                            onCustomerChanged: _setSelectedCustomer,
                          )
                        : QuickSalePage(
                            key: ValueKey('quick_sale_$_cartVersion'), // Force rebuild when cart is cleared
                            uid: widget.uid,
                            userEmail: widget.userEmail,
                            initialCartItems: _sharedCartItems,
                            onCartChanged: _updateCartItems,
                            isQuotationMode: true, // Enable quotation mode
                            customerPhone: _selectedCustomerPhone,
                            customerName: _selectedCustomerName,
                            customerGST: _selectedCustomerGST,
                            onCustomerChanged: _setSelectedCustomer,
                          ),
              ),
            ],
          ),

          // Cart overlay: Always show when there are items (with dynamic height)
          if (shouldShowCart)
            Positioned(
              top: topPadding + 10,
              left: 0,
              right: 0,
              child: _buildCartSection(screenWidth, dynamicCartHeight),
            ),
        ],
      ),
      // Bottom navigation bar with customer and quotation buttons
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Customer Button (Left)
              ElevatedButton(
                onPressed: _showCustomerSelectionDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2F7CF6), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((0.1 * 255).toInt()),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _selectedCustomerName != null && _selectedCustomerName!.isNotEmpty
                        ? Icons.person
                        : Icons.person_add_outlined,
                    color: kPrimaryColor,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Quotation Button (Right) - Expanded to fill remaining space
              Expanded(
                child: ElevatedButton(
                  onPressed: _createQuotation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    '${(_sharedCartItems?.fold(0.0, (sum, item) => sum + (item.price * item.quantity)) ?? 0.0).toStringAsFixed(0)}  Quotation',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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

  // Show customer selection dialog
  void _showCustomerSelectionDialog() {
    CommonWidgets.showCustomerSelectionDialog(
      context: context,
      onCustomerSelected: (phone, name, gst) {
        setState(() {
          _selectedCustomerPhone = phone.isEmpty ? null : phone;
          _selectedCustomerName = name.isEmpty ? null : name;
          _selectedCustomerGST = gst;
        });
      },
      selectedCustomerPhone: _selectedCustomerPhone,
    );
  }

  // Create quotation from cart items
  void _createQuotation() {
    if (_sharedCartItems == null || _sharedCartItems!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add items to create quotation'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Calculate total
    final total = _sharedCartItems!.fold(0.0, (sum, item) => sum + (item.price * item.quantity));

    // Navigate to Quotation page
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => QuotationPage(
          uid: widget.uid,
          userEmail: widget.userEmail,
          cartItems: _sharedCartItems!,
          totalAmount: total,
          customerPhone: _selectedCustomerPhone,
          customerName: _selectedCustomerName,
          customerGST: _selectedCustomerGST,
        ),
      ),
    ).then((_) {
      // Clear cart after quotation is created
      setState(() {
        _sharedCartItems = null;
      });
      _updateCartItems([]);
    });
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
            _cartHeight = _maxCartHeight;
          } else {
            _cartHeight = _minCartHeight;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        height: currentHeight,
        margin: const EdgeInsets.symmetric(horizontal: 12), // Removed .copyWith(bottom: 20)
        decoration: BoxDecoration(
          color: Colors.white, // Changed to Colors.white
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kOrange, width: 2), // Use kOrange instead of kGoogleYellow

        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isSearchFocused ? 6 : 12, // Reduced padding in search mode
              ),
              decoration: const BoxDecoration(
                color: Color(0xffffa51f),
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
                color: kPrimaryColor.withValues(alpha: 0.03),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                border: Border(top: BorderSide(color: kGrey300.withValues(alpha: 0.5))),
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
                        Text('Clear', style: TextStyle(color: Colors.redAccent.withValues(alpha: 0.8), fontWeight: FontWeight.w800, fontSize: 13)),
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
