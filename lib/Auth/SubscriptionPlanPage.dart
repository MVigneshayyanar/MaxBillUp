import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/plan_permission_helper.dart';
import 'package:maxbillup/Settings/Profile.dart';

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
  String _selectedPlan = '';
  int _selectedDuration = 12;

  Map<String, dynamic>? _storeData;

  // Modern Color Scheme
  final Color _accentPurple = const Color(0xFF7C3AED);
  final Color _accentPink = const Color(0xFFEC4899);
  final Color _darkBg = const Color(0xFF0F172A);
  final Color _cardBg = const Color(0xFF1E293B);
  final Color _textLight = const Color(0xFFF1F5F9);
  final Color _textMuted = const Color(0xFF94A3B8);

  final List<Map<String, dynamic>> plans = [
    {
      'name': 'Starter',
      'price': {'1': 0, '12': 0},
      'tagline': 'For Beginners',
      'icon': Icons.rocket_launch_outlined,
      'gradient': [Color(0xFF64748B), Color(0xFF475569)],
      'features': [
        {'text': 'Basic Billing', 'included': true},
        {'text': '7-Day History', 'included': true},
        {'text': 'Single User', 'included': true},
        {'text': 'Email Support', 'included': true},
      ],
    },
    {
      'name': 'Essential',
      'price': {'1': 249, '12': 1999},
      'tagline': 'For Solo Owners',
      'icon': Icons.business_center_outlined,
      'gradient': [Color(0xFF3B82F6), Color(0xFF2563EB)],
      'features': [
        {'text': 'Pro Reports', 'included': true},
        {'text': 'Daybook Access', 'included': true},
        {'text': 'Quotations', 'included': true},
        {'text': 'Logo on Bills', 'included': true},
      ],
    },
    {
      'name': 'Growth',
      'price': {'1': 429, '12': 3499},
      'tagline': 'For Growing Teams',
      'icon': Icons.trending_up_outlined,
      'gradient': [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
      'popular': true,
      'features': [
        {'text': 'Up to 3 Staff Accounts', 'included': true},
        {'text': 'Customer Credit System', 'included': true},
        {'text': 'Advanced Analytics', 'included': true},
        {'text': 'Priority Support', 'included': true},
      ],
    },
    {
      'name': 'Pro',
      'price': {'1': 549, '12': 4499},
      'tagline': 'For Enterprises',
      'icon': Icons.workspace_premium_outlined,
      'gradient': [Color(0xFFEC4899), Color(0xFFDB2777)],
      'features': [
        {'text': 'Up to 15 Staff Accounts', 'included': true},
        {'text': 'GST Reports & Compliance', 'included': true},
        {'text': 'Bulk Inventory Management', 'included': true},
        {'text': '24/7 Premium Support', 'included': true},
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _selectedPlan = (widget.currentPlan == 'Starter' || widget.currentPlan == 'Free')
        ? 'Growth'
        : widget.currentPlan;

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _loadStorePlan();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _loadStorePlan() async {
    try {
      final storeDoc = await FirestoreService().getCurrentStoreDoc();
      if (!mounted) return;
      if (storeDoc != null && storeDoc.exists) {
        setState(() {
          _storeData = storeDoc.data() as Map<String, dynamic>?;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    _showSuccessAndPop(response.paymentId ?? 'TXN_SUCCESS');
  }

  void _showSuccessAndPop(String paymentId) async {
    final now = DateTime.now();
    DateTime expiryDate = _selectedDuration == 1
        ? DateTime(now.year, now.month + 1, now.day)
        : DateTime(now.year + 1, now.month, now.day);

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
          content: const Text("🎉 Premium Activated Successfully!"),
          backgroundColor: _accentPurple,
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
          backgroundColor: Colors.red.shade400,
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
      'currency': 'INR',
      'theme': {'color': '#7C3AED'}
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPlanObj = plans.firstWhere((p) => p['name'] == _selectedPlan, orElse: () => plans[2]);
    final currentPrice = currentPlanObj['price'][_selectedDuration.toString()] ?? 0;
    final isCurrentPlanActive = _selectedPlan == widget.currentPlan;

    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildModernHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildDurationToggle(),
                    const SizedBox(height: 24),
                    ...plans.map((plan) => _buildModernPlanCard(plan)),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildFloatingCheckout(currentPrice, isCurrentPlanActive),
    );
  }

  Widget _buildModernHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: _textLight, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Choose Your Plan",
                  style: TextStyle(
                    color: _textLight,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Unlock premium features & grow faster",
                  style: TextStyle(color: _textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationToggle() {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          _durationOption("Monthly", 1),
          _durationOption("Yearly", 12, badge: "SAVE 20%"),
        ],
      ),
    );
  }

  Widget _durationOption(String label, int duration, {String? badge}) {
    bool isActive = _selectedDuration == duration;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedDuration = duration),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: isActive
                ? LinearGradient(colors: [_accentPurple, _accentPink])
                : null,
            color: isActive ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : _textMuted,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (badge != null && isActive)
                Positioned(
                  top: 4,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade400,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernPlanCard(Map<String, dynamic> plan) {
    bool isSelected = _selectedPlan == plan['name'];
    bool isPopular = plan['popular'] == true;
    final price = plan['price'][_selectedDuration.toString()] ?? 0;
    final gradient = plan['gradient'] as List<Color>;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = plan['name']),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: isSelected
              ? LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: isSelected ? null : _cardBg,
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.1),
            width: 2,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: gradient[0].withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ]
              : [],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withOpacity(0.2)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          plan['icon'],
                          color: isSelected ? Colors.white : gradient[0],
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan['name'],
                              style: TextStyle(
                                color: isSelected ? Colors.white : _textLight,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              plan['tagline'],
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white.withOpacity(0.8)
                                    : _textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.check, color: gradient[0], size: 20),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        price == 0 ? "Free" : "₹$price",
                        style: TextStyle(
                          color: isSelected ? Colors.white : _textLight,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          price == 0 ? "" : "/${_selectedDuration == 1 ? 'month' : 'year'}",
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white.withOpacity(0.7)
                                : _textMuted,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ...((plan['features'] as List).map((feature) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withOpacity(0.2)
                                  : Colors.green.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check,
                              size: 14,
                              color: isSelected ? Colors.white : Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              feature['text'],
                              style: TextStyle(
                                color: isSelected ? Colors.white : _textLight,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  })),
                ],
              ),
            ),
            if (isPopular)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.amber, Colors.orange]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.star, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        "POPULAR",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingCheckout(int price, bool isCurrent) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (price > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Total Amount",
                    style: TextStyle(color: _textMuted, fontSize: 14),
                  ),
                  Text(
                    "₹$price",
                    style: TextStyle(
                      color: _textLight,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isCurrent ? null : _startPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCurrent ? Colors.grey.shade700 : _accentPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                  disabledBackgroundColor: Colors.grey.shade700,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isCurrent ? Icons.check_circle : Icons.rocket_launch,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isCurrent ? "Current Active Plan" : "Upgrade Now",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}