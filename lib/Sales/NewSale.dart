import 'package:flutter/material.dart';
import 'package:maxbillup/Sales/QuickSale.dart';
import 'package:maxbillup/Sales/Saved.dart';
import 'package:maxbillup/Sales/components/sale_app_bar.dart';
import 'package:maxbillup/Sales/saleall.dart';
import 'package:maxbillup/components/common_bottom_nav.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/Colors.dart';

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
  String? _highlightedProductId;
  int _cartVersion = 0;

  late String _uid;
  String? _userEmail;

  double _cartHeight = 200;
  final double _minCartHeight = 200;
  // Dynamic max height based on screen size
  double _maxCartHeight = 600;

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
    String? triggerId;

    if (items.length > (_sharedCartItems?.length ?? 0)) {
      final oldIds = _sharedCartItems?.map((i) => i.productId).toSet() ?? {};
      for (var item in items) {
        if (!oldIds.contains(item.productId)) {
          triggerId = item.productId;
          break;
        }
      }
    }

    if (triggerId == null && _sharedCartItems != null && items.isNotEmpty) {
      for (var newItem in items) {
        try {
          final oldItem = _sharedCartItems!.firstWhere((i) => i.productId == newItem.productId);
          if (newItem.quantity > oldItem.quantity) {
            triggerId = newItem.productId;
            break;
          }
        } catch (_) {}
      }
    }

    setState(() {
      _sharedCartItems = items.isNotEmpty ? List<CartItem>.from(items) : null;
      _highlightedProductId = null;
    });

    if (triggerId != null) {
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _highlightedProductId = triggerId;
          });
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && _highlightedProductId == triggerId) {
              setState(() => _highlightedProductId = null);
            }
          });
        }
      });
    }
  }

  void _removeSingleItem(int idx) {
    if (_sharedCartItems == null) return;
    setState(() {
      _sharedCartItems!.removeAt(idx);
      _cartVersion++;
    });
    _updateCartItems(_sharedCartItems ?? []);
  }

  void _showEditCartItemDialog(int idx) async {
    final item = _sharedCartItems![idx];
    final nameController = TextEditingController(text: item.name);
    final priceController = TextEditingController(text: item.price.toString());
    final qtyController = TextEditingController(text: item.quantity.toString());
    final taxNameController = TextEditingController(text: item.taxName ?? '');
    final taxPercController = TextEditingController(text: item.taxPercentage?.toString() ?? '0');

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setDialogState) {
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
                                    color: kGrey100,
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
                        label: const Text('Remove', style: TextStyle(color: kErrorColor, fontWeight: FontWeight.bold)),
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
                              _cartVersion++;
                            });
                            _updateCartItems(_sharedCartItems!);
                            Navigator.of(context).pop();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              );
            }
        );
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
        _loadedSavedOrderId = null;
        _cartVersion++;
      });
      _updateCartItems([]);
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;

    // Dynamic max height calculation to ensure it can open to the bottom
    _maxCartHeight = screenHeight - topPadding - 130;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. Background Layer (SaleAppBar and Content)
          Column(
            children: [
              // Space for the collapsed cart section so it doesn't overlap the AppBar initially
              SizedBox(height: topPadding + 10 + (_sharedCartItems != null && _sharedCartItems!.isNotEmpty ? _minCartHeight + 12 : 0)),

              SaleAppBar(
                selectedTabIndex: _selectedTabIndex,
                onTabChanged: _handleTabChange,
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                uid: _uid,
                userEmail: _userEmail,
              ),

              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _selectedTabIndex == 0
                      ? SaleAllPage(
                    key: ValueKey('all_$_cartVersion'),
                    uid: _uid,
                    userEmail: _userEmail,
                    onCartChanged: _updateCartItems,
                    initialCartItems: _sharedCartItems,
                    savedOrderId: _loadedSavedOrderId,
                  )
                      : _selectedTabIndex == 1
                      ? QuickSalePage(
                    key: ValueKey('quick_$_cartVersion'),
                    uid: _uid,
                    userEmail: _userEmail,
                    initialCartItems: _sharedCartItems,
                    onCartChanged: _updateCartItems,
                    savedOrderId: _loadedSavedOrderId,
                  )
                      : SavedOrdersPage(
                    key: ValueKey('saved_$_cartVersion'),
                    uid: _uid,
                    userEmail: _userEmail,
                  ),
                ),
              ),
            ],
          ),

          // 2. Foreground Layer (Sliding Cart Overlay)
          if (_sharedCartItems != null && _sharedCartItems!.isNotEmpty)
            Positioned(
              top: topPadding + 10,
              left: 0,
              right: 0,
              child: _buildCartSection(screenWidth),
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

  Widget _buildCartSection(double w) {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        setState(() {
          // Slide functionality to open to the bottom (overlapping other elements)
          _cartHeight = (_cartHeight + details.delta.dy).clamp(_minCartHeight, _maxCartHeight);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        curve: Curves.linear,
        height: _cartHeight,
        margin: const EdgeInsets.symmetric(horizontal: 12).copyWith(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          // Curved Borders using Primary Color
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kPrimaryColor, width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))
          ],
        ),
        child: Column(
          children: [
            // Cart Header with Primary Color and curved top
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: kPrimaryColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 4, child: Text('Product', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white))),
                  Expanded(flex: 2, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white))),
                  Expanded(flex: 2, child: Text('Price', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white))),
                  Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white))),
                ],
              ),
            ),

            // Scrollable List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _sharedCartItems?.length ?? 0,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
                itemBuilder: (ctx, idx) {
                  final item = _sharedCartItems![idx];
                  final bool isHighlighted = item.productId == _highlightedProductId;
                  // Only highlight the newly added item (not all items)
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isHighlighted ? Colors.green.withOpacity(0.18) : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        // 1. Product & Pen Icon
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
                        // 2. Quantity
                        Expanded(
                            flex: 2,
                            child: Text('${item.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))
                        ),
                        // 3. Price
                        Expanded(flex: 2, child: Text(item.price.toStringAsFixed(0), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13))),
                        // 4. Total
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
              ),
            ),

            // Bottom Control Bar / Drag Handle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

