import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/Sales/Bill.dart';
import 'package:maxbillup/components/barcode_scanner.dart';

class SaleAllPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final Map<String, dynamic>? savedOrderData;
  final List<CartItem>? initialCartItems;
  final Function(List<CartItem>)? onCartChanged;

  const SaleAllPage({
    super.key,
    required this.uid,
    this.userEmail,
    this.savedOrderData,
    this.initialCartItems,
    this.onCartChanged,
  });

  @override
  State<SaleAllPage> createState() => _SaleAllPageState();
}

class _SaleAllPageState extends State<SaleAllPage> {
  final TextEditingController _searchController = TextEditingController();
  final List<CartItem> _cartItems = [];
  String _searchQuery = '';

  late String _uid;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _uid = widget.uid;
    _userEmail = widget.userEmail;
    _searchController.addListener(_onSearchChanged);

    // Load initial cart items from QuickSale page
    if (widget.initialCartItems != null && widget.initialCartItems!.isNotEmpty) {
      _cartItems.addAll(widget.initialCartItems!);
    }
    // Load saved order if provided
    else if (widget.savedOrderData != null) {
      _loadSavedOrderData(widget.savedOrderData!);
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  void _loadSavedOrderData(Map<String, dynamic> orderData) {
    final items = orderData['items'] as List?;
    if (items != null) {
      for (var item in items) {
        _cartItems.add(CartItem(
          productId: item['productId'] ?? '',
          name: item['name'] ?? '',
          price: (item['price'] ?? 0.0).toDouble(),
          quantity: item['quantity'] ?? 1,
        ));
      }
    }
  }

  double get _totalBill {
    return _cartItems.fold(0.0, (sum, item) => sum + item.total);
  }

  void _addToCart(String productId, String name, double price, bool stockEnabled, double currentStock) {
    final existingIndex = _cartItems.indexWhere((item) => item.productId == productId);

    if (existingIndex != -1) {
      // Check if stock is enabled and if we have enough stock
      if (stockEnabled) {
        final totalQuantityInCart = _cartItems[existingIndex].quantity + 1;
        if (totalQuantityInCart > currentStock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Not enough stock! Only ${currentStock.toInt()} available'),
              backgroundColor: const Color(0xFFFF5252),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
      }
      _cartItems[existingIndex].quantity++;

      // Move the updated item to the front (left side)
      final updatedItem = _cartItems.removeAt(existingIndex);
      _cartItems.insert(0, updatedItem);
    } else {
      // Check stock for new item
      if (stockEnabled && currentStock < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Out of stock!'),
            backgroundColor: Color(0xFFFF5252),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      // Add new item at the beginning (left side)
      _cartItems.insert(0, CartItem(
        productId: productId,
        name: name,
        price: price,
      ));
    }

    // Show success feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name added to cart'),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(milliseconds: 800),
      ),
    );

    // Notify parent about cart changes
    widget.onCartChanged?.call(_cartItems);

    // Only rebuild the cart section, not the entire page
    setState(() {});
  }

  void _removeFromCart(int index) {
    _cartItems.removeAt(index);
    // Notify parent about cart changes
    widget.onCartChanged?.call(_cartItems);
    // Only rebuild the cart section
    setState(() {});
  }

  void _clearOrder() {
    _cartItems.clear();
    // Notify parent about cart changes
    widget.onCartChanged?.call(_cartItems);
    // Only rebuild the cart section
    setState(() {});
  }

  void _showEditQuantityDialog(int index) {
    final item = _cartItems[index];
    final TextEditingController quantityController = TextEditingController(
      text: item.quantity.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Quantity - ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Price: ₹${item.price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2196F3),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.shopping_cart),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _cartItems.removeAt(index);
              // Notify parent about cart changes
              widget.onCartChanged?.call(_cartItems);
              // Only rebuild the cart section
              setState(() {});

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Item removed from cart'),
                  backgroundColor: Color(0xFFFF5252),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: Color(0xFFFF5252)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final newQuantity = int.tryParse(quantityController.text.trim());
              if (newQuantity == null || newQuantity <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid quantity'),
                    backgroundColor: Color(0xFFFF5252),
                  ),
                );
                return;
              }

