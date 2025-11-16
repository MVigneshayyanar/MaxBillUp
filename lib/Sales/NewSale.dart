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

  const NewSalePage({
    super.key,
    required this.uid,
    this.userEmail,
    this.savedOrderData,
  });

  @override
  State<NewSalePage> createState() => _NewSalePageState();
}

class _NewSalePageState extends State<NewSalePage> {
  int _selectedTabIndex = 0;
  List<CartItem>? _sharedCartItems; // Shared cart items between pages

  late String _uid;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _uid = widget.uid;
    _userEmail = widget.userEmail;

    // Load saved order data if provided
    if (widget.savedOrderData != null) {
      _loadSavedOrderData(widget.savedOrderData!);
      // Navigate to Sale/All tab to show the loaded order
      _selectedTabIndex = 0;
    }
  }

  void _loadSavedOrderData(Map<String, dynamic> orderData) {
    final items = orderData['items'] as List<dynamic>?;
    if (items != null && items.isNotEmpty) {
      final cartItems = items.map((item) => CartItem(
        productId: item['productId'] ?? '',
        name: item['name'] ?? '',
        price: (item['price'] ?? 0).toDouble(),
        quantity: item['quantity'] ?? 1,
      )).toList();

      setState(() {
        _sharedCartItems = cartItems;
      });
    }
  }

  void _handleTabChange(int index) {
    // Switch between all tabs inline (0 = Sale/All, 1 = Quick Sale, 2 = Saved Orders)
    setState(() {
      _selectedTabIndex = index;
    });
  }

  void _updateCartItems(List<CartItem> items) {
    setState(() {
      _sharedCartItems = items.isNotEmpty ? List<CartItem>.from(items) : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // App Bar Component (Tabs)
            SaleAppBar(
              selectedTabIndex: _selectedTabIndex,
              onTabChanged: _handleTabChange,
              screenWidth: screenWidth,
              screenHeight: screenHeight,
            ),

            // Content Area - Show content based on selected tab
            Expanded(
              child: _selectedTabIndex == 0
                  ? SaleAllPage(
                      uid: _uid,
                      userEmail: _userEmail,
                      onCartChanged: _updateCartItems,
                      initialCartItems: _sharedCartItems,
                    )
                  : _selectedTabIndex == 1
                      ? QuickSalePage(
                          uid: _uid,
                          userEmail: _userEmail,
                          initialCartItems: _sharedCartItems,
                          onCartChanged: _updateCartItems,
                        )
                      : SavedOrdersPage(
                          uid: _uid,
                          userEmail: _userEmail,
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CommonBottomNav(
        uid: _uid,
        userEmail: _userEmail,
        currentIndex: 2,
        screenWidth: screenWidth,
      ),
    );
  }
}

