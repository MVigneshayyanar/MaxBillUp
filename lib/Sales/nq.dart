import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:maxbillup/Sales/QuickSale.dart';
import 'package:maxbillup/Sales/Saved.dart';
import 'package:maxbillup/Sales/components/sale_app_bar.dart';
import 'package:maxbillup/Sales/saleall.dart';
import 'package:maxbillup/models/cart_item.dart';

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

class _NewQuotationPageState extends State<NewQuotationPage> {
  int _selectedTabIndex = 0;
  List<CartItem>? _sharedCartItems;

  double _cartHeight = 180;
  final double _minCartHeight = 120;
  final double _maxCartHeight = 300;

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

          // Cart section (if present)
          if (_sharedCartItems != null && _sharedCartItems!.isNotEmpty)
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
                ? SaleAllPage(
              uid: widget.uid,
              userEmail: widget.userEmail,
              onCartChanged: _updateCartItems,
              initialCartItems: _sharedCartItems,
              isQuotationMode: true, // Quotation mode enabled
            )
                : _selectedTabIndex == 1
                ? QuickSalePage(
              uid: widget.uid,
              userEmail: widget.userEmail,
              initialCartItems: _sharedCartItems,
              onCartChanged: _updateCartItems,
            )
                : SavedOrdersPage(
              uid: widget.uid,
              userEmail: widget.userEmail,
            ),
          ),
        ],
      ),
      // NO bottom navigation bar for quotation page
    );
  }

  Widget _buildCartSection(double w) {
    final primaryColor = const Color(0xFF2F7CF6);
    return Padding(
      padding: const EdgeInsets.only(top: 0),
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
