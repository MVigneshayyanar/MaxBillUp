import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:provider/provider.dart';
import 'package:heroicons/heroicons.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/utils/plan_provider.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/Auth/PlanComparisonPage.dart';

class SubscriptionPlanPage extends StatefulWidget {
  final String uid;
  final String currentPlan;

  const SubscriptionPlanPage({
    super.key,
    required this.uid,
    required this.currentPlan,
  });

  @override
  State<SubscriptionPlanPage> createState() => _SubscriptionPlanPageState();
}

class _SubscriptionPlanPageState extends State<SubscriptionPlanPage> {
  Razorpay? _razorpay;
  String _selectedPlan = 'MAX Plus';
  int _selectedDuration = 12; // 1 or 12 months
  bool _isPaymentInProgress = false;

  final List<Map<String, dynamic>> plans = [
    {
      'name': 'Starter',
      'rank': 0,
      'price': {'1': 0, '12': 0},
      'icon': HeroIcons.rocketLaunch,
      'themeColor': kOrange,
      'staffText': '1 Admin Account',
      'included': [
        'POS Billing',
        'Purchases',
        'Expenses',
        'Credit Sales',
        'Cloud Backup',
        'Unlimited Products',
        'Bill History (upto 15 days)',
      ],
      'excluded': [
        'Edit Bill',
        'Reports',
        'Tax Reports',
        'Quotation / Estimation',
        'Import Customers',
        'Support',
        'Customer Dues',
        'Bulk Product Upload',
        'Logo on Bill',
        'Remove Watermark',
      ],
    },
    {
      'name': 'MAX One',
      'rank': 1,
      'price': {'1': 299, '12': 2499},
      'icon': HeroIcons.briefcase,
      'themeColor': kPrimaryColor,
      'staffText': '1 Admin Account',
      'included': [
        'POS Billing',
        'Purchases',
        'Expenses',
        'Credit Sales',
        'Cloud Backup',
        'Unlimited Products',
        'Bill History (Unlimited)',
        'Edit Bill',
        'Reports',
        'Tax Reports',
        'Quotation / Estimation',
        'Import Customers',
        'Support',
        'Customer Dues',
        'Bulk Product Upload',
        'Logo on Bill',
        'Remove Watermark',
      ],
      'excluded': [
        'Multiple Staff Accounts',
      ],
    },
    {
      'name': 'MAX Plus',
      'rank': 2,
      'price': {'1': 449, '12': 3999},
      'icon': HeroIcons.chartBar,
      'themeColor': Colors.purple,
      'popular': true,
      'staffText': 'Admin + 2 Users',
      'included': [
        'POS Billing',
        'Purchases',
        'Expenses',
        'Credit Sales',
        'Cloud Backup',
        'Unlimited Products',
        'Bill History (Unlimited)',
        'Edit Bill',
        'Reports',
        'Tax Reports',
        'Quotation / Estimation',
        'Import Customers',
        'Support',
        'Customer Dues',
        'Bulk Product Upload',
        'Logo on Bill',
        'Remove Watermark',
      ],
      'excluded': [
        // 'Up to 9 Staff Accounts',
      ],
    },
    {
      'name': 'MAX Pro',
      'rank': 3,
      'price': {'1': 599, '12': 5499},
      'icon': HeroIcons.academicCap,
      'themeColor': kGoogleGreen,
      'staffText': 'Admin + 9 Users',
      'included': [
        'POS Billing',
        'Purchases',
        'Expenses',
        'Credit Sales',
        'Cloud Backup',
        'Unlimited Products',
        'Bill History (Unlimited)',
        'Edit Bill',
        'Reports',
        'Tax Reports',
        'Quotation / Estimation',
        'Import Customers',
        'Support',
        'Customer Dues',
        'Bulk Product Upload',
        'Logo on Bill',
        'Remove Watermark',
      ],
      'excluded': [],
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeRazorpay();
    // Default to 'MAX Plus' if current plan is Starter or Free or not found
    final currentPlanLower = widget.currentPlan.toLowerCase();
    if (currentPlanLower.contains('starter') || currentPlanLower.contains('free')) {
      _selectedPlan = 'MAX Plus';
    } else {
      // Try to find matching plan (case-insensitive)
      final matchingPlan = plans.firstWhere(
            (p) => p['name'].toString().toLowerCase() == currentPlanLower,
        orElse: () => plans[2], // Default to MAX Plus
      );
      _selectedPlan = matchingPlan['name'];
    }
  }

  void _initializeRazorpay() {
    try {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    } catch (e) {
      debugPrint('Error initializing Razorpay: $e');
    }
  }

  @override
  void dispose() {
    try {
      _razorpay?.clear();
    } catch (e) {
      debugPrint('Error disposing Razorpay: $e');
    }
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    _showSuccessAndPop(response.paymentId ?? 'TXN_SUCCESS');
  }

  void _showSuccessAndPop(String paymentId) async {
    final now = DateTime.now();
    DateTime expiryDate = DateTime(now.year, now.month + _selectedDuration, now.day);

    final storeDoc = await FirestoreService().getCurrentStoreDoc();
    if (storeDoc == null) return;

    // Update Firestore with new subscription
    await FirestoreService().storeCollection.doc(storeDoc.id).update({
      'plan': _selectedPlan,
      'subscriptionStartDate': now.toIso8601String(),
      'subscriptionExpiryDate': expiryDate.toIso8601String(),
      'paymentId': paymentId,
      'lastPaymentDate': now.toIso8601String(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // IMPORTANT: Force refresh the PlanProvider to reflect changes instantly
    if (mounted) {
      // Get the PlanProvider and force immediate refresh
      final planProvider = Provider.of<PlanProvider>(context, listen: false);

      // This will immediately update the cached plan and notify ALL listeners
      await planProvider.forceRefresh();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("🎉 ${context.tr('Plan Upgrade Successful')}"),
          backgroundColor: kGoogleGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      // Return true to indicate subscription changed - parent screens can refresh if needed
      Navigator.of(context).pop(true);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.tr('payment_failed')}: ${response.message}'),
          backgroundColor: kErrorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {}

  void _startPayment() {
    if (_razorpay == null) {
      _initializeRazorpay();
      if (_razorpay == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Payment service unavailable. Please try again.')),
            backgroundColor: kErrorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }
    }

    final plan = plans.firstWhere(
          (p) => p['name'] == _selectedPlan,
      orElse: () => plans[2], // Default to MAX Plus
    );
    final amount = plan['price'][_selectedDuration.toString()] * 100;

    if (amount <= 0) {
      _showSuccessAndPop('FREE_ACTIVATION');
      return;
    }

    var options = {
      'key': 'rzp_test_1DP5mmOlF5G5ag',
      'amount': amount,
      'name': 'MAXmybill',
      'description': '$_selectedPlan Plan Upgrade',
      // Multi-currency support - auto-detects user location
      // Image removed - Razorpay shows professional "M" circle with brand color
      'prefill': {
        'contact': '',
        'email': 'maxmybillapp@gmail.com'
      },
      'theme': {
        'color': '#2F7CF6'
      }
    };

    try {
      _razorpay!.open(options);
    } catch (e) {
      debugPrint('Razorpay open error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Failed to open payment. Please try again.')),
          backgroundColor: kErrorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedPlanData = plans.firstWhere(
          (p) => p['name'] == _selectedPlan,
      orElse: () => plans[2], // Default to MAX Plus (index 2)
    );
    final currentPrice = selectedPlanData['price'][_selectedDuration.toString()] ?? 0;
    final bool isCurrentPlanActive = _selectedPlan.toLowerCase() == widget.currentPlan.toLowerCase();

    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('Subscription Plans').toUpperCase(),
          style: const TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildHorizontalPlanSelector(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _buildComparePlansButton(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildSectionLabel("Choose Billing Cycle"),
                  const SizedBox(height: 8),
                  _buildDurationSelector(),
                  const SizedBox(height: 24),
                  // Not Included first
                  if (selectedPlanData['excluded'].isNotEmpty)
                    _buildFeatureContainer(
                      title: "Not Included",
                      features: selectedPlanData['excluded'],
                      color: kErrorColor,
                      icon: HeroIcons.xCircle,
                      isExcluded: true,
                    ),
                  if (selectedPlanData['excluded'].isNotEmpty)
                    const SizedBox(height: 16),
                  // What's Included second
                  _buildFeatureContainer(
                    title: "What's Included",
                    features: selectedPlanData['included'],
                    staffText: selectedPlanData['staffText'],
                    color: selectedPlanData['themeColor'] as Color? ?? kGoogleGreen,
                    icon: HeroIcons.checkCircle,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          _buildCheckoutBottom(currentPrice, isCurrentPlanActive),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 1.0)),
  );

  Widget _buildHorizontalPlanSelector() {
    return Container(
      height: 140,
      color: kWhite,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Row(
        children: plans.map((plan) {
          final isSelected = _selectedPlan == plan['name'];
          
          final currentPrice = plan['price'][_selectedDuration.toString()] ?? 0;
          final double dailyPrice = currentPrice > 0 ? (_selectedDuration == 12 ? currentPrice / 365.0 : currentPrice / 30.0) : 0;
          final String dailyPriceStr = dailyPrice < 10? dailyPrice.toStringAsFixed(1) : dailyPrice.toStringAsFixed(0);
          
          final themeColor = plan['themeColor'] as Color? ?? kPrimaryColor;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPlan = plan['name']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected ? themeColor : kWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSelected ? themeColor : kGrey200, width: isSelected ? 2 : 1),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HeroIcon(plan['icon'] as HeroIcons, color: isSelected ? kWhite : themeColor, size: 25),
                    const SizedBox(height: 4),
                    Text(
                      plan['name'],
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: TextStyle(
                        color: isSelected ? kWhite : kBlack87,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentPrice == 0 ? "Free" : "$currentPrice",///${_selectedDuration == 12 ? 'yr' : 'mo'}
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: TextStyle(
                        color: isSelected ? kWhite.withOpacity(0.9) : kBlack87,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentPrice == 0 ? "Forever" : "/${_selectedDuration == 12 ? 'year' : 'month'}",//$currentPrice
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: TextStyle(
                        color: isSelected ? kWhite.withOpacity(0.9) : kBlack87,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),

                    // if (currentPrice > 0)
                    //   Text(
                    //     "$dailyPriceStr/day",
                    //     textAlign: TextAlign.center,
                    //     maxLines: 1,
                    //     overflow: TextOverflow.fade,
                    //     softWrap: false,
                    //     style: TextStyle(
                    //       color: isSelected ? kWhite.withOpacity(0.7) : kBlack54,
                    //       fontWeight: FontWeight.w600,
                    //       fontSize: 8,
                    //     ),
                    //   ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDurationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7E6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.access_time_outlined, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                    children: [
                      TextSpan(text: "Limited Time Offer: "),
                      TextSpan(text: "Extra savings on yearly plans!", style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 56,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kGrey200),
          ),
          child: Row(
            children: [
              _durationToggleItem("Monthly", 1),
              _durationToggleItem("Yearly", 12, badge: "Save up to 30%"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _durationToggleItem(String label, int duration, {String? badge}) {
    bool isActive = _selectedDuration == duration;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedDuration = duration),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isActive ? kPrimaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isActive ? kWhite : kBlack54,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              if (badge != null )
                Text(
                  badge,
                  style: const TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.w900),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureContainer({
    required String title,
    required List<dynamic> features,
    String? staffText,
    required Color color,
    required HeroIcons icon,
    bool isExcluded = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HeroIcon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              Text(
                title.toUpperCase(),
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!isExcluded && staffText != null)
            _buildFeatureRow(staffText, kPrimaryColor, HeroIcons.users),

          ...features.map((feature) => _buildFeatureRow(
              feature,
              kBlack87,
              isExcluded ? HeroIcons.minusCircle : HeroIcons.checkCircle
          )),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String text, Color textColor, HeroIcons icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeroIcon(icon, color: textColor.withOpacity(0.3), size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparePlansButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PlanComparisonPage(),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: kPrimaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kPrimaryColor.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HeroIcon(HeroIcons.arrowsRightLeft, color: kPrimaryColor, size: 22),
            const SizedBox(width: 12),
            const Text(
              'COMPARE ALL PLANS',
              style: TextStyle(
                color: kPrimaryColor,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            const HeroIcon(HeroIcons.chevronRight, color: kPrimaryColor, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutBottom(int price, bool isCurrent) {
    final currentPlanData = plans.firstWhere(
            (p) => p['name'].toString().toLowerCase() == widget.currentPlan.toLowerCase(),
        orElse: () => plans[0]
    );
    final selectedPlanData = plans.firstWhere(
          (p) => p['name'] == _selectedPlan,
      orElse: () => plans[2], // Default to MAX Plus
    );
    final themeColor = selectedPlanData['themeColor'] as Color? ?? kPrimaryColor;
    final bool isUpgrade = selectedPlanData['rank'] > currentPlanData['rank'];

    String buttonText;
    bool isEnabled;

    if (isCurrent) {
      buttonText = "ACTIVE PLAN";
      isEnabled = false;
    } else if (isUpgrade) {
      buttonText = "UPGRADE NOW";
      isEnabled = true;
    } else {
      buttonText = "LOCKED";
      isEnabled = false;
    }

    final bool isYearly = _selectedDuration == 12;
    final double dailyPrice = price > 0 ? (isYearly ? price / 365.0 : price / 30.0) : 0;
    final String dailyPriceStr = dailyPrice < 10 ? dailyPrice.toStringAsFixed(1) : dailyPrice.toStringAsFixed(0);
    
    final int monthlyPrice = selectedPlanData['price']['1'] ?? 0;
    final int yearlyTotalIfMonthly = monthlyPrice * 12;
    final int savings = isYearly ? yearlyTotalIfMonthly - price : 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(
        color: kWhite,
        border: Border(top: BorderSide(color: kGrey200, width: 1.5)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isYearly && price > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: kGoogleGreen, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "Serious business owners choose yearly",
                        style: TextStyle(fontSize: 12, color: kBlack87, fontWeight: FontWeight.w600),
                      )
                    ),
                    Text(
                      "Save $savings",
                      style: const TextStyle(fontSize: 12, color: kGoogleGreen, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isYearly ? "TOTAL (YEARLY)" : "TOTAL (MONTHLY)", style: const TextStyle(color: kBlack54, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
                      const SizedBox(height: 2),
                      Text("$price", style: TextStyle(color: themeColor, fontSize: 24, fontWeight: FontWeight.w900)),
                      if (price > 0) ...[
                        const SizedBox(height: 2),
                        Text("Only $dailyPriceStr per day", style: const TextStyle(color: kBlack54, fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isEnabled ? _startPayment : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        disabledBackgroundColor: kGreyBg,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: isEnabled
                            ? BorderSide.none
                            : const BorderSide(color: kGrey200),
                      ),
                      child: Text(
                        buttonText,
                        style: TextStyle(
                            color: isEnabled ? kWhite : kBlack54,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
