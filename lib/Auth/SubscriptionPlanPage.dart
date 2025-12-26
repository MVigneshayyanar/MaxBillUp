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
  int _selectedDuration = 1;

  Map<String, dynamic>? _storeData;

  // Professional Color Palette
  final Color _primaryColor = const Color(0xFF2F7CF6);
  final Color _accentColor = const Color(0xFF2F7CF6);
  final Color _bgColor = const Color(0xFFF4F7FA);
  final Color _surfaceColor = Colors.white;
  final Color _darkTextColor = const Color(0xFF1A1C1E);

  // MAXmybill Freemium SaaS Model Plan Data
  final List<Map<String, dynamic>> plans = [
    {
      'name': 'Starter',
      'price': {'1': 0, '12': 0},
      'features': ['Basic Billing', '7-Day History', '1 Device'],
      'description': 'Free Trial',
    },
    {
      'name': 'Essential',
      'price': {'1': 249, '12': 1999},
      'features': ['Pro Reports', 'Daybook', 'Admin Only'],
      'description': 'Solo Shop',
    },
    {
      'name': 'Growth',
      'price': {'1': 429, '12': 3499},
      'features': ['3 Staff Users', 'Credit Control', 'Analytics'],
      'description': 'Growing Team',
    },
    {
      'name': 'Pro',
      'price': {'1': 549, '12': 4499},
      'features': ['15 Staff Users', 'GST Reports', 'Bulk Tools'],
      'description': 'Enterprise',
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
        const SnackBar(content: Text("Success! Plan Activated"), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop();
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment Failed: ${response.message}'), backgroundColor: Colors.red),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {}

  void _startPayment() {
    final plan = plans.firstWhere((p) => p['name'] == _selectedPlan);
    final amount = plan['price'][_selectedDuration.toString()] * 100;

    if (amount <= 0) {
      _showSuccessAndPop('FREE_PLAN_ACTIVATION');
      return;
    }

    var options = {
      'key': 'rzp_test_1DP5mmOlF5G5ag',
      'amount': amount,
      'name': 'MAXmybill',
      'description': '$_selectedPlan Upgrade',
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
    final currentPlanObj = plans.firstWhere(
            (p) => p['name'] == _selectedPlan,
        orElse: () => plans[2]
    );
    final currentPrice = currentPlanObj['price'][_selectedDuration.toString()] ?? 0;
    final isCurrentPlanActive = _selectedPlan == widget.currentPlan;

    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(
        children: [
          // Header Section
          Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 5, bottom: 10),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_accentColor, _primaryColor]),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Text(
                        "Upgrade MAXmybill",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                _buildCompactToggle(),
              ],
            ),
          ),

          // Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  children: [
                    // 2x2 Plan Grid
                    _buildPlanGrid(),
                    const SizedBox(height: 12),
                    // Full Feature Comparison Table
                    _buildFullComparisonTable(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),

          _buildCompactBottomBar(currentPrice, isCurrentPlanActive),
        ],
      ),
    );
  }

  Widget _buildCompactToggle() {
    return Container(
      width: 180,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        children: [
          _toggleItem("Monthly", 1),
          _toggleItem("Yearly", 12),
        ],
      ),
    );
  }

  Widget _toggleItem(String label, int value) {
    bool isSelected = _selectedDuration == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedDuration = value),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? _primaryColor : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanGrid() {
    return Column(
      children: [
        Row(
          children: [
            _buildCompactPlanCard(plans[0]),
            _buildCompactPlanCard(plans[1]),
          ],
        ),
        Row(
          children: [
            _buildCompactPlanCard(plans[2]),
            _buildCompactPlanCard(plans[3]),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactPlanCard(Map<String, dynamic> plan) {
    bool isSelected = _selectedPlan == plan['name'];

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPlan = plan['name']),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? _primaryColor : Colors.grey.shade200,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: _primaryColor.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 3))]
                : [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 2)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plan['name'],
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isSelected ? _primaryColor : _darkTextColor),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '₹${plan['price'][_selectedDuration.toString()]}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    '/${_selectedDuration == 1 ? 'mo' : 'yr'}',
                    style: TextStyle(fontSize: 7, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ... (plan['features'] as List).map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Row(
                  children: [
                    Icon(Icons.check, size: 8, color: isSelected ? _primaryColor : Colors.green),
                    const SizedBox(width: 3),
                    Expanded(child: Text(f, style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              )).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullComparisonTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const Text(
              "Full Feature Comparison",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueAccent),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              children: [
                _buildTableRow("Features", "Starter", "Essent.", "Growth", "Pro", isHeader: true),
                _buildTableRow("Staff Users", "Admin", "Admin", "3", "15"),
                _buildTableRow("Bill History", "7 Days", "Yes", "Yes", "Yes"),
                _buildTableRow("Daybook", "No", "Yes", "Yes", "Yes"),
                _buildTableRow("Reports", "No", "Yes", "Yes", "Yes"),
                _buildTableRow("Quotation", "No", "Yes", "Yes", "Yes"),
                _buildTableRow("Bulk Inventory", "No", "Yes", "Yes", "Yes"),
                _buildTableRow("Logo on Bill", "No", "Yes", "Yes", "Yes"),
                _buildTableRow("Customer Credit", "No", "Yes", "Yes", "Yes"),
                _buildTableRow("Edit Bill", "No", "Yes", "Yes", "Yes"),
                _buildTableRow("Tax Report", "No", "Yes", "Yes", "Yes"),
                _buildTableRow("Import Contacts", "No", "Yes", "Yes", "Yes"),
                _buildTableRow("POS Billing", "Yes", "Yes", "Yes", "Yes"),
                _buildTableRow("Expense", "Yes", "Yes", "Yes", "Yes"),
                _buildTableRow("Purchase", "Yes", "Yes", "Yes", "Yes"),
                _buildTableRow("Khata/Credit", "Yes", "Yes", "Yes", "Yes"),
                _buildTableRow("Cloud Storage", "Yes", "Yes", "Yes", "Yes"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(String feature, String v1, String v2, String v3, String v4, {bool isHeader = false}) {
    final style = TextStyle(
      fontWeight: isHeader ? FontWeight.bold : FontWeight.w600,
      fontSize: 8,
      color: isHeader ? Colors.black87 : Colors.grey.shade700,
    );

    const double colTitle = 100.0;
    const double colVal = 60.0;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        color: isHeader ? Colors.grey.shade50 : Colors.white,
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: colTitle, child: Text(feature, style: style.copyWith(color: isHeader ? _accentColor : _primaryColor))),
          _buildCompValue(v1, style, colVal),
          _buildCompValue(v2, style, colVal),
          _buildCompValue(v3, style, colVal),
          _buildCompValue(v4, style, colVal),
        ],
      ),
    );
  }

  Widget _buildCompValue(String val, TextStyle style, double width) {
    Widget content;
    if (val == "Yes") {
      content = const Icon(Icons.check_circle, size: 10, color: Colors.green);
    } else if (val == "No") {
      content = Icon(Icons.close, size: 10, color: Colors.red.shade300);
    } else {
      content = Text(val, style: style, textAlign: TextAlign.center);
    }

    return SizedBox(
      width: width,
      child: Center(child: content),
    );
  }

  Widget _buildCompactBottomBar(dynamic price, bool isCurrent) {
    return Container(
      padding: EdgeInsets.zero, // 🔴 remove all padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,     // 🔴 remove top safe padding
        bottom: false,  // 🔴 remove bottom safe padding
        child: Row(
          children: [
            // Price Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Total Payable",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    price == 0 ? "Free" : "₹$price",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                ],
              ),
            ),

            // Action Button
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 20),
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: isCurrent ? null : _startPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      isCurrent ? Colors.grey.shade300 : _primaryColor,
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.grey.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      shadowColor: Colors.black.withOpacity(0.15),
                    ),
                    child: Text(
                      isCurrent
                          ? "Active"
                          : (price == 0 ? 'Activate' : "Upgrade Now"),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
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