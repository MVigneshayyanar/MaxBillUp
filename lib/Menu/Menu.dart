import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Colors.dart';
import 'package:provider/provider.dart';
import 'package:maxbillup/Auth/SubscriptionPlanPage.dart';
import 'package:maxbillup/Sales/Bill.dart';
import 'package:maxbillup/Sales/Invoice.dart';
import 'package:maxbillup/Sales/QuotationsList.dart';
import 'package:maxbillup/Menu/CustomerManagement.dart';
import 'package:maxbillup/Menu/AddCustomer.dart';
import 'package:maxbillup/Menu/KnowledgePage.dart';
import 'package:maxbillup/components/common_bottom_nav.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/Stocks/StockPurchase.dart';
import 'package:maxbillup/Stocks/ExpenseCategories.dart';
import 'package:maxbillup/Stocks/Expenses.dart';
import 'package:maxbillup/Stocks/Vendors.dart';
import 'package:maxbillup/Settings/StaffManagement.dart' hide kPrimaryColor, kErrorColor;
import 'package:maxbillup/Reports/Reports.dart' hide kPrimaryColor;
import 'package:maxbillup/Stocks/Stock.dart';
import 'package:maxbillup/Settings/Profile.dart' hide kGreyBg, kGrey300, kPrimaryColor, kBlack54, kBlack87, kErrorColor;
import 'package:maxbillup/utils/permission_helper.dart';
import 'package:maxbillup/utils/plan_permission_helper.dart';
import 'package:maxbillup/utils/plan_provider.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/Sales/NewSale.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/services/number_generator_service.dart';
// ignore: uri_does_not_exist
import 'package:url_launcher/url_launcher.dart' as launcher;




