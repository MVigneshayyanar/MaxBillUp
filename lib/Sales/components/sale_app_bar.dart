import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:maxbillup/utils/translation_helper.dart';
// --- UI CONSTANTS ---
import 'package:maxbillup/Colors.dart';

const Color kBlack87 = Colors.black87;
const Color kBlack54 = Colors.black54;

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
    const double tabHeight = 48.0;

    // Helper to determine alignment for the sliding pill based on the specific tab order
    // Order: saved (0), View All (1), Quick Bill (2)
    double getAlignment() {
      if (hideSavedTab) {
        // 2 Tabs: Left (View All, 1), Right (Quick Bill, 2)
        return selectedTabIndex == 1 ? -1.0 : 1.0;
      } else {
        // 3 Tabs: Left (saved, 0), Middle (View All, 1), Right (Quick Bill, 2)
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
          // Back button (if enabled)
          if (showBackButton) ...[
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kGreyBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back, color: kBlack87, size: 18),
              ),
            ),
            SizedBox(width: screenWidth * 0.03),
          ],

          // Tabs Wrapper - Modern Segmented look with Border and Sliding Animation
          Expanded(
            child: Container(
              height: tabHeight + 8, // Adjusting for internal padding
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: kGreyBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color:kPrimaryColor, width: 1), // Added Border
              ),
              child: Stack(
                children: [
                  // Smooth Sliding Background Pill
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    alignment: Alignment(getAlignment(), 0),
                    child: FractionallySizedBox(
                      widthFactor: hideSavedTab ? 0.5 : 0.33,
                      child: Container(
                        decoration: BoxDecoration(
                          color: kPrimaryColor,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: kPrimaryColor.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
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
                        _buildTab(context.tr('saved'), 0), // saved is now index 0
                        const SizedBox(width: 4),
                      ],
                      _buildTab(context.tr('View All'), 1), // View All is now index 1
                      const SizedBox(width: 4),
                      _buildTab(context.tr('Quick Bill'), 2), // Quick Bill is now index 2
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
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: isSelected ? kWhite : kBlack54,
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
                child: Text(text),
              ),
              if (showBadge) ...[
                const SizedBox(width: 6),
                Container(
                  width: 18, // Fixed width
                  height: 18, // Fixed height (same as width for circle)
                  decoration: BoxDecoration(
                    color: isSelected ? kWhite : kPrimaryColor,
                    shape: BoxShape.circle, // Makes it a perfect circle
                  ),
                  child: Center(
                    child: Text(
                      savedOrderCount > 99 ? '99+' : savedOrderCount.toString(),
                      style: TextStyle(
                        color: isSelected ? kPrimaryColor : kWhite,
                        fontSize: savedOrderCount > 99 ? 8 : 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
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

// To ensure the default animation is in 'View All',
// make sure the parent widget sets selectedTabIndex = 1 by default.
// The alignment logic will then show the pill in the middle tab.
