import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:maxbillup/Sales/NewSale.dart';
import 'package:maxbillup/Settings/Profile.dart';
import 'package:maxbillup/Stocks/Stock.dart' as stock;
import 'package:maxbillup/Reports/Reports.dart';
import 'package:maxbillup/Menu/Menu.dart';
import 'package:maxbillup/utils/translation_helper.dart';

class CommonBottomNav extends StatelessWidget {
  final String uid;
  final String? userEmail;
  final int currentIndex;
  final double screenWidth;

  const CommonBottomNav({
    super.key,
    required this.uid,
    this.userEmail,
    required this.currentIndex,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate width for 5 items
    final itemWidth = screenWidth / 5;
    final indicatorWidth = itemWidth * 0.5;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE3F2FD), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 65,
          padding: const EdgeInsets.only(bottom: 5),
          child: Stack(
            children: [
              // Sliding animated indicator bar
              // We use Alignment x from -1.0 (left) to 1.0 (right)
              // For 5 items, the positions are: -1.0, -0.5, 0.0, 0.5, 1.0
              AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment: Alignment(-1.0 + (currentIndex * 0.5), -1.0),
                child: Container(
                  width: itemWidth,
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: indicatorWidth,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2F7CF6),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2F7CF6).withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Nav items
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(context, 0, Icons.menu_rounded, context.tr('menu')),
                  _buildNavItem(context, 1, Icons.assessment_rounded, context.tr('reports')),
                  _buildNavItem(context, 2, Icons.receipt_long_rounded, context.tr('new_sale')),
                  _buildNavItem(context, 3, Icons.inventory_2_rounded, context.tr('stock')),
                  _buildNavItem(context, 4, Icons.settings_rounded, context.tr('settings')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, String label) {
    final isSelected = currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _handleNavigation(context, index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            AnimatedScale(
              scale: isSelected ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Icon(
                icon,
                color: isSelected ? const Color(0xFF2F7CF6) : Colors.black45, // Lighter unselected icon
                size: 28,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'Noto Sans',
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF2F7CF6) : Colors.black38, // Lighter unselected text
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNavigation(BuildContext context, int index) {
    if (index == currentIndex) return;

    Widget targetPage;
    switch (index) {
      case 0:
        targetPage = MenuPage(uid: uid, userEmail: userEmail);
        break;
      case 1:
        targetPage = ReportsPage(uid: uid, userEmail: userEmail);
        break;
      case 2:
        targetPage = NewSalePage(uid: uid, userEmail: userEmail);
        break;
      case 3:
        targetPage = stock.StockPage(uid: uid, userEmail: userEmail);
        break;
      case 4:
      // Assuming SettingsPage is defined in Profile.dart
        targetPage = SettingsPage(uid: uid, userEmail: userEmail);
        break;
      default:
        return;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetPage,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }
}