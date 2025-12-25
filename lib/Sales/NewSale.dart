import 'package:flutter/material.dart';
import 'package:maxbillup/Sales/QuickSale.dart';
import 'package:maxbillup/Sales/Saved.dart';
import 'package:maxbillup/Sales/components/sale_app_bar.dart';
import 'package:maxbillup/Sales/saleall.dart';
import 'package:maxbillup/components/common_bottom_nav.dart';
import 'package:maxbillup/models/cart_item.dart';

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

class _NewSalePageState extends State<NewSalePage> {
  int _selectedTabIndex = 0;
  List<CartItem>? _sharedCartItems;
  String? _loadedSavedOrderId;

  late String _uid;
  String? _userEmail;

  double _cartHeight = 180; // Initial collapsed height
  final double _minCartHeight = 120;
  final double _maxCartHeight = 300;

  @override
  void initState() {
    super.initState();
    _uid = widget.uid;
    _userEmail = widget.userEmail;

    if (widget.savedOrderData != null) {
      _loadSavedOrderData(widget.savedOrderData!);
      _loadedSavedOrderId = widget.savedOrderId;
      _selectedTabIndex = 0;
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

      setState(() {
        _sharedCartItems = cartItems;
      });
    }
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
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyController,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newName = nameController.text.trim();
                final newPrice = double.tryParse(priceController.text.trim()) ?? item.price;
                final newQty = int.tryParse(qtyController.text.trim()) ?? item.quantity;
                setState(() {
                  _sharedCartItems![idx] = CartItem(
                    productId: item.productId,
                    name: newName,
                    price: newPrice,
                    quantity: newQty,
                    taxName: item.taxName,
                    taxPercentage: item.taxPercentage,
                    taxType: item.taxType,
                  );
                });
                _updateCartItems(_sharedCartItems!);
                Navigator.of(context).pop();
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
      backgroundColor: const Color(0xFFFFFFFF),
      resizeToAvoidBottomInset: false, // Prevent keyboard from pushing widgets
      body: Column(
        spacing: 0,
        children: [
          // Always add 50px top padding at the top of the page
          const SizedBox(height: 40),

          // Cart section (if present)
          if (_sharedCartItems != null && _sharedCartItems!.isNotEmpty)
            _buildCartSection(screenWidth),

          // 2. App Bar Component below cart
          SaleAppBar(
            selectedTabIndex: _selectedTabIndex,
            onTabChanged: _handleTabChange,
            screenWidth: screenWidth,
            screenHeight: screenHeight,
            uid: _uid,
            userEmail: _userEmail,
          ),

          // 3. Content Area - Show content based on selected tab
          Expanded(
            child: _selectedTabIndex == 0
                ? SaleAllPage(
              uid: _uid,
              userEmail: _userEmail,
              onCartChanged: _updateCartItems,
              initialCartItems: _sharedCartItems,
              savedOrderId: _loadedSavedOrderId,
            )
                : _selectedTabIndex == 1
                ? QuickSalePage(
              uid: _uid,
              userEmail: _userEmail,
              initialCartItems: _sharedCartItems,
              onCartChanged: _updateCartItems,
              savedOrderId: _loadedSavedOrderId,
            )
                : SavedOrdersPage(
              uid: _uid,
              userEmail: _userEmail,
            ),
          ),
        ],
      ),
      // 4. Bottom Navigation Bar
      bottomNavigationBar: CommonBottomNav(
        uid: _uid,
        userEmail: _userEmail,
        currentIndex: 2,
        screenWidth: screenWidth,
      ),
    );
  }

  Widget _buildCartSection(double w) {
    final primaryColor = const Color(0xFF2F7CF6);
    return Padding(
      padding: const EdgeInsets.only(top: 0,bottom: 5), // Padding handled by SizedBox in Column
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          setState(() {
            _cartHeight = (_cartHeight + details.delta.dy).clamp(_minCartHeight, _maxCartHeight);
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.ease,
          height: _cartHeight,
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0,2))],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                decoration: BoxDecoration(
                  color: primaryColor,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        'Product',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
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
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Price',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Total',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
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
                    itemCount: _sharedCartItems?.length ?? 0,
                    itemBuilder: (ctx, idx) {
                      final item = _sharedCartItems![idx];

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            bottom: BorderSide(
                              color: primaryColor,
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
                                  GestureDetector(
                                    onTap: () => _showEditCartItemDialog(idx),
                                    child: const Icon(
                                      Icons.edit,
                                      color: Colors.black45,
                                      size: 16,
                                    ),
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
                                  color: primaryColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              // Bottom control bar: Clear (left), Drag handle (center), Item count (right)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryColor,
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: Clear button
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _sharedCartItems = null;
                        });
                        // Notify child pages to clear cart
                        _updateCartItems([]);
                      },
                      child: Row(
                        children: [
                          Icon(Icons.clear, color: Colors.white, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            'Clear',
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
                      '${_sharedCartItems?.length ?? 0} Items',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
