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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        // Add a thin top border to visually separate the bottom nav from page content
        border: const Border(
          top: BorderSide(color: Color(0xFFE3F2FD), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 65,
          margin: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(context, 0, Icons.menu_rounded, context.tr('menu')),
              _buildNavItem(context, 1, Icons.assessment_rounded, context.tr('reports')),
              _buildNavItem(context, 2, Icons.receipt_long_rounded, context.tr('new_sale')),
              _buildNavItem(context, 3, Icons.inventory_2_rounded, context.tr('stock')),
              _buildNavItem(context, 4, Icons.settings_rounded, context.tr('settings')),
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              AnimatedScale(
                scale: isSelected ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: Icon(
                  icon,
                  color: isSelected ? const Color(0xFF2F7CF6) : Colors.black,
                  size: 30,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? const Color(0xFF2F7CF6) : Colors.black,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleNavigation(BuildContext context, int index) {
    if (index == currentIndex) return;

    switch (index) {
      case 0:
        // Menu
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                MenuPage(uid: uid, userEmail: userEmail),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 200),
          ),
        );
        break;
      case 1:
      // Navigate to Analytics Dashboard
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                ReportsPage(uid: uid, userEmail: userEmail),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 200),
          ),
        );
        break;
      case 2:
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                NewSalePage(uid: uid, userEmail: userEmail),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 200),
          ),
        );
        break;
      case 3:
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                stock.StockPage(uid: uid, userEmail: userEmail),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 200),
          ),
        );
        break;
      case 4:
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                SettingsPage(uid: uid, userEmail: userEmail),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 200),
          ),
        );
        break;
    }
  }
}