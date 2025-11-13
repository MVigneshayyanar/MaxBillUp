import 'package:flutter/material.dart';
import 'package:maxbillup/Sales/saleall.dart';
import 'package:maxbillup/Stocks/Products.dart';
import 'package:maxbillup/Stocks/AddProduct.dart';
import 'package:maxbillup/Stocks/AddCategoryPopup.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  int _selectedTabIndex = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // Tabs at the top
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  _buildTab('Products (150)', 0),
                  const SizedBox(width: 8),
                  _buildTab('Category (7)', 1),
                ],
              ),
            ),
            // Add Category button
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    _showAddCategoryDialog(context);
                  },
                  icon: const Icon(Icons.add, color: Color(0xFF4CAF50), size: 20),
                  label: const Text(
                    'Add Category',
                    style: TextStyle(
                      color: Color(0xFF4CAF50),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
            ),
            // Category list
            Expanded(
              child: Container(
                color: const Color(0xFFF5F5F5),
                child: _buildCategoryList(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildTab(String text, int index) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (index == 0) {
            // Navigate to Products page
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ProductsPage()),
            );
          } else {
            setState(() {
              _selectedTabIndex = index;
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2196F3) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryList() {
    final categories = [
      {'name': 'BAG', 'products': 0},
      {'name': 'BAG', 'products': 0},
      {'name': 'BAG', 'products': 0},
      {'name': 'BAG', 'products': 0},
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final category = categories[index];
        final showEdit = index == 1;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    category['name'] as String,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                  Row(
                    children: [
                      if (showEdit)
                        Row(
                          children: [
                            Icon(Icons.edit, color: const Color(0xFF2196F3), size: 20),
                            const SizedBox(width: 4),
                            const Text(
                              'Edit',
                              style: TextStyle(
                                color: Color(0xFF2196F3),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                        ),
                      Icon(Icons.delete, color: const Color(0xFFFF5252), size: 22),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${category['products']} Products',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF2196F3), width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AddProductPage()),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, color: Color(0xFF2196F3), size: 20),
                            SizedBox(width: 4),
                            Text(
                              'Add Product',
                              style: TextStyle(
                                color: Color(0xFF2196F3),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddProductPage()),
                  );
                },
                icon: const Icon(Icons.add, color: Color(0xFF4CAF50), size: 20),
                label: const Text(
                  'Create New Product',
                  style: TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddCategoryPopup(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
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
        currentIndex: 4,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        elevation: 0,
        onTap: (index) {
          switch (index) {
            case 0:
              // Menu
              break;
            case 1:
              // Reports
              break;
            case 2:
              // New Sale
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const SaleAllPage()),
              );
              break;
            case 3:
              // Stock
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const ProductsPage()),
              );
              break;
            case 4:
              // Settings - already on this page
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
            icon: Icon(Icons.inventory_2),
            label: 'Stock',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

