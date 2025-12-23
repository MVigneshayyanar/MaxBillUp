import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:maxbillup/Auth/SubscriptionPlanPage.dart';
import 'package:maxbillup/Sales/Bill.dart';
import 'package:maxbillup/Sales/Invoice.dart';
import 'package:maxbillup/Sales/QuotationsList.dart';
import 'package:maxbillup/Menu/CustomerManagement.dart';
import 'package:maxbillup/Menu/KnowledgePage.dart';
import 'package:maxbillup/components/common_bottom_nav.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/Stocks/StockPurchase.dart';
import 'package:maxbillup/Stocks/ExpenseCategories.dart';
import 'package:maxbillup/Stocks/Expenses.dart';
import 'package:maxbillup/Settings/StaffManagement.dart';
import 'package:maxbillup/Reports/Reports.dart';
import 'package:maxbillup/Stocks/Stock.dart';
import 'package:maxbillup/Settings/Profile.dart';
import 'package:maxbillup/utils/permission_helper.dart';
import 'package:maxbillup/utils/plan_permission_helper.dart';
import 'package:maxbillup/utils/plan_provider.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/Sales/NewSale.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/services/number_generator_service.dart';




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
    // Use Consumer for real-time plan updates (listener triggers rebuild)
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
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20, bottom: 20, left: 20, right: 20),
                color: _headerBlue,
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
                // New Sale (First item)

                // Quotation
                if (_hasPermission('quotation') || isAdmin)
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

                // Bill History
                if (_hasPermission('billHistory') || isAdmin)
                  _buildMenuItem(
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.receipt_long_outlined, color: Color(0xFF388E3C), size: 24),
                    ),
                    context.tr('billhistory'),
                    'BillHistory',
                  ),

                // Credit Notes
                if (_hasPermission('creditNotes') || isAdmin)
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

                // Customer Management
                if (_hasPermission('customerManagement') || isAdmin)
                  _buildMenuItem(
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.people_outline, color: Color(0xFF7B1FA2), size: 24),
                    ),
                    context.tr('customer_management'),
                    'Customers',
                  ),

                // Expenses (Expansion Tile)
                if (_hasPermission('expenses') || isAdmin)
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
                      ],
                    ),
                  ),

                // Credit Details
                if (_hasPermission('creditDetails') || isAdmin)
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

                // Staff Management
                if (isAdmin || _hasPermission('staffManagement'))
                  _buildMenuItem(
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCE4EC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.badge_outlined, color: Color(0xFFC2185B), size: 24),
                    ),
                    context.tr('staffmanagement'),
                    'StaffManagement',
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
                  'Knowledge',
                  'Knowledge',
                ),




                // Stock (moved from bottom nav - placed above Reports)

                // Reports Expansion (moved from bottom nav)
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
        // TopCustomers requires async checks, handle separately
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
        backgroundColor: const Color(0xFF2196F3),
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

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  // Streams
  Stream<List<QueryDocumentSnapshot>>? _combinedStream;
  StreamController<List<QueryDocumentSnapshot>>? _controller;
  StreamSubscription? _salesSub;
  StreamSubscription? _savedOrdersSub;

  // Search & Filter State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All Time';

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

  // Merges 'sales' and 'savedOrders' collections into one stream
  Future<void> _initializeCombinedStream() async {
    try {
      // Use store-scoped collections via FirestoreService
      final salesCollection = await FirestoreService().getStoreCollection('sales');
      final savedOrdersCollection = await FirestoreService().getStoreCollection('savedOrders');

      final salesStream = salesCollection
          .orderBy('timestamp', descending: true)
          .snapshots();

      final savedOrdersStream = savedOrdersCollection
          .orderBy('timestamp', descending: true)
          .snapshots();

      List<QueryDocumentSnapshot> salesDocs = [];
      List<QueryDocumentSnapshot> savedOrdersDocs = [];

      void updateController() {
        if (_controller == null || _controller!.isClosed) return;

        // Merge lists
        final allDocs = [...salesDocs, ...savedOrdersDocs];

        // Sort merged list by timestamp descending
        allDocs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>? ?? {};
          final dataB = b.data() as Map<String, dynamic>? ?? {};
          final tsA = dataA['timestamp'] as Timestamp?;
          final tsB = dataB['timestamp'] as Timestamp?;
          if (tsA == null && tsB == null) return 0;
          if (tsA == null) return 1;
          if (tsB == null) return -1;
          return tsB.compareTo(tsA);
        });

        _controller!.add(allDocs);
      }

      _controller = StreamController<List<QueryDocumentSnapshot>>.broadcast();

      _salesSub = salesStream.listen((snapshot) {
        salesDocs = snapshot.docs;
        updateController();
      });

      _savedOrdersSub = savedOrdersStream.listen((snapshot) {
        savedOrdersDocs = snapshot.docs;
        updateController();
      });

      if (mounted) {
        setState(() {
          _combinedStream = _controller!.stream;
        });
      }
    } catch (e) {
      debugPrint('Error initializing combined stream: $e');
      if (mounted) {
        setState(() {
          _combinedStream = Stream.value([]);
        });
      }
    }
  }

  // --- Filtering Logic ---

  List<QueryDocumentSnapshot> _filterDocumentsWithLimit(List<QueryDocumentSnapshot> docs, int historyDaysLimit) {
    if (docs.isEmpty) return [];

    final now = DateTime.now();
    final startOfThisMonth = DateTime(now.year, now.month, 1);
    final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
    final endOfLastMonth = DateTime(now.year, now.month, 0, 23, 59, 59);

    // Use the provided history limit
    final historyLimitDate = now.subtract(Duration(days: historyDaysLimit));

    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      // 0. Plan-based History Limit (Free users see only 7 days)
      final timestamp = data['timestamp'] as Timestamp?;
      if (timestamp != null) {
        final date = timestamp.toDate();
        if (date.isBefore(historyLimitDate)) {
          return false; // Filter out bills older than plan limit
        }
      }

      // 1. Search Filter
      bool matchesSearch = true;
      if (_searchQuery.isNotEmpty) {
        final inv = (data['invoiceNumber'] ?? '').toString().toLowerCase();
        final customer = (data['customerName'] ?? '').toString().toLowerCase(); // Assuming customerName exists
        matchesSearch = inv.contains(_searchQuery) || customer.contains(_searchQuery);
      }

      // 2. Date Dropdown Filter
      bool matchesDate = true;
      if (timestamp != null) {
        final date = timestamp.toDate();
        if (_selectedFilter == 'This Month') {
          matchesDate = date.isAfter(startOfThisMonth) || date.isAtSameMomentAs(startOfThisMonth);
        } else if (_selectedFilter == 'Last Month') {
          matchesDate = date.isAfter(startOfLastMonth) && date.isBefore(endOfLastMonth);
        }
      }

      return matchesSearch && matchesDate;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(

        title: Text(context.tr('billhistory'), style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2196F3),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack, // Use the provided callback
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search Bar & Filter Dropdown
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: context.tr('search'),
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedFilter,
                      icon: const Icon(Icons.arrow_drop_down, color: Color(
                          0xFF2196F3)),
                      items: <String>['All Time', 'This Month', 'Last Month']
                          .map((String value) {
                        String displayText = value;
                        if (value == 'All Time') displayText = context.tr('all');
                        else if (value == 'This Month') displayText = context.tr('thismonth');
                        else if (value == 'Last Month') displayText = context.tr('lastmonth');
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(displayText, style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedFilter = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _combinedStream == null
                ? const Center(child: CircularProgressIndicator())
                : FutureBuilder<int>(
              future: PlanPermissionHelper.getBillHistoryDaysLimit(),
              builder: (context, planSnapshot) {
                if (!planSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final historyDaysLimit = planSnapshot.data!;

                return StreamBuilder<List<QueryDocumentSnapshot>>(
                  stream: _combinedStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final rawData = snapshot.data ?? [];
                    // Apply client-side filters with plan-based limit
                    final filteredData = _filterDocumentsWithLimit(rawData, historyDaysLimit);

                    if (filteredData.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children:  [
                            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(context.tr('nobillsfound'), style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      );
                    }

                    // Group bills by date
                    final groupedData = _groupBillsByDate(filteredData);
                    final sortedDates = groupedData.keys.toList()..sort((a, b) {
                  // Parse "dd MMM, yyyy" back to Sortable Date if needed,
                  // but since we rely on the list order which is already sorted by timestamp,
                  // we can just iterate.
                  // To be safe, we rely on the order of keys as inserted?
                  // Map iteration order is preserved in Dart.
                  // However, to be extra safe, let's parse.
                  DateFormat fmt = DateFormat('dd MMM, yyyy');
                  return fmt.parse(b).compareTo(fmt.parse(a));
                });

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: sortedDates.length,
                  itemBuilder: (context, index) {
                    final date = sortedDates[index];
                    final bills = groupedData[date]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date Header
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                          child: Text(
                            '$date (${bills.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
                          ),
                        ),
                        // List of Bills
                        ...bills.map((doc) => _buildBillCard(context, doc)).toList(),
                      ],
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

  // Group documents by formatted date string
  Map<String, List<QueryDocumentSnapshot>> _groupBillsByDate(List<QueryDocumentSnapshot> docs) {
    final Map<String, List<QueryDocumentSnapshot>> grouped = {};
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['timestamp'];

      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        final dateString = DateFormat('dd MMM, yyyy').format(date);

        if (!grouped.containsKey(dateString)) {
          grouped[dateString] = [];
        }
        grouped[dateString]!.add(doc);
      }
    }
    return grouped;
  }

  Widget _buildBillCard(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final inv = data['invoiceNumber'] ?? 'N/A';
    // Handle total as int or double safely
    final rawTotal = data['total'];
    final totalVal = (rawTotal is int) ? rawTotal.toDouble() : (rawTotal is double ? rawTotal : 0.0);
    final total = totalVal.toStringAsFixed(1);

    final itemsCount = (data['items'] as List<dynamic>? ?? []).length;
    final staffName = data['staffName'] ?? 'Staff';
    final customerName = data['customerName'] ?? 'Guest'; // Added field for better context

    final time = data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate() : null;
    final timeString = time != null ? DateFormat('h:mm a').format(time) : '-';

    // Status Logic
    final isSettled = data.containsKey('paymentMode') && data['paymentMode'] != null;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200)
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Invoice No & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('#$inv', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: isSettled ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: isSettled ? Colors.green.shade200 : Colors.orange.shade200
                      )
                  ),
                  child: Text(
                    isSettled ? 'Settled' : 'UnSettled',
                    style: TextStyle(
                      color: isSettled ? Colors.green.shade700 : Colors.orange.shade800,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Row 2: Info Grid
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow(Icons.access_time, timeString),
                      const SizedBox(height: 4),
                      _infoRow(Icons.person_outline, customerName),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹$total',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2196F3)),
                    ),
                    Text(
                      '$itemsCount Items',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                )
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            const SizedBox(height: 10),

            // Row 3: Creator & Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${context.tr('by')}: $staffName', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),

                SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (!isSettled) {
                        // Logic to resume/settle bill
                        final List<CartItem> cartItems = (data['items'] as List<dynamic>? ?? [])
                            .map((item) => CartItem(
                          productId: item['productId'] ?? '',
                          name: item['name'] ?? '',
                          price: (item['price'] ?? 0).toDouble(),
                          quantity: (item['quantity'] ?? 1) is int
                              ? item['quantity']
                              : int.tryParse(item['quantity'].toString()) ?? 1,
                        ))
                            .toList();

                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => BillPage(
                              uid: widget.uid,
                              cartItems: cartItems,
                              totalAmount: totalVal,
                              userEmail: widget.userEmail,
                              savedOrderId: doc.id,
                            ),
                          ),
                        ).then((_) {
                          // Optional: Refresh or handle return
                          setState(() {});
                        });
                      } else {
                        // View Receipt
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => SalesDetailPage(
                              documentId: doc.id,
                              initialData: data,
                              uid: widget.uid,
                            ),
                          ),
                        );
                      }
                    },
                    icon: Icon(isSettled ? Icons.receipt_long : Icons.payment, size: 16, color: Colors.white),
                    label: Text(
                      isSettled ? context.tr('receipt') : context.tr('settle_bill'),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  // Helper widget for small info rows
  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 13, color: Colors.black87)),
      ],
    );
  }
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

  // Calculate tax totals from items
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${context.tr('invoice')} ${initialData['invoiceNumber'] ?? ''}', style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2196F3),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: FutureBuilder<DocumentReference>(
        future: FirestoreService().getDocumentReference('sales', documentId),
        builder: (context, docRefSnapshot) {
          if (!docRefSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<DocumentSnapshot>(
            // Use documentId to fetch the latest state of the bill
            stream: docRefSnapshot.data!.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return Center(child: Text(context.tr('bill_not_found')));
              }

              final data = snapshot.data!.data() as Map<String, dynamic>;
              final time = data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate() : null;
              final items = (data['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

              // Calculate tax information
              final taxInfo = _calculateTaxTotals(items);
              final subtotalWithoutTax = taxInfo['subtotalWithoutTax'] as double;
              final totalTax = taxInfo['totalTax'] as double;
              final taxBreakdown = taxInfo['taxBreakdown'] as Map<String, double>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Invoice Number and Date
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${context.tr('invoicenumber')} ${data['invoiceNumber'] ?? 'N/A'}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2196F3),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${context.tr('created_by')} ${data['staffName'] ?? 'Admin'}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                              // Show edit count indicator
                              if ((data['editCount'] ?? 0) > 0) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (data['editCount'] ?? 0) >= 2
                                        ? Colors.red.shade100
                                        : Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Edited ${data['editCount']}x (${2 - (data['editCount'] ?? 0)} edits left)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: (data['editCount'] ?? 0) >= 2
                                          ? Colors.red.shade700
                                          : Colors.orange.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${context.tr('issued_on')} :',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                time != null ? DateFormat('dd MMM yyyy').format(time) : 'N/A',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                time != null ? DateFormat('h:mm a').format(time) : 'N/A',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Customer Details
                Text(
                  context.tr('customerdetails'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['customerName'] ?? 'A',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('phone'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        data['customerPhone'] ?? '-',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Invoice Items
                Text(
                  context.tr('invoice_items'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      // Header row
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              context.tr('items'),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              context.tr('amount'),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Items list
                      ...items.map((item) => _buildItemRow(item)).toList(),
                      // Summary section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                        ),
                        child: Column(
                          children: [
                            // Items count and quantity
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${context.tr('totalitems')} : ${items.length}',
                                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                                ),
                                Text(
                                  '${context.tr('totalquantity')} : ${items.fold(0, (sum, item) => sum + (item['quantity'] as int? ?? 0))}',
                                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),

                            // Subtotal (without tax)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${context.tr('subtotal')} (${context.tr('excluding_tax')}):',
                                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                                ),
                                Text(
                                  'Rs ${subtotalWithoutTax.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                                ),
                              ],
                            ),

                            // Discount (if any)
                            if ((data['discount'] ?? 0.0) > 0) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${context.tr('discount')}:',
                                    style: const TextStyle(fontSize: 14, color: Colors.red),
                                  ),
                                  Text(
                                    '- Rs ${(data['discount'] ?? 0.0).toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red),
                                  ),
                                ],
                              ),
                            ],

                            // Tax breakdown
                            if (taxBreakdown.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ...taxBreakdown.entries.map((entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${entry.key}:',
                                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                                    ),
                                    Text(
                                      'Rs ${entry.value.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black54),
                                    ),
                                  ],
                                ),
                              )).toList(),
                            ],

                            // Total Tax
                            if (totalTax > 0) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${context.tr('total_tax')}:',
                                    style: const TextStyle(fontSize: 14, color: Colors.green),
                                  ),
                                  Text(
                                    'Rs ${totalTax.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.green),
                                  ),
                                ],
                              ),
                            ],

                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),

                            // Total Amount
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${context.tr('totalamount')}:',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  'Rs ${(data['total'] ?? 0.0).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2196F3),
                                  ),
                                ),
                              ],
                            ),

                            // Payment mode details
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${context.tr('payment_mode')}:',
                                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: data['paymentMode'] == 'Credit'
                                        ? Colors.orange.shade50
                                        : Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    data['paymentMode'] ?? 'Cash',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: data['paymentMode'] == 'Credit'
                                          ? Colors.orange.shade700
                                          : Colors.green.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Split payment details
                            if (data['paymentMode'] == 'Split') ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${context.tr('cash')}:', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                  Text('Rs ${(data['cashReceived_split'] ?? 0.0).toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${context.tr('online')}:', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                  Text('Rs ${(data['onlineReceived_split'] ?? 0.0).toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                ],
                              ),
                              if ((data['creditIssued_split'] ?? 0.0) > 0) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${context.tr('credit')}:', style: const TextStyle(fontSize: 13, color: Colors.orange)),
                                    Text('Rs ${(data['creditIssued_split'] ?? 0.0).toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 13, color: Colors.orange)),
                                  ],
                                ),
                              ],
                            ],

                            // Cash/Online received and change
                            if (data['paymentMode'] == 'Cash' || data['paymentMode'] == 'Online') ...[
                              if ((data['cashReceived'] ?? 0.0) > 0) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${context.tr('received')}:', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                    Text('Rs ${(data['cashReceived'] ?? 0.0).toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                  ],
                                ),
                              ],
                              if ((data['change'] ?? 0.0) > 0) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${context.tr('change')}:', style: const TextStyle(fontSize: 13, color: Colors.green)),
                                    Text('Rs ${(data['change'] ?? 0.0).toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 13, color: Colors.green)),
                                  ],
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                // Action buttons (Sale Return, Cancel Bill, Receipt, Edit)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      context,
                      icon: Icons.shopping_cart_outlined,
                      label: context.tr('sale_return'),
                      onTap: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => SaleReturnPage(
                              documentId: documentId,
                              invoiceData: data,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildActionButton(
                      context,
                      icon: Icons.delete_outline,
                      label: context.tr('cancel_bill'),
                      color: Colors.red,
                      onTap: () {
                        _showCancelBillDialog(context, documentId, data);
                      },
                    ),
                    _buildActionButton(
                      context,
                      icon: Icons.receipt_long_outlined,
                      label: context.tr('receipt'),
                      onTap: () => _printInvoiceReceipt(context, documentId, data),
                    ),
                    _buildActionButton(
                      context,
                      icon: Icons.edit_outlined,
                      label: context.tr('edit'),
                      onTap: () async {
                        // Check edit count - max 2 edits allowed
                        final editCount = (data['editCount'] ?? 0) as int;
                        if (editCount >= 2) {
                          if (context.mounted) {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
                                    const SizedBox(width: 8),
                                    const Text('Edit Limit Reached'),
                                  ],
                                ),
                                content: const Text(
                                  'This bill has already been edited 2 times.\n\n'
                                  'To make further changes, please contact the admin to cancel this bill and create a new corrected bill.',
                                  style: TextStyle(fontSize: 15),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          }
                          return;
                        }

                        // Check if plan allows edit bill
                        final canEdit = await PlanPermissionHelper.canEditBill();
                        if (!canEdit) {
                          if (context.mounted) {
                            PlanPermissionHelper.showUpgradeDialog(context, 'Edit Bill', uid: uid);
                          }
                          return;
                        }
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => EditBillPage(
                                documentId: documentId,
                                invoiceData: data,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ); // Close SingleChildScrollView
            }, // Close StreamBuilder builder
          ); // Close StreamBuilder
        }, // Close FutureBuilder builder
      ), // Close FutureBuilder
    ); // Close Scaffold
  } // Close build method

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
            .collection('stores')
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

      // Prepare items for invoice page
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((item) => {
                'name': item['name'] ?? '',
                'quantity': item['quantity'] ?? 0,
                'price': (item['price'] ?? 0).toDouble(),
                'total': ((item['price'] ?? 0) * (item['quantity'] ?? 1)).toDouble(),
                'productId': item['productId'] ?? '',
              })
          .toList();

      // Get timestamp
      DateTime dateTime = DateTime.now();
      if (data['timestamp'] != null) {
        dateTime = (data['timestamp'] as Timestamp).toDate();
      } else if (data['date'] != null) {
        dateTime = DateTime.tryParse(data['date'].toString()) ?? DateTime.now();
      }

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
              subtotal: (data['subtotal'] ?? data['total'] ?? 0).toDouble(),
              discount: (data['discount'] ?? 0).toDouble(),
              taxes: null, // Will be calculated from items if needed
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

  Widget _buildActionButton(BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: color ?? const Color(0xFF2196F3)),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color ?? Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelBillDialog(BuildContext context, String documentId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                style: const TextStyle(fontSize: 14, color: Color(0xFF2196F3)),
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

                // 3. Delete the sales document
                await FirestoreService().deleteDocument('sales', documentId);

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

  Widget _buildItemRow(Map<String, dynamic> item) {
    final name = item['name'] ?? 'Item';
    final price = (item['price'] ?? 0).toDouble();
    final quantity = item['quantity'] ?? 1;
    final taxName = item['taxName'] as String?;
    final taxPercentage = (item['taxPercentage'] ?? 0).toDouble();
    final taxType = item['taxType'] as String?;

    // Calculate amounts
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

    final finalTotal = itemBaseAmount + itemTax;

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
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              Text(
                'Rs ${finalTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rs ${price.toStringAsFixed(2)} × $quantity',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              if (itemTax > 0)
                Text(
                  'Base: Rs ${itemBaseAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
            ],
          ),
          // Show tax information if applicable
          if (itemTax > 0 && taxName != null && taxName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$taxName ($taxPercentage%)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                Text(
                  '+ Rs ${itemTax.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ); // Close Container
  } // Close _buildItemRow method
} // Close BillHistoryPage class

// ==========================================
// 4. CUSTOMER RELATED PAGES


// --- Global Theme Constants (Pure White BG, Standard Blue AppBar) ---
const Color kPrimaryBlue = Color(0xFF2196F3);
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
      backgroundColor: kWhite,
      appBar: AppBar(
        title: Text(context.tr('credit_notes'),
            style: const TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: kPrimaryBlue,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kWhite),
          onPressed: widget.onBack,
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Header (Matches SaleAllPage look)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kWhite,
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: kDeepNavy, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: context.tr('search'),
                        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                if (!collectionSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryBlue));

                return StreamBuilder<QuerySnapshot>(
                  stream: collectionSnapshot.data!.orderBy('timestamp', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kPrimaryBlue));

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

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
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
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kPrimaryBlue),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filterStatus,
          dropdownColor: kWhite,
          icon: const Icon(Icons.filter_list, color: kPrimaryBlue, size: 20),
          items: ['All', 'Available', 'Used'].map((s) => DropdownMenuItem(
              value: s,
              child: Text(s, style: const TextStyle(color: kDeepNavy, fontWeight: FontWeight.bold, fontSize: 13))
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
    final isAvailable = status.toLowerCase() == 'available';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))
        ],
      ),
      child: InkWell(
        onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => CreditNoteDetailPage(documentId: doc.id, creditNoteData: data))),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['creditNoteNumber'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kDeepNavy)),
                      const SizedBox(height: 4),
                      Text(timestamp != null ? DateFormat('dd MMM, yyyy').format(timestamp.toDate()) : '--', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                  _buildStatusPill(status),
                ],
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildLabelValue("CUSTOMER", data['customerName'] ?? 'Walk-in'),
                  Text("₹${amount.toStringAsFixed(0)}", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: isAvailable ? kSuccessGreen : kErrorRed)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[200]),
          const SizedBox(height: 12),
          Text("No records found", style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w600)),
        ],
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
        borderRadius: BorderRadius.circular(16),
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
          Text("₹${amount.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 32)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
  String _selectedTab = 'Sales';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(
        title: const Text('Credit Tracker',
            style: TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: kPrimaryBlue,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kWhite),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Tab Switcher (Matches Category Selector in SaleAllPage)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: kWhite,
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildTabChip("Sales", Icons.people_outline),
                  const SizedBox(width: 10),
                  _buildTabChip("Purchase", Icons.store_outlined),
                ],
              ),
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: "Search name or contact...",
                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          Expanded(
            child: _selectedTab == 'Sales' ? _buildSalesList() : _buildPurchaseList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(String key, IconData icon) {
    final isSelected = _selectedTab == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryBlue : kWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? kPrimaryBlue : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? kWhite : kMediumBlue, size: 16),
            const SizedBox(width: 8),
            Text(key, style: TextStyle(color: isSelected ? kWhite : kMediumBlue, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesList() {
    return FutureBuilder<CollectionReference>(
      future: FirestoreService().getStoreCollection('customers'),
      builder: (context, collectionSnapshot) {
        if (!collectionSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryBlue));
        return StreamBuilder<QuerySnapshot>(
          stream: collectionSnapshot.data!.where('balance', isGreaterThan: 0).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kPrimaryBlue));

            final filtered = (snapshot.data?.docs ?? []).where((d) => (d.data() as Map<String, dynamic>)['name'].toString().toLowerCase().contains(_searchQuery)).toList();

            // Calculate total sales credit
            double totalSalesCredit = 0.0;
            for (var doc in filtered) {
              final data = doc.data() as Map<String, dynamic>;
              totalSalesCredit += (data['balance'] ?? 0.0) as num;
            }

            return Column(
              children: [
                // Total Sales Credit Header
                _buildTotalCreditHeader(totalSalesCredit, kSuccessGreen, 'Total Sales Credit'),

                // Customer List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => _buildContactCard(filtered[index], kSuccessGreen, "DUE FROM CUST"),
                  ),
                ),
              ],
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
        if (!collectionSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryBlue));
        return StreamBuilder<QuerySnapshot>(
          stream: collectionSnapshot.data!.orderBy('timestamp', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kPrimaryBlue));
            final filtered = (snapshot.data?.docs ?? []).where((d) => (d.data() as Map<String, dynamic>)['supplierName'].toString().toLowerCase().contains(_searchQuery)).toList();

            // Calculate total purchase credit
            double totalPurchaseCredit = 0.0;
            for (var doc in filtered) {
              final data = doc.data() as Map<String, dynamic>;
              totalPurchaseCredit += (data['amount'] ?? 0.0) as num;
            }

            return Column(
              children: [
                // Total Purchase Credit Header
                _buildTotalCreditHeader(totalPurchaseCredit, kErrorRed, 'Total Purchase Credit'),

                // Purchase Credit Notes List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => _buildPurchaseCard(filtered[index]),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTotalCreditHeader(double totalAmount, Color color, String label) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '₹${totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(QueryDocumentSnapshot doc, Color color, String label) {
    final data = doc.data() as Map<String, dynamic>;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Text(data['name'][0].toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ),
        title: Text(data['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, color: kDeepNavy)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kMediumBlue)),
            Text("₹${(data['balance'] ?? 0).toStringAsFixed(0)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final total = (data['amount'] ?? 0.0) as num;
    final paid = (data['paidAmount'] ?? 0.0) as num;
    final remaining = total - paid;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['creditNoteNumber'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(data['supplierName'] ?? 'Supplier', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("₹${remaining.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kErrorRed)),
                    Text("of ₹${total.toStringAsFixed(0)}", style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ],
            ),
            if (remaining > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showSettleDialog(doc.id, data, remaining.toDouble()),
                      icon: const Icon(Icons.payment, size: 18),
                      label: const Text('Settle Amount'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kSuccessGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => PurchaseCreditNoteDetailPage(documentId: doc.id, creditNoteData: data))),
                    icon: const Icon(Icons.visibility, color: kPrimaryBlue),
                    style: IconButton.styleFrom(
                      backgroundColor: kPrimaryBlue.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Show dialog to settle partial or full amount for purchase credit
  void _showSettleDialog(String docId, Map<String, dynamic> data, double remaining) {
    final TextEditingController amountController = TextEditingController();
    String paymentMode = 'Cash';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Settle Amount', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Remaining: ₹${remaining.toStringAsFixed(2)}', style: const TextStyle(color: kErrorRed, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 20),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount to Pay',
                  prefixText: '₹',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: remaining.toStringAsFixed(2),
                ),
              ),
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerLeft, child: Text('Payment Method:', style: TextStyle(fontWeight: FontWeight.bold))),
              const SizedBox(height: 12),
              // Cash Option
              InkWell(
                onTap: () => setDialogState(() => paymentMode = "Cash"),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: paymentMode == 'Cash' ? kSuccessGreen.withOpacity(0.1) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: paymentMode == 'Cash' ? kSuccessGreen : Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.payments, color: paymentMode == 'Cash' ? kSuccessGreen : Colors.grey),
                      const SizedBox(width: 12),
                      Text('Cash', style: TextStyle(color: paymentMode == 'Cash' ? kSuccessGreen : Colors.grey[700], fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (paymentMode == 'Cash') const Icon(Icons.check_circle, color: kSuccessGreen),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Online Option
              InkWell(
                onTap: () => setDialogState(() => paymentMode = "Online"),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: paymentMode == 'Online' ? kPrimaryBlue.withOpacity(0.1) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: paymentMode == 'Online' ? kPrimaryBlue : Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance, color: paymentMode == 'Online' ? kPrimaryBlue : Colors.grey),
                      const SizedBox(width: 12),
                      Text('Online', style: TextStyle(color: paymentMode == 'Online' ? kPrimaryBlue : Colors.grey[700], fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (paymentMode == 'Online') const Icon(Icons.check_circle, color: kPrimaryBlue),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: kErrorRed))),
            ElevatedButton(
              onPressed: () async {
                debugPrint('🟢 [Settle] Button clicked');

                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid amount'), backgroundColor: kErrorRed),
                  );
                  return;
                }
                if (amount > remaining) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Amount cannot exceed remaining balance'), backgroundColor: kErrorRed),
                  );
                  return;
                }

                debugPrint('🟢 [Settle] Amount validated: $amount');

                // Capture navigators before async operations
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                Navigator.pop(ctx); // Close dialog

                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator())
                );

                try {
                  debugPrint('🟢 [Settle] Starting settlement process...');
                  await _settlePurchaseCredit(docId, data, amount, paymentMode);
                  debugPrint('🟢 [Settle] Settlement completed successfully');

                  // Close loading
                  navigator.pop();

                  // Show success
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Payment settled successfully'),
                      backgroundColor: kSuccessGreen,
                      duration: Duration(seconds: 2),
                    ),
                  );
                } catch (e, stackTrace) {
                  debugPrint('🔴 [Settle] Error: $e');
                  debugPrint('🔴 [Settle] Stack: $stackTrace');

                  // Close loading
                  navigator.pop();

                  // Show error
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
              child: const Text('SETTLE'),
            ),
          ],
        ),
      ),
    );
  }

  /// Settle purchase credit - Update paid amount in backend
  Future<void> _settlePurchaseCredit(String docId, Map<String, dynamic> data, double amount, String paymentMode) async {
    try {
      debugPrint('🟢 [Settle] Step 1: Getting current paid amount...');
      final currentPaid = (data['paidAmount'] ?? 0.0) as num;
      final newPaidAmount = currentPaid + amount;
      debugPrint('🟢 [Settle] Current paid: $currentPaid, New paid: $newPaidAmount');

      // Update purchase credit note with new paid amount
      debugPrint('🟢 [Settle] Step 2: Updating purchase credit note...');
      await FirestoreService().updateDocument('purchaseCreditNotes', docId, {
        'paidAmount': newPaidAmount,
        'lastPaymentDate': FieldValue.serverTimestamp(),
        'lastPaymentMethod': paymentMode,
      });
      debugPrint('🟢 [Settle] Purchase credit note updated');

      // Add payment record
      debugPrint('🟢 [Settle] Step 3: Adding payment record...');
      await FirestoreService().addDocument('purchasePayments', {
        'creditNoteId': docId,
        'creditNoteNumber': data['creditNoteNumber'],
        'supplierName': data['supplierName'],
        'amount': amount,
        'paymentMode': paymentMode,
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String(),
        'note': 'Partial payment for ${data['creditNoteNumber']}',
      });
      debugPrint('🟢 [Settle] Payment record added successfully');
    } catch (e, stackTrace) {
      debugPrint('🔴 [Settle] Error settling purchase credit: $e');
      debugPrint('🔴 [Settle] Stack trace: $stackTrace');
      rethrow;
    }
  }
}