// ==========================================
// VIDEO TUTORIAL PAGE
// ==========================================
class VideoTutorialPage extends StatelessWidget {
  final VoidCallback onBack;
  const VideoTutorialPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Tutorial', style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF2F7CF6),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: onBack,
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Watch our video tutorial:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_circle_fill, color: Colors.white),
              label: const Text('Open Video Tutorial', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0288D1),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final url = Uri.parse('https://www.youtube.com/watch?v=dQw4w9WgXcQ'); // Replace with your actual tutorial link
                try {
                  if (await launcher.canLaunchUrl(url)) {
                    await launcher.launchUrl(url, mode: launcher.LaunchMode.externalApplication);
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not launch video tutorial.')),
                      );
                    }
                  }
                } catch (e) {
                  // Fallback for missing url_launcher dependency in IDE
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not launch video tutorial. (url_launcher not available)')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 1. MAIN MENU PAGE (ROUTER)
// ==========================================
class MenuPage extends StatefulWidget {
  final String uid;
  final String? userEmail;

  const MenuPage({super.key, required this.uid, this.userEmail});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  // Navigation State
  String? _currentView;

  // Data variables
  String _businessName = "Loading...";
  String _email = "";
  String _role = "staff";
  Map<String, dynamic> _permissions = {};

  // Rebuild key - increments when plan changes to force widget refresh
  int _rebuildKey = 0;

  // Stream Subscriptions
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  StreamSubscription<DocumentSnapshot>? _storeSubscription;

  // Colors
  final Color _headerBlue = Colors.blue ;
  final Color _iconColor = const Color(0xFF424242);
  final Color _textColor = const Color(0xFF212121);

  @override
  void initState() {
    super.initState();
    _email = widget.userEmail ?? "";
    _startFastUserDataListener();
    _startStoreDataListener();
    _loadPermissions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh permissions when returning from other pages (e.g., after plan purchase)
    _loadPermissions();
  }

  void _loadPermissions() async {
    final userData = await PermissionHelper.getUserPermissions(widget.uid);
    if (mounted) {
      setState(() {
        _permissions = userData['permissions'] as Map<String, dynamic>;
        _role = userData['role'] as String;
      });
    }
  }

  void _startStoreDataListener() async {
    try {
      final storeDoc = await FirestoreService().getCurrentStoreDoc();
      if (storeDoc != null) {
        _storeSubscription = FirebaseFirestore.instance
            .collection('store')
            .doc(storeDoc.id)
            .snapshots()
            .listen((snapshot) async {
          if (snapshot.exists && mounted) {
            // Don't cache data - just trigger rebuild to fetch fresh
            setState(() {
              _rebuildKey++;
            });
          }
        });
      }
    } catch (e) {
      print('Error starting store listener: $e');
    }
  }

  void _startFastUserDataListener() {
    try {
      _userSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && mounted) {
          Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
          setState(() {
            _businessName = data['businessName'] ?? data['name'] ?? 'Karadi Crackers';
            if (data.containsKey('email')) _email = data['email'];
            _role = data['role'] ?? 'Staff';
          });
        }
      });
    } catch (e) {
      debugPrint("Error initializing stream: $e");
    }
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _storeSubscription?.cancel();
    super.dispose();
  }

  void _reset() => setState(() => _currentView = null);

  bool _hasPermission(String permission) {
    return _permissions[permission] == true;
  }

  @override
  Widget build(BuildContext context) {
    // Use Consumer for real-time plan updates (listener triggerebuild)
    return Consumer<PlanProvider>(
      builder: (context, planProvider, child) {
        bool isAdmin = _role.toLowerCase() == 'admin' || _role.toLowerCase() == 'administrator';

        // ------------------------------------------
        // CONDITIONAL RENDERING SWITCH
        // ------------------------------------------
        switch (_currentView) {
        // New Sale
          case 'NewSale':
            return NewSalePage(uid: widget.uid, userEmail: widget.userEmail);

        // Inline Lists
          case 'Quotation':
            // Always fetch fresh from backend
            return FutureBuilder<bool>(
              future: planProvider.canAccessQuotationAsync(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (!snapshot.data!) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PlanPermissionHelper.showUpgradeDialog(context, 'Quotation', uid: widget.uid);
                    _reset();
                  });
                  return Container();
                }
                if (!_hasPermission('quotation') && !isAdmin) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PermissionHelper.showPermissionDeniedDialog(context);
                    _reset();
                  });
                  return Container();
                }
                return QuotationsListPage(uid: widget.uid, userEmail: widget.userEmail, onBack: _reset);
              },
            );

          case 'BillHistory':
            if (!_hasPermission('billHistory') && !isAdmin) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                PermissionHelper.showPermissionDeniedDialog(context);
            _reset();
          });
          return Container();
        }
        return SalesHistoryPage(uid: widget.uid, userEmail: widget.userEmail, onBack: _reset);

          case 'CreditNotes':
            // Always fetch fresh from backend
            return FutureBuilder<bool>(
              future: planProvider.canAccessCustomerCreditAsync(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (!snapshot.data!) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PlanPermissionHelper.showUpgradeDialog(context, 'Customer Credit', uid: widget.uid);
                    _reset();
                  });
                  return Container();
                }
                if (!_hasPermission('creditNotes') && !isAdmin) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PermissionHelper.showPermissionDeniedDialog(context);
                    _reset();
                  });
                  return Container();
                }
                return CreditNotesPage(uid: widget.uid, onBack: _reset);
              },
            );

          case 'Customers':
        if (!_hasPermission('customerManagement') && !isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            PermissionHelper.showPermissionDeniedDialog(context);
            _reset();
          });
          return Container();
        }
        return CustomersPage(uid: widget.uid, onBack: _reset);

          case 'CreditDetails':
            // Always fetch fresh from backend
            return FutureBuilder<bool>(
              future: planProvider.canAccessCustomerCreditAsync(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (!snapshot.data!) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PlanPermissionHelper.showUpgradeDialog(context, 'Customer Credit', uid: widget.uid);
                    _reset();
                  });
                  return Container();
                }
                if (!_hasPermission('creditDetails') && !isAdmin) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PermissionHelper.showPermissionDeniedDialog(context);
                    _reset();
                  });
                  return Container();
                }
                return CreditDetailsPage(uid: widget.uid, onBack: _reset);
              },
            );

        // Expenses Sub-menu items
          case 'StockPurchase':
        if (!_hasPermission('expenses') && !isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            PermissionHelper.showPermissionDeniedDialog(context);
            _reset();
          });
          return Container();
        }
        return StockPurchasePage(uid: widget.uid, onBack: _reset);

      case 'Expenses':
        if (!_hasPermission('expenses') && !isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            PermissionHelper.showPermissionDeniedDialog(context);
            _reset();
          });
          return Container();
        }
        return ExpensesPage(uid: widget.uid, onBack: _reset);

      case 'ExpenseCategories':
        if (!_hasPermission('expenses') && !isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            PermissionHelper.showPermissionDeniedDialog(context);
            _reset();
          });
          return Container();
        }
        return ExpenseCategoriesPage(uid: widget.uid, onBack: _reset);

      case 'Vendors':
        if (!_hasPermission('expenses') && !isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            PermissionHelper.showPermissionDeniedDialog(context);
            _reset();
          });
          return Container();
        }
        return VendorsPage(uid: widget.uid, onBack: _reset);

          // Staff Management
          case 'StaffManagement':
            // Always fetch fresh from backend
            return FutureBuilder<bool>(
              future: planProvider.canAccessStaffManagementAsync(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (!snapshot.data!) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PlanPermissionHelper.showUpgradeDialog(context, 'Staff Management', uid: widget.uid);
                    _reset();
                  });
                  return Container();
                }
                if (!_hasPermission('staffManagement') && !isAdmin) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PermissionHelper.showPermissionDeniedDialog(context);
                    _reset();
                  });
                  return Container();
                }
                return StaffManagementPage(uid: widget.uid, userEmail: widget.userEmail, onBack: _reset);
              },
            );

          // Knowledge
          case 'Knowledge':
            return KnowledgePage(onBack: _reset);

          // ==========================================
          // REPORTS SECTION
          // ==========================================

          case 'Analytics':
            // Always fetch fresh from backend
            return FutureBuilder<bool>(
              future: planProvider.canAccessReportsAsync(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (!snapshot.data!) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PlanPermissionHelper.showUpgradeDialog(context, 'Reports', uid: widget.uid);
                    _reset();
                  });
                  return Container();
                }
                if (!_hasPermission('analytics') && !isAdmin) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PermissionHelper.showPermissionDeniedDialog(context);
                    _reset();
                  });
                  return Container();
                }
                return AnalyticsPage(uid: widget.uid, onBack: _reset);
              },
            );

          case 'DayBook':
            // Daybook is FREE for everyone - no restrictions
            return DayBookPage(uid: widget.uid, onBack: _reset);

          case 'Summary':
            // Always fetch fresh from backend
            return FutureBuilder<bool>(
              future: planProvider.canAccessReportsAsync(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (!snapshot.data!) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PlanPermissionHelper.showUpgradeDialog(context, 'Reports', uid: widget.uid);
                    _reset();
                  });
                  return Container();
                }
                if (!_hasPermission('salesSummary') && !isAdmin) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PermissionHelper.showPermissionDeniedDialog(context);
                    _reset();
                  });
                  return Container();
                }
                return SalesSummaryPage(onBack: _reset);
              },
            );

          case 'SalesReport':
            return FutureBuilder<bool>(
              future: planProvider.canAccessReportsAsync(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (!snapshot.data!) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PlanPermissionHelper.showUpgradeDialog(context, 'Reports', uid: widget.uid);
                    _reset();
                  });
                  return Container();
                }
                if (!_hasPermission('salesReport') && !isAdmin) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PermissionHelper.showPermissionDeniedDialog(context);
                    _reset();
                  });
                  return Container();
                }
                return FullSalesHistoryPage(onBack: _reset);
              },
            );

          case 'ItemSales':
            return FutureBuilder<bool>(
              future: planProvider.canAccessReportsAsync(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (!snapshot.data!) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PlanPermissionHelper.showUpgradeDialog(context, 'Reports', uid: widget.uid);
                    _reset();
                  });
                  return Container();
                }
                if (!_hasPermission('itemSalesReport') && !isAdmin) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PermissionHelper.showPermissionDeniedDialog(context);
                    _reset();
                  });
                  return Container();
                }
                return ItemSalesPage(onBack: _reset);
              },
            );

          case 'TopCustomers':
            return FutureBuilder<bool>(
              future: planProvider.canAccessReportsAsync(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (!snapshot.data!) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PlanPermissionHelper.showUpgradeDialog(context, 'Reports', uid: widget.uid);
                    _reset();
                  });
                  return Container();
                }
                if (!_hasPermission('topCustomer') && !isAdmin) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PermissionHelper.showPermissionDeniedDialog(context);
                    _reset();
                  });
                  return Container();
                }
                return TopCustomersPage(uid: widget.uid, onBack: _reset);
              },
            );

          case 'StockReport':
            return FutureBuilder<bool>(
              future: planProvider.canAccessReportsAsync(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (!snapshot.data!) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PlanPermissionHelper.showUpgradeDialog(context, 'Reports', uid: widget.uid);
                    _reset();
                  });
                  return Container();
                }
                if (!_hasPermission('stockReport') && !isAdmin) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PermissionHelper.showPermissionDeniedDialog(context);
                    _reset();
                  });
                  return Container();
                }
                return StockReportPage(onBack: _reset);
              },
            );

          case 'LowStock':
            return FutureBuilder<bool>(
              future: planProvider.canAccessReportsAsync(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (!snapshot.data!) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PlanPermissionHelper.showUpgradeDialog(context, 'Reports', uid: widget.uid);
                    _reset();
              });
              return Container();
            }
            if (!_hasPermission('lowStockProduct') && !isAdmin) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                PermissionHelper.showPermissionDeniedDialog(context);
                _reset();
              });
              return Container();
                }
                return LowStockPage(onBack: _reset);
              },
            );

          case 'TopProducts':
            return FutureBuilder<bool>(
              future: planProvider.canAccessReportsAsync(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (!snapshot.data!) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PlanPermissionHelper.showUpgradeDialog(context, 'Reports', uid: widget.uid);
                    _reset();
                  });
                  return Container();
                }
                if (!_hasPermission('topProducts') && !isAdmin) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PermissionHelper.showPermissionDeniedDialog(context);
                    _reset();
                  });
                  return Container();
                }
                return TopProductsPage(uid: widget.uid, onBack: _reset);
              },
            );

          case 'TopCategories':
            return FutureBuilder<bool>(
              future: planProvider.canAccessReportsAsync(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (!snapshot.data!) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PlanPermissionHelper.showUpgradeDialog(context, 'Reports', uid: widget.uid);
                    _reset();
                  });
                  return Container();
                }
                if (!_hasPermission('topCategory') && !isAdmin) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PermissionHelper.showPermissionDeniedDialog(context);
                    _reset();
                  });
                  return Container();
                }
                return TopCategoriesPage(onBack: _reset);
              },
            );

          case 'ExpenseReport':
            return FutureBuilder<bool>(
              future: planProvider.canAccessReportsAsync(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (!snapshot.data!) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PlanPermissionHelper.showUpgradeDialog(context, 'Reports', uid: widget.uid);
                    _reset();
                  });
                  return Container();
                }
                if (!_hasPermission('expensesReport') && !isAdmin) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PermissionHelper.showPermissionDeniedDialog(context);
                    _reset();
                  });
                  return Container();
                }
                return ExpenseReportPage(onBack: _reset);
              },
            );

          case 'TaxReport':
            return FutureBuilder<bool>(
              future: planProvider.canAccessReportsAsync(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (!snapshot.data!) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PlanPermissionHelper.showUpgradeDialog(context, 'Reports', uid: widget.uid);
                    _reset();
                  });
                  return Container();
                }
                if (!_hasPermission('taxReport') && !isAdmin) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PermissionHelper.showPermissionDeniedDialog(context);
                    _reset();
                  });
                  return Container();
                }
                return TaxReportPage(onBack: _reset);
              },
            );

          case 'HSNReport':
            return FutureBuilder<bool>(
              future: planProvider.canAccessReportsAsync(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (!snapshot.data!) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PlanPermissionHelper.showUpgradeDialog(context, 'Reports', uid: widget.uid);
                    _reset();
                  });
                  return Container();
                }
                if (!_hasPermission('hsnReport') && !isAdmin) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PermissionHelper.showPermissionDeniedDialog(context);
                    _reset();
                  });
                  return Container();
                }
                return HSNReportPage(onBack: _reset);
              },
            );

          case 'StaffReport':
            return FutureBuilder<bool>(
              future: planProvider.canAccessReportsAsync(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (!snapshot.data!) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PlanPermissionHelper.showUpgradeDialog(context, 'Reports', uid: widget.uid);
                    _reset();
                  });
                  return Container();
                }
                if (!_hasPermission('staffSalesReport') && !isAdmin) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    PermissionHelper.showPermissionDeniedDialog(context);
                    _reset();
                  });
                  return Container();
                }
                return StaffSaleReportPage(onBack: _reset);
              },
            );

          // ==========================================
          // STOCK PAGE (moved from bottom nav)
          // ==========================================

          case 'Stock':
            return StockPage(uid: widget.uid, userEmail: widget.userEmail);

          // ==========================================
          // SETTINGS PAGE (moved from bottom nav)
          // ==========================================

          case 'Settings':
            return SettingsPage(uid: widget.uid, userEmail: widget.userEmail);
        }

        // ------------------------------------------
        // DEFAULT VIEW (MENU)
        // ------------------------------------------
        return Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              // HEADER
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top+10, bottom: 20, left: 20, right: 20),
                color: Color(0xFF2F7CF6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Logo on left side
                    Image.asset(
                      'assets/max_my_bill_sq.png',
                      width: 175,
                      height:175,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 25),
                    // Store info on right side
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Store name
                          Text(
                            _businessName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          // Role badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _role.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Email
                          Row(
                            children: [
                              const Icon(Icons.email_outlined, color: Colors.white70, size: 12),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _email,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height:10),
                          // Plan info button
                          FutureBuilder<String>(
                            future: Provider.of<PlanProvider>(context, listen: false).getCurrentPlan(),
                            builder: (context, snapshot) {
                              final currentPlan = snapshot.data ?? 'Free';
                              return InkWell(
                                onTap: () async {
                                  final planProvider = Provider.of<PlanProvider>(context, listen: false);
                                  final plan = await planProvider.getCurrentPlan();
                                  if (!mounted) return;
                                  Navigator.push(
                                    context,
                                    CupertinoPageRoute(
                                      builder: (context) => SubscriptionPlanPage(
                                        uid: widget.uid,
                                        currentPlan: plan,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: currentPlan == 'Free' ? Colors.orange.shade700 : Colors.green.shade600,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.workspace_premium, size: 12, color: Colors.white),
                                      const SizedBox(width: 4),
                                      Text(
                                        currentPlan,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

          // MENU LIST
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                // Quotation
                if (_hasPermission('billHistory') || isAdmin) ...[
                  _buildMenuItem(
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kGreyBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.receipt_long_outlined, color: Color(0xFF388E3C), size: 24),
                    ),
                    context.tr('billhistory'),
                    'BillHistory',
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Divider(height: 1, thickness: 1, color: kBorderColor),
                  ),
                ],



                // Bill History
                // Customer Management
                if (_hasPermission('customerManagement') || isAdmin) ...[
                  _buildMenuItem(
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.people_outline, color: Color(0xFF7B1FA2), size: 24),
                    ),
                    context.tr('customers'),
                    'Customers',
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Divider(height: 1, thickness: 1, color: kBorderColor),
                  ),
                ],


                // Credit Notes
                if (_hasPermission('creditNotes') || isAdmin) ...[
                  _buildMenuItem(
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.note_alt_outlined, color: Color(0xFFF57C00), size: 24),
                    ),
                    context.tr('credit_notes'),
                    'CreditNotes',
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Divider(height: 1, thickness: 1, color: kBorderColor),
                  ),
                ],



                // Expenses (Expansion Tile)
                if (_hasPermission('expenses') || isAdmin) ...[
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFD32F2F), size: 24),
                      ),
                      title: Text(
                        context.tr('expenses'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: _textColor,
                        ),
                      ),
                      tilePadding: const EdgeInsets.symmetric(horizontal: 24),
                      childrenPadding: const EdgeInsets.only(left: 72),
                      children: [
                        _buildSubMenuItem(context.tr('stock_purchase'), 'StockPurchase'),
                        _buildSubMenuItem(context.tr('expenses'), 'Expenses'),
                        _buildSubMenuItem(context.tr('expense_category'), 'ExpenseCategories'),
                        _buildSubMenuItem('Vendors', 'Vendors'),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Divider(height: 1, thickness: 1, color: kBorderColor),
                  ),
                ],

                // Credit Details
                if (_hasPermission('creditDetails') || isAdmin) ...[
                  _buildMenuItem(
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2F1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.credit_card_outlined, color: Color(0xFF00796B), size: 24),
                    ),
                    context.tr('creditdetails'),
                    'CreditDetails',
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Divider(height: 1, thickness: 1, color: kBorderColor),
                  ),
                ],

                if (_hasPermission('quotation') || isAdmin) ...[
                  _buildMenuItem(
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.description_outlined, color: Color(0xFF1976D2), size: 24),
                    ),
                    context.tr('quotation'),
                    'Quotation',
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Divider(height: 1, thickness: 1, color: kBorderColor),
                  ),
                ],
                // Staff Management
                if (isAdmin || _hasPermission('staffManagement')) ...[
                  _buildMenuItem(
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCE4EC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.badge_outlined, color: Color(0xFFC2185B), size: 24),
                    ),
                    context.tr('staff_management'),
                    'StaffManagement',
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Divider(height: 1, thickness: 1, color: kBorderColor),
                  ),
                ],

                // Video Tutorial
                _buildMenuItem(
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1F5FE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.ondemand_video_rounded, color: Color(0xFF0288D1), size: 24),
                  ),
                  context.tr('video_tutorials'),
                  'VideoTutorial',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Divider(height: 1, thickness: 1, color: kBorderColor),
                ),

                // Knowledge
                _buildMenuItem(
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.school_rounded, color: Color(0xFFFFA000), size: 24),
                  ),
                  context.tr('knowledge_base'),
                  'Knowledge',
                ),

              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CommonBottomNav(
        uid: widget.uid,
        userEmail: widget.userEmail,
        currentIndex: 0,
        screenWidth: MediaQuery.of(context).size.width,
      ),
        );
      },
    );
  }

  Widget _buildMenuItem(Widget icon, String text, String viewKey) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: icon,
        title: Text(
          text,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: _textColor),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        onTap: () {
          _navigateToPage(viewKey);
        },
      ),
    );
  }



  Widget _buildSubMenuItem(String text, String viewKey) {
    return ListTile(
      title: Text(text, style: TextStyle(fontSize: 15, color: Color.fromRGBO((_textColor.r * 255.0).round() & 0xff, (_textColor.g * 255.0).round() & 0xff, (_textColor.b * 255.0).round() & 0xff, 0.8))),
      onTap: () async {
        // Navigate to the page in full screen
        await _navigateToPage(viewKey);
      },
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      contentPadding: EdgeInsets.zero,
    );
  }

  Future<void> _navigateToPage(String viewKey) async {
    Widget? page = await _getPageForView(viewKey);
    if (page != null) {
      Navigator.push(
        context,
        CupertinoPageRoute(builder: (context) => page),
      );
    }
  }

  Future<Widget?> _getPageForView(String viewKey) async {
    bool isAdmin = _role.toLowerCase() == 'admin' || _role.toLowerCase() == 'administrator';

    switch (viewKey) {
      case 'NewSale':
        return NewSalePage(uid: widget.uid, userEmail: widget.userEmail);

      case 'Quotation':
        // Check plan permission first (async)
        final canAccessQuotation = await PlanPermissionHelper.canAccessQuotation();
        if (!canAccessQuotation) {
          PlanPermissionHelper.showUpgradeDialog(context, 'Quotation', uid: widget.uid);
          return null;
        }
        if (!_hasPermission('quotation') && !isAdmin) {
          PermissionHelper.showPermissionDeniedDialog(context);
          return null;
        }
        return QuotationsListPage(uid: widget.uid, userEmail: widget.userEmail, onBack: () => Navigator.pop(context));

      case 'BillHistory':
        if (!_hasPermission('billHistory') && !isAdmin) {
          PermissionHelper.showPermissionDeniedDialog(context);
          return null;
        }
        return SalesHistoryPage(uid: widget.uid, userEmail: widget.userEmail, onBack: () => Navigator.pop(context));

      case 'CreditNotes':
        // Check plan permission first (async)
        final canAccessCreditNotes = await PlanPermissionHelper.canAccessCustomerCredit();
        if (!canAccessCreditNotes) {
          PlanPermissionHelper.showUpgradeDialog(context, 'Customer Credit', uid: widget.uid);
          return null;
        }
        if (!_hasPermission('creditNotes') && !isAdmin) {
          PermissionHelper.showPermissionDeniedDialog(context);
          return null;
        }
        return CreditNotesPage(uid: widget.uid, onBack: () => Navigator.pop(context));

      case 'Customers':
        if (!_hasPermission('customerManagement') && !isAdmin) {
          PermissionHelper.showPermissionDeniedDialog(context);
          return null;
        }
        return CustomersPage(uid: widget.uid, onBack: () => Navigator.pop(context));

      case 'CreditDetails':
        // Check plan permission first (async)
        final canAccessCreditDetails = await PlanPermissionHelper.canAccessCustomerCredit();
        if (!canAccessCreditDetails) {
          PlanPermissionHelper.showUpgradeDialog(context, 'Customer Credit', uid: widget.uid);
          return null;
        }
        if (!_hasPermission('creditDetails') && !isAdmin) {
          PermissionHelper.showPermissionDeniedDialog(context);
          return null;
        }
        return CreditDetailsPage(uid: widget.uid, onBack: () => Navigator.pop(context));

      case 'StockPurchase':
        if (!_hasPermission('expenses') && !isAdmin) {
          PermissionHelper.showPermissionDeniedDialog(context);
          return null;
        }
        return StockPurchasePage(uid: widget.uid, onBack: () => Navigator.pop(context));

      case 'Expenses':
        if (!_hasPermission('expenses') && !isAdmin) {
          PermissionHelper.showPermissionDeniedDialog(context);
          return null;
        }
        return ExpensesPage(uid: widget.uid, onBack: () => Navigator.pop(context));

      case 'ExpenseCategories':
        if (!_hasPermission('expenses') && !isAdmin) {
          PermissionHelper.showPermissionDeniedDialog(context);
          return null;
        }
        return ExpenseCategoriesPage(uid: widget.uid, onBack: () => Navigator.pop(context));

      case 'Vendors':
        if (!_hasPermission('expenses') && !isAdmin) {
          PermissionHelper.showPermissionDeniedDialog(context);
          return null;
        }
        return VendorsPage(uid: widget.uid, onBack: () => Navigator.pop(context));

      case 'StaffManagement':
        // Staff management requires async checks, handle separately
        _navigateToStaffManagement();
        return null;

      case 'Analytics':
        // Analytics requires async checks, handle separately
        _navigateToAnalytics();
        return null;

      case 'DayBook':
        // DayBook requires async checks, handle separately
        _navigateToDayBook();
        return null;

      case 'Summary':
        // Summary requires async checks, handle separately
        _navigateToSummary();
        return null;

      case 'SalesReport':
        // SalesReport requires async checks, handle separately
        _navigateToSalesReport();
        return null;

      case 'ItemSales':
        // ItemSales requires async checks, handle separately
        _navigateToItemSales();
        return null;

      case 'TopCustomers':
        // TopCustomerequires async checks, handle separately
        _navigateToTopCustomers();
        return null;

      case 'StockReport':
        // StockReport requires async checks, handle separately
        _navigateToStockReport();
        return null;

      case 'LowStock':
        // LowStock requires async checks, handle separately
        _navigateToLowStock();
        return null;

      case 'TopProducts':
        // TopProducts requires async checks, handle separately
        _navigateToTopProducts();
        return null;

      case 'TopCategories':
        // TopCategories requires async checks, handle separately
        _navigateToTopCategories();
        return null;

      case 'ExpenseReport':
        // ExpenseReport requires async checks, handle separately
        _navigateToExpenseReport();
        return null;

      case 'TaxReport':
        // TaxReport requires async checks, handle separately
        _navigateToTaxReport();
        return null;

      case 'HSNReport':
        // HSNReport requires async checks, handle separately
        _navigateToHSNReport();
        return null;

      case 'StaffReport':
        // StaffReport requires async checks, handle separately
        _navigateToStaffReport();
        return null;

      case 'Knowledge':
        return KnowledgePage(onBack: () => Navigator.pop(context));

      case 'VideoTutorial':
        return VideoTutorialPage(onBack: () => Navigator.pop(context));

      case 'Stock':
        return StockPage(uid: widget.uid, userEmail: widget.userEmail);

      case 'Settings':
        return SettingsPage(uid: widget.uid, userEmail: widget.userEmail);

      default:
        return null;
    }
  }

  void _navigateToStaffManagement() async {
    bool isAdmin = _role.toLowerCase() == 'admin' || _role.toLowerCase() == 'administrator';

    bool canAccess = await PlanPermissionHelper.canAccessStaffManagement();
    if (!canAccess) {
      PlanPermissionHelper.showUpgradeDialog(context, 'Staff Management', uid: widget.uid);
      return;
    }

    if (!_hasPermission('staffManagement') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => StaffManagementPage(
          uid: widget.uid,
          userEmail: widget.userEmail,
          onBack: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _navigateToAnalytics() async {
    bool isAdmin = _role.toLowerCase() == 'admin' || _role.toLowerCase() == 'administrator';

    bool canAccess = await PlanPermissionHelper.canAccessReports();
    if (!canAccess) {
      PlanPermissionHelper.showUpgradeDialog(context, 'Reports', uid: widget.uid);
      return;
    }

    if (!_hasPermission('analytics') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => AnalyticsPage(
          uid: widget.uid,
          onBack: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _navigateToDayBook() async {
    // Daybook is FREE for everyone - no restrictions
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => DayBookPage(
          uid: widget.uid,
          onBack: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _navigateToSummary() async {
    bool isAdmin = _role.toLowerCase() == 'admin' || _role.toLowerCase() == 'administrator';

    bool canAccess = await PlanPermissionHelper.canAccessReports();
    if (!canAccess) {
      PlanPermissionHelper.showUpgradeDialog(context, 'Reports', uid: widget.uid);
      return;
    }

    if (!_hasPermission('salesSummary') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => SalesSummaryPage(
          onBack: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _navigateToSalesReport() async {
    bool isAdmin = _role.toLowerCase() == 'admin' || _role.toLowerCase() == 'administrator';

    bool canAccess = await PlanPermissionHelper.canAccessReports();
    if (!canAccess) {
      PlanPermissionHelper.showUpgradeDialog(context, 'Reports', uid: widget.uid);
      return;
    }

    if (!_hasPermission('salesReport') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => FullSalesHistoryPage(
          onBack: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _navigateToItemSales() async {
    bool isAdmin = _role.toLowerCase() == 'admin' || _role.toLowerCase() == 'administrator';

    bool canAccess = await PlanPermissionHelper.canAccessReports();
    if (!canAccess) {
      PlanPermissionHelper.showUpgradeDialog(context, 'Reports', uid: widget.uid);
      return;
    }

    if (!_hasPermission('itemSalesReport') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => ItemSalesPage(
          onBack: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _navigateToTopCustomers() async {
    bool isAdmin = _role.toLowerCase() == 'admin' || _role.toLowerCase() == 'administrator';

    bool canAccess = await PlanPermissionHelper.canAccessReports();
    if (!canAccess) {
      PlanPermissionHelper.showUpgradeDialog(context, 'Reports', uid: widget.uid);
      return;
    }

    if (!_hasPermission('topCustomers') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => TopCustomersPage(
          uid: widget.uid,
          onBack: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _navigateToStockReport() async {
    bool isAdmin = _role.toLowerCase() == 'admin' || _role.toLowerCase() == 'administrator';

    bool canAccess = await PlanPermissionHelper.canAccessReports();
    if (!canAccess) {
      PlanPermissionHelper.showUpgradeDialog(context, 'Reports', uid: widget.uid);
      return;
    }

    if (!_hasPermission('stockReport') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => StockReportPage(
          onBack: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _navigateToLowStock() async {
    bool isAdmin = _role.toLowerCase() == 'admin' || _role.toLowerCase() == 'administrator';

    bool canAccess = await PlanPermissionHelper.canAccessReports();
    if (!canAccess) {
      PlanPermissionHelper.showUpgradeDialog(context, 'Reports', uid: widget.uid);
      return;
    }

    if (!_hasPermission('lowStockProduct') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => LowStockPage(
          onBack: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _navigateToTopProducts() async {
    bool isAdmin = _role.toLowerCase() == 'admin' || _role.toLowerCase() == 'administrator';

    bool canAccess = await PlanPermissionHelper.canAccessReports();
    if (!canAccess) {
      PlanPermissionHelper.showUpgradeDialog(context, 'Reports', uid: widget.uid);
      return;
    }

    if (!_hasPermission('topProducts') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => TopProductsPage(
          uid: widget.uid,
          onBack: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _navigateToTopCategories() async {
    bool isAdmin = _role.toLowerCase() == 'admin' || _role.toLowerCase() == 'administrator';

    bool canAccess = await PlanPermissionHelper.canAccessReports();
    if (!canAccess) {
      PlanPermissionHelper.showUpgradeDialog(context, 'Reports', uid: widget.uid);
      return;
    }

    if (!_hasPermission('topCategory') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => TopCategoriesPage(
          onBack: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _navigateToExpenseReport() async {
    bool isAdmin = _role.toLowerCase() == 'admin' || _role.toLowerCase() == 'administrator';

    bool canAccess = await PlanPermissionHelper.canAccessReports();
    if (!canAccess) {
      PlanPermissionHelper.showUpgradeDialog(context, 'Reports', uid: widget.uid);
      return;
    }

    if (!_hasPermission('expensesReport') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => ExpenseReportPage(
          onBack: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _navigateToTaxReport() async {
    bool isAdmin = _role.toLowerCase() == 'admin' || _role.toLowerCase() == 'administrator';

    bool canAccess = await PlanPermissionHelper.canAccessReports();
    if (!canAccess) {
      PlanPermissionHelper.showUpgradeDialog(context, 'Reports', uid: widget.uid);
      return;
    }

    if (!_hasPermission('taxReport') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => TaxReportPage(
          onBack: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _navigateToHSNReport() async {
    bool isAdmin = _role.toLowerCase() == 'admin' || _role.toLowerCase() == 'administrator';

    bool canAccess = await PlanPermissionHelper.canAccessReports();
    if (!canAccess) {
      PlanPermissionHelper.showUpgradeDialog(context, 'Reports', uid: widget.uid);
      return;
    }

    if (!_hasPermission('hsnReport') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => HSNReportPage(
          onBack: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _navigateToStaffReport() async {
    bool isAdmin = _role.toLowerCase() == 'admin' || _role.toLowerCase() == 'administrator';

    bool canAccess = await PlanPermissionHelper.canAccessReports();
    if (!canAccess) {
      PlanPermissionHelper.showUpgradeDialog(context, 'Reports', uid: widget.uid);
      return;
    }

    if (!_hasPermission('staffSalesReport') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => StaffSaleReportPage(
          onBack: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> fetchUnsettledOrders(String uid) async {
    final collection = await FirestoreService().getStoreCollection('savedOrders');
    final querySnapshot = await collection.get();

    return querySnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }



  void settleBillAndReturn(String billId) async {
    // Navigate to BillPage
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => BillPage(
          uid: widget.uid,
          cartItems: const [], // Replace with actual cart items
          totalAmount: 0.0, // Replace with actual total amount
          userEmail: widget.userEmail,
        ),
      ),
    ).then((_) {
      // Return to the current page after settling the bill
      setState(() {
        _currentView = null; // Go back to the main menu
      });
    });
  }
}

// ==========================================
// 2. HELPER WIDGETS (With onBack callback)
// ==========================================
class GenericListPage extends StatelessWidget {
  final String title;
  final String collectionPath;
  final String uid;
  final String? filterField;
  final bool filterNotEmpty;
  final num? numericFilterGreaterThan;
  final VoidCallback onBack; // Changed from Navigator
  final FirestoreService _firestoreService = FirestoreService();

  GenericListPage({
    super.key,
    required this.title,
    required this.collectionPath,
    required this.uid,
    required this.onBack,
    this.filterField,
    this.filterNotEmpty = false,
    this.numericFilterGreaterThan,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2F7CF6),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: onBack),
        centerTitle: true,
      ),
      body: FutureBuilder<CollectionReference>(
        future: _firestoreService.getStoreCollection(collectionPath),
        builder: (context, collectionSnapshot) {
          if (!collectionSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          Query collectionRef = collectionSnapshot.data!;
          if (filterNotEmpty && filterField != null) {
            collectionRef = collectionRef.where(filterField!, isNotEqualTo: null);
          }
          if (numericFilterGreaterThan != null && filterField != null) {
            collectionRef = collectionRef.where(filterField!, isGreaterThan: numericFilterGreaterThan);
          }
          collectionRef = collectionRef.orderBy('timestamp', descending: true);

          return StreamBuilder<QuerySnapshot>(
            stream: collectionRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text(context.tr('nodata')));

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final subtitle = data.containsKey('total') ? 'Total:  ${data['total']}' : (data.containsKey('phone') ? data['phone'] : '');
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  title: Text(data['customerName'] ?? data['name'] ?? data['title'] ?? doc.id, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(subtitle.toString()),
                  trailing: Text(data['timestamp'] != null ? _formatTime(data['timestamp']) : '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              );
            },
          );
        },
      );
        },
      ),
    );
  }

  String _formatTime(dynamic ts) {
    try {
      final dt = (ts as Timestamp).toDate();
      return DateFormat('dd MMM').format(dt);
    } catch (e) {
      return '';
    }
  }
}

// ==========================================
// UPDATED SALES HISTORY PAGE (UI MATCH)
// ==========================================

class SalesHistoryPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;
  final String? userEmail;

  const SalesHistoryPage({
    super.key,
    required this.uid,
    required this.onBack,
    this.userEmail,
  });

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

enum SortOption { dateNewest, dateOldest, amountHigh, amountLow }

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  // Streams
  Stream<List<QueryDocumentSnapshot>>? _combinedStream;
  StreamController<List<QueryDocumentSnapshot>>? _controller;
  StreamSubscription? _salesSub;
  StreamSubscription? _savedOrdersSub;

  // Search & Filter State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  SortOption _currentSort = SortOption.dateNewest;

  // Filter options
  String _statusFilter = 'all'; // all, settled, unsettled, cancelled
  String _paymentFilter = 'all';
  String _selectedDateFilter = 'All Time';
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    _initializeCombinedStream();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase().trim();
      });
    });
  }

  @override
  void dispose() {
    _salesSub?.cancel();
    _savedOrdersSub?.cancel();
    _controller?.close();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeCombinedStream() async {
    try {
      final salesCollection = await FirestoreService().getStoreCollection('sales');
      final savedOrdersCollection = await FirestoreService().getStoreCollection('savedOrders');

      final salesStream = salesCollection.snapshots();
      final savedOrdersStream = savedOrdersCollection.snapshots();

      List<QueryDocumentSnapshot> salesDocs = [];
      List<QueryDocumentSnapshot> savedOrdersDocs = [];

      void updateController() {
        if (_controller == null || _controller!.isClosed) return;
        final allDocs = [...salesDocs, ...savedOrdersDocs];
        _controller!.add(allDocs);
      }

      _controller = StreamController<List<QueryDocumentSnapshot>>.broadcast();
      _salesSub = salesStream.listen((snapshot) { salesDocs = snapshot.docs; updateController(); });
      _savedOrdersSub = savedOrdersStream.listen((snapshot) { savedOrdersDocs = snapshot.docs; updateController(); });

      if (mounted) setState(() => _combinedStream = _controller!.stream);
    } catch (e) {
      if (mounted) setState(() => _combinedStream = Stream.value([]));
    }
  }

  List<QueryDocumentSnapshot> _processList(List<QueryDocumentSnapshot> docs, int historyLimit) {
    final now = DateTime.now();
    final historyLimitDate = now.subtract(Duration(days: historyLimit));

    // 1. Filter
    var filtered = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['timestamp'] as Timestamp?;
      if (timestamp != null && timestamp.toDate().isBefore(historyLimitDate)) return false;

      // Status logic
      final paymentStatus = data['paymentStatus'];
      final isSettled = paymentStatus != null ? paymentStatus != 'unsettled' : (data.containsKey('paymentMode'));
      final isCancelled = data['status'] == 'cancelled';

      if (_statusFilter == 'settled' && (!isSettled || isCancelled)) return false;
      if (_statusFilter == 'unsettled' && (isSettled || isCancelled)) return false;
      if (_statusFilter == 'cancelled' && !isCancelled) return false;

      // Search
      if (_searchQuery.isNotEmpty) {
        final inv = (data['invoiceNumber'] ?? '').toString().toLowerCase();
        final customer = (data['customerName'] ?? '').toString().toLowerCase();
        if (!inv.contains(_searchQuery) && !customer.contains(_searchQuery)) return false;
      }

      return true;
    }).toList();

    // 2. Sort
    filtered.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;

      switch (_currentSort) {
        case SortOption.amountHigh:
          return (dataB['total'] ?? 0.0).compareTo(dataA['total'] ?? 0.0);
        case SortOption.amountLow:
          return (dataA['total'] ?? 0.0).compareTo(dataB['total'] ?? 0.0);
        case SortOption.dateOldest:
          return (dataA['timestamp'] as Timestamp? ?? Timestamp.now()).compareTo(dataB['timestamp'] as Timestamp? ?? Timestamp.now());
        case SortOption.dateNewest:
        default:
          return (dataB['timestamp'] as Timestamp? ?? Timestamp.now()).compareTo(dataA['timestamp'] as Timestamp? ?? Timestamp.now());
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kWhite, size: 22),
          onPressed: widget.onBack,
        ),
        title: Text(context.tr('billhistory'),
            style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: Column(
        children: [
          _buildHeaderSection(),
          Expanded(
            child: FutureBuilder<int>(
              future: PlanPermissionHelper.getBillHistoryDaysLimit(),
              builder: (context, planSnap) {
                final limit = planSnap.data ?? 7;
                return StreamBuilder<List<QueryDocumentSnapshot>>(
                  stream: _combinedStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                    final list = _processList(snapshot.data!, limit);
                    if (list.isEmpty) return _buildEmpty();

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 10),
                      itemBuilder: (c, i) => _buildBillCard(list[i]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: kWhite,
        border: Border(bottom: BorderSide(color: kGrey200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kGrey200),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: context.tr('search'),
                  hintStyle: TextStyle(color: kBlack54, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: kPrimaryColor, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 7),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildHeaderActionBtn(Icons.sort_rounded, _showSortMenu),
          const SizedBox(width: 8),
          _buildHeaderActionBtn(Icons.tune_rounded, _showFilterMenu),
        ],
      ),
    );
  }

  Widget _buildHeaderActionBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 46, width: 46,
        decoration: BoxDecoration(
          color: kPrimaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kGrey200),
        ),
        child: Icon(icon, color: kPrimaryColor, size: 22),
      ),
    );
  }

  Widget _buildBillCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final inv = data['invoiceNumber'] ?? 'N/A';
    final total = (data['total'] ?? 0.0).toDouble();
    final customerName = data['customerName'] ?? 'Walk-in Customer';
    final staffName = data['staffName'] ?? 'Staff';

    final timestamp = data['timestamp'] as Timestamp?;
    final formattedDateTime = timestamp != null
        ? DateFormat('dd MMM yy • hh:mm a').format(timestamp.toDate())
        : '--';

    final paymentStatus = data['paymentStatus'];
    final bool isSettled = paymentStatus != null ? paymentStatus != 'unsettled' : (data.containsKey('paymentMode'));
    final bool isCancelled = data['status'] == 'cancelled';

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleOnTap(doc, data, isSettled, isCancelled, total),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text("$inv", style: const TextStyle(fontWeight: FontWeight.w900, color: kPrimaryColor, fontSize: 13)),
                  Text(formattedDateTime, style: const TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w500))
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: kGreyBg, shape: BoxShape.circle),
                    child: const Icon(Icons.person_rounded, size: 16, color: kBlack54),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kOrange)),
                  ),
                  Text("${total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: kPrimaryColor)),
                ]),
                const Divider(height: 20, color: kGreyBg),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("BILLED BY", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kBlack54, letterSpacing: 0.5)),
                    Text(staffName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kBlack87))
                  ]),
                  _badge(isSettled, isCancelled)
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(bool settled, bool cancelled) {
    if (cancelled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: kBlack54.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: const Text("CANCELLED", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kBlack54)),
      );
    }
    // Logic: Unsettled (Open) is Green, Settled (Closed) is Red
    final Color statusColor = settled ? kErrorColor : kGoogleGreen;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withOpacity(0.2))),
        child: Text(settled ? "SETTLED" : "UNSETTLED",
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: statusColor)));
  }

  void _handleOnTap(QueryDocumentSnapshot doc, Map<String, dynamic> data, bool isSettled, bool isCancelled, double total) {
    if (!isSettled && !isCancelled) {
      final List<CartItem> cartItems = (data['items'] as List<dynamic>? ?? [])
          .map((item) => CartItem(
        productId: item['productId'] ?? '',
        name: item['name'] ?? '',
        price: (item['price'] ?? 0).toDouble(),
        quantity: item['quantity'] is int ? item['quantity'] : int.tryParse(item['quantity'].toString()) ?? 1,
      ))
          .toList();

      final isUnsettledSale = data.containsKey('paymentStatus') && data['paymentStatus'] == 'unsettled';

      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => BillPage(
            uid: widget.uid,
            cartItems: cartItems,
            totalAmount: total,
            userEmail: widget.userEmail,
            savedOrderId: isUnsettledSale ? null : doc.id,
            existingInvoiceNumber: data['invoiceNumber'],
            unsettledSaleId: isUnsettledSale ? doc.id : null,
            discountAmount: (data['discount'] ?? 0.0).toDouble(),
            customerPhone: data['customerPhone'],
            customerName: data['customerName'],
            customerGST: data['customerGST'],
            quotationId: data['quotationId'],
          ),
        ),
      );
    } else {
      Navigator.push(context, CupertinoPageRoute(builder: (context) => SalesDetailPage(documentId: doc.id, initialData: data, uid: widget.uid)));
    }
  }

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sort History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kBlack87)),
            const SizedBox(height: 16),
            _sortItem("Newest First", SortOption.dateNewest),
            _sortItem("Oldest First", SortOption.dateOldest),
            _sortItem("Amount: High to Low", SortOption.amountHigh),
            _sortItem("Amount: Low to High", SortOption.amountLow),
          ],
        ),
      ),
    );
  }

  Widget _sortItem(String label, SortOption option) {
    bool isSelected = _currentSort == option;
    return ListTile(
      onTap: () { setState(() => _currentSort = option); Navigator.pop(context); },
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? kPrimaryColor : kBlack87)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: kPrimaryColor) : null,
    );
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter Bills', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kBlack87)),
            const SizedBox(height: 16),
            _filterItem("All Records", 'all'),
            _filterItem("Settled Only", 'settled'),
            _filterItem("Unsettled Only", 'unsettled'),
            _filterItem("Cancelled Only", 'cancelled'),
          ],
        ),
      ),
    );
  }

  Widget _filterItem(String label, String value) {
    bool isSelected = _statusFilter == value;
    return ListTile(
      onTap: () { setState(() => _statusFilter = value); Navigator.pop(context); },
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? kPrimaryColor : kBlack87)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: kPrimaryColor) : null,
    );
  }

  Widget _buildEmpty() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.receipt_long, size: 64, color: kGrey300), const SizedBox(height: 16), Text(context.tr('nobillsfound'), style: const TextStyle(color: kBlack54, fontWeight: FontWeight.w600))]));
}

