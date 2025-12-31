import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/Colors.dart';

class SaleAppBar extends StatelessWidget {
  final int selectedTabIndex;
  final Function(int) onTabChanged;
  final double screenWidth;
  final double screenHeight;
  final String uid;
  final String? userEmail;
  final bool hideSavedTab;
  final bool showBackButton;
  final int savedOrderCount;

  const SaleAppBar({
    super.key,
    required this.selectedTabIndex,
    required this.onTabChanged,
    required this.screenWidth,
    required this.screenHeight,
    required this.uid,
    this.userEmail,
    this.hideSavedTab = false,
    this.showBackButton = false,
    this.savedOrderCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = screenWidth * 0.04;
    const double tabHeight = 44.0;

    // Helper to determine alignment for the sliding pill
    double getAlignment() {
      if (hideSavedTab) {
        return selectedTabIndex == 1 ? -1.0 : 1.0;
      } else {
        if (selectedTabIndex == 0) return -1.0; // saved
        if (selectedTabIndex == 1) return 0.0;  // View All
        return 1.0;                             // Quick Bill
      }
    }

    return Container(
      color: kWhite,
      padding: EdgeInsets.fromLTRB(horizontalPadding, 0, 16, 0),
      child: Row(
        children: [
          if (showBackButton) ...[
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kGreyBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kGrey200),
                ),
                child: const Icon(Icons.arrow_back, color: kBlack87, size: 16),
              ),
            ),
            SizedBox(width: 12),
          ],

          Expanded(
            child: Container(
              height: tabHeight + 8,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: kGreyBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kGrey200, width: 1),
              ),
              child: Stack(
                children: [
                  // Animated Sliding Pill
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.fastOutSlowIn,
                    alignment: Alignment(getAlignment(), 0),
                    child: FractionallySizedBox(
                      widthFactor: hideSavedTab ? 0.5 : 0.33,
                      child: Container(
                        decoration: BoxDecoration(
                          color: kPrimaryColor,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: kPrimaryColor.withOpacity(0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Tab Labels
                  Row(
                    children: [
                      if (!hideSavedTab) ...[
                        _buildTab(context.tr('saved').toUpperCase(), 0),
                      ],
                      _buildTab(context.tr('View All').toUpperCase(), 1),
                      _buildTab(context.tr('Quick Bill').toUpperCase(), 2),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String text, int index) {
    final isSelected = selectedTabIndex == index;
    final isSavedTab = index == 0 && !hideSavedTab;
    final showBadge = isSavedTab && savedOrderCount > 0;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTabChanged(index),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: TextStyle(
                  color: isSelected ? kWhite : kBlack54,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              if (showBadge) ...[
                const SizedBox(width: 6),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: isSelected ? kWhite : kPrimaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      savedOrderCount > 99 ? '99' : savedOrderCount.toString(),
                      style: TextStyle(
                        color: isSelected ? kPrimaryColor : kWhite,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}