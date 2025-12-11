import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:maxbillup/utils/firestore_service.dart';

class SubscriptionPlanPage extends StatefulWidget {
  final String uid;
  final String currentPlan;

  const SubscriptionPlanPage({super.key, required this.uid, required this.currentPlan});

  @override
  State<SubscriptionPlanPage> createState() => _SubscriptionPlanPageState();
}

class _SubscriptionPlanPageState extends State<SubscriptionPlanPage> {
  late Razorpay _razorpay;
  String _selectedPlan = '';
  int _selectedDuration = 1; // 1: month, 6: 6 months, 12: year
  bool _isLoading = true;
  Map<String, dynamic>? _storeData;

  final List<Map<String, dynamic>> plans = [
    {
      'name': 'Elite',
      'price': {'1': 199, '6': 999, '12': 1599},
      'features': ['Daybook', 'Report', 'All Free Features'],
      'staff': 0,
      'billHistory': true,
    },
    {
      'name': 'Prime',
      'price': {'1': 399, '6': 1699, '12': 2499},
      'features': ['User/Staff - 3', 'All Elite Features'],
      'staff': 3,
      'billHistory': true,
    },
    {
      'name': 'Max',
      'price': {'1': 499, '6': 2199, '12': 3499},
      'features': ['User/Staff - 10', 'All Prime Features'],
      'staff': 10,
      'billHistory': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    // Set default to Elite if current plan is not in the list (e.g., Free, Business Trial)
    _selectedPlan = plans.any((p) => p['name'] == widget.currentPlan) ? widget.currentPlan : 'Elite';
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    // Load store-scoped plan from backend and override the default if present
    _loadStorePlan();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      // Calculate expiry date based on duration
      final now = DateTime.now();
      DateTime expiryDate;
      if (_selectedDuration == 1) {
        expiryDate = DateTime(now.year, now.month + 1, now.day);
      } else if (_selectedDuration == 6) {
        expiryDate = DateTime(now.year, now.month + 6, now.day);
      } else {
        expiryDate = DateTime(now.year + 1, now.month, now.day);
      }

      // Update store document (store-scoped) with new plan and subscription details.
      final storeDoc = await FirestoreService().getCurrentStoreDoc();
      if (storeDoc == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No store found for current user; plan not applied')));
        }
        return;
      }

      // Update plan and subscription metadata on the store document.
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
            content: Text('Payment Successful! Your plan has been upgraded.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        // Wait a bit before navigating back to show the success message
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating subscription: ${e.toString()}')),
        );
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment Failed: ${response.message ?? "Unknown error"}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('External Wallet Selected')));
  }

  void _startPayment() {
    final plan = plans.firstWhere((p) => p['name'] == _selectedPlan);
    final amount = plan['price'][_selectedDuration.toString()] * 100; // Razorpay expects paise ( 1 = 100 paise)

    // TODO: Replace with your actual Razorpay API Key from https://dashboard.razorpay.com/
    const razorpayKey = 'rzp_test_1DP5mmOlF5G5ag'; // This is a test key, replace with your key

    var options = {
      'key': razorpayKey,
      'amount': amount,
      'name': 'MAXmybill',
      'description': '$_selectedPlan Plan - ${_selectedDuration == 1 ? '1 Month' : _selectedDuration == 6 ? '6 Months' : '1 Year'}',
      'prefill': {
        'contact': '',
        'email': ''
      },
      'currency': 'INR',
      'theme': {
        'color': '#1976D2'
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadStorePlan() async {
    try {
      final storeDoc = await FirestoreService().getCurrentStoreDoc();
      if (storeDoc != null && storeDoc.exists) {
        final data = storeDoc.data() as Map<String, dynamic>?;
        final planFromStore = data?['plan']?.toString();
        setState(() {
          _storeData = data;
          if (planFromStore != null && planFromStore.isNotEmpty && plans.any((p) => p['name'] == planFromStore)) {
            _selectedPlan = planFromStore;
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      // If loading fails, just stop loading and keep defaults
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print('Error loading store plan: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final horizontalPadding = screenWidth * 0.04;
    final verticalPadding = screenHeight * 0.02;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Choose a Plan',
          style: TextStyle(
            fontSize: screenWidth * 0.05,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Show store info if available
          if (_storeData != null) ...[
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding * 0.6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      _storeData?['businessName']?.toString() ?? _storeData?['name']?.toString() ?? 'Store',
                      style: TextStyle(fontSize: screenWidth * 0.044, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _storeData?['subscriptionExpiryDate'] != null
                        ? 'Expiry: ${_storeData!['subscriptionExpiryDate']}'
                        : '',
                    style: TextStyle(fontSize: screenWidth * 0.034, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],

          // main content

           Padding(
             padding: EdgeInsets.symmetric(vertical: verticalPadding),
             child: Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 _buildDurationButton('1 month', 1, screenWidth),
                 _buildDurationButton('6 Month', 6, screenWidth),
                 _buildDurationButton('1 Year', 12, screenWidth),
               ],
             ),
           ),
           Expanded(
             child: ListView.builder(
               itemCount: plans.length,
               itemBuilder: (context, idx) {
                 final plan = plans[idx];
                 final isSelected = _selectedPlan == plan['name'];
                 return GestureDetector(
                   onTap: () {
                     setState(() {
                       _selectedPlan = plan['name'];
                     });
                   },
                   child: Container(
                     margin: EdgeInsets.symmetric(
                       horizontal: horizontalPadding,
                       vertical: screenHeight * 0.01,
                     ),
                     padding: EdgeInsets.all(screenWidth * 0.045),
                     decoration: BoxDecoration(
                       gradient: isSelected
                           ? const LinearGradient(
                               colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
                               begin: Alignment.topLeft,
                               end: Alignment.bottomRight,
                             )
                           : null,
                       color: isSelected ? null : Colors.white,
                       borderRadius: BorderRadius.circular(16),
                       boxShadow: [
                         BoxShadow(
                           color: isSelected
                               ? const Color(0xFF1976D2).withOpacity(0.3)
                               : Colors.black.withOpacity(0.08),
                           blurRadius: isSelected ? 12 : 8,
                           offset: Offset(0, isSelected ? 4 : 2),
                         ),
                       ],
                       border: Border.all(
                         color: isSelected ? const Color(0xFF1976D2) : Colors.transparent,
                         width: 2,
                       ),
                     ),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Expanded(
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text(
                                 plan['name'],
                                 style: TextStyle(
                                   fontSize: screenWidth * 0.055,
                                   fontWeight: FontWeight.bold,
                                   color: isSelected ? Colors.white : const Color(0xFF212121),
                                 ),
                               ),
                               SizedBox(height: screenHeight * 0.008),
                               Divider(
                                 color: isSelected ? Colors.white.withOpacity(0.5) : const Color(0xFFE0E0E0),
                                 thickness: 1,
                               ),
                               SizedBox(height: screenHeight * 0.008),
                               ...plan['features'].map<Widget>((f) => Padding(
                                 padding: EdgeInsets.symmetric(vertical: screenHeight * 0.003),
                                 child: Text(
                                   f,
                                   style: TextStyle(
                                     fontSize: screenWidth * 0.036,
                                     color: isSelected ? Colors.white.withOpacity(0.9) : const Color(0xFF616161),
                                   ),
                                 ),
                               )).toList(),
                             ],
                           ),
                         ),
                         SizedBox(width: screenWidth * 0.03),
                         Column(
                           crossAxisAlignment: CrossAxisAlignment.end,
                           children: [
                             Text(
                               'Rs ${plan['price'][_selectedDuration.toString()]}.0',
                               style: TextStyle(
                                 fontSize: screenWidth * 0.06,
                                 fontWeight: FontWeight.bold,
                                 color: isSelected ? Colors.white : const Color(0xFF1976D2),
                               ),
                             ),
                             Text(
                               _selectedDuration == 1 ? '1 month' : _selectedDuration == 6 ? '6 month' : '1 Year',
                               style: TextStyle(
                                 fontSize: screenWidth * 0.035,
                                 color: isSelected ? Colors.white.withOpacity(0.8) : const Color(0xFF757575),
                               ),
                             ),
                           ],
                         ),
                       ],
                     ),
                   ),
                 );
               },
             ),
           ),
           SizedBox(
             height: screenHeight * 0.3,
             child: SingleChildScrollView(
               child: _buildFeatureComparison(screenWidth),
             ),
           ),
           Padding(
             padding: EdgeInsets.all(horizontalPadding),
             child: Container(
               decoration: BoxDecoration(
                 gradient: _selectedPlan == widget.currentPlan
                     ? null
                     : const LinearGradient(
                         colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
                         begin: Alignment.topLeft,
                         end: Alignment.bottomRight,
                       ),
                 borderRadius: BorderRadius.circular(12),
                 boxShadow: _selectedPlan == widget.currentPlan
                     ? null
                     : [
                         BoxShadow(
                           color: const Color(0xFF1976D2).withOpacity(0.4),
                           blurRadius: 12,
                           offset: const Offset(0, 4),
                         ),
                       ],
               ),
               child: ElevatedButton(
                 onPressed: _selectedPlan == widget.currentPlan ? null : _startPayment,
                 style: ElevatedButton.styleFrom(
                   minimumSize: Size.fromHeight(screenHeight * 0.065),
                   backgroundColor: _selectedPlan == widget.currentPlan ? Colors.grey.shade300 : Colors.transparent,
                   foregroundColor: Colors.white,
                   elevation: 0,
                   shadowColor: Colors.transparent,
                   shape: RoundedRectangleBorder(
                     borderRadius: BorderRadius.circular(12),
                   ),
                   textStyle: TextStyle(
                     fontSize: screenWidth * 0.048,
                     fontWeight: FontWeight.bold,
                   ),
                 ),
                 child: Text(
                   'Pay Rs ${(plans.firstWhere((p) => p['name'] == _selectedPlan, orElse: () => plans[0])['price'][_selectedDuration.toString()] ?? 0)}.0',
                 ),
               ),
             ),
           ),
         ],
       ),
     );
   }

   Widget _buildDurationButton(String label, int duration, double screenWidth) {
     final buttonWidth = screenWidth * 0.28;
     final fontSize = screenWidth * 0.038;
     final isSelected = _selectedDuration == duration;

     return Padding(
       padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.01),
       child: ElevatedButton(
         onPressed: () {
           setState(() {
             _selectedDuration = duration;
           });
         },
         style: ElevatedButton.styleFrom(
           backgroundColor: isSelected ? const Color(0xFF1976D2) : const Color(0xFFE0E0E0),
           foregroundColor: isSelected ? Colors.white : const Color(0xFF757575),
           minimumSize: Size(buttonWidth, 45),
           textStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
           shape: RoundedRectangleBorder(
             borderRadius: BorderRadius.circular(25),
           ),
           elevation: isSelected ? 4 : 0,
           shadowColor: isSelected ? const Color(0xFF1976D2).withOpacity(0.4) : Colors.transparent,
         ),
         child: Text(label),
       ),
     );
   }

   Widget _buildFeatureComparison(double screenWidth) {
     final fontSize = screenWidth * 0.032;
     final cellPadding = screenWidth * 0.018;

     return Container(
       margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
       decoration: BoxDecoration(
         color: Colors.white,
         borderRadius: BorderRadius.circular(12),
         boxShadow: [
           BoxShadow(
             color: Colors.black.withOpacity(0.05),
             blurRadius: 8,
             offset: const Offset(0, 2),
           ),
         ],
       ),
       child: Padding(
         padding: const EdgeInsets.all(8.0),
         child: Table(
           border: TableBorder.all(color: const Color(0xFFE0E0E0), width: 1),
           columnWidths: const {
             0: FlexColumnWidth(2),
             1: FlexColumnWidth(1),
             2: FlexColumnWidth(1),
             3: FlexColumnWidth(1),
             4: FlexColumnWidth(1),
           },
           children: [
             TableRow(
               decoration: BoxDecoration(
                 color: const Color(0xFFF5F5F5),
               ),
               children: [
                 _tableCell('', fontSize, cellPadding, isHeader: true),
                 _tableCell('Free', fontSize, cellPadding, isHeader: true),
                 _tableCell('Elite', fontSize, cellPadding, isHeader: true),
                 _tableCell('Prime', fontSize, cellPadding, isHeader: true),
                 _tableCell('Max', fontSize, cellPadding, isHeader: true),
               ],
             ),
             TableRow(children: [
               _tableCell('Staff', fontSize, cellPadding),
               _tableCell('✗', fontSize, cellPadding, color: Colors.red),
               _tableCell('✗', fontSize, cellPadding, color: Colors.red),
               _tableCell('3', fontSize, cellPadding, color: const Color(0xFF1976D2)),
               _tableCell('10', fontSize, cellPadding, color: const Color(0xFF1976D2)),
             ]),
             TableRow(children: [
               _tableCell('Bill History', fontSize, cellPadding),
               _tableCell('7 days', fontSize, cellPadding, color: Colors.orange),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
             ]),
             TableRow(children: [
               _tableCell('DayBook', fontSize, cellPadding),
               _tableCell('✗', fontSize, cellPadding, color: Colors.red),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
             ]),
             TableRow(children: [
               _tableCell('Report', fontSize, cellPadding),
               _tableCell('✗', fontSize, cellPadding, color: Colors.red),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
             ]),
             TableRow(children: [
               _tableCell('Quotation', fontSize, cellPadding),
               _tableCell('✗', fontSize, cellPadding, color: Colors.red),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
             ]),
             TableRow(children: [
               _tableCell('Bulk Inventory Upload', fontSize, cellPadding),
               _tableCell('✗', fontSize, cellPadding, color: Colors.red),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
             ]),
             TableRow(children: [
               _tableCell('Logo On Bill', fontSize, cellPadding),
               _tableCell('✗', fontSize, cellPadding, color: Colors.red),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
             ]),
             TableRow(children: [
               _tableCell('Customer credit details', fontSize, cellPadding),
               _tableCell('✗', fontSize, cellPadding, color: Colors.red),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
             ]),
             TableRow(children: [
               _tableCell('Edit Bill', fontSize, cellPadding),
               _tableCell('✗', fontSize, cellPadding, color: Colors.red),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
             ]),
             TableRow(children: [
               _tableCell('TAX Report', fontSize, cellPadding),
               _tableCell('✗', fontSize, cellPadding, color: Colors.red),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
             ]),
             TableRow(children: [
               _tableCell('Import Contacts', fontSize, cellPadding),
               _tableCell('✗', fontSize, cellPadding, color: Colors.red),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
             ]),
             TableRow(children: [
               _tableCell('POS Billing', fontSize, cellPadding),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
             ]),
             TableRow(children: [
               _tableCell('Expense', fontSize, cellPadding),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
             ]),
             TableRow(children: [
               _tableCell('Purchase', fontSize, cellPadding),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
             ]),
             TableRow(children: [
               _tableCell('Credit', fontSize, cellPadding),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
             ]),
             TableRow(children: [
               _tableCell('Cloud Storage', fontSize, cellPadding),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
               _tableCell('✓', fontSize, cellPadding, color: Colors.green),
             ]),
           ],
         ),
       ),
     );
   }

   Widget _tableCell(String text, double fontSize, double padding, {bool isHeader = false, Color? color}) {
     return Padding(
       padding: EdgeInsets.all(padding),
       child: Center(
         child: Text(
           text,
           style: TextStyle(
             fontSize: fontSize,
             fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
             color: color ?? (isHeader ? const Color(0xFF212121) : const Color(0xFF616161)),
           ),
           textAlign: TextAlign.center,
         ),
       ),
     );
   }
 }
