import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
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
      'icon': Icons.rocket_launch_outlined,
      'staffText': 'Single admin + no staff',
      'included': [
        'bill history for 7 days',
        'POS Billing',
        'Expense',
        'Purchase',
        'Credit',
        'Cloud Storage'
      ],
      'excluded': [
        'DayBook',
        'Report',
        'Quotation',
        'Bulk Inventory Upload',
        'Logo On Bill',
        'Customer credit details',
        'Edit Bill',
        'TAX Report',
        'Import Contacts'
      ],
    },
    {
      'name': 'Essential',
      'rank': 1,
      'price': {'1': 249, '6': 1299, '12': 1999},
      'icon': Icons.business_center_outlined,
      'staffText': 'Single admin + no staff account',
      'included': [
        'bill history full',
        'POS Billing',
        'Expense',
        'Purchase',
        'Credit',
        'Cloud Storage',
        'DayBook',
        'Report',
        'Quotation',
        'Bulk Inventory Upload',
        'Logo On Bill',
        'Customer credit details',
        'Edit Bill',
        'TAX Report',
        'Import Contacts'
      ],
      'excluded': [
        'Up to 3 Staff Accounts',
        'Advanced Team Analytics',
        'Priority Support',
      ],
    },
    {
      'name': 'Growth',
      'rank': 2,
      'price': {'1': 429, '6': 2299, '12': 3499},
      'icon': Icons.trending_up_outlined,
      'popular': true,
      'staffText': 'Single admin + upto 3 staff account',
      'included': [
        'bill history full',
        'POS Billing',
        'Expense',
        'Purchase',
        'Credit',
        'Cloud Storage',
        'DayBook',
        'Report',
        'Quotation',
        'Bulk Inventory Upload',
        'Logo On Bill',
        'Customer credit details',
        'Edit Bill',
        'TAX Report',
        'Import Contacts'
      ],
      'excluded': [
        'Up to 15 Staff Accounts',
        'Bulk SMS Marketing',
        'Dedicated Account Manager'
      ],
    },
    {
      'name': 'Pro',
      'rank': 3,
      'price': {'1': 529, '6': 2899, '12': 4299},
      'icon': Icons.workspace_premium_outlined,
      'staffText': 'Single admin + up to 15 staff account',
      'included': [
        'bill history full',
        'POS Billing',
        'Expense',
        'Purchase',
        'Credit',
        'Cloud Storage',
        'DayBook',
        'Report',
        'Quotation',
        'Bulk Inventory Upload',
        'Logo On Bill',
        'Customer credit details',
        'Edit Bill',
        'TAX Report',
        'Import Contacts'
      ],
      'excluded': [],
    },
  ];

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    // Default to 'Growth' if current plan is Starter or Free
    _selectedPlan = (widget.currentPlan == 'Starter' || widget.currentPlan == 'Free' || widget.currentPlan == 'Free Plan')
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

    await FirestoreService().storeCollection.doc(storeDoc.id).update({
      'plan': _selectedPlan,
      'subscriptionStartDate': now.toIso8601String(),
      'subscriptionExpiryDate': expiryDate.toIso8601String(),
      'paymentId': paymentId,
      'lastPaymentDate': now.toIso8601String(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("🎉 Plan Upgraded Successfully!"),
          backgroundColor: kGoogleGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment Failed: ${response.message}'),
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
      'name': 'MAXbillup',
      'description': '$_selectedPlan Plan Upgrade',
      'currency': 'INR',
      'theme': {'color': '#2F7CF6'}
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

    // Logic to handle matching plans accurately
    final bool isCurrentPlanActive = _selectedPlan.toLowerCase() == widget.currentPlan.toLowerCase();

    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('Subscription Plans'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: kBorderColor, thickness: 1.5),
        ),
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
                  const SizedBox(height: 16),
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
                      color: kGoogleRed,
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

  Widget _buildHorizontalPlanSelector() {
    return Container(
      height: 110,
      color: kWhite,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        itemCount: plans.length,
        itemBuilder: (context, index) {
          final plan = plans[index];
          final isSelected = _selectedPlan == plan['name'];
          final monthlyPrice = plan['price']['1'];

          return GestureDetector(
            onTap: () => setState(() => _selectedPlan = plan['name']),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 87,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: isSelected ? kPrimaryColor : kWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSelected ? kPrimaryColor : kBorderColor, width: 2),
                boxShadow: isSelected ? [BoxShadow(color: kPrimaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(plan['icon'], color: isSelected ? kWhite : kBlack54, size: 22),
                  const SizedBox(height: 4),
                  Text(
                    plan['name'],
                    style: TextStyle(
                      color: isSelected ? kWhite : kBlack87,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    monthlyPrice == 0 ? "Free" : "$monthlyPrice/mo",
                    style: TextStyle(
                      color: isSelected ? kWhite.withOpacity(0.9) : kBlack54,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor, width: 1.5),
      ),
      child: Row(
        children: [
          _durationToggleItem("1 Month", 1),
          _durationToggleItem("6 Months", 6),
          _durationToggleItem("1 Year", 12, badge: "SAVE 20%"),
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
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isActive ? kWhite : kBlack54,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.2), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Text(
                title.toUpperCase(),
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!isExcluded && staffText != null)
            _buildFeatureRow(staffText, kOrange, Icons.people_alt_rounded),

          ...features.map((feature) => _buildFeatureRow(
              feature,
              kBlack87,
              isExcluded ? Icons.remove_circle_outline : Icons.check_circle_outline
          )),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String text, Color textColor, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor.withOpacity(0.6), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutBottom(int price, bool isCurrent) {
    // Current Plan Rank mapping
    final currentPlanData = plans.firstWhere(
            (p) => p['name'].toLowerCase() == widget.currentPlan.toLowerCase(),
        orElse: () => plans[0] // Defaults to Starter if current plan is unknown
    );

    // Selected Plan Rank mapping
    final selectedPlanData = plans.firstWhere((p) => p['name'] == _selectedPlan);

    // Switch logic: Only allowed to move to a HIGHER rank
    final bool isUpgrade = selectedPlanData['rank'] > currentPlanData['rank'];

    String buttonText;
    bool isEnabled;

    if (isCurrent) {
      buttonText = "Active Plan";
      isEnabled = false;
    } else if (isUpgrade) {
      buttonText = "Upgrade Now";
      isEnabled = true;
    } else {
      buttonText = "Higher Plan Only";
      isEnabled = false;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: kWhite,
        border: Border(top: BorderSide(color: kBorderColor, width: 2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Total Payable", style: TextStyle(color: kBlack54, fontWeight: FontWeight.w700, fontSize: 12)),
                Text("$price", style: const TextStyle(color: kPrimaryColor, fontSize: 26, fontWeight: FontWeight.w900)),
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
                  backgroundColor: isEnabled ? kPrimaryColor : kGrey300,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                  disabledBackgroundColor: kGrey300,
                ),
                child: Text(
                  buttonText,
                  style: TextStyle(
                      color: isEnabled ? kWhite : kBlack54,
                      fontSize: 15,
                      fontWeight: FontWeight.w900
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}