// ==========================================
// 3. SALES DETAIL PAGE
// ==========================================
class SalesDetailPage extends StatelessWidget {
  final String documentId;
  final Map<String, dynamic> initialData;
  final String uid;

  const SalesDetailPage({
    super.key,
    required this.documentId,
    required this.initialData,
    required this.uid,
  });

  // ==========================================
  // LOGIC METHODS (PRESERVED BIT-BY-BIT)
  // ==========================================

  Map<String, dynamic> _calculateTaxTotals(List<Map<String, dynamic>> items) {
    double subtotalWithoutTax = 0.0;
    double totalTax = 0.0;
    Map<String, double> taxBreakdown = {};

    for (var item in items) {
      final price = (item['price'] ?? 0).toDouble();
      final quantity = (item['quantity'] ?? 1);
      final taxName = item['taxName'] as String?;
      final taxPercentage = (item['taxPercentage'] ?? 0).toDouble();
      final taxType = item['taxType'] as String?;

      double itemTotal = price * quantity;
      double itemTax = 0.0;
      double itemBaseAmount = itemTotal;

      if (taxPercentage > 0 && taxType != null) {
        if (taxType == 'Price includes Tax') {
          // Tax is included in price, extract it
          itemBaseAmount = itemTotal / (1 + taxPercentage / 100);
          itemTax = itemTotal - itemBaseAmount;
        } else if (taxType == 'Price is without Tax') {
          // Tax needs to be added
          itemTax = itemTotal * (taxPercentage / 100);
        }
      }

      subtotalWithoutTax += itemBaseAmount;
      totalTax += itemTax;

      // Track tax breakdown by tax name
      if (itemTax > 0 && taxName != null && taxName.isNotEmpty) {
        taxBreakdown[taxName] = (taxBreakdown[taxName] ?? 0.0) + itemTax;
      }
    }

    return {
      'subtotalWithoutTax': subtotalWithoutTax,
      'totalTax': totalTax,
      'taxBreakdown': taxBreakdown,
    };
  }

  // Check user permissions for actions
  Future<Map<String, dynamic>> _getUserPermissions() async {
    try {
      // Use the same method that MenuPage uses to load permissions
      final userData = await PermissionHelper.getUserPermissions(uid);
      final role = userData['role'] as String;
      final permissions = userData['permissions'] as Map<String, dynamic>;

      debugPrint('Permission Check: role = $role');
      debugPrint('Staff permissions retrieved: $permissions');

      // Check if user is admin
      final isAdmin = role.toLowerCase() == 'admin' || role.toLowerCase() == 'administrator';
      debugPrint('User is admin: $isAdmin');

      if (isAdmin) {
        debugPrint('User is admin - granting all permissions');
        return {
          'canSaleReturn': true,
          'canCancelBill': true,
          'canEditBill': true,
          'isAdmin': true,
        };
      }

      final result = {
        'canSaleReturn': permissions['saleReturn'] == true,
        'canCancelBill': permissions['cancelBill'] == true,
        'canEditBill': permissions['editBill'] == true,
        'isAdmin': false,
      };

      debugPrint('Final permission result: $result');
      return result;
    } catch (e) {
      debugPrint('Error getting user permissions: $e');
      return {
        'canSaleReturn': false,
        'canCancelBill': false,
        'canEditBill': false,
        'isAdmin': false,
      };
    }
  }

  Future<void> _printInvoiceReceipt(BuildContext context, String documentId, Map<String, dynamic> data) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Get store details
      final storeId = await FirestoreService().getCurrentStoreId();
      String businessName = 'Business';
      String businessPhone = '';
      String businessLocation = '';
      String? businessGSTIN;

      if (storeId != null) {
        final storeDoc = await FirebaseFirestore.instance
            .collection('store')  // FIXED: Changed from 'stores' to 'store'
            .doc(storeId)
            .get();
        if (storeDoc.exists) {
          final storeData = storeDoc.data() as Map<String, dynamic>;
          businessName = storeData['businessName'] ?? 'Business';
          businessPhone = storeData['businessPhone'] ?? storeData['ownerPhone'] ?? '';
          businessLocation = storeData['address'] ?? storeData['location'] ?? '';
          businessGSTIN = storeData['gstin'];
        }
      }

      // Prepare items for invoice page with complete tax information
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((item) => {
        'name': item['name'] ?? '',
        'quantity': item['quantity'] ?? 0,
        'price': (item['price'] ?? 0).toDouble(),
        'total': ((item['price'] ?? 0) * (item['quantity'] ?? 1)).toDouble(),
        'productId': item['productId'] ?? '',
        'taxName': item['taxName'],
        'taxPercentage': (item['taxPercentage'] ?? 0).toDouble(),
        'taxAmount': (item['taxAmount'] ?? 0).toDouble(),
        'taxType': item['taxType'],
      })
          .toList();

      // Get timestamp
      DateTime dateTime = DateTime.now();
      if (data['timestamp'] != null) {
        dateTime = (data['timestamp'] as Timestamp).toDate();
      } else if (data['date'] != null) {
        dateTime = DateTime.tryParse(data['date'].toString()) ?? DateTime.now();
      }

      // Calculate tax information from items
      final taxCalculations = _calculateTaxTotals(items.cast<Map<String, dynamic>>());
      final taxBreakdown = taxCalculations['taxBreakdown'] as Map<String, double>;
      final taxList = taxBreakdown.entries
          .map((e) => {'name': e.key, 'amount': e.value})
          .toList();

