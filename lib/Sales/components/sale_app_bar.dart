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
  });

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = screenWidth * 0.04;
    const double tabHeight = 48.0;

    // Helper to determine alignment for the sliding pill based on the specific tab order
    // Order: Quick Bill (1), View All (0), Saved (2)
    double getAlignment() {
      if (hideSavedTab) {
        // 2 Tabs: Left (1), Right (0)
        return selectedTabIndex == 1 ? -1.0 : 1.0;
      } else {
        // 3 Tabs: Left (1), Middle (0), Right (2)
        if (selectedTabIndex == 1) return -1.0;
        if (selectedTabIndex == 0) return 0.0;
        return 1.0;
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
                color: kGrey100,
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
                      _buildTab(context.tr('Quick Bill'), 1),
                      const SizedBox(width: 4),
                      _buildTab(context.tr('View All'), 0),
                      if (!hideSavedTab) ...[
                        const SizedBox(width: 4),
                        _buildTab(context.tr('saved'), 2),
                      ],
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

    return Expanded(
      child: GestureDetector(
        onTap: () => onTabChanged(index),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: isSelected ? kWhite : kBlack54,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            ),
            child: Text(text),
          ),
        ),
      ),
    );
  }
}