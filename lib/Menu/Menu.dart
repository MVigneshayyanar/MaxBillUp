import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/components/common_bottom_nav.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Sales/Bill.dart'; // Placeholder import if BillPage is in a different file
import 'package:maxbillup/Sales/QuotationsList.dart';
import 'package:maxbillup/Menu/CustomerManagement.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/Stocks/StockPurchase.dart';
import 'package:maxbillup/Stocks/ExpenseCategories.dart';
import 'package:maxbillup/Stocks/Expenses.dart';
import 'package:maxbillup/Settings/StaffManagement.dart';
import 'package:maxbillup/Reports/Reports.dart';
import 'package:maxbillup/Stocks/Stock.dart';
import 'package:maxbillup/Settings/Profile.dart'; // For SettingsPage
import 'package:maxbillup/utils/permission_helper.dart';
import 'package:maxbillup/utils/plan_permission_helper.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/printer_service.dart';
import 'package:maxbillup/Sales/NewSale.dart';


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

  // Stream Subscription
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  // Colors
  final Color _headerBlue = const Color(0xFF007AFF);
  final Color _iconColor = const Color(0xFF424242);
  final Color _textColor = const Color(0xFF212121);

  @override
  void initState() {
    super.initState();
    _email = widget.userEmail ?? "maestromindssdg@gmail.com";
    _startFastUserDataListener();
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
    super.dispose();
  }

  void _reset() => setState(() => _currentView = null);

  bool _hasPermission(String permission) {
    return _permissions[permission] == true;
  }

  @override
  Widget build(BuildContext context) {
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
        if (!_hasPermission('quotation') && !isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            PermissionHelper.showPermissionDeniedDialog(context);
            _reset();
          });
          return Container();
        }
        return QuotationsListPage(uid: widget.uid, userEmail: widget.userEmail, onBack: _reset);

      case 'BillHistory':
        if (!_hasPermission('billHistory') && !isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            PermissionHelper.showPermissionDeniedDialog(context);
            _reset();
          });
          return Container();
        }
        return SalesHistoryPage(uid: widget.uid, userEmail: widget.userEmail!, onBack: _reset);

      case 'CreditNotes':
        if (!_hasPermission('creditNotes') && !isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            PermissionHelper.showPermissionDeniedDialog(context);
            _reset();
          });
          return Container();
        }
        return CreditNotesPage(uid: widget.uid, onBack: _reset);

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
        if (!_hasPermission('creditDetails') && !isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            PermissionHelper.showPermissionDeniedDialog(context);
            _reset();
          });
          return Container();
        }
        return CreditDetailsPage(uid: widget.uid, onBack: _reset);

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
        // Check plan access first
        return FutureBuilder<bool>(
          future: PlanPermissionHelper.canAccessStaffManagement(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.data!) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                PlanPermissionHelper.showUpgradeDialog(context, 'Staff Management');
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

      // ==========================================
      // REPORTS SECTION
      // ==========================================

      case 'Analytics':
        return FutureBuilder<bool>(
          future: PlanPermissionHelper.canAccessReports(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            if (!snapshot.data!) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                PlanPermissionHelper.showUpgradeDialog(context, 'Reports');
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
        return FutureBuilder<bool>(
          future: PlanPermissionHelper.canAccessReports(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            if (!snapshot.data!) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                PlanPermissionHelper.showUpgradeDialog(context, 'Reports');
                _reset();
              });
              return Container();
            }
            if (!_hasPermission('daybook') && !isAdmin) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                PermissionHelper.showPermissionDeniedDialog(context);
                _reset();
              });
              return Container();
            }
            return DayBookPage(uid: widget.uid, onBack: _reset);
          },
        );

      case 'Summary':
        return FutureBuilder<bool>(
          future: PlanPermissionHelper.canAccessReports(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            if (!snapshot.data!) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                PlanPermissionHelper.showUpgradeDialog(context, 'Reports');
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
          future: PlanPermissionHelper.canAccessReports(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            if (!snapshot.data!) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                PlanPermissionHelper.showUpgradeDialog(context, 'Reports');
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
          future: PlanPermissionHelper.canAccessReports(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            if (!snapshot.data!) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                PlanPermissionHelper.showUpgradeDialog(context, 'Reports');
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
          future: PlanPermissionHelper.canAccessReports(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            if (!snapshot.data!) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                PlanPermissionHelper.showUpgradeDialog(context, 'Reports');
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
          future: PlanPermissionHelper.canAccessReports(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            if (!snapshot.data!) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                PlanPermissionHelper.showUpgradeDialog(context, 'Reports');
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
          future: PlanPermissionHelper.canAccessReports(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            if (!snapshot.data!) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                PlanPermissionHelper.showUpgradeDialog(context, 'Reports');
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
          future: PlanPermissionHelper.canAccessReports(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            if (!snapshot.data!) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                PlanPermissionHelper.showUpgradeDialog(context, 'Reports');
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
          future: PlanPermissionHelper.canAccessReports(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            if (!snapshot.data!) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                PlanPermissionHelper.showUpgradeDialog(context, 'Reports');
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
          future: PlanPermissionHelper.canAccessReports(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            if (!snapshot.data!) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                PlanPermissionHelper.showUpgradeDialog(context, 'Reports');
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
          future: PlanPermissionHelper.canAccessReports(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            if (!snapshot.data!) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                PlanPermissionHelper.showUpgradeDialog(context, 'Reports');
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
          future: PlanPermissionHelper.canAccessReports(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            if (!snapshot.data!) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                PlanPermissionHelper.showUpgradeDialog(context, 'Reports');
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
          future: PlanPermissionHelper.canAccessReports(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            if (!snapshot.data!) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                PlanPermissionHelper.showUpgradeDialog(context, 'Reports');
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
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20, bottom: 25, left: 20, right: 20),
            color: _headerBlue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(_businessName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NewSalePage(uid: widget.uid, userEmail: widget.userEmail),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_shopping_cart, size: 18, color: Colors.white),
                      label: const Text('New Sale', style: TextStyle(color: Colors.white, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white24,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(_email, style: const TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),

          // MENU LIST
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                // Quotation
                if (_hasPermission('quotation') || isAdmin)
                  _buildMenuItem(Icons.assignment_outlined, "Quotation", 'Quotation'),

                // Bill History
                if (_hasPermission('billHistory') || isAdmin)
                  _buildMenuItem(Icons.receipt_long_outlined, "Bill History", 'BillHistory'),

                // Credit Notes
                if (_hasPermission('creditNotes') || isAdmin)
                  _buildMenuItem(Icons.description_outlined, "Credit Notes", 'CreditNotes'),

                // Customer Management
                if (_hasPermission('customerManagement') || isAdmin)
                  _buildMenuItem(Icons.group_outlined, "Customer Management", 'Customers'),

                // Expenses Expansion
                if (_hasPermission('expenses') || isAdmin)
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      leading: Icon(Icons.account_balance_wallet_outlined, color: _iconColor),
                      title: Text("Expenses", style: TextStyle(fontSize: 16, color: _textColor, fontWeight: FontWeight.w500)),
                      iconColor: _iconColor,
                      collapsedIconColor: _iconColor,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 24),
                      childrenPadding: const EdgeInsets.only(left: 72),
                      children: [
                        _buildSubMenuItem("Stock Purchase", 'StockPurchase'),
                        _buildSubMenuItem("Expenses", 'Expenses'),
                        _buildSubMenuItem("Expense Category", 'ExpenseCategories'),
                      ],
                    ),
                  ),

                // Credit Details
                if (_hasPermission('creditDetails') || isAdmin)
                  _buildMenuItem(Icons.request_quote_outlined, "Credit Details", 'CreditDetails'),

                // Staff Management
                if (isAdmin || _hasPermission('staffManagement'))
                  _buildMenuItem(Icons.badge_outlined, "Staff Management", 'StaffManagement'),

                // Stock (moved from bottom nav - placed above Reports)
                _buildMenuItem(Icons.inventory_2_outlined, "Stock", 'Stock'),

                // Reports Expansion (moved from bottom nav)
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    leading: Icon(Icons.bar_chart_outlined, color: _iconColor),
                    title: Text("Reports", style: TextStyle(fontSize: 16, color: _textColor, fontWeight: FontWeight.w500)),
                    iconColor: _iconColor,
                    collapsedIconColor: _iconColor,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 24),
                    childrenPadding: const EdgeInsets.only(left: 72),
                    children: [
                      // Analytics & Overview
                      if (_hasPermission('analytics') || isAdmin)
                        _buildSubMenuItem("Analytics", 'Analytics'),
                      if (_hasPermission('daybook') || isAdmin)
                        _buildSubMenuItem("DayBook", 'DayBook'),
                      if (_hasPermission('salesSummary') || isAdmin)
                        _buildSubMenuItem("Sales Summary", 'Summary'),

                      // Sales & Transactions
                      if (_hasPermission('salesReport') || isAdmin)
                        _buildSubMenuItem("Sales Report", 'SalesReport'),
                      if (_hasPermission('itemSalesReport') || isAdmin)
                        _buildSubMenuItem("Item Sales Report", 'ItemSales'),
                      if (_hasPermission('topCustomer') || isAdmin)
                        _buildSubMenuItem("Top Customers", 'TopCustomers'),

                      // Inventory & Products
                      if (_hasPermission('stockReport') || isAdmin)
                        _buildSubMenuItem("Stock Report", 'StockReport'),
                      if (_hasPermission('lowStockProduct') || isAdmin)
                        _buildSubMenuItem("Low Stock Products", 'LowStock'),
                      if (_hasPermission('topProducts') || isAdmin)
                        _buildSubMenuItem("Top Products", 'TopProducts'),
                      if (_hasPermission('topCategory') || isAdmin)
                        _buildSubMenuItem("Top Categories", 'TopCategories'),

                      // Financials & Tax
                      if (_hasPermission('expensesReport') || isAdmin)
                        _buildSubMenuItem("Expense Report", 'ExpenseReport'),
                      if (_hasPermission('taxReport') || isAdmin)
                        _buildSubMenuItem("Tax Report", 'TaxReport'),
                      if (_hasPermission('hsnReport') || isAdmin)
                        _buildSubMenuItem("HSN Report", 'HSNReport'),
                      if (_hasPermission('staffSalesReport') || isAdmin)
                        _buildSubMenuItem("Staff Sale Report", 'StaffReport'),
                    ],
                  ),
                ),

                // Settings (moved from bottom nav - placed below Reports)
                _buildMenuItem(Icons.settings_outlined, "Settings", 'Settings'),
              ],
            ),
          ),
        ],
      ),
      // bottomNavigationBar: CommonBottomNav(
      //   uid: widget.uid,
      //   userEmail: widget.userEmail,
      //   currentIndex: 0,
      //   screenWidth: MediaQuery.of(context).size.width,
      // ),
    );
  }

  Widget _buildMenuItem(IconData icon, String text, String viewKey) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: _iconColor),
        title: Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: _textColor)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        onTap: () {
          // Navigate to the page in full screen
          _navigateToPage(viewKey);
        },
      ),
    );
  }

  Widget _buildSubMenuItem(String text, String viewKey) {
    return ListTile(
      title: Text(text, style: TextStyle(fontSize: 15, color: Color.fromRGBO((_textColor.r * 255.0).round() & 0xff, (_textColor.g * 255.0).round() & 0xff, (_textColor.b * 255.0).round() & 0xff, 0.8))),
      onTap: () {
        // Navigate to the page in full screen
        _navigateToPage(viewKey);
      },
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      contentPadding: EdgeInsets.zero,
    );
  }

  void _navigateToPage(String viewKey) {
    Widget? page = _getPageForView(viewKey);
    if (page != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => page),
      );
    }
  }

  Widget? _getPageForView(String viewKey) {
    bool isAdmin = _role.toLowerCase() == 'admin' || _role.toLowerCase() == 'administrator';

    switch (viewKey) {
      case 'NewSale':
        return NewSalePage(uid: widget.uid, userEmail: widget.userEmail);

      case 'Quotation':
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
        return SalesHistoryPage(uid: widget.uid, userEmail: widget.userEmail!, onBack: () => Navigator.pop(context));

      case 'CreditNotes':
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
      PlanPermissionHelper.showUpgradeDialog(context, 'Staff Management');
      return;
    }

    if (!_hasPermission('staffManagement') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
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
      PlanPermissionHelper.showUpgradeDialog(context, 'Reports');
      return;
    }

    if (!_hasPermission('analytics') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnalyticsPage(
          uid: widget.uid,
          onBack: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _navigateToDayBook() async {
    bool isAdmin = _role.toLowerCase() == 'admin' || _role.toLowerCase() == 'administrator';

    bool canAccess = await PlanPermissionHelper.canAccessReports();
    if (!canAccess) {
      PlanPermissionHelper.showUpgradeDialog(context, 'Reports');
      return;
    }

    if (!_hasPermission('daybook') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
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
      PlanPermissionHelper.showUpgradeDialog(context, 'Reports');
      return;
    }

    if (!_hasPermission('salesSummary') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
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
      PlanPermissionHelper.showUpgradeDialog(context, 'Reports');
      return;
    }

    if (!_hasPermission('salesReport') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
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
      PlanPermissionHelper.showUpgradeDialog(context, 'Reports');
      return;
    }

    if (!_hasPermission('itemSalesReport') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
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
      PlanPermissionHelper.showUpgradeDialog(context, 'Reports');
      return;
    }

    if (!_hasPermission('topCustomers') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
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
      PlanPermissionHelper.showUpgradeDialog(context, 'Reports');
      return;
    }

    if (!_hasPermission('stockReport') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
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
      PlanPermissionHelper.showUpgradeDialog(context, 'Reports');
      return;
    }

    if (!_hasPermission('lowStockProduct') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
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
      PlanPermissionHelper.showUpgradeDialog(context, 'Reports');
      return;
    }

    if (!_hasPermission('topProducts') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
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
      PlanPermissionHelper.showUpgradeDialog(context, 'Reports');
      return;
    }

    if (!_hasPermission('topCategory') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
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
      PlanPermissionHelper.showUpgradeDialog(context, 'Reports');
      return;
    }

    if (!_hasPermission('expensesReport') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
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
      PlanPermissionHelper.showUpgradeDialog(context, 'Reports');
      return;
    }

    if (!_hasPermission('taxReport') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
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
      PlanPermissionHelper.showUpgradeDialog(context, 'Reports');
      return;
    }

    if (!_hasPermission('hsnReport') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
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
      PlanPermissionHelper.showUpgradeDialog(context, 'Reports');
      return;
    }

    if (!_hasPermission('staffSalesReport') && !isAdmin) {
      PermissionHelper.showPermissionDeniedDialog(context);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
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
      MaterialPageRoute(
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
        backgroundColor: const Color(0xFF007AFF),
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
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text('No $title found'));

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final subtitle = data.containsKey('total') ? 'Total: ₹${data['total']}' : (data.containsKey('phone') ? data['phone'] : '');
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
  final String userEmail;

  const SalesHistoryPage({super.key, required this.uid, required this.onBack, required this.userEmail});

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  Stream<List<QueryDocumentSnapshot>>? _combinedStream;
  StreamController<List<QueryDocumentSnapshot>>? _controller;
  StreamSubscription? _salesSub;
  StreamSubscription? _savedOrdersSub;

  @override
  void initState() {
    super.initState();
    _initializeCombinedStream();
  }

  @override
  void dispose() {
    _salesSub?.cancel();
    _savedOrdersSub?.cancel();
    _controller?.close();
    super.dispose();
  }

  Future<void> _initializeCombinedStream() async {
    try {
      final salesStream = await FirestoreService().getCollectionStream('sales');
      final savedOrdersStream = await FirestoreService().getCollectionStream('savedOrders');

      List<QueryDocumentSnapshot> salesDocs = [];
      List<QueryDocumentSnapshot> savedOrdersDocs = [];

      void updateController() {
        final allDocs = [...salesDocs, ...savedOrdersDocs];
        allDocs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>? ?? {};
          final dataB = b.data() as Map<String, dynamic>? ?? {};
          final tsA = dataA['timestamp'] as Timestamp?;
          final tsB = dataB['timestamp'] as Timestamp?;
          if (tsA == null && tsB == null) return 0;
          if (tsA == null) return 1;
          if (tsB == null) return -1;
          return tsB.compareTo(tsA); // descending
        });
        if (_controller != null && !_controller!.isClosed) {
          _controller!.add(allDocs);
        }
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
      debugPrint('Error initializing bill history stream: $e');
      if (mounted) {
        setState(() {
          _combinedStream = Stream.value([]);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill History', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF007AFF),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: widget.onBack),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: () {
              // TODO: Implement filter logic
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Search Bar & Filter Dropdown Area (Matches the top layout)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search',
                      prefixIcon: Icon(Icons.search),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: 'All Time',
                  items: <String>['All Time', 'This Month', 'Last Month'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (_) {},
                ),
                IconButton(
                  icon: const Icon(Icons.tune),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          Expanded(
            child: _combinedStream == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<List<QueryDocumentSnapshot>>(
                    stream: _combinedStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No bills found'));

                      // 2. Group bills by date
                final groupedData = _groupBillsByDate(snapshot.data!);
                final sortedDates = groupedData.keys.toList()..sort((a, b) => b.compareTo(a));

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: sortedDates.length,
                  itemBuilder: (context, index) {
                    final date = sortedDates[index];
                    final bills = groupedData[date]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date Header (e.g., "18 Nov, 2025 (1)")
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                          child: Text(
                            '$date (${bills.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),

                        // List of Bills for this date
                        ...bills.map((doc) => _buildBillCard(context, doc)).toList(),
                      ],
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

  // Utility function to group documents by date
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

  // Widget to build a single bill card
  Widget _buildBillCard(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final inv = data['invoiceNumber'] ?? 'N/A';
    final total = (data['total'] ?? 0.0).toStringAsFixed(1);
    final itemsCount = (data['items'] as List<dynamic>? ?? []).length;
    final staffName = data['staffName'] ?? 'Vishal'; // Assuming 'Created by Vishal' is static or needs staffName
    final time = data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate() : null;
    final timeString = time != null ? DateFormat('dd-MM-yyyy & h:mm a').format(time) : '-';

    // Status Logic: Check for a payment mode or 'change' to determine settlement
    // 'sales' collection docs will have paymentMode, 'savedOrders' will not.
    final isSettled = data['paymentMode'] != null;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Invoice No, Status Tag, Items Count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Invoice : $inv', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSettled ? Colors.green.shade100 : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isSettled ? 'Settled' : 'UnSettled',
                    style: TextStyle(
                      color: isSettled ? Colors.green.shade800 : Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                Text('Items : $itemsCount', style: const TextStyle(fontSize: 14)),
              ],
            ),

            const SizedBox(height: 8),

            // Row 2: Date & Time, Total
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Date & Time : ', style: TextStyle(fontSize: 13, color: Colors.black87)),
                Text(timeString, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.black)),
                const Spacer(),
                const Text('Total : ', style: TextStyle(fontSize: 15, color: Colors.black87)),
                Text(total, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF007AFF))),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Total : ', style: TextStyle(fontSize: 15, color: Colors.black87)),
                Text(total, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF007AFF))),
              ],
            ),

            const SizedBox(height: 8),

            const Divider(height: 1, color: Colors.grey),

            const SizedBox(height: 8),

            // Row 3: Customer/Creator, Action Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('Customer : ', style: TextStyle(fontSize: 13, color: Colors.black87)),
                    Text('Created by $staffName', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  ],
                ),

                // Action Button (Settle Bill or Receipt)
                SizedBox(
                  height: 35,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (!isSettled) {
                        // If this is an unsettled (saved) order, extract cart items and total
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
                        final double totalAmount = (data['total'] ?? 0).toDouble();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BillPage(
                              uid: widget.uid,
                              cartItems: cartItems,
                              totalAmount: totalAmount,
                              userEmail: widget.userEmail,
                              savedOrderId: doc.id, // Pass the saved order ID for reference
                            ),
                          ),
                        ).then((_) {
                          setState(() {}); // Refresh after returning from BillPage
                        });
                      } else {
                        // If settled, show receipt
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SalesDetailPage(documentId: doc.id, initialData: data),
                          ),
                        );
                      }
                    },
                    icon: Icon(isSettled ? Icons.receipt : Icons.person_add, size: 16, color: Colors.white),
                    label: Text(
                      isSettled ? 'Receipt' : 'Settle Bill',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSettled ? const Color(0xFF007AFF) : const Color(0xFF007AFF),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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

// ==========================================
// 3. SALES DETAIL PAGE
// ==========================================
class SalesDetailPage extends StatelessWidget {
  final String documentId;
  final Map<String, dynamic> initialData;

  const SalesDetailPage({super.key, required this.documentId, required this.initialData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Invoice ${initialData['invoiceNumber'] ?? 'Details'}', style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF007AFF),
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
                return const Center(child: Text('Bill not found or deleted.'));
              }

              final data = snapshot.data!.data() as Map<String, dynamic>;
              final time = data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate() : null;
          final items = (data['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

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
                                'Invoice No. ${data['invoiceNumber'] ?? 'N/A'}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF007AFF),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Created by ${data['staffName'] ?? 'Admin'}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Issued on :',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                time != null ? DateFormat('dd MMM yyyy h:mm a').format(time) : 'N/A',
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
                const Text(
                  'Customer Details',
                  style: TextStyle(
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
                      const Text(
                        'Phone Number',
                        style: TextStyle(
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
                const Text(
                  'Invoice items',
                  style: TextStyle(
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
                            Text(
                              'Amount',
                              style: TextStyle(
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total items : ${items.length}'),
                                Text('Sub Total : ${(data['subtotal'] ?? 0.0).toStringAsFixed(2)}'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total Qty : ${items.fold(0, (sum, item) => sum + (item['quantity'] as int? ?? 0))}'),
                                const Text(''),
                              ],
                            ),
                            if (data['paymentMode'] == 'Credit') ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Credit : ${(data['total'] ?? 0.0).toStringAsFixed(2)}'),
                                  const Text(''),
                                ],
                              ),
                            ],
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Amount :',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Rs ${(data['total'] ?? 0.0).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF007AFF),
                                  ),
                                ),
                              ],
                            ),
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
                      label: 'Sale Return',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
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
                      label: 'Cancel Bill',
                      color: Colors.red,
                      onTap: () {
                        _showCancelBillDialog(context, documentId, data);
                      },
                    ),
                    _buildActionButton(
                      context,
                      icon: Icons.receipt_long_outlined,
                      label: 'Receipt',
                      onTap: () => _printInvoiceReceipt(context, documentId, data),
                    ),
                    _buildActionButton(
                      context,
                      icon: Icons.edit_outlined,
                      label: 'Edit',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditBillPage(
                              documentId: documentId,
                              invoiceData: data,
                            ),
                          ),
                        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preparing print...')),
      );

      // Get store details
      final storeId = await FirestoreService().getCurrentStoreId();
      String? businessName;
      String? businessPhone;
      String? businessAddress;
      String? gstin;

      if (storeId != null) {
        final storeDoc = await FirebaseFirestore.instance
            .collection('stores')
            .doc(storeId)
            .get();
        if (storeDoc.exists) {
          final storeData = storeDoc.data() as Map<String, dynamic>;
          businessName = storeData['businessName'];
          businessPhone = storeData['businessPhone'] ?? storeData['ownerPhone'];
          businessAddress = storeData['address'];
          gstin = storeData['gstin'];
        }
      }

      // Prepare invoice data
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((item) => {
                'name': item['name'] ?? '',
                'quantity': item['quantity'] ?? 0,
                'price': (item['price'] ?? 0).toDouble(),
              })
          .toList();

      // Call printer service
      // TODO: Implement printInvoice in PrinterService
      // await PrinterService.printInvoice(
      //   invoiceNumber: data['invoiceNumber'] ?? 'N/A',
      //   customerName: data['customerName'] ?? 'Walk-in Customer',
      //   customerPhone: data['customerPhone'] ?? '',
      //   items: items,
      //   subtotal: (data['subtotal'] ?? 0).toDouble(),
      //   discount: (data['discount'] ?? 0).toDouble(),
      //   tax: (data['tax'] ?? 0).toDouble(),
      //   total: (data['total'] ?? 0).toDouble(),
      //   paymentMode: data['paymentMode'] ?? 'Cash',
      //   businessName: businessName,
      //   businessPhone: businessPhone,
      //   businessAddress: businessAddress,
      //   gstin: gstin,
      //   timestamp: data['timestamp'] != null
      //       ? (data['timestamp'] as Timestamp).toDate()
      //       : null,
      // );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print failed: $e'),
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
            Icon(icon, size: 32, color: color ?? const Color(0xFF007AFF)),
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
                style: const TextStyle(fontSize: 14, color: Color(0xFF007AFF)),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
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
                  // Generate credit note number
                  final creditNoteNumber = 'CN${DateTime.now().millisecondsSinceEpoch}';

                  // Create credit note document
                  await FirestoreService().addDocument('creditNotes', {
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
                      content: Text('Error cancelling bill: $e'),
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
            child: const Text('Cancel Bill', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(Map<String, dynamic> item) {
    final name = item['name'] ?? 'Item';
    final price = item['price'] ?? 0;
    final quantity = item['quantity'] ?? 1;
    final total = (price * quantity) as double? ?? 0.0;

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
                '-0.00',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${price.toStringAsFixed(2)} × ${quantity.toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                '0.00',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                total.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                total.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF007AFF),
                ),
              ),
            ],
          ),
        ],
      ),
    ); // Close Container
  } // Close _buildItemRow method
} // Close BillHistoryPage class