      // Close loading
      if (context.mounted) {
        Navigator.pop(context);

        // Navigate to Invoice page
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => InvoicePage(
              uid: data['staffId'] ?? '',
              businessName: businessName,
              businessLocation: businessLocation,
              businessPhone: businessPhone,
              businessGSTIN: businessGSTIN,
              invoiceNumber: data['invoiceNumber']?.toString() ?? 'N/A',
              dateTime: dateTime,
              items: items.cast<Map<String, dynamic>>(),
              subtotal: taxCalculations['subtotalWithoutTax'] as double,
              discount: (data['discount'] ?? 0).toDouble(),
              taxes: taxList.isNotEmpty ? taxList : null,
              total: (data['total'] ?? 0).toDouble(),
              paymentMode: data['paymentMode'] ?? 'Cash',
              cashReceived: (data['cashReceived'] ?? data['total'] ?? 0).toDouble(),
              customerName: data['customerName'],
              customerPhone: data['customerPhone'],
              customerGSTIN: data['customerGST'],
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCancelBillDialog(BuildContext context, String documentId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Are you sure ?',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Do you want to cancel Invoice No : ${data['invoiceNumber']} .',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            if (data['customerPhone'] != null && (data['total'] as num) > 0) ...[
              Text(
                'A Credit Note will be created for customer ${data['customerName'] ?? data['customerPhone']}',
                style: const TextStyle(fontSize: 14, color: Color(0xFF2F7CF6)),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Show loading
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );

                // 1. Restore stock for all items
                final items = (data['items'] as List<dynamic>? ?? []);
                final productsCollection = await FirestoreService().getStoreCollection('Products');
                for (var item in items) {
                  if (item['productId'] != null && item['productId'].toString().isNotEmpty) {
                    final productRef = productsCollection.doc(item['productId']);

                    await FirebaseFirestore.instance.runTransaction((transaction) async {
                      final productDoc = await transaction.get(productRef);
                      if (productDoc.exists) {
                        final productData = productDoc.data() as Map<String, dynamic>?;
                        final currentStock = productData?['currentStock'] ?? 0.0;
                        final quantity = (item['quantity'] ?? 0) is int
                            ? item['quantity']
                            : int.tryParse(item['quantity'].toString()) ?? 0;
                        final newStock = currentStock + quantity;
                        transaction.update(productRef, {'currentStock': newStock});
                      }
                    });
                  }
                }

                // 2. Create credit note if customer was involved (for any payment mode)
                if (data['customerPhone'] != null && (data['total'] as num) > 0) {
                  // Generate sequential credit note number
                  final creditNoteNumber = await NumberGeneratorService.generateCreditNoteNumber();

                  // Create credit note document - store-scoped
                  final creditNotesCollection = await FirestoreService().getStoreCollection('creditNotes');
                  await creditNotesCollection.add({
                    'creditNoteNumber': creditNoteNumber,
                    'invoiceNumber': data['invoiceNumber'],
                    'customerPhone': data['customerPhone'],
                    'customerName': data['customerName'] ?? 'Unknown',
                    'amount': (data['total'] as num).toDouble(),
                    'items': items.map((item) => {
                      'name': item['name'],
                      'quantity': item['quantity'],
                      'price': item['price'],
                      'total': (item['price'] ?? 0) * (item['quantity'] ?? 0),
                    }).toList(),
                    'timestamp': FieldValue.serverTimestamp(),
                    'status': 'Available',
                    'reason': 'Bill Cancelled',
                    'createdBy': 'Admin',
                  });

                  // If it was a credit sale, also reverse the balance
                  if (data['paymentMode'] == 'Credit') {
                    final customersCollection = await FirestoreService().getStoreCollection('customers');
                    final customerRef = customersCollection.doc(data['customerPhone']);

                    await FirebaseFirestore.instance.runTransaction((transaction) async {
                      final customerDoc = await transaction.get(customerRef);
                      if (customerDoc.exists) {
                        final customerData = customerDoc.data() as Map<String, dynamic>?;
                        final currentBalance = customerData?['balance'] ?? 0.0;
                        final billTotal = (data['total'] as num).toDouble();
                        final newBalance = currentBalance - billTotal;
                        transaction.update(customerRef, {'balance': newBalance});
                      }
                    });
                  }
                }

                // 3. Mark the sales document as cancelled (don't delete)
                final salesCollection = await FirestoreService().getStoreCollection('sales');
                await salesCollection.doc(documentId).update({
                  'status': 'cancelled',
                  'cancelledAt': FieldValue.serverTimestamp(),
                  'cancelledBy': data['staffName'] ?? 'Admin',
                  'cancelReason': 'Bill Cancelled',
                });

                if (context.mounted) {
                  // Close loading dialog
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          data['customerPhone'] != null
                              ? 'Bill cancelled. Credit note created for customer. Stock restored.'
                              : 'Bill cancelled successfully. Stock has been restored.'
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );

                  // Go back to bill history
                  Navigator.pop(context);
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${context.tr('error')}: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(context.tr('cancel_bill'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // UI BUILD METHODS (QUOTATION PAGE STYLE)
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimaryColor, // Primary color background like QuotationPage entry
      appBar: AppBar(
        title: const Text('Invoice Details', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 22), onPressed: () => Navigator.pop(context)),
      ),
      body: FutureBuilder<DocumentReference>(
        future: FirestoreService().getDocumentReference('sales', documentId),
        builder: (context, docRefSnapshot) {
          if (!docRefSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kWhite));

          return StreamBuilder<DocumentSnapshot>(
            stream: docRefSnapshot.data!.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kWhite));
              if (!snapshot.hasData || !snapshot.data!.exists) return Center(child: Text(context.tr('bill_not_found'), style: const TextStyle(color: kWhite)));

              final data = snapshot.data!.data() as Map<String, dynamic>;
              final ts = data['timestamp'] as Timestamp?;
              final dateStr = ts != null ? DateFormat('dd MMM yy • hh:mm a').format(ts.toDate()) : '--';
              final items = (data['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

              // Calculate tax from items (for new sales with tax fields)
              final taxInfo = _calculateTaxTotals(items);
              double subtotalWithoutTax = taxInfo['subtotalWithoutTax'] as double;
              Map<String, double> taxBreakdown = taxInfo['taxBreakdown'] as Map<String, double>;

              // Fallback: If no tax in items, check if document has taxes field (backward compatibility)
              if (taxBreakdown.isEmpty && data['taxes'] != null) {
                final docTaxes = data['taxes'] as List<dynamic>?;
                if (docTaxes != null) {
                  for (var tax in docTaxes) {
                    final taxName = tax['name'] as String?;
                    final taxAmount = (tax['amount'] ?? 0).toDouble();
                    if (taxName != null && taxAmount > 0) {
                      taxBreakdown[taxName] = taxAmount;
                    }
                  }
                }
                // Use stored subtotal if available
                if (data['subtotal'] != null) {
                  subtotalWithoutTax = (data['subtotal'] ?? 0).toDouble();
                }
              }

              // Fallback: If still no tax but totalTax exists
              if (taxBreakdown.isEmpty && data['totalTax'] != null) {
                final totalTax = (data['totalTax'] ?? 0).toDouble();
                if (totalTax > 0) {
                  taxBreakdown['Tax'] = totalTax;
                }
              }

              final status = data['paymentStatus'];
              final bool settled = status != null ? status != 'unsettled' : (data.containsKey('paymentMode'));
              final bool isCancelled = data['status'] == 'cancelled';

              return Column(
                children: [
                  // Top Floating Card: Customer Info (Reduced vertical gap)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12,0, 12, 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: kWhite,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                              backgroundColor: kOrange.withOpacity(0.1),
                              radius: 18,
                              child: const Icon(Icons.person, color: kOrange, size: 18)
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['customerName'] ?? 'Walk-in Customer',
                                  style: const TextStyle(color: kOrange, fontSize: 15, fontWeight: FontWeight.w700),
                                ),
                                if (data['customerPhone'] != null)
                                  Text(data['customerPhone'], style: const TextStyle(color: kBlack54, fontSize: 11)),
                              ],
                            ),
                          ),
                          _buildStatusTag(settled, isCancelled),
                        ],
                      ),
                    ),
                  ),

                  // Main Body: White Container extending to bottom
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: kWhite,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text('BILLING OVERVIEW', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: kBlack54, letterSpacing: 0.5)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: kSuccessGreen.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: kSuccessGreen.withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          '${items.length} ${items.length == 1 ? 'Item' : 'Items'}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: kSuccessGreen,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(Icons.receipt_long_rounded, 'Invoice No', 'INV-${data['invoiceNumber']}'),
                                  _buildDetailRow(Icons.badge_rounded, 'Billed By', data['staffName'] ?? 'Admin'),
                                  _buildDetailRow(Icons.calendar_month_rounded, 'Date Issued', dateStr),
                                  _buildDetailRow(Icons.payment_rounded, 'Payment Mode', data['paymentMode'] ?? 'Not Set'),

                                  const Padding(padding: EdgeInsets.symmetric(vertical: 0), child: Divider(color: kGreyBg, thickness: 1)),

                                  // Table-formatted Item List
                                  const Text('ITEMS LIST', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: kBlack54, letterSpacing: 0.5)),
                                  const SizedBox(height: 8),
                                  _buildTableHeader(),
                                  ...items.map((item) => _buildItemTableRow(item)).toList(),

                                  const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Divider(color: kGreyBg, thickness: 1)),

                                  const Text('VALUATION SUMMARY', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: kBlack54, letterSpacing: 0.5)),
                                  const SizedBox(height: 8),
                                  _buildPriceRow('Subtotal (Net)', subtotalWithoutTax),
                                  if ((data['discount'] ?? 0.0) > 0)
                                    _buildPriceRow(context.tr('discount'), -(data['discount'] ?? 0.0).toDouble(), valueColor: kErrorColor),

                                  // Tax Breakdown
                                  ...taxBreakdown.entries.map((e) => _buildPriceRow(e.key, e.value)).toList(),

                                  const SizedBox(height: 32),
                                ],
                              ),
                            ),
                          ),
                          _buildFixedBottomArea(context, data),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusTag(bool settled, bool cancelled) {
    String label = cancelled ? "CANCELLED" : (settled ? "SETTLED" : "UNSETTLED");
    Color color = cancelled ? kBlack54 : (settled ? kErrorColor : kGoogleGreen);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: kGrey400),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(color: kBlack54, fontSize: 11, fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: kBlack87), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(8)),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('PRODUCT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54))),
          Expanded(flex: 1, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54))),
          Expanded(flex: 2, child: Text('RATE', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54))),
          Expanded(flex: 1, child: Text('TAX %', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54))),
          Expanded(flex: 2, child: Text('TAX AMT', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54))),
          Expanded(flex: 2, child: Text('TOTAL', textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54))),
        ],
      ),
    );
  }

  Widget _buildItemTableRow(Map<String, dynamic> item) {
    final price = (item['price'] ?? 0).toDouble();
    final quantity = (item['quantity'] ?? 1);
    final itemSubtotal = price * quantity;

    // Try to get tax info from item
    double taxVal = (item['taxAmount'] ?? 0.0).toDouble();
    int taxPerc = ((item['taxPercentage'] ?? 0) as num).toInt();
    String? taxName = item['taxName'] as String?;
    final taxType = item['taxType'] as String?;

    debugPrint('📊 Item: ${item['name']}, taxVal=$taxVal, taxPerc=$taxPerc, taxType=$taxType');

    // Calculate based on taxType if we have percentage but no amount
    if (taxVal == 0 && taxPerc > 0 && taxType != null) {
      if (taxType == 'Price includes Tax') {
        final baseAmount = itemSubtotal / (1 + taxPerc / 100);
        taxVal = itemSubtotal - baseAmount;
      } else if (taxType == 'Price is without Tax') {
        taxVal = itemSubtotal * (taxPerc / 100);
      }
      debugPrint('   ✅ Calculated tax from type: $taxVal');
    }

    final itemTotalWithTax = itemSubtotal + taxVal;

    debugPrint('   Final: taxPerc=$taxPerc, taxVal=$taxVal, total=$itemTotalWithTax');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kGreyBg))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3, 
            child: Text(
              item['name'] ?? 'Item', 
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: kBlack87), 
              maxLines: 3,
              overflow: TextOverflow.ellipsis
            )
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${item['quantity']}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w700)
            )
          ),
          Expanded(
            flex: 2, 
            child: Text(
              price.toStringAsFixed(2),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w700)
            )
          ),
          Expanded(
            flex: 1,
            child: Text(
              taxPerc > 0 ? '$taxPerc%' : '0%',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: kBlack87, fontWeight: FontWeight.w700)
            )
          ),
          Expanded(
            flex: 2, 
            child: Text(
              taxVal > 0.01 ? taxVal.toStringAsFixed(2) : '0',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10,  color: kBlack87, fontWeight: FontWeight.w700)
            )
          ),
          Expanded(
            flex: 2,
            child: Text(
              itemTotalWithTax.toStringAsFixed(2), 
              textAlign: TextAlign.right, 
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800,  color: kPrimaryColor)
            )
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double val, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kBlack54)),
          Text('${val.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: valueColor ?? kBlack87)),
        ],
      ),
    );
  }

  Widget _buildFixedBottomArea(BuildContext context, Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
          color: kWhite,
          border: const Border(top: BorderSide(color: kGrey200)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))]
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Net Amount Fixed at Bottom
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Final Total Payable', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: kBlack54)),
              Text('${(data['total'] ?? 0.0).toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kPrimaryColor)),
            ],
          ),
          const SizedBox(height: 12),
          // Row 2: Square Action Buttons (Reordered)
          _buildActionGrid(context, data),
        ],
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context, Map<String, dynamic> data) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getUserPermissions(),
      builder: (context, permSnap) {
        if (!permSnap.hasData) return const SizedBox.shrink();
        final perms = permSnap.data!;
        final bool isCancelled = data['status'] == 'cancelled';

        List<Widget> actions = [];

        // 1. Receipt
        actions.add(_squareActionButton(Icons.receipt_long_rounded, 'Receipt', kPrimaryColor, () => _printInvoiceReceipt(context, documentId, data)));

        // 2. Edit
        if (!isCancelled && (perms['canEditBill'] || perms['isAdmin'])) {
          actions.add(_squareActionButton(Icons.edit_note_rounded, 'Edit', kPrimaryColor, () async {
            if ((data['editCount'] ?? 0) >= 2) {
              showDialog(context: context, builder: (_) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), title: const Text('Limit Reached'), content: const Text('This bill has been edited 2 times. Please cancel and create a new bill for further changes.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
              return;
            }
            if (await PlanPermissionHelper.canEditBill()) {
              if (context.mounted) Navigator.push(context, CupertinoPageRoute(builder: (_) => EditBillPage(documentId: documentId, invoiceData: data)));
            } else {
              if (context.mounted) PlanPermissionHelper.showUpgradeDialog(context, 'Edit Bill', uid: uid);
            }
          }));
        }

        // 3. Return
        if (!isCancelled && (perms['canSaleReturn'] || perms['isAdmin'])) {
          actions.add(_squareActionButton(Icons.keyboard_return_rounded, 'Return', kPrimaryColor, () => Navigator.push(context, CupertinoPageRoute(builder: (_) => SaleReturnPage(documentId: documentId, invoiceData: data)))));
        }

        // 4. Cancel
        if (!isCancelled && (perms['canCancelBill'] || perms['isAdmin'])) {
          actions.add(_squareActionButton(Icons.cancel_outlined, 'Cancel', kErrorColor, () => _showCancelBillDialog(context, documentId, data)));
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: actions,
        );
      },
    );
  }

  Widget _squareActionButton(IconData icon, String lbl, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 68, height: 68,
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2))
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(lbl, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}// Close BillHistoryPage class

// ==========================================
// 4. CUSTOMER RELATED PAGES


// --- Global Theme Constants (Pure White BG, Standard Blue AppBar) ---
const Color kPrimaryBlue = Color(0xFF2F7CF6);
const Color kDeepNavy = Color(0xFF1E293B);
const Color kMediumBlue = Color(0xFF475569);
const Color kWhite = Colors.white;
const Color kSoftAzure = Color(0xFFF1F5F9);
const Color kBorderColor = Color(0xFFE2E8F0);

// Semantic Colors
const Color kSuccessGreen = Color(0xFF4CAF50);
const Color kWarningOrange = Color(0xFFFF9800);
const Color kErrorRed = Color(0xFFFF5252);

// ==========================================
// 1. CREDIT NOTES LIST PAGE
// ==========================================
class CreditNotesPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;

  const CreditNotesPage({super.key, required this.uid, required this.onBack});

  @override
  State<CreditNotesPage> createState() => _CreditNotesPageState();
}

