import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:maxbillup/utils/firestore_service.dart';
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
  int _selectedDuration = 1; // 1: month, 6: 6 months, 12: year

  // 0.000ms Loading Strategy:
  // We initialize as 'false' immediately so the UI builds instantly.
  // We don't block the UI for the Firestore call.
  bool _isLoading = false;

  Map<String, dynamic>? _storeData;

  // Define App Colors for consistency
  final Color _primaryColor = Colors.blue;
  final Color _backgroundColor = const Color(0xFFF8F9FA);

  final List<Map<String, dynamic>> plans = [
    {
      'name': 'Elite',
      'price': {'1': 199, '6': 999, '12': 1599},
      'features': ['Daybook', 'Report', 'All Free Features'],
      'staff': 0,
      'description': 'Perfect for starters',
    },
    {
      'name': 'Prime',
      'price': {'1': 399, '6': 1699, '12': 2499},
      'features': ['User/Staff - 3', 'All Elite Features', 'Priority Support'],
      'staff': 3,
      'description': 'Best for growing shops',
    },
    {
      'name': 'Max',
      'price': {'1': 499, '6': 2199, '12': 3499},
      'features': ['User/Staff - 10', 'All Prime Features', 'Bulk Tools'],
      'staff': 10,
      'description': 'For large businesses',
    },
  ];

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();

    // Instant Initialization: Use passed widget data immediately
    _selectedPlan = plans.any((p) => p['name'] == widget.currentPlan)
        ? widget.currentPlan
        : 'Elite';

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    // Background Fetch: Updates UI silently when data arrives
    _loadStorePlan();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  // "Fetched Fetching Algorithm": Render first, fetch later, update silently.
  Future<void> _loadStorePlan() async {
    try {
      final storeDoc = await FirestoreService().getCurrentStoreDoc();

      // Safety check: Ensure widget is still on screen
      if (!mounted) return;

      if (storeDoc != null && storeDoc.exists) {
        final data = storeDoc.data() as Map<String, dynamic>?;
        final planFromStore = data?['plan']?.toString();

        setState(() {
          _storeData = data;
          // Only override if the plan from store is valid and different
          if (planFromStore != null &&
              planFromStore.isNotEmpty &&
              plans.any((p) => p['name'] == planFromStore)) {
            _selectedPlan = planFromStore;
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading store plan silently: $e");
      // No setState needed here as we want to keep the default UI rather than showing an error
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final now = DateTime.now();
      DateTime expiryDate;
      if (_selectedDuration == 1) {
        expiryDate = DateTime(now.year, now.month + 1, now.day);
      } else if (_selectedDuration == 6) {
        expiryDate = DateTime(now.year, now.month + 6, now.day);
      } else {
        expiryDate = DateTime(now.year + 1, now.month, now.day);
      }

      final storeDoc = await FirestoreService().getCurrentStoreDoc();
      if (storeDoc == null) return;

      await FirestoreService().storeCollection.doc(storeDoc.id).update({
        'plan': _selectedPlan,
        'subscriptionStartDate': now.toIso8601String(),
        'subscriptionExpiryDate': expiryDate.toIso8601String(),
        'paymentId': response.paymentId,
        'lastPaymentDate': now.toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment Successful! Plan Upgraded.'),
            backgroundColor: Colors.green,
          ),
        );
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => SettingsPage(uid: widget.uid),
            ),
                (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${response.message}'), backgroundColor: Colors.red),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {}

  void _startPayment() {
    final plan = plans.firstWhere((p) => p['name'] == _selectedPlan);
    final amount = plan['price'][_selectedDuration.toString()] * 100;

    const razorpayKey = 'rzp_test_1DP5mmOlF5G5ag';

    var options = {
      'key': razorpayKey,
      'amount': amount,
      'name': 'MAXmybill',
      'description': '$_selectedPlan Plan',
      'prefill': {'contact': '', 'email': ''},
      'currency': 'INR',
      'theme': {'color': '#1565C0'}
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine Current Price for Bottom Bar
    final currentPlanObj = plans.firstWhere(
          (p) => p['name'] == _selectedPlan,
      orElse: () => plans[0],
    );
    final currentPrice = currentPlanObj['price'][_selectedDuration.toString()] ?? 0;

    // Check active status safely
    final isCurrentPlanActive = _selectedPlan == widget.currentPlan;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => SettingsPage(uid: widget.uid),
              ),
                  (route) => false,
            );
          },
        ),
        title: const Text(
          'Upgrade Plan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey.shade200, height: 1.0),
        ),
      ),
      body: WillPopScope(
        onWillPop: () async {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => SettingsPage(uid: widget.uid),
            ),
                (route) => false,
          );
          return false;
        },
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStoreHeader(),
                const SizedBox(height: 24),
                _buildDurationToggle(),
                const SizedBox(height: 24),
                _buildPlanList(),
                const SizedBox(height: 32),
                _buildComparisonSection(),
                const SizedBox(height: 100), // Space for bottom bar
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(currentPrice, isCurrentPlanActive),
    );
  }

  Widget _buildStoreHeader() {
    // If store data hasn't loaded yet (0ms load), we hide this section gracefully
    // or you could show a placeholder. For now, we hide it to prevent layout jumps.
    if (_storeData == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.store, color: _primaryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _storeData?['businessName'] ?? 'Your Store',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (_storeData?['subscriptionExpiryDate'] != null)
                    Text(
                      'Expires: ${_storeData!['subscriptionExpiryDate'].toString().split('T')[0]}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isPlanActive(widget.currentPlan) ? Colors.green.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.currentPlan,
                style: TextStyle(
                  color: isPlanActive(widget.currentPlan) ? Colors.green.shade700 : Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  bool isPlanActive(String planName) {
    return planName != 'Free';
  }

  Widget _buildDurationToggle() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(30),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _toggleOption('Monthly', 1),
            _toggleOption('6 Months', 6),
            _toggleOption('Yearly', 12, discount: 'SAVE 20%'),
          ],
        ),
      ),
    );
  }

  Widget _toggleOption(String title, int value, {String? discount}) {
    final bool isSelected = _selectedDuration == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedDuration = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]
              : [],
        ),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.black87 : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
            if (discount != null && !isSelected) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  discount,
                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildPlanList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: plans.length,
      itemBuilder: (context, index) {
        final plan = plans[index];
        final isSelected = _selectedPlan == plan['name'];
        final price = plan['price'][_selectedDuration.toString()];

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? _primaryColor : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: _primaryColor.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ]
                : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _selectedPlan = plan['name']),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan['name'],
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              plan['description'],
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹$price',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _primaryColor,
                              ),
                            ),
                            Text(
                              _selectedDuration == 1 ? '/month' : '/period',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: Colors.grey.shade200),
                    const SizedBox(height: 12),
                    ...plan['features'].map<Widget>((feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 18, color: Colors.green.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              feature,
                              style: const TextStyle(fontSize: 14, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildComparisonSection() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text(
            "Full Feature Comparison",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            children: [
              // Header
              _buildTableRow("Feature", "Free", "Elite", "Prime", "Max", isHeader: true),
              // Data Rows
              _buildTableRow("Staff", "No", "No", "3", "10"),
              _buildTableRow("Bill History", "7 days", "Yes", "Yes", "Yes"),
              _buildTableRow("DayBook", "No", "Yes", "Yes", "Yes"),
              _buildTableRow("Report", "No", "Yes", "Yes", "Yes"),
              _buildTableRow("Quotation", "No", "Yes", "Yes", "Yes"),
              _buildTableRow("Bulk Inventory", "No", "Yes", "Yes", "Yes"),
              _buildTableRow("Logo On Bill", "No", "Yes", "Yes", "Yes"),
              _buildTableRow("Customer Credit", "No", "Yes", "Yes", "Yes"),
              _buildTableRow("Edit Bill", "No", "Yes", "Yes", "Yes"),
              _buildTableRow("TAX Report", "No", "Yes", "Yes", "Yes"),
              _buildTableRow("Import Contacts", "No", "Yes", "Yes", "Yes"),
              _buildTableRow("POS Billing", "Yes", "Yes", "Yes", "Yes"),
              _buildTableRow("Expense", "Yes", "Yes", "Yes", "Yes"),
              _buildTableRow("Purchase", "Yes", "Yes", "Yes", "Yes"),
              _buildTableRow("Credit", "Yes", "Yes", "Yes", "Yes"),
              _buildTableRow("Cloud Storage", "Yes", "Yes", "Yes", "Yes"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableRow(String f, String v0, String v1, String v2, String v3, {bool isHeader = false}) {
    final style = TextStyle(
      fontWeight: isHeader ? FontWeight.bold : FontWeight.w500,
      fontSize: isHeader ? 12 : 11,
      color: isHeader ? Colors.black87 : Colors.grey.shade700,
    );

    final checkIcon = Icon(Icons.check, size: 16, color: Colors.green.shade600);
    final closeIcon = Icon(Icons.close, size: 16, color: Colors.red.shade400);

    Widget buildValue(String val) {
      if (val == "Yes") return checkIcon;
      if (val == "No") return closeIcon;
      if (val == "7 days") {
        return Text(val,
          style: style.copyWith(color: Colors.orange, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        );
      }
      return Text(
          val,
          style: style.copyWith(
              color: _primaryColor,
              fontWeight: FontWeight.bold
          )
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        color: isHeader ? Colors.grey.shade50 : Colors.white,
      ),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Row(
        children: [
          // Feature Name
          Expanded(flex: 2, child: Text(f, style: style.copyWith(fontWeight: FontWeight.w600))),
          // Free
          Expanded(child: Center(child: isHeader ? Text(v0, style: style) : buildValue(v0))),
          // Elite
          Expanded(child: Center(child: isHeader ? Text(v1, style: style) : buildValue(v1))),
          // Prime
          Expanded(child: Center(child: isHeader ? Text(v2, style: style) : buildValue(v2))),
          // Max
          Expanded(child: Center(child: isHeader ? Text(v3, style: style) : buildValue(v3))),
        ],
      ),
    );
  }

  Widget _buildBottomBar(dynamic price, bool isCurrent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Total Payable", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(
                    "₹$price.0",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ElevatedButton(
                onPressed: isCurrent ? null : _startPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  disabledBackgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  isCurrent ? "Current Plan" : "Pay Now",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}