// ==========================================
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
                  _buildSummaryRow("Purchase Liability", "₹${total.toStringAsFixed(2)}"),
                  _buildSummaryRow("Settled Amount", "₹${paid.toStringAsFixed(2)}", color: kSuccessGreen),
                  const Divider(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("UNPAID DUE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: kMediumBlue)),
                      Text("₹${remaining.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: kErrorRed)),
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
      borderRadius: BorderRadius.circular(16),
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
        Text("₹${price.toStringAsFixed(0)} × ${qty.toInt()}", style: const TextStyle(fontSize: 12, color: kMediumBlue)),
      ])),
      Text("₹${total.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kDeepNavy)),
    ]),
  );
}

Widget _buildDetailTotalRow(num amount, int itemCount) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text("TOTAL RETURN ($itemCount)", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kMediumBlue)),
      Text("₹${amount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPrimaryBlue)),
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
// 1. CUSTOMERS MANAGEMENT PAGE
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: kWhite,
        title: Text(context.tr('addnewcustomer'),
            style: const TextStyle(fontWeight: FontWeight.w900, color: kDeepNavy, fontSize: 20)),
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
              child: const Text("CANCEL", style: TextStyle(color: kErrorRed, fontWeight: FontWeight.bold))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(
        title: Text(context.tr('customer_management'),
            style: const TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 18)),
        backgroundColor: kPrimaryBlue,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kWhite),
          onPressed: widget.onBack,
        ),
      ),
      body: Column(
        children: [
          // Search Header Area
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: const BoxDecoration(
              color: kWhite,
              border: Border(bottom: BorderSide(color: kSoftAzure, width: 2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kSoftAzure),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: kDeepNavy, fontWeight: FontWeight.w600, fontSize: 14),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, color: kPrimaryBlue, size: 22),
                        hintText: context.tr('search'),
                        hintStyle: const TextStyle(color: kMediumBlue, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _showAddCustomer,
                  child: Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      color: kPrimaryBlue,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: kPrimaryBlue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: const Icon(Icons.add, color: kWhite, size: 28),
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
                if (!streamSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryBlue));
                return StreamBuilder<QuerySnapshot>(
                  stream: streamSnapshot.data,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kPrimaryBlue));
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildManagerNoDataState(context.tr('no_customers_found'));

                    final docs = snapshot.data!.docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final name = (data['name'] ?? '').toString().toLowerCase();
                      final phone = (data['phone'] ?? '').toString().toLowerCase();
                      return name.contains(_searchQuery) || phone.contains(_searchQuery);
                    }).toList();

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
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
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kSoftAzure, width: 1.5),
        boxShadow: [
          BoxShadow(color: kPrimaryBlue.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            CupertinoPageRoute(builder: (context) => CustomerDetailsPage(customerId: docId, customerData: data)),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: kSoftAzure,
                    radius: 22,
                    child: Text((data['name'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(color: kPrimaryBlue, fontWeight: FontWeight.w900, fontSize: 18)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['name'] ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kDeepNavy)),
                        Text(data['phone'] ?? '--',
                            style: const TextStyle(color: kMediumBlue, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: kSoftAzure, size: 16),
                ],
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: kSoftAzure, thickness: 1.5)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildManagerStatItem("TOTAL SALES", "₹${(data['totalSales'] ?? 0).toStringAsFixed(0)}", kSuccessGreen),
                  _buildManagerStatItem("CREDIT DUE", "₹${(data['balance'] ?? 0).toStringAsFixed(0)}", kErrorRed, align: CrossAxisAlignment.end),
                ],
              ),
            ],
          ),
        ),
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
                    if (snapshot.data!.docs.isEmpty) return _buildManagerNoDataState("No staff members registered");

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
                            borderRadius: BorderRadius.circular(16),
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
                  borderRadius: BorderRadius.circular(16),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
          borderRadius: BorderRadius.circular(16),
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
        borderRadius: BorderRadius.circular(16),
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
        backgroundColor: const Color(0xFF2196F3),
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
                          color: Color(0xFF2196F3),
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
                                    color: const Color(0xFF2196F3),
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
                                    color: const Color(0xFF2196F3),
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
                        'Rs ${totalReturnAmount.toStringAsFixed(2)}',
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
                      Text('Rs ${(totalReturnAmount * 0).toStringAsFixed(1)}'),
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
                        'Rs ${totalReturnAmount.toStringAsFixed(1)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2196F3),
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
                    backgroundColor: const Color(0xFF2196F3),
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

