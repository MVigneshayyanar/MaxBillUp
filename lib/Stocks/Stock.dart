import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maxbillup/Stocks/Products.dart';
import 'package:maxbillup/Stocks/Category.dart';
import 'package:maxbillup/Stocks/components/stock_app_bar.dart';
import 'package:maxbillup/Stocks/AddProduct.dart';
import 'package:maxbillup/components/common_bottom_nav.dart';

class StockPage extends StatefulWidget {
  final String uid;
  final String? userEmail;

  const StockPage({
    super.key,
    required this.uid,
    this.userEmail,
  });

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedTabIndex = 0;

  late String _uid;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _uid = widget.uid;
    _userEmail = widget.userEmail;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: Column(
        children: [
          // Stock AppBar Component
          StockAppBar(
            uid: _uid,
            userEmail: _userEmail,
            searchController: _searchController,
            selectedTabIndex: _selectedTabIndex,
            onTabChanged: (index) {
              setState(() {
                _selectedTabIndex = index;
              });
            },
            onAddProduct: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddProductPage(uid: _uid, userEmail: _userEmail),
                ),
              );
            },
            buildActionButton: _buildActionButton,
          ),

          // Content area - Show Products or Category based on selected tab
          Expanded(
            child: _selectedTabIndex == 0
                ? ProductsPage(uid: _uid, userEmail: _userEmail)
                : CategoryPage(uid: _uid, userEmail: _userEmail),
          ),
        ],
      ),
      bottomNavigationBar: CommonBottomNav(
        uid: _uid,
        userEmail: _userEmail,
        currentIndex: 3,
        screenWidth: MediaQuery.of(context).size.width,
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color) {
    return Container(
      height: 48,
      width: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