class _CreditNotesPageState extends State<CreditNotesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterStatus = 'All';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        title: Text(context.tr('credit_notes'),
            style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kWhite, size: 22),
          onPressed: widget.onBack,
        ),
      ),
      body: Column(
        children: [
          // ENTERPRISE SEARCH & FILTER HEADER
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: const BoxDecoration(
              color: kWhite,
              border: Border(bottom: BorderSide(color: kGrey200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kGrey200),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: kBlack87, fontWeight: FontWeight.w600, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: context.tr('search'),
                        hintStyle: const TextStyle(color: kBlack54, fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: kPrimaryColor, size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 7),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _buildStatusFilter(),
              ],
            ),
          ),

          Expanded(
            child: FutureBuilder<CollectionReference>(
              future: FirestoreService().getStoreCollection('creditNotes'),
              builder: (context, collectionSnapshot) {
                if (!collectionSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));

                return StreamBuilder<QuerySnapshot>(
                  stream: collectionSnapshot.data!.orderBy('timestamp', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyState();
                    }

                    var docs = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      if (_filterStatus != 'All' && (data['status'] ?? 'Available') != _filterStatus) return false;
                      if (_searchQuery.isNotEmpty) {
                        final cn = (data['creditNoteNumber'] ?? '').toString().toLowerCase();
                        final cust = (data['customerName'] ?? '').toString().toLowerCase();
                        return cn.contains(_searchQuery) || cust.contains(_searchQuery);
                      }
                      return true;
                    }).toList();

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _buildCreditNoteCard(docs[index]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: kPrimaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filterStatus,
          dropdownColor: kWhite,
          icon: const Icon(Icons.tune_rounded, color: kPrimaryColor, size: 20),
          items: ['All', 'Available', 'Used'].map((s) => DropdownMenuItem(
              value: s,
              child: Text(s, style: const TextStyle(color: kBlack87, fontWeight: FontWeight.bold, fontSize: 13))
          )).toList(),
          onChanged: (v) => setState(() => _filterStatus = v!),
        ),
      ),
    );
  }

  Widget _buildCreditNoteCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] ?? 'Available';
    final amount = (data['amount'] ?? 0.0) as num;
    final timestamp = data['timestamp'] as Timestamp?;
    final dateStr = timestamp != null ? DateFormat('dd MMM yy • hh:mm a').format(timestamp.toDate()) : '--';
    final isAvailable = status.toLowerCase() == 'available';

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => _CreditNoteDetailPage(documentId: doc.id, creditNoteData: data))),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(data['creditNoteNumber'] ?? 'CN-N/A', style: const TextStyle(fontWeight: FontWeight.w900, color: kPrimaryColor, fontSize: 13)),
                    Text(dateStr, style: const TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: kGreyBg, shape: BoxShape.circle),
                      child: const Icon(Icons.note_rounded, size: 16, color: kBlack54),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(data['customerName'] ?? 'Walk-in Customer',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kOrange)),
                    ),
                    Text("Rs ${amount.toStringAsFixed(2)}",
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: kPrimaryColor)),
                  ],
                ),
                const Divider(height: 20, color: kGrey100),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("FOR INVOICE", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: kBlack54, letterSpacing: 0.5)),
                          Text(data['invoiceNumber'] ?? 'Manual Entry', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: kBlack87))
                        ],
                      ),
                    ),
                    _statusBadge(isAvailable),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(bool available) {
    final Color c = available ? kGoogleGreen : kErrorColor;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: c.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.withOpacity(0.2))),
        child: Text(available ? "AVAILABLE" : "USED",
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: c)));
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: kGrey300),
          const SizedBox(height: 16),
          Text(context.tr('no_records_found'), style: const TextStyle(color: kBlack54, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ==========================================
// INTERNAL SUB-PAGE: CREDIT NOTE DETAIL
// ==========================================
class _CreditNoteDetailPage extends StatelessWidget {
  final String documentId;
  final Map<String, dynamic> creditNoteData;

  const _CreditNoteDetailPage({required this.documentId, required this.creditNoteData});

  @override
  Widget build(BuildContext context) {
    final amount = (creditNoteData['amount'] ?? 0.0) as num;
    final status = creditNoteData['status'] ?? 'Available';
    final items = (creditNoteData['items'] as List<dynamic>? ?? []);
    final ts = creditNoteData['timestamp'] as Timestamp?;
    final dateStr = ts != null ? DateFormat('dd MMM yy • hh:mm a').format(ts.toDate()) : 'N/A';
    final bool isAvailable = status.toLowerCase() == 'available';

    return Scaffold(
      backgroundColor: kPrimaryColor,
      appBar: AppBar(
        title: const Text('Credit Note Info', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 22), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  CircleAvatar(backgroundColor: kOrange.withOpacity(0.1), radius: 18, child: const Icon(Icons.person, color: kOrange, size: 18)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(creditNoteData['customerName'] ?? 'Walk-in Customer', style: const TextStyle(color: kOrange, fontSize: 15, fontWeight: FontWeight.w700)),
                      Text(creditNoteData['customerPhone'] ?? '--', style: const TextStyle(color: kBlack54, fontSize: 11)),
                    ]),
                  ),
                  _buildStatusTag(isAvailable),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(color: kWhite, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('NOTE INFORMATION', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: kBlack54, letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.receipt_long_rounded, 'Reference ID', creditNoteData['creditNoteNumber'] ?? 'N/A'),
                    _buildDetailRow(Icons.history_rounded, 'Against Invoice', creditNoteData['invoiceNumber'] ?? 'Manual'),
                    _buildDetailRow(Icons.calendar_month_rounded, 'Date Issued', dateStr),
                    _buildDetailRow(Icons.info_outline_rounded, 'Reason', creditNoteData['reason'] ?? 'Not Specified'),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: kGrey100, thickness: 1)),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('TOTAL CREDIT VALUE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: kBlack54)),
                      Text('Rs ${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kPrimaryColor)),
                    ]),
                    const SizedBox(height: 24),
                    const Text('RETURNED ITEMS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: kBlack54, letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    ...items.map((i) => _buildItemTile(i)).toList(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildStatusTag(bool available) {
    final Color c = available ? kGoogleGreen : kErrorColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(available ? "AVAILABLE" : "USED", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: c)),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [Icon(icon, size: 14, color: kGrey400), const SizedBox(width: 10), Text('$label: ', style: const TextStyle(color: kBlack54, fontSize: 11, fontWeight: FontWeight.w500)), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: kBlack87), overflow: TextOverflow.ellipsis))]));

  Widget _buildItemTile(Map<String, dynamic> i) => Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kGrey100))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(i['name'] ?? 'Item', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kBlack87)), Text("${i['quantity']} × Rs ${(i['price'] ?? 0).toStringAsFixed(0)}", style: const TextStyle(color: kBlack54, fontSize: 11))])), Text("Rs ${((i['price'] ?? 0) * (i['quantity'] ?? 1)).toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kBlack87))]));
}

class LedgerEntry {
  final DateTime date; final String type; final String desc; final double debit; final double credit; double balance;
  LedgerEntry({required this.date, required this.type, required this.desc, required this.debit, required this.credit, this.balance = 0});
}

class CustomerLedgerPage extends StatefulWidget {
  final String customerId; final String customerName;
  const CustomerLedgerPage({super.key, required this.customerId, required this.customerName});
  @override State<CustomerLedgerPage> createState() => _CustomerLedgerPageState();
}

class _CustomerLedgerPageState extends State<CustomerLedgerPage> {
  List<LedgerEntry> _entries = []; bool _loading = true;

  @override
  void initState() { super.initState(); _loadLedger(); }

  Future<void> _loadLedger() async {
    final sales = await FirestoreService().getStoreCollection('sales').then((c) => c.where('customerPhone', isEqualTo: widget.customerId).get());
    final credits = await FirestoreService().getStoreCollection('credits').then((c) => c.where('customerId', isEqualTo: widget.customerId).get());
    List<LedgerEntry> entries = [];
    for (var doc in sales.docs) {
      final d = doc.data() as Map<String, dynamic>;
      final date = (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      final total = (d['total'] ?? 0.0).toDouble();
      final mode = d['paymentMode'] ?? 'Unknown';
      entries.add(LedgerEntry(date: date, type: 'INV', desc: "Invoice #${d['invoiceNumber']}", debit: total, credit: 0));
      if (mode == 'Cash' || mode == 'Online') {
        entries.add(LedgerEntry(date: date, type: 'PAY', desc: "Immediate Payment", debit: 0, credit: total));
      } else if (mode == 'Split') {
        final paid = (d['cashReceived'] ?? 0.0).toDouble();
        if (paid > 0) entries.add(LedgerEntry(date: date, type: 'PAY', desc: "Partial Payment", debit: 0, credit: paid));
      }
    }
    for (var doc in credits.docs) {
      final d = doc.data() as Map<String, dynamic>;
      final date = (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      final amt = (d['amount'] ?? 0.0).toDouble();
      final type = d['type'] ?? '';
      final method = d['method'] ?? '';
      if (type == 'payment_received') {
        entries.add(LedgerEntry(date: date, type: 'CR', desc: "Payment (${method.isNotEmpty ? method : 'Cash'})", debit: 0, credit: amt));
      } else if (type == 'add_credit') {
        entries.add(LedgerEntry(date: date, type: 'DR', desc: "Sales Credit Added (${method.isNotEmpty ? method : 'Manual'})", debit: amt, credit: 0));
      }
    }
    entries.sort((a, b) => a.date.compareTo(b.date));
    double running = 0;
    for (var e in entries) {
      running += (e.debit - e.credit);
      e.balance = running;
    }
    if (mounted) setState(() { _entries = entries.reversed.toList(); _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(title: Text("${widget.customerName} Ledger", style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 16)), backgroundColor: kPrimaryColor, centerTitle: true, elevation: 0, iconTheme: const IconThemeData(color: kWhite)),
      body: _loading ? const Center(child: CircularProgressIndicator(color: kPrimaryColor)) : Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          color: kPrimaryColor.withOpacity(0.05),
          child: const Row(children: [
            Expanded(flex: 2, child: Text("DATE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5))),
            Expanded(flex: 3, child: Text("PARTICULARS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5))),
            Expanded(flex: 2, child: Text("DEBIT", textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kErrorColor))),
            Expanded(flex: 2, child: Text("CREDIT", textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kGoogleGreen))),
            Expanded(flex: 2, child: Text("BALANCE", textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kBlack54))),
          ]),
        ),
        Expanded(child: ListView.separated(
          itemCount: _entries.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: kGrey100),
          itemBuilder: (c, i) {
            final e = _entries[i];
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: Row(children: [
                Expanded(flex: 2, child: Text(DateFormat('dd/MM/yy').format(e.date), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kBlack87))),
                Expanded(flex: 3, child: Text(e.desc, style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Expanded(flex: 2, child: Text(e.debit > 0 ? e.debit.toStringAsFixed(0) : "-", textAlign: TextAlign.right, style: const TextStyle(color: kErrorColor, fontSize: 11, fontWeight: FontWeight.w900))),
                Expanded(flex: 2, child: Text(e.credit > 0 ? e.credit.toStringAsFixed(0) : "-", textAlign: TextAlign.right, style: const TextStyle(color: kGoogleGreen, fontSize: 11, fontWeight: FontWeight.w900))),
                Expanded(flex: 2, child: Text(e.balance.toStringAsFixed(0), textAlign: TextAlign.right, style: TextStyle(color: e.balance > 0 ? kErrorColor : kGoogleGreen, fontSize: 12, fontWeight: FontWeight.w900))),
              ]),
            );
          },
        )),
        _buildClosingBar(),
      ]),
    );
  }

  Widget _buildClosingBar() {
    final bal = _entries.isNotEmpty ? _entries.first.balance : 0.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      decoration: BoxDecoration(color: kWhite, border: const Border(top: BorderSide(color: kGrey200))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text("Current Closing Balance:", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: kBlack54)),
        Text("Rs ${bal.toStringAsFixed(2)}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: bal > 0 ? kErrorColor : kGoogleGreen)),
      ]),
    );
  }
}
class CustomerBillsPage extends StatelessWidget {
  final String phone; const CustomerBillsPage({super.key, required this.phone});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(title: const Text("Billing History", style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 16)), backgroundColor: kPrimaryColor, elevation: 0, centerTitle: true, iconTheme: const IconThemeData(color: kWhite)),
      body: FutureBuilder<QuerySnapshot>(
        future: FirestoreService().getStoreCollection('sales').then((c) => c.where('customerPhone', isEqualTo: phone).get()),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("No bills found", style: TextStyle(color: kBlack54, fontWeight: FontWeight.bold)));
          return ListView.separated(
            padding: const EdgeInsets.all(16), itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final date = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
              return Container(
                decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
                child: ListTile(
                  title: Text("Invoice #${data['invoiceNumber']}", style: const TextStyle(fontWeight: FontWeight.w900, color: kPrimaryColor, fontSize: 14)),
                  subtitle: Text(DateFormat('dd MMM yyyy').format(date), style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w600)),
                  trailing: Text("Rs ${data['total']}", style: const TextStyle(fontWeight: FontWeight.w900, color: kBlack87, fontSize: 15)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CustomerCreditsPage extends StatelessWidget {
  final String customerId; const CustomerCreditsPage({super.key, required this.customerId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(title: const Text("Payment Log", style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 16)), backgroundColor: kPrimaryColor, elevation: 0, centerTitle: true, iconTheme: const IconThemeData(color: kWhite)),
      body: FutureBuilder<QuerySnapshot>(
        future: _fetchCredits(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history_rounded, size: 64, color: kGrey300), const SizedBox(height: 16), const Text("No transaction history", style: TextStyle(color: kBlack54, fontWeight: FontWeight.bold))]));
          final docs = snapshot.data!.docs;
          return ListView.separated(
            padding: const EdgeInsets.all(16), itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              bool isPayment = data['type'] == 'payment_received';
              final date = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
              return Container(
                decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: (isPayment ? kGoogleGreen : kErrorColor).withOpacity(0.1), radius: 18, child: Icon(isPayment ? Icons.arrow_downward : Icons.arrow_upward, color: isPayment ? kGoogleGreen : kErrorColor, size: 16)),
                  title: Text(isPayment ? "Payment Received" : "Credit Added", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: kBlack87)),
                  subtitle: Text("${DateFormat('dd MMM yy • HH:mm').format(date)} • ${data['method'] ?? 'Manual'}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kBlack54)),
                  trailing: Text("Rs ${data['amount']}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: isPayment ? kGoogleGreen : kErrorColor)),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<QuerySnapshot> _fetchCredits() async {
    try {
      final collection = await FirestoreService().getStoreCollection('credits');
      return await collection.where('customerId', isEqualTo: customerId).orderBy('timestamp', descending: true).get();
    } catch (e) {
      final collection = await FirestoreService().getStoreCollection('credits');
      return await collection.where('customerId', isEqualTo: customerId).get();
    }
  }
}
class _ReceiveCreditPage extends StatefulWidget {
  final String customerId; final Map<String, dynamic> customerData; final double currentBalance;
  const _ReceiveCreditPage({required this.customerId, required this.customerData, required this.currentBalance});
  @override State<_ReceiveCreditPage> createState() => _ReceiveCreditPageState();
}

class _ReceiveCreditPageState extends State<_ReceiveCreditPage> {
  final TextEditingController _amountController = TextEditingController();
  double _amt = 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(title: const Text("Receive Payment", style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)), backgroundColor: kPrimaryColor, centerTitle: true, elevation: 0, iconTheme: const IconThemeData(color: kWhite)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.customerData['name'] ?? 'Customer', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kOrange)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("Real Balance", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack54)),
              Text("Rs ${widget.currentBalance.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kErrorColor)),
            ]),
          ),
          const SizedBox(height: 32),
          const Text("Enter Amount Received", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: kBlack54, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) => setState(() => _amt = double.tryParse(v) ?? 0.0),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: kPrimaryColor),
            decoration: InputDecoration(prefixText: "Rs ", filled: true, fillColor: kWhite, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrey300)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryColor, width: 2))),
          ),
          const Spacer(),
          SizedBox(width: double.infinity, height: 60, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (_amt <= 0) return;
              final cCol = await FirestoreService().getStoreCollection('customers');
              final crCol = await FirestoreService().getStoreCollection('credits');
              await cCol.doc(widget.customerId).update({'balance': widget.currentBalance - _amt});
              await crCol.add({'customerId': widget.customerId, 'customerName': widget.customerData['name'], 'amount': _amt, 'type': 'payment_received', 'method': 'Cash', 'timestamp': FieldValue.serverTimestamp()});
              if (mounted) Navigator.pop(context);
            },
            child: const Text("SAVE PAYMENT", style: TextStyle(color: kWhite, fontSize: 16, fontWeight: FontWeight.w900)),
          )),
        ]),
      ),
    );
  }
}

// ==========================================
// 2. CREDIT NOTE DETAIL PAGE
// ==========================================
class CreditNoteDetailPage extends StatelessWidget {
  final String documentId;
  final Map<String, dynamic> creditNoteData;

  const CreditNoteDetailPage({
    super.key,
    required this.documentId,
    required this.creditNoteData,
  });

  @override
  Widget build(BuildContext context) {
    final amount = (creditNoteData['amount'] ?? 0.0) as num;
    final status = creditNoteData['status'] ?? 'Available';
    final items = (creditNoteData['items'] as List<dynamic>? ?? []);
    final timestamp = creditNoteData['timestamp'] as Timestamp?;
    final dateString = timestamp != null ? DateFormat('dd MMM yyyy • h:mm a').format(timestamp.toDate()) : 'N/A';

    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(
        title: const Text('Detail Overview',
            style: TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: kPrimaryBlue,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kWhite),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prominent Amount Card
            _buildHeroCard(creditNoteData['creditNoteNumber'] ?? 'N/A', amount, status),

            const SizedBox(height: 24),
            _buildSectionTitle("INFORMATION"),
            _buildSectionCard(
              child: Column(
                children: [
                  _buildIconRow(Icons.receipt_long, "Invoice ID", "#${creditNoteData['invoiceNumber']}", kPrimaryBlue),
                  const Divider(height: 32),
                  _buildIconRow(Icons.person, "Customer", creditNoteData['customerName'] ?? 'Walk-in', kSuccessGreen),
                  const Divider(height: 32),
                  _buildIconRow(Icons.calendar_today, "Issued", dateString, kWarningOrange),
                ],
              ),
            ),

            const SizedBox(height: 24),
            _buildSectionTitle("ITEMS LIST"),
            _buildSectionCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  if (items.isEmpty)
                    const Padding(padding: EdgeInsets.all(32), child: Text("No items listed", style: TextStyle(color: kMediumBlue))),
                  ...items.map((item) => _buildItemRow(item)).toList(),
                  _buildDetailTotalRow(amount, items.length),
                ],
              ),
            ),

            const SizedBox(height: 32),
            if (status == 'Available')
              _buildLargeButton(
                context,
                label: "PROCESS REFUND",
                icon: Icons.check_circle_outline,
                color: kSuccessGreen,
                onPressed: () => _showRefundDialog(context),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(String id, num amount, String status) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kPrimaryBlue,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: kPrimaryBlue.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(id, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              _buildStatusPill(status, isInverse: true),
            ],
          ),
          const SizedBox(height: 20),
          const Text("REFUND AMOUNT", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11)),
          const SizedBox(height: 4),
          Text("${amount.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 32)),
        ],
      ),
    );
  }

  void _showRefundDialog(BuildContext context) {
    String mode = 'Cash';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Confirm Refund', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select refund method:', style: TextStyle(color: kMediumBlue)),
              const SizedBox(height: 24),
              _buildDialogOption(onSelect: () => setState(() => mode = "Cash"), mode: "Cash", current: mode, icon: Icons.payments, color: kSuccessGreen),
              const SizedBox(height: 12),
              _buildDialogOption(onSelect: () => setState(() => mode = "Online"), mode: "Online", current: mode, icon: Icons.account_balance, color: kPrimaryBlue),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: kErrorRed))),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                Navigator.pop(ctx); // Close dialog

                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator()),
                );

                try {
                  debugPrint('🔵 [Refund] Starting refund process...');
                  debugPrint('🔵 [Refund] Document ID: $documentId');
                  debugPrint('🔵 [Refund] Amount: ${creditNoteData['amount']}');
                  debugPrint('🔵 [Refund] Customer Phone: ${creditNoteData['customerPhone']}');

                  // Process refund - Update backend
                  await _processRefund(mode);

                  debugPrint('🔵 [Refund] Refund completed successfully');

                  // Always close loading first
                  navigator.pop(); // Close loading

                  // Then close detail page
                  navigator.pop(); // Close detail page

                  // Show success message
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Refund processed successfully'),
                      backgroundColor: kSuccessGreen,
                      duration: Duration(seconds: 2),
                    ),
                  );
                } catch (e) {
                  debugPrint('🔴 [Refund] Error: $e');

                  // Always close loading
                  navigator.pop(); // Close loading

                  // Show error message
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: kErrorRed,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: kSuccessGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('CONFIRM'),
            ),
          ],
        ),
      ),
    );
  }

  /// Process refund - Update credit note status and customer balance in backend
  Future<void> _processRefund(String paymentMode) async {
    try {
      debugPrint('🔵 [Refund] Step 1: Getting credit note data...');
      final amount = (creditNoteData['amount'] ?? 0.0) as num;
      final customerPhone = creditNoteData['customerPhone'] as String?;
      debugPrint('🔵 [Refund] Amount: $amount, Customer Phone: $customerPhone');

      // Update credit note status to 'Used' in backend
      debugPrint('🔵 [Refund] Step 2: Updating credit note status...');
      await FirestoreService().updateDocument('creditNotes', documentId, {
        'status': 'Used',
        'refundMethod': paymentMode,
        'refundedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('🔵 [Refund] Credit note status updated');

      // Update customer balance - reduce by refund amount
      if (customerPhone != null && customerPhone.isNotEmpty) {
        debugPrint('🔵 [Refund] Step 3: Getting customer reference...');
        final customerRef = await FirestoreService().getDocumentReference('customers', customerPhone);

        debugPrint('🔵 [Refund] Step 4: Starting transaction to update balance...');
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final customerDoc = await transaction.get(customerRef);
          if (customerDoc.exists) {
            final currentBalance = (customerDoc.data() as Map<String, dynamic>?)?['balance'] as double? ?? 0.0;
            final newBalance = (currentBalance - amount.toDouble()).clamp(0.0, double.infinity);

            debugPrint('🔵 [Refund] Current balance: $currentBalance, New balance: $newBalance');

            transaction.update(customerRef, {
              'balance': newBalance,
              'lastUpdated': FieldValue.serverTimestamp()
            });
          }
        });
        debugPrint('🔵 [Refund] Customer balance updated');

        // Add refund record to credits collection
        debugPrint('🔵 [Refund] Step 5: Adding refund record to credits...');
        await FirestoreService().addDocument('credits', {
          'customerId': customerPhone,
          'customerName': creditNoteData['customerName'] ?? 'Unknown',
          'amount': -amount.toDouble(),  // Negative for refund
          'type': 'refund',
          'method': paymentMode,
          'creditNoteNumber': creditNoteData['creditNoteNumber'],
          'invoiceNumber': creditNoteData['invoiceNumber'],
          'timestamp': FieldValue.serverTimestamp(),
          'date': DateTime.now().toIso8601String(),
          'note': 'Refund for Credit Note #${creditNoteData['creditNoteNumber']}',
        });
        debugPrint('🔵 [Refund] Refund record added to credits');
      }

      debugPrint('🔵 [Refund] Process completed successfully');
    } catch (e, stackTrace) {
      debugPrint('🔴 [Refund] Error processing refund: $e');
      debugPrint('🔴 [Refund] Stack trace: $stackTrace');
      rethrow;
    }
  }
}

