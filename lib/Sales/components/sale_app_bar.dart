import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:maxbillup/utils/translation_helper.dart';

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
        padding: EdgeInsets.fromLTRB(tabPadding-8, tabPadding + 30, tabPadding, tabPadding-5),
        child: Row(
          children: [
            // Menu Button
            SizedBox(width: screenWidth * 0.02),
            _buildTab(context.tr('sale_all'), 0, screenWidth, tabHeight),
            SizedBox(width: screenWidth * 0.02),
            _buildTab(context.tr('quick_sale'), 1, screenWidth, tabHeight),
            SizedBox(width: screenWidth * 0.02),
            _buildTab(context.tr('saved'), 2, screenWidth, tabHeight),
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
