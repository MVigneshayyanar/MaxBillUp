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

  // Animation controller for smooth highlight effect
  AnimationController? _highlightController;
  Animation<Color?>? _highlightAnimation;

  double _cartHeight = 200;
  final double _minCartHeight = 200;
  double _maxCartHeight = 600;

  // Customer selection state (shared across tabs)
  String? _selectedCustomerPhone;
  String? _selectedCustomerName;
  String? _selectedCustomerGST;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _highlightAnimation = ColorTween(
      begin: Colors.green.withValues(alpha: 0.4),
      end: Colors.green.withValues(alpha: 0.05),
    ).animate(CurvedAnimation(
      parent: _highlightController!,
      curve: Curves.easeInOut,
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

  void _updateCartItems(List<CartItem> items) {
    setState(() {
      _sharedCartItems = items.isNotEmpty ? List<CartItem>.from(items) : null;
    });
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

  void _showEditCartItemDialog(int idx) async {
    final item = _sharedCartItems![idx];
    final nameController = TextEditingController(text: item.name);
    final priceController = TextEditingController(text: item.price.toString());
    final qtyController = TextEditingController(text: item.quantity.toString());
    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8), // Dark overlay to hide background
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Cart Item'),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Product Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Price'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newName = nameController.text.trim();
                final newPrice = double.tryParse(priceController.text.trim()) ?? item.price;
                final newQty = int.tryParse(qtyController.text.trim()) ?? item.quantity;

                if (newName.isNotEmpty && newQty > 0) {
                  setState(() {
                    _sharedCartItems![idx] = CartItem(
                      productId: item.productId,
                      name: newName,
                      price: newPrice,
                      quantity: newQty,
                    );
                  });
                  _updateCartItems(_sharedCartItems!);
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      resizeToAvoidBottomInset: false, // Prevent keyboard from pushing widgets
      body: Column(
        spacing: 0,
        children: [
          // Top padding
          const SizedBox(height: 40),

          // Cart section (if present and search is not focused)
          if (_sharedCartItems != null && _sharedCartItems!.isNotEmpty && !_isSearchFocused)
            _buildCartSection(screenWidth),

          // App Bar Component with back button and tabs (Saved tab hidden)
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

  Widget _buildCartSection(double w) {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
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
      onDoubleTap: () {
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
        height: _cartHeight,
        margin: const EdgeInsets.symmetric(horizontal: 12).copyWith(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kGoogleYellow, width: 2),
          //boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xffffa51f),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 4, child: Text('Product', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.black))),
                  Expanded(flex: 2, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.black))),
                  Expanded(flex: 2, child: Text('Price', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.black))),
                  Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.black))),
                ],
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: _highlightAnimation!,
                builder: (context, child) {
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _sharedCartItems?.length ?? 0,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
                    itemBuilder: (ctx, idx) {
                      final item = _sharedCartItems![idx];
                      final bool isHighlighted = item.productId == _highlightedProductId;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          // Use animated color for smooth transition
                          color: isHighlighted ? _highlightAnimation!.value : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: kPrimaryColor.withValues(alpha: 0.03),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                border: Border(top: BorderSide(color: kGrey300.withValues(alpha: 0.5))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _sharedCartItems = null;
                      });
                      _updateCartItems([]);
                    },
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