// ==========================================
// 3. CREDIT DETAILS PAGE
// ==========================================


// --- UI CONSTANTS (Matching Quotations Style) ---
const Color _primaryColor = Color(0xFF2F7CF6);
const Color _successColor = Color(0xFF4CAF50);
const Color _errorColor = Color(0xFFEF4444);
const Color _cardBorder = Color(0xFFE3F2FD);
const Color _bgColor = Colors.white;

class CreditDetailsPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;

  const CreditDetailsPage({super.key, required this.uid, required this.onBack});

  @override
  State<CreditDetailsPage> createState() => _CreditDetailsPageState();
}

class _CreditDetailsPageState extends State<CreditDetailsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: kGreyBg,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: kPrimaryColor,
          iconTheme: const IconThemeData(color: kWhite),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 22),
            onPressed: widget.onBack,
          ),
          title: _isSearching
              ? TextField(
            controller: _searchController,
            autofocus: true,
            style: const TextStyle(color: kWhite, fontSize: 16),
            decoration: const InputDecoration(
              hintText: "Search name or contact...",
              hintStyle: TextStyle(color: Colors.white70),
              border: InputBorder.none,
            ),
          )
              : const Text(
            'Credit Tracker',
            style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search, size: 22),
              onPressed: () => setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchController.clear();
              }),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: kWhite,
            indicatorWeight: 4,
            labelStyle: TextStyle(fontWeight: FontWeight.w800, color: kWhite, fontSize: 12, letterSpacing: 0.5),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, color: Colors.white70, fontSize: 12),
            tabs: [
              Tab(text: "SALES CREDIT"),
              Tab(text: "PURCHASE CREDIT"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSalesList(),
            _buildPurchaseList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesList() {
    return FutureBuilder<CollectionReference>(
      future: FirestoreService().getStoreCollection('customers'),
      builder: (context, collectionSnapshot) {
        if (!collectionSnapshot.hasData) return _buildLoading();
        return StreamBuilder<QuerySnapshot>(
          stream: collectionSnapshot.data!.where('balance', isGreaterThan: 0).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return _buildLoading();

            final docs = snapshot.data?.docs ?? [];
            final filtered = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              final name = (data['name'] ?? '').toString().toLowerCase();
              final phone = (data['phone'] ?? '').toString().toLowerCase();
              return name.contains(_searchQuery) || phone.contains(_searchQuery);
            }).toList();

            double totalSalesCredit = 0.0;
            for (var doc in filtered) {
              totalSalesCredit += ((doc.data() as Map<String, dynamic>)['balance'] ?? 0.0) as num;
            }

            if (filtered.isEmpty && _searchQuery.isEmpty) return _buildEmptyState("No outstanding customer dues.");
            if (filtered.isEmpty) return _buildEmptyState("No results found for '$_searchQuery'");

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length + 1,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) return _buildTotalSummary(totalSalesCredit, kGoogleGreen, "TOTAL RECEIVABLE");
                return _buildSalesCard(filtered[index - 1]);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPurchaseList() {
    return FutureBuilder<CollectionReference>(
      future: FirestoreService().getStoreCollection('purchaseCreditNotes'),
      builder: (context, collectionSnapshot) {
        if (!collectionSnapshot.hasData) return _buildLoading();
        return StreamBuilder<QuerySnapshot>(
          stream: collectionSnapshot.data!.orderBy('timestamp', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return _buildLoading();

            final docs = snapshot.data?.docs ?? [];
            final filtered = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              final supplier = (data['supplierName'] ?? '').toString().toLowerCase();
              final noteNo = (data['creditNoteNumber'] ?? '').toString().toLowerCase();
              return supplier.contains(_searchQuery) || noteNo.contains(_searchQuery);
            }).toList();

            double totalPurchaseCredit = 0.0;
            for (var doc in filtered) {
              final data = doc.data() as Map<String, dynamic>;
              totalPurchaseCredit += ((data['amount'] ?? 0.0) - (data['paidAmount'] ?? 0.0)) as num;
            }

            if (filtered.isEmpty && _searchQuery.isEmpty) return _buildEmptyState("No pending purchase credits.");
            if (filtered.isEmpty) return _buildEmptyState("No results found for '$_searchQuery'");

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length + 1,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) return _buildTotalSummary(totalPurchaseCredit, kErrorColor, "TOTAL PAYABLE");
                return _buildPurchaseCard(filtered[index - 1]);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTotalSummary(double amount, Color color, String title) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text('Rs ${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kPrimaryColor)),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.account_balance_wallet_rounded, color: color, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final customerName = (data['name'] ?? 'Walk-in Customer').toString();
    final balance = (data['balance'] ?? 0.0).toDouble();
    final phone = (data['phone'] ?? 'N/A').toString();

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showCustomerSettlementDialog(doc.id, data, balance),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: kOrange.withOpacity(0.1),
                      radius: 18,
                      child: const Icon(Icons.person, color: kOrange, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kOrange)),
                          Text(phone, style: const TextStyle(color: kBlack54, fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: kGrey100)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('BALANCE DUE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54, letterSpacing: 0.5)),
                        Text('Rs ${balance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kPrimaryColor)),
                      ],
                    ),
                    _statusBadge("SETTLE", kGoogleGreen),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPurchaseCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final total = (data['amount'] ?? 0.0) as num;
    final paid = (data['paidAmount'] ?? 0.0) as num;
    final remaining = (total - paid).toDouble();
    final supplierName = (data['supplierName'] ?? 'Supplier').toString();
    final noteNumber = (data['creditNoteNumber'] ?? 'N/A').toString();
    final timestamp = data['timestamp'] as Timestamp?;
    final date = timestamp != null ? DateFormat('dd MMM yy').format(timestamp.toDate()) : 'Recent';

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showSettleDialog(doc.id, data, remaining),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$noteNumber', style: const TextStyle(fontWeight: FontWeight.w900, color: kPrimaryColor, fontSize: 12)),
                    Text(date, style: const TextStyle(color: kBlack54, fontSize: 10, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: kGreyBg, shape: BoxShape.circle),
                      child: const Icon(Icons.store_rounded, size: 16, color: kBlack54),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(supplierName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kBlack87), overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: kGrey100)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PENDING AMOUNT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54, letterSpacing: 0.5)),
                        Text('Rs ${remaining.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kPrimaryColor)),
                      ],
                    ),
                    _statusBadge("RECORD", kGoogleGreen),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
    );
  }

  // --- REFINED DIALOGS ---

  void _showSettleDialog(String docId, Map<String, dynamic> data, double remaining) {
    final TextEditingController amountController = TextEditingController();
    String paymentMode = 'Cash';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: kWhite,
          title: const Text('Settle Purchase', style: TextStyle(fontWeight: FontWeight.w800, color: kBlack87, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: kErrorColor.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: kErrorColor.withOpacity(0.15))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('DUE AMOUNT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kErrorColor, letterSpacing: 0.5)),
                    Text('Rs ${remaining.toStringAsFixed(2)}', style: const TextStyle(color: kErrorColor, fontWeight: FontWeight.w900, fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildDialogField(amountController, 'Amount to Pay', Icons.money_rounded),
              const SizedBox(height: 20),
              _buildPayOption(setDialogState, paymentMode, 'Cash', Icons.payments_outlined, kGoogleGreen, (v) => paymentMode = v),
              const SizedBox(height: 8),
              _buildPayOption(setDialogState, paymentMode, 'Online', Icons.account_balance_outlined, kPrimaryColor, (v) => paymentMode = v),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: kBlack54, fontWeight: FontWeight.bold))),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0 || amount > remaining) return;
                Navigator.pop(ctx);
                _performAsyncAction(() => _settlePurchaseCredit(docId, data, amount, paymentMode), "Purchase settled successfully");
              },
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('CONFIRM', style: TextStyle(color: kWhite, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomerSettlementDialog(String customerId, Map<String, dynamic> customerData, double currentBalance) {
    final TextEditingController amountController = TextEditingController(text: currentBalance.toStringAsFixed(2));
    String paymentMode = 'Cash';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: kWhite,
          title: const Text('Customer Payment', style: TextStyle(fontWeight: FontWeight.w800, color: kBlack87, fontSize: 18)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: kGoogleGreen.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: kGoogleGreen.withOpacity(0.15))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL DUE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kGoogleGreen, letterSpacing: 0.5)),
                      Text('Rs ${currentBalance.toStringAsFixed(2)}', style: const TextStyle(color: kGoogleGreen, fontWeight: FontWeight.w900, fontSize: 16)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildDialogField(amountController, 'Settlement Amount', Icons.currency_rupee_rounded),
                const SizedBox(height: 20),
                _buildPayOption(setDialogState, paymentMode, 'Cash', Icons.payments_outlined, kGoogleGreen, (v) => paymentMode = v),
                const SizedBox(height: 8),
                _buildPayOption(setDialogState, paymentMode, 'Online', Icons.account_balance_outlined, kPrimaryColor, (v) => paymentMode = v),
                const SizedBox(height: 8),
                _buildPayOption(setDialogState, paymentMode, 'Waive Off', Icons.block_outlined, kOrange, (v) => paymentMode = v),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: kBlack54, fontWeight: FontWeight.bold))),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0 || amount > currentBalance) return;
                Navigator.pop(ctx);
                _performAsyncAction(() => _settleCustomerCredit(customerId, customerData, amount, paymentMode, currentBalance), "Payment recorded successfully");
              },
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('SETTLE', style: TextStyle(color: kWhite, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogField(TextEditingController ctrl, String label, IconData icon) {
    return Container(
      decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        decoration: InputDecoration(
          labelText: label, prefixIcon: Icon(icon, color: kPrimaryColor, size: 18),
          border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildPayOption(StateSetter setDialogState, String current, String val, IconData icon, Color color, Function(String) onSel) {
    final sel = current == val;
    return InkWell(
      onTap: () => setDialogState(() => onSel(val)),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: sel ? color.withOpacity(0.08) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: sel ? color : kGrey200)),
        child: Row(
          children: [
            Icon(icon, color: sel ? color : kBlack54, size: 18),
            const SizedBox(width: 12),
            Text(val, style: TextStyle(color: sel ? color : kBlack87, fontWeight: sel ? FontWeight.w900 : FontWeight.w600, fontSize: 13)),
            const Spacer(),
            if (sel) Icon(Icons.check_circle_rounded, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  // --- ASYNC HELPERS ---

  Future<void> _performAsyncAction(Future<void> Function() action, String successMsg) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: kPrimaryColor)));
    try {
      await action();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMsg), backgroundColor: kGoogleGreen, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kErrorColor, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    }
  }

  Future<void> _settlePurchaseCredit(String docId, Map<String, dynamic> data, double amount, String mode) async {
    final paid = (data['paidAmount'] ?? 0.0) as num;
    await FirestoreService().updateDocument('purchaseCreditNotes', docId, {
      'paidAmount': paid + amount,
      'lastPaymentDate': FieldValue.serverTimestamp(),
      'lastPaymentMethod': mode,
    });
    await FirestoreService().addDocument('purchasePayments', {
      'creditNoteId': docId, 'creditNoteNumber': data['creditNoteNumber'], 'supplierName': data['supplierName'],
      'amount': amount, 'paymentMode': mode, 'timestamp': FieldValue.serverTimestamp(), 'date': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _settleCustomerCredit(String id, Map<String, dynamic> data, double amt, String mode, double old) async {
    final custs = await FirestoreService().getStoreCollection('customers');
    final creds = await FirestoreService().getStoreCollection('credits');
    await FirebaseFirestore.instance.runTransaction((tx) async {
      tx.update(custs.doc(id), {'balance': old - amt, 'lastUpdated': FieldValue.serverTimestamp()});
    });
    await creds.add({
      'customerId': id, 'customerName': data['name'], 'amount': amt, 'type': 'settlement', 'method': mode, 'timestamp': FieldValue.serverTimestamp(), 'date': DateTime.now().toIso8601String(),
    });
  }

  Widget _buildEmptyState(String msg) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.receipt_long_outlined, size: 60, color: kPrimaryColor.withOpacity(0.1)),
      const SizedBox(height: 16),
      Text(msg, style: const TextStyle(fontWeight: FontWeight.w700, color: kBlack54)),
    ]));
  }

  Widget _buildLoading() => const Center(child: CircularProgressIndicator(color: kPrimaryColor));
}
// 4. PURCHASE CREDIT NOTE DETAIL PAGE
// ==========================================
class PurchaseCreditNoteDetailPage extends StatefulWidget {
  final String documentId;
  final Map<String, dynamic> creditNoteData;

  const PurchaseCreditNoteDetailPage({super.key, required this.documentId, required this.creditNoteData});

  @override
  State<PurchaseCreditNoteDetailPage> createState() => _PurchaseCreditNoteDetailPageState();
}

class _PurchaseCreditNoteDetailPageState extends State<PurchaseCreditNoteDetailPage> {
  @override
  Widget build(BuildContext context) {
    final data = widget.creditNoteData;
    final total = (data['amount'] ?? 0.0) as num;
    final paid = (data['paidAmount'] ?? 0.0) as num;
    final remaining = total - paid;

    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(
        title: const Text('Purchase Overview',
            style: TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: kPrimaryBlue,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kWhite),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSectionCard(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(data['creditNoteNumber'] ?? 'N/A', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPrimaryBlue)),
                      _buildStatusPill(data['status'] ?? 'Available'),
                    ],
                  ),
                  const Divider(height: 32),
                  _buildLabelValue("SUPPLIER", data['supplierName'] ?? 'Unknown'),
                  const SizedBox(height: 16),
                  _buildLabelValue("BUSINESS CONTACT", data['supplierPhone'] ?? '--'),
                ],
              ),
            ),

            const SizedBox(height: 24),
            _buildSectionTitle("FINANCIAL SUMMARY"),
            _buildSectionCard(
              child: Column(
                children: [
                  _buildSummaryRow("Purchase Liability", "${total.toStringAsFixed(2)}"),
                  _buildSummaryRow("Settled Amount", "${paid.toStringAsFixed(2)}", color: kSuccessGreen),
                  const Divider(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("UNPAID DUE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: kMediumBlue)),
                      Text("${remaining.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: kErrorRed)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            if (remaining > 0)
              _buildLargeButton(context, label: "RECORD PAYMENT", icon: Icons.receipt_long_rounded, color: kPrimaryBlue, onPressed: () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: kMediumBlue, fontWeight: FontWeight.bold, fontSize: 14)),
          Text(value, style: TextStyle(color: color ?? kDeepNavy, fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }
}

// --- Top Level Helper Widgets (SaleAllPage Aesthetics) ---

Widget _buildSectionCard({required Widget child, EdgeInsets? padding}) {
  return Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: kWhite,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))
      ],
    ),
    child: child,
  );
}

Widget _buildSectionTitle(String title) {
  return Padding(padding: const EdgeInsets.only(left: 6, bottom: 12), child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kMediumBlue, letterSpacing: 1)));
}

Widget _buildLabelValue(String label, String value, {CrossAxisAlignment crossAlign = CrossAxisAlignment.start, Color? color}) {
  return Column(crossAxisAlignment: crossAlign, children: [
    Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kMediumBlue)),
    const SizedBox(height: 4),
    Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color ?? kDeepNavy)),
  ]);
}

