import 'package:flutter/material.dart';
import 'package:maxbillup/Menu/Menu.dart';

class SaleAppBar extends StatelessWidget {
  final int selectedTabIndex;
  final Function(int) onTabChanged;
  final double screenWidth;
  final double screenHeight;
  final String uid;
  final String? userEmail;

  const SaleAppBar({
    super.key,
    required this.selectedTabIndex,
    required this.onTabChanged,
    required this.screenWidth,
    required this.screenHeight,
    required this.uid,
    this.userEmail,
  });

  @override
  Widget build(BuildContext context) {
    final tabPadding = screenWidth * 0.04;
    final tabHeight = screenHeight * 0.06;

    return Container(
      color: Colors.white,
      child: Container(
        padding: EdgeInsets.fromLTRB(tabPadding, tabPadding + 30, tabPadding, tabPadding),
        child: Row(
          children: [
            // Menu Button
            GestureDetector(
              onTap: () {
                Scaffold.of(context).openDrawer();
              },
              child: Container(
                width: screenWidth * 0.12,
                height: tabHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.menu,
                  color: const Color(0xFF2196F3),
                  size: screenWidth * 0.06,
                ),
              ),
            ),
            SizedBox(width: screenWidth * 0.02),
            _buildTab('Sale / All', 0, screenWidth, tabHeight),
            SizedBox(width: screenWidth * 0.02),
            _buildTab('Quick Sale', 1, screenWidth, tabHeight),
            SizedBox(width: screenWidth * 0.02),
            _buildTab('Saved ', 2, screenWidth, tabHeight),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String text, int index, double screenWidth, double tabHeight) {
    final isSelected = selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTabChanged(index),
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
}