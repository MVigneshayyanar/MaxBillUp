import 'package:flutter/material.dart';
import 'package:maxbillup/Stocks/Products.dart';
import 'package:maxbillup/Stocks/Category.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/Sales/QuickSale.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:maxbillup/Sales/Saved.dart';
import 'package:maxbillup/Sales/Bill.dart';

class SaleAllPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final Map<String, dynamic>? savedOrderData;

  const SaleAllPage({
    super.key,
    required this.uid,
    this.userEmail,
    this.savedOrderData,
  });

  @override
  State<SaleAllPage> createState() => _SaleAllPageState();
}

class _SaleAllPageState extends State<SaleAllPage> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedTabIndex = 0;
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

    // Load saved order if provided
    if (widget.savedOrderData != null) {
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
    setState(() {
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
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _cartItems.removeAt(index);
    });
  }

  void _clearOrder() {
    setState(() {
      _cartItems.clear();
    });
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
              setState(() {
                _cartItems.removeAt(index);
              });
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

              setState(() {
                _cartItems[index].quantity = newQuantity;
              });
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
        builder: (context) => _BarcodeScannerPage(
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
        setState(() {
          _cartItems.clear();
        });
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
    final tabHeight = screenHeight * 0.06;
    final searchBarHeight = screenHeight * 0.06;
    final cartHeight = screenHeight * 0.12;
    final floatingButtonSize = screenWidth * 0.14;
    final gridPadding = screenWidth * 0.04;
    final gridSpacing = screenWidth * 0.03;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // Tabs at the top
            Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(tabPadding, tabPadding, tabPadding, tabPadding * 0.5),
              child: Row(
                children: [
                  _buildTab('Sale / All', 0, screenWidth, tabHeight),
                  SizedBox(width: screenWidth * 0.02),
                  _buildTab('Quick Sale', 1, screenWidth, tabHeight),
                  SizedBox(width: screenWidth * 0.02),
                  _buildTab('Saved Orders', 2, screenWidth, tabHeight),
                ],
              ),
            ),

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
                            vertical: screenHeight * 0.015,
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
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Bookmark button
            GestureDetector(
              onTap: _showSaveOrderDialog,
              child: Container(
                height: floatingButtonSize,
                width: floatingButtonSize,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.bookmark,
                  color: const Color(0xFF2196F3),
                  size: screenWidth * 0.065,
                ),
              ),
            ),
            SizedBox(width: screenWidth * 0.04),
            // Print button
            Container(
              height: floatingButtonSize,
              width: floatingButtonSize,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.print,
                color: const Color(0xFF2196F3),
                size: screenWidth * 0.065,
              ),
            ),
            SizedBox(width: screenWidth * 0.04),
            // Bill button
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
                height: floatingButtonSize,
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
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
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: screenWidth * 0.05,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.025),
                    Text(
                      'Bill',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: screenWidth * 0.045,
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: Container(
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
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF2196F3),
          unselectedItemColor: Colors.grey[400],
          currentIndex: 2,
          selectedFontSize: screenWidth * 0.03,
          unselectedFontSize: screenWidth * 0.03,
          elevation: 0,
          iconSize: screenWidth * 0.06,
          onTap: (index) {
            switch (index) {
              case 0:
                break;
              case 1:
                break;
              case 2:
                break;
              case 3:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductsPage(uid: _uid, userEmail: _userEmail),
                  ),
                );
                break;
              case 4:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CategoryPage(uid: _uid, userEmail: _userEmail),
                  ),
                );
                break;
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.menu),
              label: 'Menu',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: 'Reports',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag),
              label: 'New Sale',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              label: 'Stock',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String text, int index, double screenWidth, double tabHeight) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (index == 1) {
            // Navigate to Quick Sale with current cart items
            final List<CartItem>? cartItemsCopy = _cartItems.isNotEmpty ? List<CartItem>.from(_cartItems) : null;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => QuickSalePage(
                  uid: _uid,
                  userEmail: _userEmail,
                  initialCartItems: cartItemsCopy,
                ),
              ),
            );
          } else if (index == 2) {
            // Navigate to Saved Orders
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => SavedOrdersPage(
                  uid: _uid,
                  userEmail: _userEmail,
                ),
              ),
            );
          } else {
            setState(() {
              _selectedTabIndex = index;
            });
          }
        },
        child: Container(
          height: tabHeight,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2196F3) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontSize: screenWidth * 0.035,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
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

// Barcode Scanner Page Widget
class _BarcodeScannerPage extends StatefulWidget {
  final Function(String) onBarcodeScanned;

  const _BarcodeScannerPage({
    required this.onBarcodeScanned,
  });

  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanning = true;
  String _lastScannedCode = '';
  int _scannedCount = 0;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _handleBarcodeScan(String barcode) {
    if (!_isScanning || barcode == _lastScannedCode) return;

    setState(() {
      _lastScannedCode = barcode;
      _scannedCount++;
    });

    // Call the callback to add product
    widget.onBarcodeScanned(barcode);

    // Show feedback with vibration-like animation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Product added! ($barcode) - Total scanned: $_scannedCount'),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Reset last scanned code after 2 seconds to allow scanning same product again
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _lastScannedCode = '';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: const Color(0xFF2196F3),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(cameraController.torchEnabled ? Icons.flash_on : Icons.flash_off),
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera view
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final barcode = barcodes.first;
                if (barcode.rawValue != null) {
                  _handleBarcodeScan(barcode.rawValue!);
                }
              }
            },
          ),

          // Overlay with scanning area
          CustomPaint(
            painter: ScannerOverlay(
              scanAreaSize: screenWidth * 0.7,
            ),
            child: const SizedBox.expand(),
          ),

          // Instructions and scan count
          Positioned(
            bottom: screenHeight * 0.1,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Scan counter
                  if (_scannedCount > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Products Scanned: $_scannedCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  // Instructions
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Text(
                      'Scan multiple products\nPress back when done',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for scanner overlay
class ScannerOverlay extends CustomPainter {
  final double scanAreaSize;

  ScannerOverlay({required this.scanAreaSize});

  @override
  void paint(Canvas canvas, Size size) {
    final double scanAreaLeft = (size.width - scanAreaSize) / 2;
    final double scanAreaTop = (size.height - scanAreaSize) / 2;
    final Rect scanArea = Rect.fromLTWH(scanAreaLeft, scanAreaTop, scanAreaSize, scanAreaSize);

    // Draw dark overlay
    final Paint backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()
          ..addRRect(RRect.fromRectAndRadius(scanArea, const Radius.circular(12)))
          ..close(),
      ),
      backgroundPaint,
    );

    // Draw border corners
    final Paint borderPaint = Paint()
      ..color = const Color(0xFF2196F3)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final double cornerLength = 30;

    // Top-left corner
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop),
      Offset(scanAreaLeft + cornerLength, scanAreaTop),
      borderPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop),
      Offset(scanAreaLeft, scanAreaTop + cornerLength),
      borderPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop),
      Offset(scanAreaLeft + scanAreaSize - cornerLength, scanAreaTop),
      borderPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop),
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + cornerLength),
      borderPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop + scanAreaSize),
      Offset(scanAreaLeft + cornerLength, scanAreaTop + scanAreaSize),
      borderPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop + scanAreaSize),
      Offset(scanAreaLeft, scanAreaTop + scanAreaSize - cornerLength),
      borderPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + scanAreaSize),
      Offset(scanAreaLeft + scanAreaSize - cornerLength, scanAreaTop + scanAreaSize),
      borderPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + scanAreaSize),
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + scanAreaSize - cornerLength),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