Widget _buildStatusPill(String status, {bool isInverse = false}) {
  Color c;
  switch (status.toLowerCase()) {
    case 'available': c = kSuccessGreen; break;
    case 'used': c = kErrorRed; break;
    default: c = kWarningOrange;
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: isInverse ? kWhite.withOpacity(0.2) : c.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      border: isInverse ? Border.all(color: kWhite.withOpacity(0.4)) : Border.all(color: c.withOpacity(0.2)),
    ),
    child: Text(status.toUpperCase(), style: TextStyle(color: isInverse ? kWhite : c, fontWeight: FontWeight.bold, fontSize: 10)),
  );
}

Widget _buildItemRow(Map<String, dynamic> item) {
  final name = item['name'] ?? 'Item';
  final qty = (item['quantity'] ?? 0).toDouble();
  final price = (item['price'] ?? 0).toDouble();
  final total = (item['total'] ?? (price * qty)).toDouble();
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kDeepNavy)),
        const SizedBox(height: 2),
        Text("${price.toStringAsFixed(0)} × ${qty.toInt()}", style: const TextStyle(fontSize: 12, color: kMediumBlue)),
      ])),
      Text("${total.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kDeepNavy)),
    ]),
  );
}

Widget _buildDetailTotalRow(num amount, int itemCount) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text("TOTAL RETURN ($itemCount)", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kMediumBlue)),
      Text("${amount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPrimaryBlue)),
    ]),
  );
}

Widget _buildIconRow(IconData icon, String label, String value, Color iconColor) {
  return Row(children: [
    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 20)),
    const SizedBox(width: 16),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kMediumBlue)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kDeepNavy)),
    ])),
  ]);
}

Widget _buildLargeButton(BuildContext context, {required String label, required IconData icon, required Color color, required VoidCallback onPressed}) {
  return SizedBox(
    width: double.infinity, height: 56,
    child: ElevatedButton.icon(
      onPressed: onPressed, icon: Icon(icon, color: kWhite, size: 20),
      label: Text(label, style: const TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 16)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}

Widget _buildDialogOption({required VoidCallback onSelect, required String mode, required String current, required IconData icon, required Color color}) {
  final isSelected = current == mode;
  return InkWell(
    onTap: onSelect, borderRadius: BorderRadius.circular(12),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.05) : kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? color : Colors.grey.shade200, width: 2),
      ),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 22, color: color)),
        const SizedBox(width: 16),
        Text(mode, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isSelected ? color : kDeepNavy)),
        const Spacer(),
        if (isSelected) Icon(Icons.check_circle, color: color, size: 20),
      ]),
    ),
  );
}


// ==========================================
// 1. CUSTOMEMANAGEMENT PAGE
// ==========================================
class CustomersPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;

  const CustomersPage({super.key, required this.uid, required this.onBack});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'sales'; // 'sales' or 'credit'

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text.toLowerCase()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<double> _calculateTotalSalesFromBackend(String customerPhone) async {
    try {
      final salesCollection = await FirestoreService().getStoreCollection('sales');
      final salesSnapshot = await salesCollection.where('customerPhone', isEqualTo: customerPhone).get();
      double totalSales = 0.0;
      for (var saleDoc in salesSnapshot.docs) {
        final saleData = saleDoc.data() as Map<String, dynamic>;
        totalSales += (saleData['total'] ?? 0.0).toDouble();
      }
      return totalSales;
    } catch (e) {
      return 0.0;
    }
  }

  Future<Map<String, dynamic>> _fetchCustomerDataWithTotalSales(String customerPhone) async {
    try {
      final customerDoc = await FirestoreService().getDocument('customers', customerPhone);
      Map<String, dynamic> customerData = {};
      if (customerDoc.exists) {
        customerData = customerDoc.data() as Map<String, dynamic>;
      }
      final calculatedTotalSales = await _calculateTotalSalesFromBackend(customerPhone);
      customerData['totalSales'] = calculatedTotalSales;
      return customerData;
    } catch (e) {
      return {};
    }
  }

  void _showAddCustomer() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final gstController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: kWhite,
        title: Text(context.tr('addnewcustomer'),
            style: const TextStyle(fontWeight: FontWeight.w900, color: kBlack87, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCustomerDialogField(nameController, context.tr('customername'), Icons.person_outline),
            const SizedBox(height: 12),
            _buildCustomerDialogField(phoneController, context.tr('customerphone'), Icons.phone_android_outlined, type: TextInputType.phone),
            const SizedBox(height: 12),
            _buildCustomerDialogField(gstController, context.tr('gstin'), Icons.assignment_outlined),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL", style: TextStyle(color: kBlack54, fontWeight: FontWeight.bold))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryBlue,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(context.tr('add'), style: const TextStyle(color: kWhite, fontWeight: FontWeight.bold)),
            onPressed: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              final gst = gstController.text.trim();
              if (name.isEmpty || phone.isEmpty) return;

              await FirestoreService().setDocument('customers', phone, {
                'name': name,
                'phone': phone,
                'gst': gst.isEmpty ? null : gst,
                'balance': 0.0,
                'totalSales': 0.0,
                'lastUpdated': FieldValue.serverTimestamp(),
                'timestamp': FieldValue.serverTimestamp(),
              });
              if (mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sort Customers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kBlack87)),
            const SizedBox(height: 20),
            _buildSortOption('Sort by Sales', 'sales', Icons.trending_up_rounded),
            _buildSortOption('Sort by Credit', 'credit', Icons.account_balance_wallet_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String label, String value, IconData icon) {
    bool isSelected = _sortBy == value;
    return ListTile(
      onTap: () {
        setState(() => _sortBy = value);
        Navigator.pop(context);
      },
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryBlue.withOpacity(0.1) : kGreyBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: isSelected ? kPrimaryBlue : kBlack54, size: 22),
      ),
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? kPrimaryBlue : kBlack87)),
      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: kPrimaryBlue, size: 20) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        title: Text(context.tr('customer_management'),
            style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: kPrimaryBlue,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kWhite, size: 22),
          onPressed: widget.onBack,
        ),
      ),
      body: Column(
        children: [
          // Updated Search Header Area with Sort Button
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: const BoxDecoration(
              color: kWhite,
              border: Border(bottom: BorderSide(color: kGrey200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kGrey200),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: kBlack87, fontWeight: FontWeight.w600, fontSize: 14),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, color: kPrimaryBlue, size: 20),
                        hintText: context.tr('search'),
                        hintStyle: const TextStyle(color: kBlack54, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 7),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // New Sort Button UI
                InkWell(
                  onTap: _showSortMenu,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      color: kPrimaryBlue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kGrey200),
                    ),
                    child: const Icon(Icons.sort_rounded, color: kPrimaryBlue, size: 22),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => AddCustomerPage(
                          uid: widget.uid,
                          onBack: null,
                        ),
                      ),
                    ).then((value) {
                      if (value == true) {
                        setState(() {}); // Refresh the list
                      }
                    });
                  },
                  child: Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      color: kPrimaryBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded, color: kWhite, size: 22),
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: FutureBuilder<Stream<QuerySnapshot>>(
              future: FirestoreService().getCollectionStream('customers'),
              builder: (context, streamSnapshot) {
                if (!streamSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                return StreamBuilder<QuerySnapshot>(
                  stream: streamSnapshot.data,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildManagerNoDataState(context.tr('no_customers_found'));

                    final docs = snapshot.data!.docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final name = (data['name'] ?? '').toString().toLowerCase();
                      final phone = (data['phone'] ?? '').toString().toLowerCase();
                      return name.contains(_searchQuery) || phone.contains(_searchQuery);
                    }).toList();

                    // Sort docs based on selected sort option
                    docs.sort((a, b) {
                      final dataA = a.data() as Map<String, dynamic>;
                      final dataB = b.data() as Map<String, dynamic>;
                      if (_sortBy == 'sales') {
                        final salesA = (dataA['totalSales'] ?? 0).toDouble();
                        final salesB = (dataB['totalSales'] ?? 0).toDouble();
                        return salesB.compareTo(salesA); // Descending
                      } else {
                        final creditA = (dataA['balance'] ?? 0).toDouble();
                        final creditB = (dataB['balance'] ?? 0).toDouble();
                        return creditB.compareTo(creditA); // Descending
                      }
                    });

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final docId = docs[index].id;
                        final data = docs[index].data() as Map<String, dynamic>;

                        return FutureBuilder<Map<String, dynamic>>(
                          future: _fetchCustomerDataWithTotalSales(docId),
                          builder: (context, freshSnapshot) {
                            final freshData = freshSnapshot.data ?? data;
                            return _buildCustomerCard(docId, freshData);
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(String docId, Map<String, dynamic> data) {
    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(builder: (context) => CustomerDetailsPage(customerId: docId, customerData: data)),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: kPrimaryBlue.withOpacity(0.08),
                      radius: 20,
                      child: Text((data['name'] ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(color: kPrimaryBlue, fontWeight: FontWeight.w900, fontSize: 16)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['name'] ?? 'Unknown',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kOrange)),
                          Text(data['phone'] ?? '--',
                              style: const TextStyle(color: kBlack54, fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: kGrey400, size: 20),
                  ],
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: kGrey100)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildManagerStatItem("TOTAL SALES", "${(data['totalSales'] ?? 0).toStringAsFixed(0)}", kPrimaryBlue),
                    _buildManagerStatItem("CREDIT DUE", "${(data['balance'] ?? 0).toStringAsFixed(0)}", kErrorRed, align: CrossAxisAlignment.end),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerDialogField(TextEditingController ctrl, String label, IconData icon, {TextInputType type = TextInputType.text}) {
    return Container(
      decoration: BoxDecoration(
          color: kPrimaryColor.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kGrey200)
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        style: const TextStyle(fontWeight: FontWeight.w600, color: kBlack87, fontSize: 14),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: kPrimaryBlue, size: 18),
          hintText: label,
          hintStyle: const TextStyle(color: kBlack54, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildManagerStatItem(String label, String value, Color color, {CrossAxisAlignment align = CrossAxisAlignment.start}) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text("$value", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: color)),
      ],
    );
  }

  Widget _buildManagerNoDataState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded, size: 64, color: kGrey300),
          const SizedBox(height: 16),
          Text(msg, style: const TextStyle(color: kBlack54, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ==========================================
// 2. STAFF MANAGEMENT LIST
// ==========================================
class StaffManagementList extends StatelessWidget {
  final String adminUid;
  final VoidCallback onBack;
  final VoidCallback onAddStaff;

  const StaffManagementList({super.key, required this.adminUid, required this.onBack, required this.onAddStaff});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(
        title: Text(context.tr('staffmanagement'),
            style: const TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 18)),
        backgroundColor: kPrimaryBlue,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite), onPressed: onBack),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Staff Overview", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: kMediumBlue, letterSpacing: 0.5)),
                TextButton.icon(
                  onPressed: onAddStaff,
                  icon: const Icon(Icons.add_circle_outline, size: 20, color: kWhite),
                  label: const Text("ADD NEW", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: kWhite)),
                  style: TextButton.styleFrom(
                      backgroundColor: kPrimaryBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: kSoftAzure, thickness: 2),
          Expanded(
            child: FutureBuilder<String?>(
              future: FirestoreService().getCurrentStoreId(),
              builder: (context, storeIdSnapshot) {
                if (!storeIdSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryBlue));
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').where('storeId', isEqualTo: storeIdSnapshot.data).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryBlue));
                    if (snapshot.data!.docs.isEmpty) return _buildManagerNoDataState("No staff memberegistered");

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                        bool isActive = (data['status'] ?? '') == 'Active';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: kWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kSoftAzure, width: 1.5),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: kPrimaryBlue.withOpacity(0.1),
                              child: Text((data['name'] ?? 'S')[0].toUpperCase(),
                                  style: const TextStyle(color: kPrimaryBlue, fontWeight: FontWeight.w900)),
                            ),
                            title: Text(data['name'] ?? 'Unknown',
                                style: const TextStyle(fontWeight: FontWeight.w900, color: kDeepNavy, fontSize: 15)),
                            subtitle: Text("${data['role'] ?? 'Staff'} • ${data['email'] ?? ''}",
                                style: const TextStyle(fontSize: 12, color: kMediumBlue, fontWeight: FontWeight.w600)),
                            trailing: _buildManagerStatusPill(isActive ? "ACTIVE" : "INACTIVE", isActive ? kSuccessGreen : kErrorRed),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. ADD STAFF PAGE
// ==========================================
class AddStaffPage extends StatefulWidget {
  final String adminUid;
  final VoidCallback onBack;

  const AddStaffPage({super.key, required this.adminUid, required this.onBack});

  @override
  State<AddStaffPage> createState() => _AddStaffPageState();
}

class _AddStaffPageState extends State<AddStaffPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _selectedRole = "Administrator";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(
        title: Text(context.tr('addnewstaff'),
            style: const TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 18)),
        backgroundColor: kPrimaryBlue,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite), onPressed: widget.onBack),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildManagerSectionTitle("LOGIN INFORMATION"),
              _buildManagerFormTextField(_nameCtrl, "Staff Full Name", Icons.badge_outlined),
              const SizedBox(height: 16),
              _buildManagerFormTextField(_emailCtrl, "Email Address / User ID", Icons.alternate_email_outlined),
              const SizedBox(height: 16),
              _buildManagerFormTextField(_passCtrl, "Password", Icons.vpn_key_outlined, isObscure: true),
              const SizedBox(height: 32),
              _buildManagerSectionTitle("ACCESS PERMISSIONS"),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kSoftAzure),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRole,
                    isExpanded: true,
                    dropdownColor: kWhite,
                    icon: const Icon(Icons.expand_more, color: kPrimaryBlue),
                    items: ["Administrator", "Cashier", "Sales"].map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(r, style: const TextStyle(fontWeight: FontWeight.w700, color: kDeepNavy))
                    )).toList(),
                    onChanged: (val) => setState(() => _selectedRole = val!),
                  ),
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;
                    final storeId = await FirestoreService().getCurrentStoreId();
                    await FirebaseFirestore.instance.collection('users').add({
                      'name': _nameCtrl.text,
                      'email': _emailCtrl.text,
                      'role': _selectedRole,
                      'status': 'Active',
                      'storeId': storeId,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    widget.onBack();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text("CREATE STAFF ACCOUNT",
                      style: TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManagerFormTextField(TextEditingController ctrl, String hint, IconData icon, {bool isObscure = false}) {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kSoftAzure)
      ),
      child: TextFormField(
        controller: ctrl,
        obscureText: isObscure,
        style: const TextStyle(fontWeight: FontWeight.w700, color: kDeepNavy),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: kPrimaryBlue, size: 22),
          hintText: hint,
          hintStyle: const TextStyle(color: kMediumBlue, fontWeight: FontWeight.w500),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

// --- Common UI Helper Widgets ---

Widget _buildCustomerDialogField(TextEditingController ctrl, String label, IconData icon, {TextInputType type = TextInputType.text}) {
  return Container(
    height: 54,
    decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kSoftAzure)
    ),
    child: TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(fontWeight: FontWeight.w700, color: kDeepNavy),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: kPrimaryBlue, size: 20),
        hintText: label,
        hintStyle: const TextStyle(color: kMediumBlue, fontSize: 13),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    ),
  );
}

Widget _buildManagerStatItem(String label, String value, Color color, {CrossAxisAlignment align = CrossAxisAlignment.start}) {
  return Column(
    crossAxisAlignment: align,
    children: [
      Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kMediumBlue, letterSpacing: 1)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: color)),
    ],
  );
}

Widget _buildManagerStatusPill(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.2), width: 1),
    ),
    child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
  );
}

Widget _buildManagerNoDataState(String msg) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.folder_open_outlined, size: 60, color: kSoftAzure),
        const SizedBox(height: 12),
        Text(msg, style: TextStyle(color: kMediumBlue.withOpacity(0.6), fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

Widget _buildManagerSectionTitle(String title) {
  return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kMediumBlue, letterSpacing: 2))
  );
}


// ==========================================
// SALE RETURN PAGE
// ==========================================
class SaleReturnPage extends StatefulWidget {
  final String documentId;
  final Map<String, dynamic> invoiceData;

  const SaleReturnPage({
    super.key,
    required this.documentId,
    required this.invoiceData,
  });

  @override
  State<SaleReturnPage> createState() => _SaleReturnPageState();
}

class _SaleReturnPageState extends State<SaleReturnPage> {
  Map<int, int> returnQuantities = {}; // index -> quantity to return
  String returnMode = 'CreditNote';