// ==========================================
// EDIT BILL PAGE
// ==========================================
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
  // --- New Design Palette (Based on Reference Images) ---
  static const Color kPrimaryColor = Color(0xFF4F46E5); // Deep Indigo/Purple (Like 'Verify' button)
  static const Color kAccentColor = Color(0xFF4F46E5);
  static const Color kBackgroundColor = Color(0xFFF3F4F6); // Light Grey scaffold background
  static const Color kSurfaceColor = Colors.white;
  static const Color kTextPrimary = Color(0xFF1F2937); // Dark Grey
  static const Color kTextSecondary = Color(0xFF6B7280); // Cool Grey
  static const Color kBorderColor = Color(0xFFE5E7EB); // Very light border
  static const Color kSuccessColor = Color(0xFF10B981);
  static const double kCardRadius = 16.0;

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
  double get subtotal {
    return _items.fold(0.0, (sum, item) {
      final price = (item['price'] ?? 0).toDouble();
      final qty = (item['quantity'] ?? 0) is int
          ? (item['quantity'] as int).toDouble()
          : double.tryParse(item['quantity'].toString()) ?? 0.0;
      return sum + (price * qty);
    });
  }

  double get discount => double.tryParse(_discountController.text) ?? 0;
  double get totalBeforeCreditNotes => subtotal - discount;
  double get finalTotal => (totalBeforeCreditNotes - _creditNotesAmount).clamp(0, double.infinity);

  // --- UI Construction ---

  @override
  Widget build(BuildContext context) {
    final time = widget.invoiceData['timestamp'] != null
        ? (widget.invoiceData['timestamp'] as Timestamp).toDate()
        : null;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      // Clean AppBar design (White with dark text)
      appBar: AppBar(
        title: Text(
          context.tr('edit'),
          style: const TextStyle(fontWeight: FontWeight.w700, color: kTextPrimary, fontSize: 18),
        ),
        backgroundColor: kSurfaceColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: kTextPrimary, size: 20),
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
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Invoice Header Card (Like Profile Header)
                  _buildSectionHeader('INVOICE DETAILS'),
                  _buildInvoiceHeaderCard(time),
                  const SizedBox(height: 20),

                  // 2. Customer Card (Like Account Selection)
                  _buildSectionHeader('CUSTOMER'),
                  _buildCustomerSelectorCard(),
                  const SizedBox(height: 20),

                  // 3. Items List (Like Menu Items)
                  _buildSectionHeader('ITEMS'),
                  _buildItemsCard(),
                ],
              ),
            ),
          ),

          // 4. Bottom Total & Action Panel
          _buildBottomActionPanel(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: kTextSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // Mimics the "Profile" card from the reference image
  Widget _buildInvoiceHeaderCard(DateTime? time) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(kCardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon Container (Like the Avatar)
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.receipt_long_rounded, color: kPrimaryColor, size: 28),
            ),
          ),
          const SizedBox(width: 16),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invoice #${widget.invoiceData['invoiceNumber'] ?? 'N/A'}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextPrimary),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 12, color: kTextSecondary.withOpacity(0.8)),
                    const SizedBox(width: 4),
                    Text(
                      time != null ? DateFormat('dd MMM yyyy, h:mm a').format(time) : 'N/A',
                      style: const TextStyle(fontSize: 13, color: kTextSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Verified Badge style (Staff name)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: kBackgroundColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.badge, size: 14, color: kTextSecondary),
                const SizedBox(width: 4),
                Text(
                  '${widget.invoiceData['staffName'] ?? 'Staff'}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Mimics the "Select Account" card style
  Widget _buildCustomerSelectorCard() {
    final hasCustomer = _selectedCustomerPhone != null;
    return InkWell(
      onTap: hasCustomer ? null : () {}, // Logic to add customer if needed
      borderRadius: BorderRadius.circular(kCardRadius),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSurfaceColor,
          borderRadius: BorderRadius.circular(kCardRadius),
          border: Border.all(color: Colors.transparent), // Removing border for clean look
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: hasCustomer ? kPrimaryColor : kBackgroundColor,
              child: Icon(
                Icons.person,
                color: hasCustomer ? Colors.white : kTextSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedCustomerName ?? 'Walk-in Customer',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: kTextPrimary,
                    ),
                  ),
                  if (hasCustomer)
                    Text(
                      _selectedCustomerPhone!,
                      style: const TextStyle(color: kTextSecondary, fontSize: 13),
                    ),
                ],
              ),
            ),
            if (hasCustomer)
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedCustomerPhone = null;
                    _selectedCustomerName = null;
                    _selectedCreditNotes = [];
                    _creditNotesAmount = 0.0;
                  });
                },
                icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
                splashRadius: 20,
              )
            else
              const Icon(Icons.chevron_right, color: kTextSecondary),
          ],
        ),
      ),
    );
  }

  // Mimics the Menu List style (Clean rows)
  Widget _buildItemsCard() {
    return Container(
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(kCardRadius),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 48, color: kTextSecondary.withOpacity(0.3)),
                  const SizedBox(height: 12),
                  Text('No items added', style: TextStyle(color: kTextSecondary.withOpacity(0.5))),
                ],
              ),
            ),

          ..._items.asMap().entries.map((entry) {
            return _buildItemRow(entry.value, entry.key, entry.key == _items.length - 1);
          }),

          // "Create New Account" style button for Adding Items
          InkWell(
            onTap: _showAddProductDialog,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(kCardRadius)),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: kBackgroundColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_circle, size: 20, color: kPrimaryColor),
                  const SizedBox(width: 8),
                  const Text(
                    'Add New Item',
                    style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(Map<String, dynamic> item, int index, bool isLast) {
    final name = item['name'] ?? '';
    final price = (item['price'] ?? 0).toDouble();
    final qty = (item['quantity'] ?? 0) is int
        ? (item['quantity'] as int)
        : int.tryParse(item['quantity'].toString()) ?? 0;
    final itemTotal = price * qty;

    return Dismissible(
      key: Key('item_${item['productId']}_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red.withOpacity(0.1),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      onDismissed: (_) {
        setState(() {
          _items.removeAt(index);
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Number badge
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: kBackgroundColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text('${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextSecondary)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kTextPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    '₹${price.toStringAsFixed(2)} × $qty',
                    style: const TextStyle(color: kTextSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${itemTotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextPrimary),
                ),
              ],
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => setState(() => _items.removeAt(index)),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(Icons.close, color: kTextSecondary.withOpacity(0.5), size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Modern Bottom Panel
  Widget _buildBottomActionPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Calculation Rows
            _buildSummaryRow('Subtotal', '₹${subtotal.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _buildSummaryRow(
              'Discount',
              '- ₹${discount.toStringAsFixed(2)}',
              isLink: true,
              onTap: _showDiscountDialog,
              valueColor: kSuccessColor,
            ),
            if (_selectedCustomerPhone != null) ...[
              const SizedBox(height: 8),
              _buildSummaryRow(
                'Credit Notes',
                '- ₹${_creditNotesAmount.toStringAsFixed(2)}',
                isLink: true,
                onTap: _showCreditNotesDialog,
                valueColor: Colors.orange[800],
              ),
            ],

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(color: kBorderColor),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Payable', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextPrimary)),
                Text(
                  '₹${finalTotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: kPrimaryColor),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Payment Mode Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPaymentChip('Cash', Icons.payments_outlined),
                  const SizedBox(width: 10),
                  _buildPaymentChip('Online', Icons.qr_code_2),
                  const SizedBox(width: 10),
                  _buildPaymentChip('Credit', Icons.credit_score),
                  const SizedBox(width: 10),
                  _buildPaymentChip('Split', Icons.call_split),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Big "Verify" style button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _updateBill,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  elevation: 4,
                  shadowColor: kPrimaryColor.withOpacity(0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'Update Invoice',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isLink = false, VoidCallback? onTap, Color? valueColor}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(color: kTextSecondary, fontSize: 14)),
              if (isLink) ...[
                const SizedBox(width: 4),
                Icon(Icons.edit_note, size: 16, color: kPrimaryColor.withOpacity(0.7)),
              ],
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: valueColor ?? kTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentChip(String label, IconData icon) {
    final isSelected = _selectedPaymentMode == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMode = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? kPrimaryColor : kBorderColor,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : kTextSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : kTextPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Dialogs (Functionality Preserved, UI Updated) ---

  void _showDiscountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(context.tr('add_discount'), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _discountController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.tr('discount_amount'),
            prefixText: '₹ ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kPrimaryColor, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('cancel'), style: const TextStyle(color: kTextSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {});
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(context.tr('apply'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCreditNotesDialog() async {
    if (_selectedCustomerPhone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer first'), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      final creditNotesCollection = await FirestoreService().getStoreCollection('creditNotes');
      final snapshot = await creditNotesCollection
          .where('customerPhone', isEqualTo: _selectedCustomerPhone)
          .where('status', isEqualTo: 'Available')
          .get();

      final availableCreditNotes = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      if (!mounted) return;

      if (availableCreditNotes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No credit notes available'), behavior: SnackBarBehavior.floating),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (ctx) {
          List<Map<String, dynamic>> tempSelected = List.from(_selectedCreditNotes);

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text('Select Credit Notes', style: TextStyle(fontWeight: FontWeight.bold)),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: availableCreditNotes.length,
                    separatorBuilder: (c, i) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final cn = availableCreditNotes[index];
                      final isSelected = tempSelected.any((s) => s['id'] == cn['id']);
                      final amount = (cn['amount'] ?? 0).toDouble();

                      return CheckboxListTile(
                        value: isSelected,
                        activeColor: kPrimaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        title: Text('${cn['creditNoteNumber']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('₹${amount.toStringAsFixed(2)} • ${cn['reason'] ?? 'Credit Note'}'),
                        onChanged: (value) {
                          setDialogState(() {
                            if (value == true) {
                              tempSelected.add(cn);
                            } else {
                              tempSelected.removeWhere((s) => s['id'] == cn['id']);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(context.tr('cancel'), style: const TextStyle(color: kTextSecondary)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedCreditNotes = tempSelected;
                        _creditNotesAmount = _selectedCreditNotes.fold(0.0, (sum, cn) => sum + ((cn['amount'] ?? 0) as num).toDouble());
                      });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: Text('Apply (${tempSelected.length})', style: const TextStyle(color: Colors.white)),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading credit notes: $e'), backgroundColor: Colors.red),
        );
      }
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
        builder: (ctx) {
          final searchController = TextEditingController();
          String searchQuery = '';

          return StatefulBuilder(
            builder: (context, setSheetState) {
              final filteredProducts = products.where((p) {
                final name = (p['name'] ?? '').toString().toLowerCase();
                return name.contains(searchQuery.toLowerCase());
              }).toList();

              return Container(
                height: MediaQuery.of(context).size.height * 0.85,
                decoration: const BoxDecoration(
                  color: kSurfaceColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          const Text('Add Item', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Search products...',
                          prefixIcon: const Icon(Icons.search, color: kTextSecondary),
                          filled: true,
                          fillColor: kBackgroundColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onChanged: (value) {
                          setSheetState(() => searchQuery = value);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filteredProducts.length,
                        separatorBuilder: (c, i) => const Divider(height: 1, indent: 20, endIndent: 20),
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];
                          final stock = product['currentStock'] as double;
                          final stockEnabled = product['stockEnabled'] as bool;
                          final isOutOfStock = stockEnabled && stock <= 0;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            enabled: !isOutOfStock,
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isOutOfStock ? Colors.grey[100] : kPrimaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.inventory_2_outlined,
                                color: isOutOfStock ? Colors.grey : kPrimaryColor,
                                size: 22,
                              ),
                            ),
                            title: Text(
                              product['name'],
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isOutOfStock ? Colors.grey : kTextPrimary,
                              ),
                            ),
                            subtitle: Text(
                              '₹${(product['price'] as double).toStringAsFixed(2)}${stockEnabled ? ' • Stock: ${stock.toInt()}' : ''}',
                              style: TextStyle(color: isOutOfStock ? Colors.red : kTextSecondary),
                            ),
                            trailing: isOutOfStock
                                ? const Chip(label: Text('Out', style: TextStyle(fontSize: 10, color: Colors.white)), backgroundColor: Colors.red)
                                : CircleAvatar(
                              radius: 16,
                              backgroundColor: kPrimaryColor,
                              child: const Icon(Icons.add, color: Colors.white, size: 20),
                            ),
                            onTap: isOutOfStock ? null : () {
                              setState(() {
                                _items.add({
                                  'productId': product['id'],
                                  'name': product['name'],
                                  'price': product['price'],
                                  'quantity': 1,
                                });
                              });
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Item added'), duration: Duration(milliseconds: 1000)),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateBill() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item'), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
      );

      final oldPaymentMode = widget.invoiceData['paymentMode'];
      final oldTotal = (widget.invoiceData['total'] ?? 0).toDouble();
      final currentEditCount = (widget.invoiceData['editCount'] ?? 0) as int;

      // Update bill in Firestore
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

      // Handle Credit Notes Logic (Same as before)
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

      // Handle Customer Credit Logic (Same as before)
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('bill_updated_success')), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Go back
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.tr('error_updating_bill')}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ==========================================
