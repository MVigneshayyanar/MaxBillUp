import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:provider/provider.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/utils/plan_provider.dart';
import 'package:maxbillup/Colors.dart';

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
  late Razorpay _razorpay;
  String _selectedPlan = 'Growth';
  int _selectedDuration = 1; // 1, 6, or 12 months

  final List<Map<String, dynamic>> plans = [
    {
      'name': 'Starter',
      'rank': 0,
      'price': {'1': 0, '6': 0, '12': 0},
      'icon': Icons.rocket_launch_rounded,
      'staffText': 'Single admin account',
      'included': [
        'Bill history (7 days)',
        'POS Billing',
        'Expense Tracking',
        'Purchase Records',
        'Cloud Storage'
      ],
      'excluded': [
        'Advanced DayBook',
        'Quotations',
        'Bulk Uploads',
        'Business Logo',
        'TAX Reports',
      ],
    },
    {
      'name': 'Essential',
      'rank': 1,
      'price': {'1': 249, '6': 1299, '12': 1999},
      'icon': Icons.business_center_rounded,
      'staffText': 'Admin + 1 Manager',
      'included': [
        'Full Bill History',
        'POS Billing',
        'Full Reports',
        'Quotations',
        'Bulk Inventory',
        'Business Logo',
        'TAX Report'
      ],
      'excluded': [
        'Multiple Staff Accounts',
        'Advanced Analytics',
      ],
    },
    {
      'name': 'Growth',
      'rank': 2,
      'price': {'1': 429, '6': 2299, '12': 3499},
      'icon': Icons.trending_up_rounded,
      'popular': true,
      'staffText': 'Admin + 3 Staff accounts',
      'included': [
        'Full Bill History',
        'Full Reports & GST',
        'Customer Credit Details',
        'Quotations & Proforma',
        'Bulk SMS Support',
        'Contact Imports'
      ],
      'excluded': [
        'Up to 15 Staff Accounts',
        'Dedicated Manager'
      ],
    },
    {
      'name': 'Pro',
      'rank': 3,
      'price': {'1': 529, '6': 2899, '12': 4299},
      'icon': Icons.workspace_premium_rounded,
      'staffText': 'Admin + 15 Staff accounts',
      'included': [
        'Full Enterprise Access',
        'All Modules Included',
        'Priority Support',
        'Advanced Data Exports',
        'Custom Invoice Hooks'
      ],
      'excluded': [],
    },
  ];

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    // Default to 'Growth' if current plan is Starter or Free
    _selectedPlan = (widget.currentPlan.toLowerCase().contains('starter') || widget.currentPlan.toLowerCase().contains('free'))
        ? 'Growth'
        : widget.currentPlan;

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
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
    final plan = plans.firstWhere((p) => p['name'] == _selectedPlan);
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
      _razorpay.open(options);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedPlanData = plans.firstWhere((p) => p['name'] == _selectedPlan);
    final currentPrice = selectedPlanData['price'][_selectedDuration.toString()] ?? 0;
    final bool isCurrentPlanActive = _selectedPlan.toLowerCase() == widget.currentPlan.toLowerCase();

    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kWhite, size: 18),
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
                  _buildFeatureContainer(
                    title: "What's Included",
                    features: selectedPlanData['included'],
                    staffText: selectedPlanData['staffText'],
                    color: kGoogleGreen,
                    icon: Icons.check_circle_rounded,
                  ),
                  const SizedBox(height: 16),
                  if (selectedPlanData['excluded'].isNotEmpty)
                    _buildFeatureContainer(
                      title: "Not Included",
                      features: selectedPlanData['excluded'],
                      color: kErrorColor,
                      icon: Icons.cancel_rounded,
                      isExcluded: true,
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
                  Icon(plan['icon'], color: isSelected ? kWhite : kPrimaryColor, size: 22),
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
          _durationToggleItem("ANNUAL", 12, badge: "SAVE 20%"),
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
    required IconData icon,
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
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              Text(
                title.toUpperCase(),
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!isExcluded && staffText != null)
            _buildFeatureRow(staffText, kPrimaryColor, Icons.people_alt_rounded),

          ...features.map((feature) => _buildFeatureRow(
              feature,
              kBlack87,
              isExcluded ? Icons.remove_circle_outline_rounded : Icons.check_circle_outline_rounded
          )),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String text, Color textColor, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor.withOpacity(0.3), size: 16),
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

  Widget _buildCheckoutBottom(int price, bool isCurrent) {
    final currentPlanData = plans.firstWhere(
            (p) => p['name'].toLowerCase() == widget.currentPlan.toLowerCase(),
        orElse: () => plans[0]
    );
    final selectedPlanData = plans.firstWhere((p) => p['name'] == _selectedPlan);
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