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
  int _selectedDuration = 1; // 1, 6, or 12 months
  bool _isPaymentInProgress = false;

  final List<Map<String, dynamic>> plans = [
    {
      'name': 'Starter',
      'rank': 0,
      'price': {'1': 0, '6': 0, '12': 0},
      'icon': HeroIcons.rocketLaunch,
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
      'name': 'MAX Lite',
      'rank': 1,
      'price': {'1': 249, '6': 1299, '12': 1999},
      'icon': HeroIcons.briefcase,
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
      'price': {'1': 429, '6': 2299, '12': 3499},
      'icon': HeroIcons.chartBar,
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
        'Up to 9 Staff Accounts',
        'Web Application',
      ],
    },
    {
      'name': 'MAX Pro',
      'rank': 3,
      'price': {'1': 529, '6': 2899, '12': 4299},
      'icon': HeroIcons.academicCap,
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
                    color: kGoogleGreen,
                    icon: HeroIcons.checkCircle,
                  ),
                  const SizedBox(height: 20),
                  // Compare Plans Button
                  _buildComparePlansButton(),
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
      height: 120,
      color: kWhite,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        itemCount: plans.length,
        itemBuilder: (context, index) {
          final plan = plans[index];
          final isSelected = _selectedPlan == plan['name'];
          final monthlyPrice = plan['price']['1'];

          return GestureDetector(
            onTap: () => setState(() => _selectedPlan = plan['name']),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 90,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: isSelected ? kPrimaryColor : kWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSelected ? kPrimaryColor : kGrey200, width: isSelected ? 2 : 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HeroIcon(plan['icon'] as HeroIcons, color: isSelected ? kWhite : kPrimaryColor, size: 22),
                  const SizedBox(height: 6),
                  Text(
                    plan['name'],
                    style: TextStyle(
                      color: isSelected ? kWhite : kBlack87,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    monthlyPrice == 0 ? "Free" : "$monthlyPrice",
                    style: TextStyle(
                      color: isSelected ? kWhite.withOpacity(0.8) : kBlack54,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDurationSelector() {
    return Container(
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kGrey200),
      ),
      child: Row(
        children: [
          _durationToggleItem("1 MONTH", 1),
          _durationToggleItem("6 MONTHS", 6),
          _durationToggleItem("Annual", 12, badge: "Save 20%"),
        ],
      ),
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
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
              if (badge != null && isActive)
                Text(
                  badge,
                  style: const TextStyle(color: kOrange, fontSize: 8, fontWeight: FontWeight.w900),
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

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(
        color: kWhite,
        border: Border(top: BorderSide(color: kGrey200, width: 1.5)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("TOTAL PAYABLE", style: TextStyle(color: kBlack54, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text("$price", style: const TextStyle(color: kPrimaryColor, fontSize: 24, fontWeight: FontWeight.w900)),
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
                    backgroundColor: kPrimaryColor,
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
      ),
    );
  }
}
