import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:maxbillup/Sales/NewSale.dart';
import 'package:maxbillup/Settings/Profile.dart' hide kPrimaryColor, kBlack54;
import 'package:maxbillup/Stocks/Stock.dart' as stock;
import 'package:maxbillup/Reports/Reports.dart' hide kPrimaryColor;
import 'package:maxbillup/Menu/Menu.dart' hide kWhite;
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/Colors.dart';

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
    final indicatorWidth = itemWidth * 0.45; // Refined width for enterprise look

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        border: Border(
          top: BorderSide(color: kGrey200, width: 1),
        ),
      ),
      child: SafeArea(
        child: Container(
          height: 68, // Increased height for standard modern mobile feel
          padding: const EdgeInsets.only(bottom: 4),
          child: Stack(
            children: [
              // Sliding animated indicator bar (Flat design)
              AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                curve: Curves.fastOutSlowIn,
                alignment: Alignment(-1.0 + (currentIndex * 0.5), -1.0),
                child: Container(
                  width: itemWidth,
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: indicatorWidth,
                    height: 3, // Slimmer bar
                    decoration: BoxDecoration(
                      color: kPrimaryColor,
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
              // Nav items
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(context, 0, Icons.grid_view_rounded, context.tr('menu')),
                  _buildNavItem(context, 1, Icons.bar_chart_rounded, context.tr('reports')),
                  _buildNavItem(context, 2, Icons.add_circle_rounded, context.tr('new_sale')),
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
            const SizedBox(height: 6),
            Icon(
              icon,
              color: isSelected ? kPrimaryColor : kBlack54.withOpacity(0.4),
              size: 26, // Slightly larger icon to balance increased height
            ),
            const SizedBox(height: 4),
            Text(
              label, // Enterprise standard uppercase
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                color: isSelected ? kPrimaryColor : kBlack54.withOpacity(0.4),
                letterSpacing: 0.5,
              ),
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
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }
}