  double get totalReturnAmount {
    double total = 0;
    final items = widget.invoiceData['items'] as List<dynamic>? ?? [];
    returnQuantities.forEach((index, qty) {
      if (index < items.length) {
        final item = items[index];
        final price = (item['price'] ?? 0).toDouble();
        total += price * qty;
      }
    });
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.invoiceData['items'] as List<dynamic>? ?? [];
    final discount = (widget.invoiceData['discount'] ?? 0).toDouble();
    final tax = (widget.invoiceData['tax'] ?? 0).toDouble();
    final total = (widget.invoiceData['total'] ?? 0).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(context.tr('sale_return'), style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2F7CF6),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Invoice details header
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invoice No. ${widget.invoiceData['invoiceNumber']}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2F7CF6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Discount : ${discount.toStringAsFixed(1)}'),
                      Text('Tax : ${tax.toStringAsFixed(1)}'),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Items : ${items.length}'),
                      const SizedBox(height: 8),
                      Text(
                        'Total : ${total.toStringAsFixed(1)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Items list
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Items',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...List.generate(items.length, (index) {
                    final item = items[index];
                    final name = item['name'] ?? '';
                    final qty = (item['quantity'] ?? 0) is int
                        ? item['quantity']
                        : int.tryParse(item['quantity'].toString()) ?? 0;
                    final price = (item['price'] ?? 0).toDouble();
                    final discount = (item['discount'] ?? 0).toDouble();
                    final itemTotal = price * qty;
                    final returnQty = returnQuantities[index] ?? 0;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text('${context.tr('available')} ${context.tr('quantity')} : ${qty.toStringAsFixed(2)}'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Qty : ${qty.toStringAsFixed(2)}'),
                                  Text('Price : ${price.toStringAsFixed(2)}'),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Discount : ${discount.toStringAsFixed(2)}'),
                                  Text(
                                    'Total : ${itemTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Return Qty :',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: returnQty > 0
                                        ? () {
                                            setState(() {
                                              returnQuantities[index] = returnQty - 1;
                                              if (returnQuantities[index]! <= 0) {
                                                returnQuantities.remove(index);
                                              }
                                            });
                                          }
                                        : null,
                                    icon: const Icon(Icons.remove_circle_outline),
                                    color: const Color(0xFF2F7CF6),
                                  ),
                                  Container(
                                    width: 60,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      returnQty.toString(),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: returnQty < qty
                                        ? () {
                                            setState(() {
                                              returnQuantities[index] = returnQty + 1;
                                            });
                                          }
                                        : null,
                                    icon: const Icon(Icons.add_circle_outline),
                                    color: const Color(0xFF2F7CF6),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Summary
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(context.tr('amount')),
                      Text(
                        '${totalReturnAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${context.tr('gst')} :'),
                      Text('${(totalReturnAmount * 0).toStringAsFixed(1)}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${context.tr('totalamount')} :',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${totalReturnAmount.toStringAsFixed(1)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2F7CF6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Return mode
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Return Mode :',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: returnMode,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: 'CreditNote',
                              child: Text('CreditNote'),
                            ),
                            DropdownMenuItem(
                              value: 'Cash',
                              child: Text('Cash'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              returnMode = value ?? 'CreditNote';
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Save button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: returnQuantities.isEmpty
                      ? null
                      : () => _processSaleReturn(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2F7CF6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: Colors.grey,
                  ),
                  child: const Text(
                    'Save Credit Note',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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

  Future<void> _processSaleReturn() async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final items = widget.invoiceData['items'] as List<dynamic>? ?? [];

      // 1. Restore stock for returned items - store-scoped
      final productsCollection = await FirestoreService().getStoreCollection('Products');
      for (var entry in returnQuantities.entries) {
        final index = entry.key;
        final returnQty = entry.value;

        if (index < items.length) {
          final item = items[index];
          if (item['productId'] != null && item['productId'].toString().isNotEmpty) {
            final productRef = productsCollection.doc(item['productId']);

            await FirebaseFirestore.instance.runTransaction((transaction) async {
              final productDoc = await transaction.get(productRef);
              if (productDoc.exists) {
                final productData = productDoc.data() as Map<String, dynamic>?;
                final currentStock = (productData?['currentStock'] ?? 0.0) as num;
                final newStock = currentStock.toDouble() + returnQty;
                transaction.update(productRef, {'currentStock': newStock});
              }
            });
          }
        }
      }

      // 2. Create credit note if mode is CreditNote - store-scoped with sequential number
      if (returnMode == 'CreditNote' && widget.invoiceData['customerPhone'] != null) {
        // Generate sequential credit note number
        final creditNoteNumber = await NumberGeneratorService.generateCreditNoteNumber();

        // Create credit note document - store-scoped
        final creditNotesCollection = await FirestoreService().getStoreCollection('creditNotes');
        await creditNotesCollection.add({
          'creditNoteNumber': creditNoteNumber,
          'invoiceNumber': widget.invoiceData['invoiceNumber'],
          'customerPhone': widget.invoiceData['customerPhone'],
          'customerName': widget.invoiceData['customerName'] ?? 'Unknown',
          'amount': totalReturnAmount,
          'items': returnQuantities.entries.map((entry) {
            final item = items[entry.key];
            return {
              'name': item['name'],
              'quantity': entry.value,
              'price': item['price'],
              'total': (item['price'] ?? 0) * entry.value,
            };
          }).toList(),
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'Available',
          'reason': 'Sale Return',
          'createdBy': 'Admin',
        });

        // NOTE: We do NOT add to customer balance here
        // Customer can only use the credit note when making a new purchase
      }

      // 3. Update the invoice - reduce quantities and update total
      final salesCollection = await FirestoreService().getStoreCollection('sales');

      // Create updated items list with reduced quantities
      List<Map<String, dynamic>> updatedItems = [];
      final oldTotal = (widget.invoiceData['total'] ?? 0).toDouble();

      for (int i = 0; i < items.length; i++) {
        final item = Map<String, dynamic>.from(items[i]);
        final originalQty = (item['quantity'] ?? 0) is int
            ? (item['quantity'] as int)
            : int.tryParse(item['quantity'].toString()) ?? 0;

        final returnedQty = returnQuantities[i] ?? 0;
        final newQty = originalQty - returnedQty;

        // Only add item if quantity is still positive
        if (newQty > 0) {
          item['quantity'] = newQty;
          updatedItems.add(item);
        }
      }

      // Calculate new total
      final newTotal = oldTotal - totalReturnAmount;
      final currentReturnAmount = (widget.invoiceData['returnAmount'] ?? 0).toDouble();

      // Track returned items separately
      List<Map<String, dynamic>> returnedItems = [];
      returnQuantities.forEach((index, qty) {
        if (index < items.length) {
          final item = items[index];
          returnedItems.add({
            'name': item['name'],
            'quantity': qty,
            'price': item['price'],
            'returnedAt': DateTime.now().toIso8601String(),
          });
        }
      });

      // Get existing returned items
      final existingReturnedItems = widget.invoiceData['returnedItems'] as List<dynamic>? ?? [];
      final allReturnedItems = [...existingReturnedItems, ...returnedItems];

      // Update invoice with reduced items and new total
      await salesCollection.doc(widget.documentId).update({
        'items': updatedItems,
        'total': newTotal,
        'hasReturns': true,
        'returnAmount': currentReturnAmount + totalReturnAmount,
        'lastReturnAt': FieldValue.serverTimestamp(),
        'returnedItems': allReturnedItems,
      });

      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              returnMode == 'CreditNote'
                  ? 'Credit note created successfully for customer'
                  : 'Sale return processed successfully'
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Go back
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
                content: Text('${context.tr('error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}


class EditBillPage extends StatefulWidget {
  final String documentId;
  final Map<String, dynamic> invoiceData;

  const EditBillPage({
    super.key,
    required this.documentId,
    required this.invoiceData,
  });

  @override
  State<EditBillPage> createState() => _EditBillPageState();
}

class _EditBillPageState extends State<EditBillPage> {
  // --- Standardized Color Palette (Matches SaleAllPage) ---
  static const Color kPrimaryColor = Color(0xFF2F7CF6);
  static const Color kBackgroundColor = Colors.white;
  static const Color kSurfaceColor = Colors.white;
  static const Color kTextPrimary = Color(0xFF1E293B);
  static const Color kTextSecondary = Color(0xFF64748B);
  static const Color kBorderColor = Color(0xFFE3F2FD); // Light blue border
  static const Color kSuccessColor = Color(0xFF4CAF50);
  static const Color kErrorColor = Color(0xFFFF5252);
  static const double kCardRadius = 12.0;

  late TextEditingController _discountController;
  late String _selectedPaymentMode;
  late String? _selectedCustomerPhone;
  late String? _selectedCustomerName;
  late List<Map<String, dynamic>> _items;
  List<Map<String, dynamic>> _selectedCreditNotes = [];
  double _creditNotesAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _discountController = TextEditingController(
      text: (widget.invoiceData['discount'] ?? 0).toString(),
    );
    _selectedPaymentMode = widget.invoiceData['paymentMode'] ?? 'Cash';
    _selectedCustomerPhone = widget.invoiceData['customerPhone'];
    _selectedCustomerName = widget.invoiceData['customerName'];

    // Copy items to editable list
    final originalItems = widget.invoiceData['items'] as List<dynamic>? ?? [];
    _items = originalItems.map((item) => Map<String, dynamic>.from(item)).toList();

    // Load previously selected credit notes
    final selectedNotes = widget.invoiceData['selectedCreditNotes'] as List<dynamic>?;
    if (selectedNotes != null) {
      _selectedCreditNotes = selectedNotes.map((n) => Map<String, dynamic>.from(n)).toList();
      _creditNotesAmount = _selectedCreditNotes.fold(0.0, (sum, cn) => sum + ((cn['amount'] ?? 0) as num).toDouble());
    }
  }

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  // --- Calculations ---
  double get subtotal => _items.fold(0.0, (sum, item) {
    final price = (item['price'] ?? 0).toDouble();
    final qty = (item['quantity'] ?? 0) is int
        ? (item['quantity'] as int).toDouble()
        : double.tryParse(item['quantity'].toString()) ?? 0.0;
    return sum + (price * qty);
  });

  double get discount => double.tryParse(_discountController.text) ?? 0;
  double get totalBeforeCreditNotes => subtotal - discount;
  double get finalTotal => (totalBeforeCreditNotes - _creditNotesAmount).clamp(0, double.infinity);

  @override
  Widget build(BuildContext context) {
    final time = widget.invoiceData['timestamp'] != null
        ? (widget.invoiceData['timestamp'] as Timestamp).toDate()
        : null;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(
          context.tr('edit_bill'),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
        backgroundColor: kPrimaryColor ,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: kBorderColor, height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel('INVOICE OVERVIEW'),
                  _buildHeaderCard(time),
                  const SizedBox(height: 24),

                  _buildSectionLabel('CUSTOMER INFORMATION'),
                  _buildCustomerCard(),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionLabel('BILLING ITEMS'),
                      TextButton.icon(
                        onPressed: _showAddProductDialog,
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text('Add Item'),
                        style: TextButton.styleFrom(foregroundColor: kPrimaryColor),
                      ),
                    ],
                  ),
                  _buildItemsList(),
                  const SizedBox(height: 120), // Spacing for bottom panel
                ],
              ),
            ),
          ),
          _buildSummaryPanel(),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: kTextSecondary,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildHeaderCard(DateTime? time) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBackgroundColor,
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(color: kBorderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: kPrimaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invoice #${widget.invoiceData['invoiceNumber'] ?? 'N/A'}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextPrimary),
                ),
                Text(
                  time != null ? DateFormat('MMM dd, yyyy • hh:mm a').format(time) : 'No date',
                  style: const TextStyle(color: kTextSecondary, fontSize: 13),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kBackgroundColor,
                    border: Border.all(color: kBorderColor),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.invoiceData['staffName'] ?? 'Admin',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kTextSecondary),
                  ),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildCustomerCard() {
    final hasCustomer = _selectedCustomerPhone != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kBackgroundColor,
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(color: kBorderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: hasCustomer ? kPrimaryColor : kBorderColor,
            radius: 20,
            child: Icon(Icons.person, color: hasCustomer ? Colors.white : kTextSecondary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedCustomerName ?? 'Walk-in Customer',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kTextPrimary),
                ),
                if (hasCustomer)
                  Text(_selectedCustomerPhone!, style: const TextStyle(color: kTextSecondary, fontSize: 12)),
              ],
            ),
          ),
          if (hasCustomer)
            IconButton(
              onPressed: () => setState(() {
                _selectedCustomerPhone = null;
                _selectedCustomerName = null;
                _selectedCreditNotes = [];
                _creditNotesAmount = 0;
              }),
              icon: const Icon(Icons.cancel, color: kErrorColor, size: 20),
            )
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    return Container(
      decoration: BoxDecoration(
        color: kBackgroundColor,
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(color: kBorderColor),
      ),
      child: _items.isEmpty
          ? const Padding(
        padding: EdgeInsets.all(40.0),
        child: Center(child: Text('No items in this bill', style: TextStyle(color: kTextSecondary))),
      )
          : ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _items.length,
        separatorBuilder: (context, index) => const Divider(height: 1, color: kBorderColor),
        itemBuilder: (context, index) {
          final item = _items[index];
          return Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text('Qty: ${item['quantity']} × ${item['price']}', style: const TextStyle(color: kTextSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Text(
                  '${((item['price'] ?? 0) * (item['quantity'] ?? 0)).toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kPrimaryColor),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => setState(() => _items.removeAt(index)),
                  child: const Icon(Icons.delete_outline, color: kErrorColor, size: 20),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, -5))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryLine('Subtotal', '${subtotal.toStringAsFixed(0)}'),
                GestureDetector(
                  onTap: _showDiscountDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: kSuccessColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text('Discount: -${discount.toStringAsFixed(0)}',
                        style: const TextStyle(color: kSuccessColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
            if (_selectedCustomerPhone != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryLine('Credit Notes', '-${_creditNotesAmount.toStringAsFixed(0)}', color: Colors.orange),
                  GestureDetector(
                    onTap: _showCreditNotesDialog,
                    child: Text('Change Notes', style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ],
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: kBorderColor)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL PAYABLE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
                Text('${finalTotal.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kPrimaryColor)),
              ],
            ),
            const SizedBox(height: 16),
            _buildPaymentModeSelector(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _updateBill,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('CONFIRM UPDATES', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryLine(String label, String value, {Color? color}) {
    return Text('$label: $value', style: TextStyle(color: color ?? kTextSecondary, fontWeight: FontWeight.w600, fontSize: 13));
  }

  Widget _buildPaymentModeSelector() {
    final modes = ['Cash', 'Online', 'Credit', 'Split'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: modes.map((mode) {
        final isSelected = _selectedPaymentMode == mode;
        return GestureDetector(
          onTap: () => setState(() => _selectedPaymentMode = mode),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? kPrimaryColor : kBackgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isSelected ? kPrimaryColor : kBorderColor),
            ),
            child: Text(mode, style: TextStyle(
                color: isSelected ? Colors.white : kTextSecondary,
                fontWeight: FontWeight.bold, fontSize: 12
            )),
          ),
        );
      }).toList(),
    );
  }

  // --- Dialogs (Functionality Preserved) ---

  void _showDiscountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Add Discount', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _discountController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            prefixText: ' ',
            hintText: '0',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () { setState(() {}); Navigator.pop(context); }, child: const Text('Apply')),
        ],
      ),
    );
  }

  void _showCreditNotesDialog() async {
    if (_selectedCustomerPhone == null) return;

    try {
      final creditNotesCollection = await FirestoreService().getStoreCollection('creditNotes');
      final snapshot = await creditNotesCollection
          .where('customerPhone', isEqualTo: _selectedCustomerPhone)
          .where('status', isEqualTo: 'Available')
          .get();

      final availableCreditNotes = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();

      if (!mounted) return;
      if (availableCreditNotes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No credit notes available')));
        return;
      }

      showDialog(
        context: context,
        builder: (ctx) {
          List<Map<String, dynamic>> tempSelected = List.from(_selectedCreditNotes);
          return StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('Select Credit Notes', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableCreditNotes.length,
                  itemBuilder: (context, index) {
                    final cn = availableCreditNotes[index];
                    final isSelected = tempSelected.any((s) => s['id'] == cn['id']);
                    return CheckboxListTile(
                      value: isSelected,
                      title: Text('${cn['creditNoteNumber']} (${cn['amount']})'),
                      subtitle: Text(cn['reason'] ?? ''),
                      onChanged: (val) => setDialogState(() {
                        if (val == true) tempSelected.add(cn);
                        else tempSelected.removeWhere((s) => s['id'] == cn['id']);
                      }),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(onPressed: () {
                  setState(() {
                    _selectedCreditNotes = tempSelected;
                    _creditNotesAmount = _selectedCreditNotes.fold(0.0, (sum, cn) => sum + ((cn['amount'] ?? 0) as num).toDouble());
                  });
                  Navigator.pop(ctx);
                }, child: const Text('Apply')),
              ],
            ),
          );
        },
      );
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _showAddProductDialog() async {
    try {
      final productsCollection = await FirestoreService().getStoreCollection('Products');
      final snapshot = await productsCollection.limit(50).get();

      final products = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['itemName'] ?? data['name'] ?? 'Unknown',
          'price': (data['price'] ?? 0).toDouble(),
          'currentStock': (data['currentStock'] ?? 0).toDouble(),
          'stockEnabled': data['stockEnabled'] ?? false,
        };
      }).toList();

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setSheetState) => Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: kBorderColor, borderRadius: BorderRadius.circular(2))),
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Select Product', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: products.length,
                    separatorBuilder: (c, i) => const Divider(height: 1, indent: 20, endIndent: 20),
                    itemBuilder: (context, index) {
                      final p = products[index];
                      return ListTile(
                        title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${p['price']}'),
                        trailing: const Icon(Icons.add_circle, color: kPrimaryColor),
                        onTap: () {
                          setState(() {
                            _items.add({
                              'productId': p['id'],
                              'name': p['name'],
                              'price': p['price'],
                              'quantity': 1,
                            });
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _updateBill() async {
    if (_items.isEmpty) return;

    try {
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));

      final oldPaymentMode = widget.invoiceData['paymentMode'];
      final oldTotal = (widget.invoiceData['total'] ?? 0).toDouble();
      final currentEditCount = (widget.invoiceData['editCount'] ?? 0) as int;

      final salesCollection = await FirestoreService().getStoreCollection('sales');
      await salesCollection.doc(widget.documentId).update({
        'items': _items,
        'subtotal': subtotal,
        'discount': discount,
        'total': finalTotal,
        'paymentMode': _selectedPaymentMode,
        'customerPhone': _selectedCustomerPhone,
        'customerName': _selectedCustomerName,
        'selectedCreditNotes': _selectedCreditNotes,
        'creditNotesAmount': _creditNotesAmount,
        'updatedAt': FieldValue.serverTimestamp(),
        'editCount': currentEditCount + 1,
      });

      // Credit Notes Logic
      if (_selectedCreditNotes.isNotEmpty) {
        final creditNotesCollection = await FirestoreService().getStoreCollection('creditNotes');
        for (var cn in _selectedCreditNotes) {
          await creditNotesCollection.doc(cn['id']).update({
            'status': 'Used',
            'usedInInvoice': widget.invoiceData['invoiceNumber'],
            'usedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Customer Balance Logic
      if (_selectedCustomerPhone != null) {
        final customersCollection = await FirestoreService().getStoreCollection('customers');
        final customerRef = customersCollection.doc(_selectedCustomerPhone);

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final customerDoc = await transaction.get(customerRef);
          if (customerDoc.exists) {
            final customerData = customerDoc.data() as Map<String, dynamic>?;
            double currentBalance = ((customerData?['balance'] ?? 0.0) as num).toDouble();
            if (oldPaymentMode == 'Credit') currentBalance -= oldTotal;
            if (_selectedPaymentMode == 'Credit') currentBalance += finalTotal;
            transaction.update(customerRef, {'balance': currentBalance});
          }
        });
      }

      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('bill_updated_success')), backgroundColor: kSuccessColor));
        Navigator.pop(context); // Go back
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${context.tr('error_updating_bill')}: $e'), backgroundColor: kErrorColor));
      }
    }
  }
}