// ==========================================
// 4. CUSTOMER RELATED PAGES
// ==========================================

// ==========================================
// CREDIT NOTES PAGE
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
  String _filterStatus = 'All'; // All, Available, Used

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
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Credit Notes', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF007AFF),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search Bar and Filter
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButton<String>(
                    value: _filterStatus,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All')),
                      DropdownMenuItem(value: 'Available', child: Text('Available')),
                      DropdownMenuItem(value: 'Used', child: Text('Used')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filterStatus = value ?? 'All';
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // Credit Notes List
          Expanded(
            child: FutureBuilder<CollectionReference>(
              future: FirestoreService().getStoreCollection('creditNotes'),
              builder: (context, collectionSnapshot) {
                if (!collectionSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return StreamBuilder<QuerySnapshot>(
                  stream: collectionSnapshot.data!
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No credit notes found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                var creditNotes = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  // Filter by status
                  if (_filterStatus != 'All') {
                    final status = data['status'] ?? 'Available';
                    if (status != _filterStatus) return false;
                  }

                  // Filter by search query
                  if (_searchQuery.isNotEmpty) {
                    final creditNoteNumber = (data['creditNoteNumber'] ?? '').toString().toLowerCase();
                    final invoiceNumber = (data['invoiceNumber'] ?? '').toString().toLowerCase();
                    final customerName = (data['customerName'] ?? '').toString().toLowerCase();
                    final customerPhone = (data['customerPhone'] ?? '').toString().toLowerCase();

                    return creditNoteNumber.contains(_searchQuery) ||
                        invoiceNumber.contains(_searchQuery) ||
                        customerName.contains(_searchQuery) ||
                        customerPhone.contains(_searchQuery);
                  }

                  return true;
                }).toList();

                if (creditNotes.isEmpty) {
                  return const Center(
                    child: Text(
                      'No matching credit notes',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: creditNotes.length,
                  itemBuilder: (context, index) {
                    final doc = creditNotes[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final creditNoteNumber = data['creditNoteNumber'] ?? 'N/A';
                    final invoiceNumber = data['invoiceNumber'] ?? 'N/A';
                    final amount = (data['amount'] ?? 0.0) as num;
                    final status = data['status'] ?? 'Available';
                    final timestamp = data['timestamp'] as Timestamp?;
                    final dateString = timestamp != null
                        ? DateFormat('dd-MM-yyyy').format(timestamp.toDate())
                        : 'N/A';

                    return GestureDetector(
                      onTap: () {
                        // Navigate to credit note details
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CreditNoteDetailPage(
                              documentId: doc.id,
                              creditNoteData: data,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: status == 'Available'
                                ? Colors.green.shade200
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
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
                                        'Credit Notes : $creditNoteNumber',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF007AFF),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Invoice : $invoiceNumber',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF007AFF),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: status == 'Available'
                                          ? Colors.green.shade100
                                          : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: status == 'Available'
                                            ? Colors.green.shade800
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Date : $dateString',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    'Amount : ${amount.toStringAsFixed(1)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF007AFF),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
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
// CREDIT NOTE DETAIL PAGE
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
    final creditNoteNumber = creditNoteData['creditNoteNumber'] ?? 'N/A';
    final invoiceNumber = creditNoteData['invoiceNumber'] ?? 'N/A';
    final customerName = creditNoteData['customerName'] ?? 'Unknown';
    final amount = (creditNoteData['amount'] ?? 0.0) as num;
    final status = creditNoteData['status'] ?? 'Available';
    final timestamp = creditNoteData['timestamp'] as Timestamp?;
    final items = (creditNoteData['items'] as List<dynamic>? ?? []);
    final dateString = timestamp != null
        ? DateFormat('dd MMM yyyy h:mm a').format(timestamp.toDate())
        : 'N/A';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Credit Note', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF007AFF),
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
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Credit Note No : $creditNoteNumber',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Created by Admin',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Issued on:',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        dateString,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Invoice Info & Customer Details
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Invoice No : $invoiceNumber',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: status == 'Available'
                              ? Colors.green.shade100
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: status == 'Available'
                                ? Colors.green.shade800
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  const Text(
                    'Customer Details',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    customerName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF007AFF),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    creditNoteData['customerPhone'] ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            // Items
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
                          ),
                        ),
                        Text(
                          'Amount',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...items.map((item) {
                    final name = item['name'] ?? 'Unknown';
                    final qty = item['quantity'] ?? 0;
                    final price = (item['price'] ?? 0).toDouble();
                    final total = (item['total'] ?? 0).toDouble();

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
                                  ),
                                ),
                              ),
                              const Text(
                                '- 0.00',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${price.toStringAsFixed(2)} x ${qty.toStringAsFixed(1)}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              const Text(
                                '0.00',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                total.toStringAsFixed(2),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                total.toStringAsFixed(2),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF007AFF),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Items : ${items.length}'),
                        const Text(''),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount :',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Rs ${amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: status == 'Available'
                          ? () {
                              _showRefundDialog(context);
                            }
                          : null,
                      icon: const Icon(Icons.attach_money, color: Colors.white),
                      label: const Text(
                        'Refund',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _printCreditNote(context),
                      icon: const Icon(Icons.receipt_long, color: Colors.white),
                      label: const Text(
                        'Receipt',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printCreditNote(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preparing print...')),
      );

      // Get store details
      final storeId = await FirestoreService().getCurrentStoreId();
      String? businessName;
      String? businessPhone;

      if (storeId != null) {
        final storeDoc = await FirebaseFirestore.instance
            .collection('stores')
            .doc(storeId)
            .get();
        if (storeDoc.exists) {
          final storeData = storeDoc.data() as Map<String, dynamic>;
          businessName = storeData['businessName'];
          businessPhone = storeData['businessPhone'] ?? storeData['ownerPhone'];
        }
      }

      // Extract data from creditNoteData
      final cnNumber = creditNoteData['creditNoteNumber'] ?? 'N/A';
      final invNumber = creditNoteData['invoiceNumber'] ?? 'N/A';
      final custName = creditNoteData['customerName'] ?? 'Unknown';
      final custPhone = creditNoteData['customerPhone'] ?? '';
      final cnAmount = (creditNoteData['amount'] ?? 0.0) as num;
      final cnItems = (creditNoteData['items'] as List<dynamic>? ?? []);
      final cnTimestamp = creditNoteData['timestamp'] as Timestamp?;

      // Call printer service
      // TODO: Implement printCreditNote in PrinterService
      // await PrinterService.printCreditNote(
      //   creditNoteNumber: cnNumber,
      //   invoiceNumber: invNumber,
      //   customerName: custName,
      //   customerPhone: custPhone,
      //   items: cnItems.map((item) => {
      //     'name': item['name'] ?? '',
      //     'quantity': item['quantity'] ?? 0,
      //     'price': (item['price'] ?? 0).toDouble(),
      //     'total': (item['total'] ?? 0).toDouble(),
      //   }).toList(),
      //   amount: cnAmount.toDouble(),
      //   businessName: businessName,
      //   businessPhone: businessPhone,
      //   timestamp: cnTimestamp?.toDate(),
      // );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showRefundDialog(BuildContext context) {
    String selectedMode = 'Cash';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Are you sure?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Refund CreditNote ${creditNoteData['creditNoteNumber']}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text(
                'Mode:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => selectedMode = 'Cash'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: selectedMode == 'Cash'
                                ? const Color(0xFF007AFF)
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Radio<String>(
                              value: 'Cash',
                              groupValue: selectedMode,
                              onChanged: (value) => setState(() => selectedMode = value!),
                            ),
                            const Text('Cash'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => selectedMode = 'Online'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: selectedMode == 'Online'
                                ? const Color(0xFF007AFF)
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Radio<String>(
                              value: 'Online',
                              groupValue: selectedMode,
                              onChanged: (value) => setState(() => selectedMode = value!),
                            ),
                            const Text('Online'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  Navigator.pop(ctx);
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(child: CircularProgressIndicator()),
                  );

                  // Update credit note status to Used
                  await FirestoreService().updateDocument('creditNotes', documentId, {
                    'status': 'Used',
                    'refundMode': selectedMode,
                    'refundedAt': FieldValue.serverTimestamp(),
                  });

                  // NOTE: We do NOT touch customer balance
                  // Credit notes are separate from balance
                  // This refund represents giving cash/online payment back to customer

                  if (context.mounted) {
                    Navigator.pop(context); // Close loading
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Credit note refunded via $selectedMode successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    Navigator.pop(context); // Go back
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
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
              child: const Text('Refund', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// CREDIT DETAILS PAGE
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
  String _selectedTab = 'Sales'; // Sales or Purchase

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
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Credit Details', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF007AFF),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Tab Selector
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 'Sales'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTab == 'Sales'
                            ? const Color(0xFF007AFF)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Sales',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _selectedTab == 'Sales' ? Colors.white : Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 'Purchase'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTab == 'Purchase'
                            ? const Color(0xFF007AFF)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Purchase',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _selectedTab == 'Purchase' ? Colors.white : Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Content based on selected tab
          Expanded(
            child: _selectedTab == 'Sales' ? _buildSalesCreditList() : _buildPurchaseCreditList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesCreditList() {
    return FutureBuilder<CollectionReference>(
      future: FirestoreService().getStoreCollection('customers'),
      builder: (context, collectionSnapshot) {
        if (!collectionSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return StreamBuilder<QuerySnapshot>(
          stream: collectionSnapshot.data!
              .where('balance', isGreaterThan: 0)
              .snapshots(),
          builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No sales credits found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        final customers = snapshot.data!.docs.where((doc) {
          if (_searchQuery.isEmpty) return true;
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] ?? '').toString().toLowerCase();
          final phone = (data['phone'] ?? '').toString().toLowerCase();
          return name.contains(_searchQuery) || phone.contains(_searchQuery);
        }).toList();

        if (customers.isEmpty) {
          return const Center(
            child: Text(
              'No matching customers found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        // Calculate total
        double totalCredit = 0;
        for (var doc in customers) {
          final data = doc.data() as Map<String, dynamic>;
          totalCredit += (data['balance'] ?? 0.0) as num;
        }

        return Column(
          children: [
            // Total Credit Header
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Total Sales Credit : ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'Rs ${totalCredit.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF007AFF),
                    ),
                  ),
                ],
              ),
            ),

            // Customer List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: customers.length,
                itemBuilder: (context, index) {
                  final data = customers[index].data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'Unknown';
                  final phone = data['phone'] ?? '';
                  final balance = (data['balance'] ?? 0.0) as num;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          const Text(
                            'Phone Number',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            phone,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      trailing: Text(
                        balance.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                      onTap: () {
                        // Navigate to customer details
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CustomerDetailsPage(
                              customerId: customers[index].id,
                              customerData: data,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
      },
    );
  }

  Widget _buildPurchaseCreditList() {
    return FutureBuilder<CollectionReference>(
      future: FirestoreService().getStoreCollection('purchaseCreditNotes'),
      builder: (context, collectionSnapshot) {
        if (!collectionSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return StreamBuilder<QuerySnapshot>(
          stream: collectionSnapshot.data!
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No purchase credits found',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final purchaseCreditNotes = snapshot.data!.docs.where((doc) {
          if (_searchQuery.isEmpty) return true;
          final data = doc.data() as Map<String, dynamic>;
          final creditNoteNumber = (data['creditNoteNumber'] ?? '').toString().toLowerCase();
          final supplierName = (data['supplierName'] ?? '').toString().toLowerCase();
          final supplierPhone = (data['supplierPhone'] ?? '').toString().toLowerCase();

          return creditNoteNumber.contains(_searchQuery) ||
              supplierName.contains(_searchQuery) ||
              supplierPhone.contains(_searchQuery);
        }).toList();

        if (purchaseCreditNotes.isEmpty) {
          return const Center(
            child: Text(
              'No matching purchase credits',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        // Calculate total
        double totalCredit = 0;
        for (var doc in purchaseCreditNotes) {
          final data = doc.data() as Map<String, dynamic>;
          totalCredit += (data['amount'] ?? 0.0) as num;
        }

        return Column(
          children: [
            // Total Credit Header
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Total Purchase Credit : ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'Rs ${totalCredit.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF007AFF),
                    ),
                  ),
                ],
              ),
            ),

            // Purchase Credit Notes List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: purchaseCreditNotes.length,
                itemBuilder: (context, index) {
                  final data = purchaseCreditNotes[index].data() as Map<String, dynamic>;
                  final creditNoteNumber = data['creditNoteNumber'] ?? 'N/A';
                  final supplierName = data['supplierName'] ?? 'Unknown Supplier';
                  final supplierPhone = data['supplierPhone'] ?? '';
                  final amount = (data['amount'] ?? 0.0) as num;
                  final status = data['status'] ?? 'Available';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: status == 'Available'
                            ? Colors.green.shade200
                            : Colors.grey.shade300,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Credit Note: $creditNoteNumber',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF007AFF),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  supplierName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: status == 'Available'
                                  ? Colors.green.shade100
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: status == 'Available'
                                    ? Colors.green.shade800
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          const Text(
                            'Phone Number',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            supplierPhone,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'Rs ${amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF007AFF),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      onTap: () {
                        // Navigate to purchase credit note details
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PurchaseCreditNoteDetailPage(
                              documentId: purchaseCreditNotes[index].id,
                              creditNoteData: data,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
      },
    );
  }
}

// ==========================================
// PURCHASE CREDIT NOTE DETAIL PAGE
// ==========================================
class PurchaseCreditNoteDetailPage extends StatefulWidget {
  final String documentId;
  final Map<String, dynamic> creditNoteData;

  const PurchaseCreditNoteDetailPage({
    super.key,
    required this.documentId,
    required this.creditNoteData,
  });

  @override
  State<PurchaseCreditNoteDetailPage> createState() => _PurchaseCreditNoteDetailPageState();
}

class _PurchaseCreditNoteDetailPageState extends State<PurchaseCreditNoteDetailPage> {
  Stream<DocumentSnapshot>? _documentStream;

  @override
  void initState() {
    super.initState();
    _initializeStream();
  }

  Future<void> _initializeStream() async {
    final collection = await FirestoreService().getStoreCollection('purchaseCreditNotes');
    if (mounted) {
      setState(() {
        _documentStream = collection.doc(widget.documentId).snapshots();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_documentStream == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _documentStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF5F5F5),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: const Color(0xFFF5F5F5),
            appBar: AppBar(
              title: const Text('Purchase Credit Note',
                  style: TextStyle(color: Colors.white)),
              backgroundColor: const Color(0xFF007AFF),
            ),
            body: const Center(child: Text('Credit note not found')),
          );
        }

        // Get real-time data from Firestore
        final liveData = snapshot.data!.data() as Map<String, dynamic>;
        final creditNoteNumber = liveData['creditNoteNumber'] ?? 'N/A';
        final purchaseNumber = liveData['purchaseNumber'] ?? 'N/A';
        final supplierName = liveData['supplierName'] ?? 'Unknown Supplier';
        final supplierPhone = liveData['supplierPhone'] ?? '';
        final amount = (liveData['amount'] ?? 0.0) as num;
        final paidAmount = (liveData['paidAmount'] ?? 0.0) as num;
        final remainingAmount = amount - paidAmount;
        final status = liveData['status'] ?? 'Available';
        final timestamp = liveData['timestamp'] as Timestamp?;
        final items = (liveData['items'] as List<dynamic>? ?? []);
        final dateString = timestamp != null
            ? DateFormat('dd MMM yyyy h:mm a').format(timestamp.toDate())
            : 'N/A';

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: AppBar(
            title: const Text('Purchase Credit Note',
                style: TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF007AFF),
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
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Credit Note No : $creditNoteNumber',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF007AFF),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Created by Admin',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Issued on:',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            dateString,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Purchase Info & Supplier Details
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Purchase No : $purchaseNumber',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: status == 'Available'
                                  ? Colors.green.shade100
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: status == 'Available'
                                    ? Colors.green.shade800
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      const Text(
                        'Supplier Details',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        supplierName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        supplierPhone,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),

                // Items
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
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
                              ),
                            ),
                            Text(
                              'Amount',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...items.map((item) {
                        final name = item['name'] ?? 'Unknown';
                        final qty = item['quantity'] ?? 0;
                        final price = (item['price'] ?? 0).toDouble();
                        final total = (item['total'] ?? 0).toDouble();

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
                                      ),
                                    ),
                                  ),
                                  const Text(
                                    '- 0.00',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${price.toStringAsFixed(2)} x ${qty.toStringAsFixed(1)}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                  const Text(
                                    '0.00',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    total.toStringAsFixed(2),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    total.toStringAsFixed(2),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF007AFF),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Items : ${items.length}'),
                            const Text(''),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Amount :',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Rs ${amount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF007AFF),
                                  ),
                                ),
                              ],
                            ),
                            if (paidAmount > 0) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Paid Amount :',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    'Rs ${paidAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (remainingAmount > 0) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Remaining :',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                  Text(
                                    'Rs ${remainingAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Payment History Section
                FutureBuilder<CollectionReference>(
                  future: FirestoreService().getStoreCollection('purchaseCreditNotes'),
                  builder: (context, collSnapshot) {
                    if (!collSnapshot.hasData) {
                      return const SizedBox.shrink();
                    }
                    return StreamBuilder<QuerySnapshot>(
                      stream: collSnapshot.data!
                          .doc(widget.documentId)
                          .collection('paymentHistory')
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                      builder: (context, historySnapshot) {
                    if (!historySnapshot.hasData ||
                        historySnapshot.data!.docs.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                              children: [
                                Icon(Icons.history,
                                    color: Color(0xFF007AFF), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Payment History',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...historySnapshot.data!.docs.map((paymentDoc) {
                            final paymentData =
                            paymentDoc.data() as Map<String, dynamic>;
                            final payAmount =
                            (paymentData['amount'] ?? 0.0) as num;
                            final payMode =
                                paymentData['paymentMode'] ?? 'Cash';
                            final payTimestamp =
                            paymentData['timestamp'] as Timestamp?;
                            final payDateString = payTimestamp != null
                                ? DateFormat('dd MMM yyyy, h:mm a')
                                .format(payTimestamp.toDate())
                                : 'N/A';

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom:
                                  BorderSide(color: Colors.grey.shade200),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      payMode == 'Cash'
                                          ? Icons.money
                                          : payMode == 'Online' ||
                                          payMode == 'UPI'
                                          ? Icons.credit_card
                                          : Icons.account_balance,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Rs ${payAmount.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          payDateString,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF007AFF)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      payMode,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF007AFF),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    );
                  },
                );
                  },
                ),
                const SizedBox(height: 16),

                // Action Buttons
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: remainingAmount > 0
                              ? () {
                            _showPurchaseRefundDialog(
                                context, widget.documentId, liveData);
                          }
                              : null,
                          icon: const Icon(Icons.attach_money,
                              color: Colors.white),
                          label: Text(
                            remainingAmount > 0 ? 'Pay' : 'Paid',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007AFF),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            disabledBackgroundColor: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Printing Receipt...')),
                            );
                          },
                          icon: const Icon(Icons.receipt_long,
                              color: Colors.white),
                          label: const Text(
                            'Receipt',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007AFF),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPurchaseRefundDialog(BuildContext context, String documentId,
      Map<String, dynamic> creditNoteData) {
    final TextEditingController amountController = TextEditingController();
    String selectedMode = 'Cash';

    final totalAmount = (creditNoteData['amount'] ?? 0.0) as num;
    final paidAmount = (creditNoteData['paidAmount'] ?? 0.0) as num;
    final remainingAmount = totalAmount - paidAmount;

    // Set default to remaining amount
    amountController.text = remainingAmount.toStringAsFixed(2);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Settle Payment',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Credit Note: ${creditNoteData['creditNoteNumber']}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                    'Total Amount', 'Rs ${totalAmount.toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                _buildInfoRow(
                    'Already Paid', 'Rs ${paidAmount.toStringAsFixed(2)}',
                    valueColor: Colors.green),
                const SizedBox(height: 8),
                _buildInfoRow(
                    'Remaining', 'Rs ${remainingAmount.toStringAsFixed(2)}',
                    valueColor: const Color(0xFF007AFF), isBold: true),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Payment Amount',
                    prefixText: 'Rs ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    helperText:
                    'Enter amount to pay (max: ${remainingAmount.toStringAsFixed(2)})',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Payment Mode:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['Cash', 'Online', 'UPI', 'Card', 'Bank Transfer']
                      .map((mode) {
                    final isSelected = selectedMode == mode;
                    return GestureDetector(
                      onTap: () => setState(() => selectedMode = mode),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF007AFF)
                              : Colors.white,
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF007AFF)
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          mode,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final paymentAmount =
                    double.tryParse(amountController.text) ?? 0.0;

                if (paymentAmount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter a valid amount')),
                  );
                  return;
                }

                if (paymentAmount > remainingAmount) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Amount cannot exceed remaining balance (Rs ${remainingAmount.toStringAsFixed(2)})')),
                  );
                  return;
                }

                // 1. Close the Input Dialog FIRST
                Navigator.pop(ctx);

                // 2. Show Loading Indicator


                try {
                  // Calculate new paid amount and status
                  final newPaidAmount = paidAmount + paymentAmount;
                  final newStatus =
                  newPaidAmount >= totalAmount ? 'Paid' : 'Partially Paid';

                  // Update purchase credit note
                  await FirebaseFirestore.instance
                      .collection('purchaseCreditNotes')
                      .doc(documentId)
                      .update({
                    'paidAmount': newPaidAmount,
                    'status': newStatus,
                    'lastPaymentDate': FieldValue.serverTimestamp(),
                  });

                  // Add payment history entry
                  await FirebaseFirestore.instance
                      .collection('purchaseCreditNotes')
                      .doc(documentId)
                      .collection('paymentHistory')
                      .add({
                    'amount': paymentAmount,
                    'paymentMode': selectedMode,
                    'timestamp': FieldValue.serverTimestamp(),
                    'paidBy': 'Admin',
                    'remainingAfterPayment': totalAmount - newPaidAmount,
                  });

                  // Update supplier balance if applicable
                  final supplierPhone = creditNoteData['supplierPhone'] ?? '';
                  if (supplierPhone.isNotEmpty) {
                    final supplierRef = FirebaseFirestore.instance
                        .collection('suppliers')
                        .doc(supplierPhone);

                    await FirebaseFirestore.instance
                        .runTransaction((transaction) async {
                      final supplierDoc = await transaction.get(supplierRef);
                      if (supplierDoc.exists) {
                        final currentBalance =
                            supplierDoc.data()?['creditBalance'] ?? 0.0;
                        final newBalance = currentBalance - paymentAmount;
                        transaction.update(supplierRef, {
                          'creditBalance': newBalance > 0 ? newBalance : 0,
                          'lastUpdated': FieldValue.serverTimestamp(),
                        });
                      }
                    });
                  }

                  // 3. Close the Loading Indicator
                  if (context.mounted) {
                    Navigator.of(context).pop();

                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(newStatus == 'Paid'
                            ? '✓ Payment settled successfully! Credit note fully paid.'
                            : '✓ Payment of Rs ${paymentAmount.toStringAsFixed(2)} recorded.'),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  // If error, Close Loading Indicator
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error processing payment: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Pay Now', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: valueColor ?? Colors.black87,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class CustomersPage extends StatefulWidget {
  final String uid; // Kept your uid parameter
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

  void _showAddCustomer() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final gstController = TextEditingController();

    showDialog(context: context, builder: (context) {
      return AlertDialog(
        title: const Text('Add New Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: 8),
            TextField(controller: gstController, decoration: const InputDecoration(labelText: 'GST No (Optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007AFF)),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              final gst = gstController.text.trim();

              if (name.isEmpty || phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and phone required')));
                return;
              }

              // Save to Firestore with initial 0 balance and 0 total sales
              await FirestoreService().setDocument('customers', phone, {
                'name': name,
                'phone': phone,
                'gst': gst.isEmpty ? null : gst,
                'balance': 0.0,     // Initial Credit Balance
                'totalSales': 0.0,  // Initial Total Sales
                'lastUpdated': FieldValue.serverTimestamp(),
                'timestamp': FieldValue.serverTimestamp(),
              });
              if (mounted) Navigator.pop(context);
            },
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background for better card contrast
      appBar: AppBar(
        title: const Text('Customer Management', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF007AFF),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: widget.onBack),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. Search Bar and Add Button Area
          Container(
            padding: const EdgeInsets.all(12.0),
            color: Colors.white,
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    hintText: 'Search',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Square Add Button
              Container(
                decoration: BoxDecoration(color: const Color(0xFFEAF4FF), borderRadius: BorderRadius.circular(8)),
                child: IconButton(
                  icon: const Icon(Icons.add, color: Color(0xFF007AFF)),
                  onPressed: _showAddCustomer,
                ),
              ),
            ]),
          ),

          // 2. Customer List
          Expanded(
            child: FutureBuilder<Stream<QuerySnapshot>>(
              future: FirestoreService().getCollectionStream('customers'),
              builder: (context, streamSnapshot) {
                if (!streamSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: streamSnapshot.data,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No customers found'));

                final docs = snapshot.data!.docs.where((d) {
                  if (_searchQuery.isEmpty) return true;
                  final data = d.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final phone = (data['phone'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || phone.contains(_searchQuery);
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final docId = docs[index].id; // This is the Phone Number based on your logic

                    return GestureDetector(
                      onTap: () {
                        // Navigate to the External File Page
                        Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) => CustomerDetailsPage(
                                customerId: docId,
                                customerData: data,
                              ),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                              transitionDuration: const Duration(milliseconds: 100),
                            )
                        );
                      },
                      child: Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Customer Name
                              Text(data['name'] ?? 'Unknown', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF007AFF))),
                              const SizedBox(height: 4),
                              // Phone
                              Text("Phone Number\n${data['phone'] ?? '--'}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              const SizedBox(height: 12),
                              // Stats Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Total Sales :", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                      Text("₹${data['totalSales'] ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text("Credit Amount", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                      Text("₹${data['balance'] ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF007AFF))),
                                    ],
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                    ); // Close Card
                  }, // Close ListView itemBuilder
                ); // Close ListView
                  }, // Close StreamBuilder builder
                ); // Close StreamBuilder
              }, // Close FutureBuilder builder
            ), // Close FutureBuilder
          ), // Close Expanded widget
          ], // Close Column children
        ), // Close Column widget (body parameter)
    ); // Close Scaffold
  } // Close build method
} // Close CustomersPage class


// ==========================================
// 5. STAFF RELATED PAGES
// ==========================================

class StaffManagementList extends StatelessWidget {
  final String adminUid;
  final VoidCallback onBack;
  final VoidCallback onAddStaff;
  final FirestoreService _firestoreService = FirestoreService();

  StaffManagementList({super.key, required this.adminUid, required this.onBack, required this.onAddStaff});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Staff Management', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF007AFF),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: onBack),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onAddStaff, // Calls Parent Switch
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Add New Staff"),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF007AFF), side: const BorderSide(color: Color(0xFF007AFF))),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<String?>(
              future: _firestoreService.getCurrentStoreId(),
              builder: (context, storeIdSnapshot) {
                if (!storeIdSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final storeId = storeIdSnapshot.data;

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('storeId', isEqualTo: storeId)
                      .snapshots(),
                  builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                return ListView.separated(
                  itemCount: snapshot.data!.docs.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    String name = data['name'] ?? 'Unknown';
                    String email = data['email'] ?? '';
                    String role = data['role'] ?? 'Staff';
                    bool isActive = (data['status'] ?? '') == 'Active';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.grey.shade100,
                        child: Text(name.isNotEmpty ? name.substring(0, 2).toUpperCase() : "NA", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF007AFF))),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(email, style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text("Role: $role", style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 8),
                              const Text("|", style: TextStyle(color: Colors.grey)),
                              const SizedBox(width: 8),
                              Text(isActive ? "Active" : "Inactive", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isActive ? Colors.green : Colors.red)),
                            ],
                          )
                        ],
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

class AddStaffPage extends StatefulWidget {
  final String adminUid;
  final VoidCallback onBack;

  const AddStaffPage({super.key, required this.adminUid, required this.onBack});

  @override
  State<AddStaffPage> createState() => _AddStaffPageState();
}

class _AddStaffPageState extends State<AddStaffPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _selectedRole = "Administrator";
  final List<String> _roles = ["Administrator", "Cashier", "Sales"];

  Map<String, Map<String, dynamic>> permissions = {
    "Bill History": {
      "enabled": true,
      "desc": "This role enables user to view bill history, return bills etc.",
      "sub": {"View Bill History": true, "Block Others Bill": true, "Return Bill": true, "Cancel bill": true}
    },
    "Inventory Management": {
      "enabled": true,
      "desc": "Manage stock.",
      "sub": {"View Inventory": true, "Edit Inventory": true, "Delete Inventory": true}
    },
    // ... add other permissions as needed
  };

  Future<void> _saveStaff() async {
    if(!_formKey.currentState!.validate()) return;
    try {
      // Get current user's storeId
      final storeId = await FirestoreService().getCurrentStoreId();

      await FirebaseFirestore.instance.collection('users').add({
        'name': _nameController.text,
        'email': _emailController.text,
        'role': _selectedRole,
        'status': 'Active',
        'parentAdmin': widget.adminUid,
        'storeId': storeId,
        'createdAt': FieldValue.serverTimestamp(),
        'permissions': permissions,
      });

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Staff Added Successfully")));
        widget.onBack(); // Go back to Staff List
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Add New Staff', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF007AFF),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: widget.onBack),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField("Name", _nameController),
              const SizedBox(height: 12),
              _buildTextField("Login Mail id", _emailController, isEmail: true),
              const SizedBox(height: 12),
              _buildTextField("Password", _passwordController, isPassword: true),
              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: InputDecoration(
                  labelText: 'Role',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                ),
                items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) => setState(() => _selectedRole = val!),
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveStaff,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007AFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text("Save Staff", style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isEmail = false, bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade300)),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
        decoration: InputDecoration(labelText: label, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
        validator: (val) => val!.isEmpty ? "Required" : null,
      ),
    );
  }
}

// ==========================================
// 6. BILL PAGE (Initiation point for Settle Bill)
// Note: This class uses the CartItem model and is the 'Sales/Bill.dart' reference
// ==========================================
class BillPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final List<CartItem> cartItems;
  final double totalAmount;
  final String? savedOrderId;

  const BillPage({
    super.key,
    required this.uid,
    this.userEmail,
    required this.cartItems,
    required this.totalAmount,
    this.savedOrderId,
  });

  @override
  State<BillPage> createState() => _BillPageState();
}

class _BillPageState extends State<BillPage> {
  late String _uid;
  String? _selectedCustomerPhone;
  String? _selectedCustomerName;
  String? _selectedCustomerGST;
  double _discountAmount = 0.0;
  String _creditNote = '';

  @override
  void initState() {
    super.initState();
    _uid = widget.uid;
  }

  double get _finalAmount => widget.totalAmount - _discountAmount;

  void _showCustomerDialog() {
    showDialog(
      context: context,
      builder: (context) => _CustomerSelectionDialog(
        uid: _uid,
        onCustomerSelected: (phone, name, gst) {
          setState(() {
            _selectedCustomerPhone = phone;
            _selectedCustomerName = name;
            _selectedCustomerGST = gst;
          });
        },
      ),
    );
  }

  void _showDiscountDialog() {
    final TextEditingController discountController = TextEditingController(
      text: _discountAmount.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Discount'),
        content: TextField(
          controller: discountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Discount Amount',
            border: OutlineInputBorder(),
            prefixText: '₹ ',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final discount = double.tryParse(discountController.text) ?? 0.0;
              setState(() {
                _discountAmount = discount;
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showCreditNoteDialog() {
    final TextEditingController noteController = TextEditingController(
      text: _creditNote,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Credit Note'),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Credit Note',
            border: OutlineInputBorder(),
            hintText: 'Enter note...',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _creditNote = noteController.text;
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _clearOrder() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Order'),
        content: const Text('Are you sure you want to clear this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: Color(0xFFFF5252)),
            ),
          ),
        ],
      ),
    );
  }

  void _proceedToPayment(String paymentMode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentPage(
          uid: _uid,
          userEmail: widget.userEmail,
          cartItems: widget.cartItems,
          totalAmount: _finalAmount,
          paymentMode: paymentMode,
          customerPhone: _selectedCustomerPhone,
          customerName: _selectedCustomerName,
          customerGST: _selectedCustomerGST,
          discountAmount: _discountAmount,
          creditNote: _creditNote,
          savedOrderId: widget.savedOrderId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        title: const Text(
          'Bill Details',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Add Customer Details Button
          GestureDetector(
            onTap: _showCustomerDialog,
            child: Container(
              margin: EdgeInsets.all(screenWidth * 0.04),
              padding: EdgeInsets.symmetric(
                vertical: screenHeight * 0.02,
                horizontal: screenWidth * 0.04,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF2196F3),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.person_add,
                    color: Color(0xFF2196F3),
                    size: 24,
                  ),
                  SizedBox(width: screenWidth * 0.02),
                  Text(
                    _selectedCustomerName ?? 'Add Customer Details',
                    style: TextStyle(
                      color: const Color(0xFF2196F3),
                      fontSize: screenWidth * 0.04,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Items List
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
              itemCount: widget.cartItems.length,
              itemBuilder: (context, index) {
                final item = widget.cartItems[index];
                return Container(
                  margin: EdgeInsets.only(bottom: screenHeight * 0.015),
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                              fontSize: screenWidth * 0.04,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '- 0.00', // Discount per item - kept as hardcoded placeholder
                            style: TextStyle(
                              fontSize: screenWidth * 0.035,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenHeight * 0.008),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₹${item.price.toStringAsFixed(2)} × ${item.quantity}',
                            style: TextStyle(
                              fontSize: screenWidth * 0.035,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            '0.00', // Tax per item - kept as hardcoded placeholder
                            style: TextStyle(
                              fontSize: screenWidth * 0.035,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenHeight * 0.008),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₹${item.total.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: screenWidth * 0.045,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '₹${item.total.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: screenWidth * 0.045,
                              color: const Color(0xFF2196F3),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Bottom Section
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Drag Handle
                Container(
                  margin: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
                  width: screenWidth * 0.1,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                  child: Column(
                    children: [
                      // Clear Order and Items Count
                      Row(
                        children: [
                          TextButton(
                            onPressed: _clearOrder,
                            child: const Text(
                              'Clear Order',
                              style: TextStyle(
                                color: Color(0xFFFF5252),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Items Count : ${widget.cartItems.length}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: screenHeight * 0.01),

                      // Amount Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Amount :', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          Text(
                            'Rs ${widget.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),

                      SizedBox(height: screenHeight * 0.015),

                      // Add Discount Button
                      GestureDetector(
                        onTap: _showDiscountDialog,
                        child: Text(
                          _discountAmount > 0
                              ? 'Discount: ₹${_discountAmount.toStringAsFixed(2)}'
                              : 'Add Discount',
                          style: const TextStyle(
                            color: Color(0xFF2196F3),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.01),

                      // Add Credit Note Button
                      GestureDetector(
                        onTap: _showCreditNoteDialog,
                        child: Text(
                          _creditNote.isNotEmpty
                              ? 'Note: $_creditNote'
                              : 'Add Credit Note',
                          style: const TextStyle(
                            color: Color(0xFF2196F3),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.015),

                      // Divider
                      Divider(thickness: 1, color: Colors.grey[300]),

                      SizedBox(height: screenHeight * 0.015),

                      // Total Amount
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Amount :',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Rs ${_finalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2196F3),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: screenHeight * 0.02),

                      // Payment Methods
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildPaymentButton(
                            icon: Icons.money,
                            label: 'Cash',
                            onTap: () => _proceedToPayment('Cash'),
                          ),
                          _buildPaymentButton(
                            icon: Icons.credit_card,
                            label: 'Online',
                            onTap: () => _proceedToPayment('Online'),
                          ),
                          _buildPaymentButton(
                            icon: Icons.access_time,
                            label: 'Set\nlater',
                            onTap: () => _proceedToPayment('Set later'),
                          ),
                          _buildPaymentButton(
                            icon: Icons.note_alt,
                            label: 'Credit',
                            onTap: () => _proceedToPayment('Credit'),
                          ),
                          _buildPaymentButton(
                            icon: Icons.call_split,
                            label: 'Split',
                            onTap: () => _proceedToPayment('Split'),
                          ),
                        ],
                      ),

                      SizedBox(height: screenHeight * 0.02),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF2196F3), width: 2),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF2196F3),
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// Customer Selection Dialog
class _CustomerSelectionDialog extends StatefulWidget {
  final String uid;
  final Function(String phone, String name, String? gst) onCustomerSelected;

  const _CustomerSelectionDialog({
    required this.uid,
    required this.onCustomerSelected,
  });

  @override
  State<_CustomerSelectionDialog> createState() =>
      _CustomerSelectionDialogState();
}

class _CustomerSelectionDialogState extends State<_CustomerSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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

  void _showAddCustomerDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController gstController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: gstController,
              decoration: const InputDecoration(
                labelText: 'GST No (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              final gst = gstController.text.trim();

              if (name.isEmpty || phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter name and phone number'),
                    backgroundColor: Color(0xFFFF5252),
                  ),
                );
                return;
              }

              try {
                await FirestoreService().setDocument('customers', phone, {
                  'name': name,
                  'phone': phone,
                  'gst': gst.isEmpty ? null : gst,
                  'balance': 0.0,
                  'lastUpdated': FieldValue.serverTimestamp(),
                });

                if (mounted) {
                  Navigator.pop(context);
                  widget.onCustomerSelected(
                      phone, name, gst.isEmpty ? null : gst);
                  Navigator.pop(context);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error adding customer: $e'),
                      backgroundColor: const Color(0xFFFF5252),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: screenWidth * 0.9,
        height: screenHeight * 0.7,
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Existing Customer',
                  style: TextStyle(
                    fontSize: screenWidth * 0.05,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            SizedBox(height: screenHeight * 0.02),

            // Search Bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Contact/Name/GST No',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: screenWidth * 0.02),
                GestureDetector(
                  onTap: _showAddCustomerDialog,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.person_add,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: screenHeight * 0.02),

            // Customer List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('customers')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('No customers found'),
                    );
                  }

                  final customers = snapshot.data!.docs.where((doc) {
                    if (_searchQuery.isEmpty) return true;

                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final phone =
                    (data['phone'] ?? '').toString().toLowerCase();
                    final gst = (data['gst'] ?? '').toString().toLowerCase();

                    return name.contains(_searchQuery) ||
                        phone.contains(_searchQuery) ||
                        gst.contains(_searchQuery);
                  }).toList();

                  if (customers.isEmpty) {
                    return const Center(
                      child: Text('No matching customers'),
                    );
                  }

                  return ListView.builder(
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final customerData =
                      customers[index].data() as Map<String, dynamic>;
                      final name = customerData['name'] ?? 'Unknown';
                      final phone = customerData['phone'] ?? '';
                      final gst = customerData['gst'];

                      return GestureDetector(
                        onTap: () {
                          widget.onCustomerSelected(phone, name, gst);
                          Navigator.pop(context);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2196F3),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Phone Number',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      phone,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (gst != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'GST No:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        gst,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Current Bal:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    (customerData['balance'] ?? 0.0).toStringAsFixed(2),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
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
        title: const Text('Sale Return', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF007AFF),
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
                          color: Color(0xFF007AFF),
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
                              Text('Available qty : ${qty.toStringAsFixed(2)}'),
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
                                    color: const Color(0xFF007AFF),
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
                                    color: const Color(0xFF007AFF),
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
                      const Text('Amount :'),
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
                      const Text('Total GST :'),
                      Text('Rs ${(totalReturnAmount * 0).toStringAsFixed(1)}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount :',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Rs ${totalReturnAmount.toStringAsFixed(1)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF007AFF),
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
                    backgroundColor: const Color(0xFF007AFF),
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

      // 1. Restore stock for returned items
      for (var entry in returnQuantities.entries) {
        final index = entry.key;
        final returnQty = entry.value;

        if (index < items.length) {
          final item = items[index];
          if (item['productId'] != null && item['productId'].toString().isNotEmpty) {
            final productRef = await FirestoreService().getDocumentReference('Products', item['productId']);

            await FirebaseFirestore.instance.runTransaction((transaction) async {
              final productDoc = await transaction.get(productRef);
              if (productDoc.exists) {
                final currentStock = (productDoc.data() as Map<String, dynamic>?)?['currentStock'] ?? 0.0;
                final newStock = currentStock + returnQty;
                transaction.update(productRef, {'currentStock': newStock});
              }
            });
          }
        }
      }

      // 2. Create credit note if mode is CreditNote
      if (returnMode == 'CreditNote' && widget.invoiceData['customerPhone'] != null) {
        // Generate credit note number
        final creditNoteNumber = 'CN${DateTime.now().millisecondsSinceEpoch}';

        // Create credit note document
        await FirestoreService().addDocument('creditNotes', {
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
            content: Text('Error processing return: $e'),
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
  late TextEditingController _discountController;
  late TextEditingController _creditNoteController;
  late String _selectedPaymentMode;
  late String? _selectedCustomerPhone;
  late String? _selectedCustomerName;
  late double _creditAmount;

  @override
  void initState() {
    super.initState();
    _discountController = TextEditingController(
      text: (widget.invoiceData['discount'] ?? 0).toString(),
    );
    _creditNoteController = TextEditingController(
      text: widget.invoiceData['creditNote'] ?? '',
    );
    _selectedPaymentMode = widget.invoiceData['paymentMode'] ?? 'Cash';
    _selectedCustomerPhone = widget.invoiceData['customerPhone'];
    _selectedCustomerName = widget.invoiceData['customerName'];
    _creditAmount = _selectedPaymentMode == 'Credit'
        ? (widget.invoiceData['total'] ?? 0).toDouble()
        : 0.0;
  }

  @override
  void dispose() {
    _discountController.dispose();
    _creditNoteController.dispose();
    super.dispose();
  }

  double get subtotal {
    final items = widget.invoiceData['items'] as List<dynamic>? ?? [];
    return items.fold(0.0, (sum, item) {
      final price = (item['price'] ?? 0).toDouble();
      final qty = (item['quantity'] ?? 0) is int
          ? item['quantity']
          : int.tryParse(item['quantity'].toString()) ?? 0;
      return sum + (price * qty);
    });
  }

  double get total {
    final discount = double.tryParse(_discountController.text) ?? 0;
    return subtotal - discount;
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.invoiceData['items'] as List<dynamic>? ?? [];
    final time = widget.invoiceData['timestamp'] != null
        ? (widget.invoiceData['timestamp'] as Timestamp).toDate()
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Edit', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF007AFF),
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
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invoice No. ${widget.invoiceData['invoiceNumber'] ?? 'N/A'}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Created by ${widget.invoiceData['staffName'] ?? 'Admin'}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Issued on :',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        time != null ? DateFormat('dd MMM yyyy h:mm a').format(time) : 'N/A',
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
            ),
            const SizedBox(height: 16),

            // Customer Details
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Customer Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () {
                      // Remove customer
                      setState(() {
                        _selectedCustomerPhone = null;
                        _selectedCustomerName = null;
                      });
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.all(16),
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
                    _selectedCustomerName ?? 'A',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('Phone Number', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(
                    _selectedCustomerPhone ?? '',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

            // Invoice Items
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Text(
                'Invoice items',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
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
                        Text('Items', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Amount', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  ...items.map((item) {
                    final name = item['name'] ?? '';
                    final price = (item['price'] ?? 0).toDouble();
                    final qty = (item['quantity'] ?? 0) is int
                        ? item['quantity']
                        : int.tryParse(item['quantity'].toString()) ?? 0;
                    final itemTotal = price * qty;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
                              const Text('-0.00', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${price.toStringAsFixed(2)} × ${qty.toStringAsFixed(1)}'),
                              const Text('0.00', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(itemTotal.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                itemTotal.toStringAsFixed(2),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF007AFF)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  // Add More button (placeholder)
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Add items feature coming soon')),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, color: Color(0xFF007AFF)),
                          SizedBox(width: 8),
                          Text(
                            'Add More',
                            style: TextStyle(color: Color(0xFF007AFF), fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Summary section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total items : ${items.length}'),
                            Text('Sub Total : Rs ${subtotal.toStringAsFixed(2)}'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Add Discount
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Add Discount'),
                                content: TextField(
                                  controller: _discountController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Discount Amount',
                                    prefixText: '₹ ',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {});
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Apply'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: const Text(
                            'Add Discount',
                            style: TextStyle(color: Color(0xFF007AFF), fontSize: 16),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Add Credit Note
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Add Credit Note'),
                                content: TextField(
                                  controller: _creditNoteController,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: 'Credit Note',
                                    hintText: 'Enter note...',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {});
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Save'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: const Text(
                            'Add Credit Note',
                            style: TextStyle(color: Color(0xFF007AFF), fontSize: 16),
                          ),
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Amount :', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text(
                              'Rs ${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF007AFF),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Payment Mode
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payment Mode :', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildPaymentModeButton('Cash'),
                      _buildPaymentModeButton('Online'),
                      _buildPaymentModeButton('Set Later'),
                      _buildPaymentModeButton('Split'),
                      _buildPaymentModeButton('Credit'),
                    ],
                  ),
                  if (_selectedPaymentMode == 'Credit') ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text('Credit : ', style: TextStyle(fontSize: 16)),
                        Text(
                          'Rs ${total.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF007AFF)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Update button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _updateBill,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Update',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentModeButton(String mode) {
    final isSelected = _selectedPaymentMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMode = mode;
          if (mode == 'Credit') {
            _creditAmount = total;
          } else {
            _creditAmount = 0.0;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF007AFF) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF007AFF) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          mode,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Future<void> _updateBill() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final discount = double.tryParse(_discountController.text) ?? 0;
      final oldPaymentMode = widget.invoiceData['paymentMode'];
      final oldTotal = (widget.invoiceData['total'] ?? 0).toDouble();

      // Update bill in Firestore
      await FirebaseFirestore.instance
          .collection('sales')
          .doc(widget.documentId)
          .update({
        'discount': discount,
        'total': total,
        'creditNote': _creditNoteController.text,
        'paymentMode': _selectedPaymentMode,
        'customerPhone': _selectedCustomerPhone,
        'customerName': _selectedCustomerName,
      });

      // Update customer credit if payment mode changed
      if (_selectedCustomerPhone != null) {
        final customerRef = FirebaseFirestore.instance
            .collection('customers')
            .doc(_selectedCustomerPhone);

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final customerDoc = await transaction.get(customerRef);
          if (customerDoc.exists) {
            double currentBalance = customerDoc.data()?['balance'] ?? 0.0;

            // Remove old credit
            if (oldPaymentMode == 'Credit') {
              currentBalance -= oldTotal;
            }

            // Add new credit
            if (_selectedPaymentMode == 'Credit') {
              currentBalance += total;
            }

            transaction.update(customerRef, {'balance': currentBalance});
          }
        });
      }

      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill updated successfully'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Go back
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating bill: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ==========================================
