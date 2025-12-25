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
  final bool hideSavedTab; // New parameter to hide saved tab
  final bool showBackButton; // New parameter to show back button

  const SaleAppBar({
    super.key,
    required this.selectedTabIndex,
    required this.onTabChanged,
    required this.screenWidth,
    required this.screenHeight,
    required this.uid,
    this.userEmail,
    this.hideSavedTab = false, // Default to false
    this.showBackButton = false, // Default to false
  });
  final Color _bgColor = const Color(0xFFF9FAFC);
  final Color _cardBorder = const Color(0xFFE3F2FD);
  final Color _primaryColor = const Color(0xFF2F7CF6);
  @override
  Widget build(BuildContext context) {
    final tabPadding = screenWidth * 0.04;
    final tabHeight = screenHeight * 0.06;

    return Container(
      color: _bgColor,
      child: Container(
        padding: EdgeInsets.fromLTRB(tabPadding, 0, tabPadding, tabPadding-15),
        child: Row(
          children: [
            // Back button (if enabled)
            if (showBackButton) ...[
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
              ),
              SizedBox(width: screenWidth * 0.02),
            ],
            // Tabs
            _buildTab(context.tr('Quick Bill'), 1, screenWidth, tabHeight),
            SizedBox(width: screenWidth * 0.02),
            _buildTab(context.tr('View All'), 0, screenWidth, tabHeight),
            if (!hideSavedTab) ...[
              SizedBox(width: screenWidth * 0.02),
              _buildTab(context.tr('saved'), 2, screenWidth, tabHeight),
            ],
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
            color: isSelected ? const Color(0xFF2F7CF6) : _primaryColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _cardBorder),
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