              _cartItems[index].quantity = newQuantity;
              // Notify parent about cart changes
              widget.onCartChanged?.call(_cartItems);
              // Only rebuild the cart section
              setState(() {});

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Quantity updated to $newQuantity'),
                  backgroundColor: const Color(0xFF4CAF50),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _openBarcodeScanner() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BarcodeScannerPage(
          onBarcodeScanned: (barcode) {
            _searchProductByBarcode(barcode);
          },
        ),
      ),
    );
  }

  void _searchProductByBarcode(String barcode) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('Products')
          .where('barcode', isEqualTo: barcode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Product not found with barcode: $barcode'),
              backgroundColor: const Color(0xFFFF9800),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      final productDoc = querySnapshot.docs.first;
      final productData = productDoc.data();
      final productId = productDoc.id;

      final itemName = productData['itemName'] ?? 'Unnamed Product';
      final price = productData['price'] ?? 0.0;
      final stockEnabled = productData['stockEnabled'] ?? false;
      final currentStock = productData['currentStock'] ?? 0.0;

      if (price > 0) {
        _addToCart(productId, itemName, price.toDouble(), stockEnabled, currentStock);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$itemName has no price set'),
              backgroundColor: const Color(0xFFFF9800),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching product: $e'),
            backgroundColor: const Color(0xFFFF5252),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showSaveOrderDialog() {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cart is empty!'),
          backgroundColor: Color(0xFFFF9800),
        ),
      );
      return;
    }

    final TextEditingController phoneController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    bool isLoadingCustomer = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Save Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Customer Phone Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                onChanged: (value) async {
                  if (value.length >= 10) {
                    setDialogState(() {
                      isLoadingCustomer = true;
                    });

                    // Check if customer exists
                    final customerDoc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(_uid)
                        .collection('customers')
                        .doc(value)
                        .get();

                    if (customerDoc.exists) {
                      final customerData = customerDoc.data();
                      nameController.text = customerData?['name'] ?? '';
                    }

                    setDialogState(() {
                      isLoadingCustomer = false;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              if (isLoadingCustomer)
                const CircularProgressIndicator()
              else
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Customer Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final phone = phoneController.text.trim();
                final name = nameController.text.trim();

                if (phone.isEmpty || name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter phone number and name'),
                      backgroundColor: Color(0xFFFF5252),
                    ),
                  );
                  return;
                }

                Navigator.pop(context);
                await _saveOrder(phone, name);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
              ),
              child: const Text('Save Order'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveOrder(String phone, String name) async {
    try {
      // Save or update customer
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('customers')
          .doc(phone)
          .set({
        'name': name,
        'phone': phone,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Prepare order items
      final items = _cartItems.map((item) => {
        'productId': item.productId,
        'name': item.name,
        'price': item.price,
        'quantity': item.quantity,
        'total': item.total,
      }).toList();

      // Save order
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('savedOrders')
          .add({
        'customerName': name,
        'customerPhone': phone,
        'items': items,
        'total': _totalBill,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order saved successfully!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );

        // Clear cart
        _cartItems.clear();
        // Notify parent about cart changes
        widget.onCartChanged?.call(_cartItems);
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving order: $e'),
            backgroundColor: const Color(0xFFFF5252),
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Responsive sizing values
    final tabPadding = screenWidth * 0.04;
    final searchBarHeight = screenHeight * 0.06;
    final cartHeight = screenHeight * 0.12;
    final gridPadding = screenWidth * 0.04;
    final gridSpacing = screenWidth * 0.03;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // App Bar Component (Tabs only)


            // Search bar
            Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(tabPadding, 0, tabPadding, tabPadding),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: searchBarHeight,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: screenWidth * 0.04,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search',
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: screenWidth * 0.04,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey[400],
                            size: screenWidth * 0.06,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.04,
                            vertical: searchBarHeight * 0.25,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  GestureDetector(
                    onTap: _openBarcodeScanner,
                    child: Container(
                      height: searchBarHeight,
                      width: searchBarHeight,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.qr_code_scanner,
                        color: Colors.grey[600],
                        size: screenWidth * 0.06,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Cart Items Section (Billing Products) - Compact horizontal cards
            if (_cartItems.isNotEmpty)
              Container(
                color: Colors.white,
                padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: tabPadding),
                      child: Row(
                        children: [
                          Text(
                            'Cart',
                            style: TextStyle(
                              fontSize: screenWidth * 0.04,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.02,
                              vertical: screenHeight * 0.003,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_cartItems.length}',
                              style: TextStyle(
                                fontSize: screenWidth * 0.03,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '₹${_totalBill.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: screenWidth * 0.045,
                              color: const Color(0xFF2196F3),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          GestureDetector(
                            onTap: _clearOrder,
                            child: Icon(
                              Icons.delete_outline,
                              color: const Color(0xFFFF5252),
                              size: screenWidth * 0.055,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.015),
                    // Horizontal scrollable cart items
                    SizedBox(
                      height: cartHeight,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: tabPadding),
                        itemCount: _cartItems.length,
                        itemBuilder: (context, index) {
                          final item = _cartItems[index];
                          return GestureDetector(
                            onTap: () => _showEditQuantityDialog(index),
                            child: Container(
                              width: screenWidth * 0.4,
                              margin: EdgeInsets.only(right: screenWidth * 0.03),
                              padding: EdgeInsets.all(screenWidth * 0.025),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          style: TextStyle(
                                            fontSize: screenWidth * 0.035,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => _removeFromCart(index),
                                        child: Icon(
                                          Icons.close,
                                          size: screenWidth * 0.04,
                                          color: const Color(0xFFFF5252),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: screenHeight * 0.005),
                                  Row(
                                    children: [
                                      Text(
                                        '₹${item.price.toStringAsFixed(0)} × ${item.quantity}',
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.032,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      SizedBox(width: screenWidth * 0.01),
                                      Icon(
                                        Icons.edit,
                                        size: screenWidth * 0.03,
                                        color: const Color(0xFF2196F3),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Text(
                                    '₹${item.total.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.04,
                                      color: const Color(0xFF4CAF50),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

            // Product grid
            Expanded(
              child: Container(
                color: const Color(0xFFF5F5F5),
                child: _buildProductGrid(screenWidth, screenHeight, gridPadding, gridSpacing),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Action buttons container (static above bottom navbar)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Saved button - Save Order
                GestureDetector(
                  onTap: _showSaveOrderDialog,
                  child: Container(
                    height: 56,
                    width: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2196F3), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.bookmark_border,
                      color: Color(0xFF2196F3),
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Print button
                Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2196F3), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.print,
                    color: Color(0xFF2196F3),
                    size: 26,
                  ),
                ),
                const Spacer(),
                // Bill button (on right side)
                GestureDetector(
                  onTap: () {
                    if (_cartItems.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BillPage(
                            uid: _uid,
                            userEmail: _userEmail,
                            cartItems: _cartItems,
                            totalAmount: _totalBill,
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _totalBill.toStringAsFixed(2),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Bill',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Bottom Navigation Bar
        ],
      ),
    );
  }

  Widget _buildProductGrid(double screenWidth, double screenHeight, double gridPadding, double gridSpacing) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('Products')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF2196F3),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: screenWidth * 0.2,
                  color: Colors.grey[300],
                ),
                SizedBox(height: screenHeight * 0.02),
                Text(
                  'No products available',
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: screenHeight * 0.01),
                Text(
                  'Add products to start making sales',
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          );
        }

        final products = snapshot.data!.docs;

        // Filter products based on search query
        final filteredProducts = products.where((doc) {
          if (_searchQuery.isEmpty) return true;

          final productData = doc.data() as Map<String, dynamic>;
          final itemName = (productData['itemName'] ?? '').toString().toLowerCase();
          final barcode = (productData['barcode'] ?? '').toString().toLowerCase();

          return itemName.contains(_searchQuery) || barcode.contains(_searchQuery);
        }).toList();

        if (filteredProducts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: screenWidth * 0.2,
                  color: Colors.grey[300],
                ),
                SizedBox(height: screenHeight * 0.02),
                Text(
                  'No products found',
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: screenHeight * 0.01),
                Text(
                  'Try a different search term',
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: EdgeInsets.all(gridPadding),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: gridSpacing,
            mainAxisSpacing: gridSpacing,
            childAspectRatio: 1.15,
          ),
          itemCount: filteredProducts.length,
          itemBuilder: (context, index) {
            final productDoc = filteredProducts[index];
            final productData = productDoc.data() as Map<String, dynamic>;
            final productId = productDoc.id;

            final itemName = productData['itemName'] ?? 'Unnamed Product';
            final price = productData['price'] ?? 0.0;
            final stockEnabled = productData['stockEnabled'] ?? false;
            final currentStock = productData['currentStock'] ?? 0.0;
            final stockUnit = productData['stockUnit'] ?? 'box';

            final isOutOfStock = stockEnabled && currentStock <= 0;

            return GestureDetector(
              onTap: () {
                if (price != null && price > 0) {
                  _addToCart(productId, itemName, price.toDouble(), stockEnabled, currentStock);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Price not set for this product'),
                      backgroundColor: Color(0xFFFF9800),
                    ),
                  );
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(screenWidth * 0.04),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            itemName,
                            style: TextStyle(
                              fontSize: screenWidth * 0.04,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: screenHeight * 0.005),
                          Text(
                            price != null && price > 0
                                ? '₹${price.toStringAsFixed(0)}'
                                : 'Price on sale',
                            style: TextStyle(
                              fontSize: screenWidth * 0.04,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.005),
                          if (stockEnabled)
                            Text(
                              '${currentStock.toStringAsFixed(0)} $stockUnit',
                              style: TextStyle(
                                fontSize: screenWidth * 0.035,
                                color: isOutOfStock
                                    ? const Color(0xFFFF5252)
                                    : const Color(0xFF4CAF50),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isOutOfStock)
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: screenWidth * 0.09,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF5252),
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                          child: Center(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: Text(
                                'Out Of Stock',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: screenWidth * 0.025,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

