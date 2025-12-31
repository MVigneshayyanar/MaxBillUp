import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';

class StockAppBar extends StatelessWidget {
  final String uid;
  final String? userEmail;
  final TextEditingController searchController;
  final int selectedTabIndex;
  final Function(int) onTabChanged;
  final VoidCallback onAddProduct;
  final double screenWidth;
  final double screenHeight;
  final Widget Function(IconData, Color) buildActionButton;

  const StockAppBar({
    super.key,
    required this.uid,
    this.userEmail,
    required this.searchController,
    required this.selectedTabIndex,
    required this.onTabChanged,
    required this.onAddProduct,
    required this.screenWidth,
    required this.screenHeight,
    required this.buildActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    const double tabHeight = 44.0;

    return Container(
      padding: EdgeInsets.only(top: topPadding + 10, bottom: 12),
      decoration: const BoxDecoration(
        color: kWhite,
        border: Border(bottom: BorderSide(color: kGrey200, width: 1)),
      ),
      child: Column(
        children: [
          // ENTERPRISE FLAT TABS
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    alignment: Alignment(selectedTabIndex == 0 ? -1.0 : 1.0, 0),
                    child: FractionallySizedBox(
                      widthFactor: 0.5,
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
                  // Tab Labels with Real-time Counts
                  Row(
                    children: [
                      // Product Tab
                      _buildTabWithCount(
                        context,
                        label: context.tr('products').toUpperCase(),
                        collection: 'Products',
                        index: 0,
                      ),
                      // Category Tab
                      _buildTabWithCount(
                        context,
                        label: context.tr('category').toUpperCase(),
                        collection: 'categories',
                        index: 1,
                      ),
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

  Widget _buildTabWithCount(BuildContext context, {required String label, required String collection, required int index}) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTabChanged(index),
        behavior: HitTestBehavior.opaque,
        child: FutureBuilder<Stream<QuerySnapshot>>(
          future: FirestoreService().getCollectionStream(collection),
          builder: (context, streamSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: streamSnapshot.data,
              builder: (context, snapshot) {
                final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                final isSelected = selectedTabIndex == index;

                return Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? kWhite : kBlack54,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? kWhite.withOpacity(0.2) : kPrimaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: isSelected ? kWhite : kPrimaryColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}