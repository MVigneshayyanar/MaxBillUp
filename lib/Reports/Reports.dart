import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/components/common_bottom_nav.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/utils/permission_helper.dart';
import 'package:maxbillup/utils/firestore_service.dart';

// ==========================================
// COLOR CONSTANTS
// ==========================================
const Color kPrimaryBlue = Color(0xFF1976D2);
const Color kIncomeGreen = Color(0xFF22C55E);
const Color kExpenseRed = Color(0xFFEF4444);
const Color kLightGreen = Color(0xFFE8F5E9);
const Color kLightRed = Color(0xFFFFEBEE);
const Color kBackgroundGrey = Color(0xFFF5F5F5);

// ==========================================
// 1. MAIN REPORTS MENU (ROUTER)
// ==========================================
class ReportsPage extends StatefulWidget {
  final String uid;
  final String? userEmail;

  const ReportsPage({super.key, required this.uid, this.userEmail});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String? _currentView;
  Map<String, dynamic> _permissions = {};
  bool _isLoading = true;
  String _role = 'staff';

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final userData = await PermissionHelper.getUserPermissions(widget.uid);
    if (mounted) {
      setState(() {
        _permissions = userData['permissions'] as Map<String, dynamic>;
        _role = userData['role'] as String;
        _isLoading = false;
      });
    }
  }

  bool _hasPermission(String permission) {
    return _permissions[permission] == true;
  }

  bool get isAdmin => _role.toLowerCase() == 'admin' || _role.toLowerCase() == 'administrator';

  @override
  Widget build(BuildContext context) {
    // Permission checks for navigation
    switch (_currentView) {
      case 'Analytics':
        if (!_hasPermission('analytics') && !isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            PermissionHelper.showPermissionDeniedDialog(context);
            _reset();
          });
          return Container();
        }
        return AnalyticsPage(uid: widget.uid, onBack: _reset);

      case 'DayBook':
        if (!_hasPermission('daybook') && !isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            PermissionHelper.showPermissionDeniedDialog(context);
            _reset();
          });
          return Container();
        }
        return DayBookPage(uid: widget.uid, onBack: _reset);

      case 'Summary':
        if (!_hasPermission('salesSummary') && !isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            PermissionHelper.showPermissionDeniedDialog(context);
            _reset();
          });
          return Container();
        }
        return SalesSummaryPage(onBack: _reset);

      case 'SalesReport':
        if (!_hasPermission('salesReport') && !isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            PermissionHelper.showPermissionDeniedDialog(context);
            _reset();
          });
          return Container();
        }
        return FullSalesHistoryPage(onBack: _reset);

      case 'ExpenseReport':
        if (!_hasPermission('expensesReport') && !isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            PermissionHelper.showPermissionDeniedDialog(context);
            _reset();
          });
          return Container();
        }
        return ExpenseReportPage(onBack: _reset);

      case 'TopProducts':
        if (!_hasPermission('topProducts') && !isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            PermissionHelper.showPermissionDeniedDialog(context);
            _reset();
          });
          return Container();
        }
        return TopProductsPage(uid: widget.uid, onBack: _reset);

      case 'LowStock':
        if (!_hasPermission('lowStockProduct') && !isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            PermissionHelper.showPermissionDeniedDialog(context);
            _reset();
          });
          return Container();
        }
        return LowStockPage(onBack: _reset);

      case 'ItemSales':
        if (!_hasPermission('itemSalesReport') && !isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            PermissionHelper.showPermissionDeniedDialog(context);
            _reset();
          });
          return Container();
        }
        return ItemSalesPage(onBack: _reset);

      case 'HSNReport':
        if (!_hasPermission('hsnReport') && !isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            PermissionHelper.showPermissionDeniedDialog(context);
            _reset();
          });
          return Container();
        }
        return HSNReportPage(onBack: _reset);

      case 'TopCategories':
        if (!_hasPermission('topCategory') && !isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            PermissionHelper.showPermissionDeniedDialog(context);
            _reset();
          });
          return Container();
        }
        return TopCategoriesPage(onBack: _reset);

      case 'TopCustomers':
        if (!_hasPermission('topCustomer') && !isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            PermissionHelper.showPermissionDeniedDialog(context);
            _reset();
          });
          return Container();
        }
        return TopCustomersPage(uid: widget.uid, onBack: _reset);

      case 'StockReport':
        if (!_hasPermission('stockReport') && !isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            PermissionHelper.showPermissionDeniedDialog(context);
            _reset();
          });
          return Container();
        }
        return StockReportPage(onBack: _reset);

      case 'StaffReport':
        if (!_hasPermission('staffSalesReport') && !isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            PermissionHelper.showPermissionDeniedDialog(context);
            _reset();
          });
          return Container();
        }
        return StaffSaleReportPage(onBack: _reset);

      case 'TaxReport':
        if (!_hasPermission('taxReport') && !isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            PermissionHelper.showPermissionDeniedDialog(context);
            _reset();
          });
          return Container();
        }
        return TaxReportPage(onBack: _reset);
    }

    // Show loading indicator while checking permissions
    if (_isLoading) {
      return Scaffold(
        backgroundColor: kBackgroundGrey,
        appBar: AppBar(
          title: const Text("Reports", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: kPrimaryBlue,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: kBackgroundGrey,
      appBar: AppBar(
        title: const Text("Reports", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kPrimaryBlue,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Analytics & Overview Section
          if (_hasPermission('analytics') || _hasPermission('daybook') || _hasPermission('salesSummary') || isAdmin) ...[
            _sectionHeader("Analytics & Overview"),
            if (_hasPermission('analytics') || isAdmin)
              _tile("Analytics", Icons.bar_chart, kPrimaryBlue, 'Analytics'),
            if (_hasPermission('daybook') || isAdmin)
              _tile("DayBook (Today)", Icons.today, kPrimaryBlue, 'DayBook'),
            if (_hasPermission('salesSummary') || isAdmin)
              _tile("Sales Summary", Icons.dashboard_outlined, kPrimaryBlue, 'Summary'),
          ],

          // Sales & Transactions Section
          if (_hasPermission('salesReport') || _hasPermission('itemSalesReport') || _hasPermission('topCustomer') || isAdmin) ...[
            _sectionHeader("Sales & Transactions"),
            if (_hasPermission('salesReport') || isAdmin)
              _tile("Sales Report", Icons.receipt_long, kPrimaryBlue, 'SalesReport'),
            if (_hasPermission('itemSalesReport') || isAdmin)
              _tile("Item Sales Report", Icons.category_outlined, kPrimaryBlue, 'ItemSales'),
            if (_hasPermission('topCustomer') || isAdmin)
              _tile("Top Customers", Icons.people_outline, kPrimaryBlue, 'TopCustomers'),
          ],

          // Inventory & Products Section
          if (_hasPermission('stockReport') || _hasPermission('lowStockProduct') || _hasPermission('topProducts') || _hasPermission('topCategory') || isAdmin) ...[
            _sectionHeader("Inventory & Products"),
            if (_hasPermission('stockReport') || isAdmin)
              _tile("Stock Report", Icons.inventory, kPrimaryBlue, 'StockReport'),
            if (_hasPermission('lowStockProduct') || isAdmin)
              _tile("Low Stock Products", Icons.warning_amber_rounded, kExpenseRed, 'LowStock'),
            if (_hasPermission('topProducts') || isAdmin)
              _tile("Top Products", Icons.star_border, kPrimaryBlue, 'TopProducts'),
            if (_hasPermission('topCategory') || isAdmin)
              _tile("Top Categories", Icons.folder_open, kPrimaryBlue, 'TopCategories'),
          ],

          // Financials & Tax Section
          if (_hasPermission('expensesReport') || _hasPermission('taxReport') || _hasPermission('hsnReport') || _hasPermission('staffSalesReport') || isAdmin) ...[
            _sectionHeader("Financials & Tax"),
            if (_hasPermission('expensesReport') || isAdmin)
              _tile("Expense Report", Icons.money_off, kExpenseRed, 'ExpenseReport'),
            if (_hasPermission('taxReport') || isAdmin)
              _tile("Tax Report", Icons.percent, kIncomeGreen, 'TaxReport'),
            if (_hasPermission('hsnReport') || isAdmin)
              _tile("HSN Report", Icons.description, kPrimaryBlue, 'HSNReport'),
            if (_hasPermission('staffSalesReport') || isAdmin)
              _tile("Staff Sale Report", Icons.badge_outlined, kPrimaryBlue, 'StaffReport'),
          ],

          // No permissions message
          if (!isAdmin && !_hasAnyReportPermission())
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.lock_outline, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No Report Access',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You don\'t have permission to view any reports. Contact your administrator.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: CommonBottomNav(
        uid: widget.uid,
        userEmail: widget.userEmail,
        currentIndex: 1,
        screenWidth: MediaQuery.of(context).size.width,
      ),
    );
  }

  bool _hasAnyReportPermission() {
    return _hasPermission('analytics') ||
        _hasPermission('daybook') ||
        _hasPermission('salesSummary') ||
        _hasPermission('salesReport') ||
        _hasPermission('itemSalesReport') ||
        _hasPermission('topCustomer') ||
        _hasPermission('stockReport') ||
        _hasPermission('lowStockProduct') ||
        _hasPermission('topProducts') ||
        _hasPermission('topCategory') ||
        _hasPermission('expensesReport') ||
        _hasPermission('taxReport') ||
        _hasPermission('hsnReport') ||
        _hasPermission('staffSalesReport');
  }

  void _reset() => setState(() => _currentView = null);

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
      child: Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
    );
  }

  Widget _tile(String title, IconData icon, Color color, String view) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: ListTile(
        onTap: () => setState(() => _currentView = view),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      ),
    );
  }
}

// ==========================================
// 2. ANALYTICS PAGE
// ==========================================
class AnalyticsPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;

  const AnalyticsPage({super.key, required this.uid, required this.onBack});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  String _selectedDuration = 'Last 7 Days';
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
        title: const Text("Analytics", style: TextStyle(color: Colors.white)),
        backgroundColor: kPrimaryBlue,
        elevation: 0,
        centerTitle: true,
      ),
      body: FutureBuilder<List<CollectionReference>>(
        future: Future.wait([
          _firestoreService.getStoreCollection('sales'),
          _firestoreService.getStoreCollection('expenses'),
        ]),
        builder: (context, collectionsSnapshot) {
          if (!collectionsSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final salesCollection = collectionsSnapshot.data![0];
          final expensesCollection = collectionsSnapshot.data![1];

          return StreamBuilder<QuerySnapshot>(
            stream: salesCollection.snapshots(),
            builder: (context, salesSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: expensesCollection.snapshots(),
                builder: (context, expenseSnap) {
              if (!salesSnap.hasData || !expenseSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final now = DateTime.now();
              final todayStr = DateFormat('yyyy-MM-dd').format(now);

              double todayRevenue = 0;
              int todaySaleCount = 0;
              double todayExpense = 0;
              int todayExpenseCount = 0;
              double todayRefund = 0;

              Map<int, double> weekRevenue = {};
              Map<int, double> weekExpense = {};
              double periodIncome = 0;
              double periodExpense = 0;
              double totalCash = 0;
              double totalOnline = 0;

              for (var doc in salesSnap.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                double amount = double.tryParse(data['total'].toString()) ?? 0.0;
                String dateStr = data['date'] ?? '';
                DateTime? dt = DateTime.tryParse(dateStr);
                String mode = (data['paymentMode'] ?? '').toString().toLowerCase();

                if (dateStr.startsWith(todayStr)) {
                  todayRevenue += amount;
                  todaySaleCount++;
                }

                if (dt != null && now.difference(dt).inDays <= 7) {
                  periodIncome += amount;
                  weekRevenue[dt.day] = (weekRevenue[dt.day] ?? 0) + amount;
                  if (mode.contains('online') || mode.contains('upi')) {
                    totalOnline += amount;
                  } else {
                    totalCash += amount;
                  }
                }
              }

              for (var doc in expenseSnap.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                double amount = double.tryParse(data['amount'].toString()) ?? 0.0;
                String dateStr = data['date'] ?? '';
                DateTime? dt = DateTime.tryParse(dateStr);

                if (dateStr.isNotEmpty && dateStr.startsWith(todayStr)) {
                  todayExpense += amount;
                  todayExpenseCount++;
                }
                if (dt != null && now.difference(dt).inDays <= 7) {
                  periodExpense += amount;
                  weekExpense[dt.day] = (weekExpense[dt.day] ?? 0) + amount;
                }
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Today Summary", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
                    const SizedBox(height: 12),

                    _buildFullWidthCard(
                        title: "Revenue",
                        value: todayRevenue,
                        icon: Icons.inventory_2_outlined,
                        iconBg: kPrimaryBlue.withOpacity(0.1),
                        iconColor: kPrimaryBlue
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(child: _buildGridCard(
                            title: "Net Sale", value: todayRevenue, count: todaySaleCount,
                            icon: Icons.receipt_long, iconBg: kPrimaryBlue.withOpacity(0.1), iconColor: kPrimaryBlue
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _buildGridCard(
                            title: "Sale Profit", value: todayRevenue * 0.2,
                            icon: Icons.bar_chart, iconBg: kLightGreen, iconColor: kIncomeGreen,
                            hideCount: true
                        )),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(child: _buildGridCard(
                            title: "Refund", value: todayRefund, count: 0,
                            icon: Icons.credit_card_off, iconBg: const Color(0xFFFFF3E0), iconColor: Colors.orange.shade700
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _buildGridCard(
                            title: "Expense", value: todayExpense, count: todayExpenseCount,
                            icon: Icons.account_balance_wallet, iconBg: kLightRed, iconColor: kExpenseRed
                        )),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Analytics", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedDuration,
                              isDense: true,
                              style: const TextStyle(fontSize: 12, color: Colors.black87),
                              items: ['Last 7 Days', 'Last 30 Days'].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (newValue) => setState(() => _selectedDuration = newValue!),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // BAR CHART: Revenue vs Expenses
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))]
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Revenue vs Expenses", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 220,
                            child: BarChart(
                              BarChartData(
                                gridData: FlGridData(show: false),
                                borderData: FlBorderData(
                                    show: true,
                                    border: const Border(bottom: BorderSide(color: Colors.grey, width: 0.5), left: BorderSide(color: Colors.grey, width: 0.5))
                                ),
                                titlesData: FlTitlesData(
                                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) => Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Text(value.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                        ),
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 30,
                                            getTitlesWidget: (value, meta) => Text("${value~/1000}k", style: const TextStyle(fontSize: 9, color: Colors.grey))
                                        )
                                    )
                                ),
                                barGroups: _generateChartGroups(weekRevenue, weekExpense),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildLegendDot(kIncomeGreen, "Revenue"),
                              const SizedBox(width: 20),
                              _buildLegendDot(kExpenseRed, "Expenses"),
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(child: _buildTrendCard("Income", periodIncome, true)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTrendCard("Expense", periodExpense, false)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // PIE CHART: Payment Mode
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))]
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Payment Mode", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 200,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 0,
                                centerSpaceRadius: 50,
                                sections: _generatePieSections(totalCash, totalOnline),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildPieLegend(kPrimaryBlue, "Cash", totalCash),
                              _buildPieLegend(Colors.orange, "Online", totalOnline),
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
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

  Widget _buildFullWidthCard({required String title, required double value, required IconData icon, required Color iconBg, required Color iconColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Rs ${value.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black87)),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 24),
          )
        ],
      ),
    );
  }

  Widget _buildGridCard({required String title, required double value, int count = 0, required IconData icon, required Color iconBg, required Color iconColor, bool hideCount = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Rs ${value.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.black87)),
                if (!hideCount) ...[
                  const SizedBox(height: 4),
                  Text("Count : $count", style: const TextStyle(fontSize: 10, color: Colors.black87, fontWeight: FontWeight.w500)),
                ],
                const SizedBox(height: 4),
                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconColor, size: 20),
          )
        ],
      ),
    );
  }

  Widget _buildTrendCard(String title, double value, bool isIncome) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.black87)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: isIncome ? kLightGreen : kLightRed, borderRadius: BorderRadius.circular(4)),
                child: Row(
                  children: [
                    Icon(Icons.trending_up, size: 12, color: isIncome ? kIncomeGreen : kExpenseRed),
                    const SizedBox(width: 4),
                    Text(isIncome ? "35%" : "15%", style: TextStyle(fontSize: 10, color: isIncome ? kIncomeGreen : kExpenseRed, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          Text("Rs ${value.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildPieLegend(Color color, String label, double value) {
    return Row(
      children: [
        Container(width: 18, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
            Text("₹${value.toStringAsFixed(2)}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87)),
          ],
        )
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500))
    ]);
  }

  List<BarChartGroupData> _generateChartGroups(Map<int, double> revenue, Map<int, double> expenses) {
    List<int> days = revenue.keys.toList()..addAll(expenses.keys.toList());
    days = days.toSet().toList()..sort();
    return days.map((day) {
      return BarChartGroupData(
        x: day,
        barRods: [
          BarChartRodData(toY: revenue[day] ?? 0, color: kIncomeGreen, width: 12, borderRadius: BorderRadius.zero),
          BarChartRodData(toY: expenses[day] ?? 0, color: kExpenseRed, width: 12, borderRadius: BorderRadius.zero),
        ],
      );
    }).toList();
  }

  List<PieChartSectionData> _generatePieSections(double cash, double online) {
    if (cash == 0 && online == 0) return [PieChartSectionData(value: 1, color: Colors.grey.shade200, radius: 80, showTitle: false)];
    return [
      if (cash > 0) PieChartSectionData(value: cash, color: kPrimaryBlue, radius: 80, showTitle: true, title: "${((cash/(cash+online))*100).toInt()}%", titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      if (online > 0) PieChartSectionData(value: online, color: Colors.orange, radius: 80, showTitle: true, title: "${((online/(cash+online))*100).toInt()}%", titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    ];
  }
}

// ==========================================
// 3. DAYBOOK WITH LINE CHART
// ==========================================
class DayBookPage extends StatelessWidget {
  final String uid;
  final VoidCallback onBack;
  final FirestoreService _firestoreService = FirestoreService();

  DayBookPage({super.key, required this.uid, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final String todayDateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      appBar: _buildAppBar("DayBook", onBack),
      body: FutureBuilder<CollectionReference>(
        future: _firestoreService.getStoreCollection('sales'),
        builder: (context, collectionSnapshot) {
          if (!collectionSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<QuerySnapshot>(
            stream: collectionSnapshot.data!.snapshots(),
            builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final allDocs = snapshot.data!.docs;

          // 1. Filter documents for today (Safely checking for 'date' field)
          var todayDocs = allDocs.where((doc) {
            // Safely retrieve data map and access 'date' field
            final data = doc.data() as Map<String, dynamic>;
            final docDate = data['date']?.toString() ?? '';
            return docDate.startsWith(todayDateStr);
          }).toList();

          // 2. Safely calculate total revenue
          double total = todayDocs.fold(0, (sum, doc) {
            final data = doc.data() as Map<String, dynamic>;
            // Safely parse 'total' field, defaulting to 0 if null or non-numeric
            return sum + (double.tryParse(data['total']?.toString() ?? '0') ?? 0);
          });

          // 3. Build hourly chart data (Safely checking for 'date' and 'total')
          Map<int, double> hourlyRevenue = {};
          for (var doc in todayDocs) {
            final data = doc.data() as Map<String, dynamic>;
            String dateStr = data['date']?.toString() ?? '';
            DateTime? dt = DateTime.tryParse(dateStr);
            if (dt != null) {
              double saleTotal = double.tryParse(data['total']?.toString() ?? '0') ?? 0;
              hourlyRevenue[dt.hour] = (hourlyRevenue[dt.hour] ?? 0) + saleTotal;
            }
          }

          return Column(
            children: [
              // --- HEADER REVENUE CARD ---
              Container(
                  padding: const EdgeInsets.all(20),
                  color: kPrimaryBlue,
                  width: double.infinity,
                  child: Column(children: [
                    const Text("Today's Revenue", style: TextStyle(color: Colors.white70)),
                    Text("₹${total.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                    Text("${todayDocs.length} Bills", style:const TextStyle(color:Colors.white70))
                  ])
              ),
              // --- END HEADER ---

              // --- LINE CHART FOR HOURLY REVENUE ---
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Hourly Revenue Trend", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: LineChart(
                        LineChartData(
                          minX: 0,
                          maxX: 23,
                          gridData: FlGridData(show: true, drawVerticalLine: false),
                          borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: Colors.grey.shade400), left: BorderSide(color: Colors.grey.shade400), right: BorderSide.none, top: BorderSide.none)),
                          titlesData: FlTitlesData(
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              axisNameWidget: const Text('Hour', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 4,
                                getTitlesWidget: (value, meta) => Text("${value.toInt()}h", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                              ),
                            ),
                            leftTitles: AxisTitles(
                              axisNameWidget: const Text('₹', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) => Text("₹${value.toInt()}", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                              ),
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: hourlyRevenue.entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                              isCurved: true,
                              color: kPrimaryBlue,
                              barWidth: 3,
                              dotData: FlDotData(show: true),
                              belowBarData: BarAreaData(show: true, color: kPrimaryBlue.withOpacity(0.2)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // --- END CHART ---

              // --- LIST OF TODAY'S BILLS ---
              Expanded(
                  child: ListView.builder(
                      itemCount: todayDocs.length,
                      itemBuilder: (context, index) {
                        var docData = todayDocs[index].data() as Map<String, dynamic>;
                        // Safely access fields in the list view
                        double saleTotal = double.tryParse(docData['total']?.toString() ?? '0') ?? 0;

                        return ListTile(
                            title: Text(docData['customerName'] ?? 'Walk-in'),
                            subtitle: Text("#${docData['invoiceNumber'] ?? 'N/A'}"),
                            trailing: Text("₹${saleTotal.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, color: kIncomeGreen))
                        );
                      }
                  )
              ),
            ],
          );
        },
      );
        },
      ),
    );
  }
}

// ==========================================
// 4. SALES SUMMARY WITH COLUMN CHART
// ==========================================
class SalesSummaryPage extends StatelessWidget {
  final VoidCallback onBack;
  final FirestoreService _firestoreService = FirestoreService();

  SalesSummaryPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar("Summary", onBack),
      body: FutureBuilder<List<CollectionReference>>(
        future: Future.wait([
          _firestoreService.getStoreCollection('sales'),
          _firestoreService.getStoreCollection('expenses'),
        ]),
        builder: (context, collectionsSnapshot) {
          if (!collectionsSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final salesCollection = collectionsSnapshot.data![0];
          final expensesCollection = collectionsSnapshot.data![1];

          return StreamBuilder<QuerySnapshot>(
            stream: salesCollection.snapshots(),
            builder: (context, salesSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: expensesCollection.snapshots(),
                builder: (context, expenseSnapshot) {
              if (!salesSnapshot.hasData || !expenseSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final now = DateTime.now();
              final todayStr = DateFormat('yyyy-MM-dd').format(now);
              final yesterdayStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

              // Income calculations
              double todayIncome = 0;
              double yesterdayIncome = 0;
              double last7DaysIncome = 0;
              double novemberIncome = 0;
              double octoberIncome = 0;

              for (var doc in salesSnapshot.data!.docs) {
                double amount = double.tryParse(doc['total'].toString()) ?? 0;
                String dateStr = doc['date'] ?? '';
                DateTime? dt = DateTime.tryParse(dateStr);

                if (dateStr.startsWith(todayStr)) {
                  todayIncome += amount;
                }
                if (dateStr.startsWith(yesterdayStr)) {
                  yesterdayIncome += amount;
                }
                if (dt != null) {
                  if (now.difference(dt).inDays <= 7) {
                    last7DaysIncome += amount;
                  }
                  if (dt.month == 11 && dt.year == now.year) {
                    novemberIncome += amount;
                  }
                  if (dt.month == 10 && dt.year == now.year) {
                    octoberIncome += amount;
                  }
                }
              }

              // Expense calculations
              double todayExpense = 0;
              double yesterdayExpense = 0;
              double last7DaysExpense = 0;
              double novemberExpense = 0;
              double octoberExpense = 0;

              for (var doc in expenseSnapshot.data!.docs) {
                double amount = double.tryParse(doc['amount'].toString()) ?? 0;
                String dateStr = doc['date'] ?? '';
                DateTime? dt = DateTime.tryParse(dateStr);

                if (dateStr.startsWith(todayStr)) {
                  todayExpense += amount;
                }
                if (dateStr.startsWith(yesterdayStr)) {
                  yesterdayExpense += amount;
                }
                if (dt != null) {
                  if (now.difference(dt).inDays <= 7) {
                    last7DaysExpense += amount;
                  }
                  if (dt.month == 11 && dt.year == now.year) {
                    novemberExpense += amount;
                  }
                  if (dt.month == 10 && dt.year == now.year) {
                    octoberExpense += amount;
                  }
                }
              }

              double incomePercentChange = yesterdayIncome > 0 ? ((todayIncome - yesterdayIncome) / yesterdayIncome * 100) : 35;
              double expensePercentChange = yesterdayExpense > 0 ? ((todayExpense - yesterdayExpense) / yesterdayExpense * 100) : 15;

              return SingleChildScrollView(
                child: Column(
                  children: [

                    const SizedBox(height: 16),

                    // Income Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Income",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Today Income Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: kIncomeGreen,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Rs ${todayIncome.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Today",
                                      style: TextStyle(color: Colors.white70, fontSize: 14),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.trending_up, color: Colors.white, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            "${incomePercentChange.toStringAsFixed(0)}%",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Income Grid
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummarySmallCard(
                                  "Rs ${yesterdayIncome.toStringAsFixed(2)}",
                                  "Yesterday",
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSummarySmallCard(
                                  "Rs ${last7DaysIncome.toStringAsFixed(2)}",
                                  "Last 7 Days",
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: _buildSummarySmallCard(
                                  "Rs ${novemberIncome.toStringAsFixed(2)}",
                                  "November",
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSummarySmallCard(
                                  "Rs ${octoberIncome.toStringAsFixed(2)}",
                                  "October",
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Expense Section
                          const Text(
                            "Expense",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Today Expense Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: kExpenseRed,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Rs ${todayExpense.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Today",
                                      style: TextStyle(color: Colors.white70, fontSize: 14),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.trending_up, color: Colors.white, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            "${expensePercentChange.toStringAsFixed(0)}%",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Expense Grid
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummarySmallCard(
                                  "Rs ${yesterdayExpense.toStringAsFixed(2)}",
                                  "Yesterday",
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSummarySmallCard(
                                  "Rs ${last7DaysExpense.toStringAsFixed(2)}",
                                  "Last 7 Days",
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: _buildSummarySmallCard(
                                  "Rs ${novemberExpense.toStringAsFixed(2)}",
                                  "November",
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSummarySmallCard(
                                  "Rs ${octoberExpense.toStringAsFixed(2)}",
                                  "October",
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Dues Section
                          const Text(
                            "Dues",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: kLightGreen,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: kIncomeGreen.withOpacity(0.3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Rs 14,000.00",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: kIncomeGreen,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Sales",
                                        style: TextStyle(
                                          color: kIncomeGreen.withOpacity(0.7),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: kLightRed,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: kExpenseRed.withOpacity(0.3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Rs 20,000.00",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: kExpenseRed,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Purchase",
                                        style: TextStyle(
                                          color: kExpenseRed.withOpacity(0.7),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
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

  Widget _buildSummarySmallCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 5. FULL SALES REPORT WITH AREA CHART
// ==========================================
class FullSalesHistoryPage extends StatelessWidget {
  final VoidCallback onBack;
  final FirestoreService _firestoreService = FirestoreService();

  FullSalesHistoryPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar("All Sales Report", onBack),
      body: FutureBuilder<CollectionReference>(
        future: _firestoreService.getStoreCollection('sales'),
        builder: (context, collectionSnapshot) {
          if (!collectionSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<QuerySnapshot>(
            stream: collectionSnapshot.data!.orderBy('date', descending: true).snapshots(),
            builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          // Build daily trend
          Map<int, double> dailySales = {};
          for (var doc in snapshot.data!.docs) {
            DateTime? dt = DateTime.tryParse(doc['date'] ?? '');
            if (dt != null && DateTime.now().difference(dt).inDays <= 30) {
              dailySales[dt.day] = (dailySales[dt.day] ?? 0) + (double.tryParse(doc['total'].toString()) ?? 0);
            }
          }

          return Column(
            children: [
              // AREA CHART
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Sales Trend (Last 30 Days)", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(show: true, drawVerticalLine: false),
                          borderData: FlBorderData(show: true, border: const Border(bottom: BorderSide(color: Colors.grey), left: BorderSide(color: Colors.grey))),
                          titlesData: FlTitlesData(
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              axisNameWidget: const Text('Day of Month', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 5,
                                getTitlesWidget: (value, meta) => Text("${value.toInt()}", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                              ),
                            ),
                            leftTitles: AxisTitles(
                              axisNameWidget: const Text('₹', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) => Text("₹${value~/1000}k", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                              ),
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: dailySales.entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                              isCurved: true,
                              color: kPrimaryBlue,
                              barWidth: 3,
                              dotData: FlDotData(show: true),
                              belowBarData: BarAreaData(show: true, color: kPrimaryBlue.withOpacity(0.2)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView.separated(
                    itemCount: snapshot.data!.docs.length,
                    separatorBuilder: (c,i)=>const Divider(height: 1),
                    itemBuilder: (c, i) {
                      var d = snapshot.data!.docs[i];
                      return ListTile(
                          title: Text(d['customerName']??''),
                          subtitle: Text(d['date']??''),
                          trailing: Text("₹${d['total']}", style:TextStyle(fontWeight: FontWeight.bold, color: kIncomeGreen))
                      );
                    }
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
}

// ==========================================
// 6. ITEM SALES REPORT WITH HORIZONTAL BAR
// ==========================================
class ItemSalesPage extends StatelessWidget {
  final VoidCallback onBack;
  final FirestoreService _firestoreService = FirestoreService();

  ItemSalesPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar("Item Sales", onBack),
      body: FutureBuilder<CollectionReference>(
        future: _firestoreService.getStoreCollection('sales'),
        builder: (context, collectionSnapshot) {
          if (!collectionSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<QuerySnapshot>(
            stream: collectionSnapshot.data!.snapshots(),
            builder: (context, snapshot) {
          if(!snapshot.hasData) return const Center(child:CircularProgressIndicator());
          Map<String, int> qty = {};
          for(var d in snapshot.data!.docs) {
            for(var item in (d['items'] as List)) {
              qty[item['name']] = (qty[item['name']]??0) + (int.tryParse(item['quantity'].toString())??0);
            }
          }
          var sorted = qty.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));

          return Column(
            children: [
              // HORIZONTAL BAR CHART
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                height: 280,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Top 5 Items by Quantity Sold", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 16),
                    Expanded(
                      child: BarChart(
                        BarChartData(
                          gridData: FlGridData(show: true, drawVerticalLine: false),
                          borderData: FlBorderData(show: true, border: const Border(bottom: BorderSide(color: Colors.grey), left: BorderSide(color: Colors.grey))),
                          titlesData: FlTitlesData(
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              axisNameWidget: const Text('Product Name', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 60,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() >= 0 && value.toInt() < sorted.length && value.toInt() < 5) {
                                    String name = sorted[value.toInt()].key;
                                    return Transform.rotate(
                                      angle: -0.5,
                                      child: Text(name.length > 8 ? '${name.substring(0, 8)}...' : name, style: const TextStyle(fontSize: 9), overflow: TextOverflow.ellipsis),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              axisNameWidget: const Text('Qty', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 35,
                                getTitlesWidget: (value, meta) => Text("${value.toInt()}", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                              ),
                            ),
                          ),
                          barGroups: sorted.take(5).toList().asMap().entries.map((entry) {
                            return BarChartGroupData(
                              x: entry.key,
                              barRods: [BarChartRodData(toY: entry.value.value.toDouble(), color: kPrimaryBlue, width: 30)],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView.builder(
                    itemCount: sorted.length,
                    itemBuilder: (c, i) {
                      return ListTile(
                          leading: CircleAvatar(backgroundColor: kPrimaryBlue, child: Text("#${i+1}", style: const TextStyle(color: Colors.white))),
                          title: Text(sorted[i].key),
                          trailing: Text("${sorted[i].value} Sold", style: const TextStyle(fontWeight: FontWeight.bold))
                      );
                    }
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
}

// ==========================================
// 7. TOP CUSTOMERS WITH BAR CHART
// ==========================================
class TopCustomersPage extends StatelessWidget {
  final String uid;
  final VoidCallback onBack;
  final FirestoreService _firestoreService = FirestoreService();

  TopCustomersPage({super.key, required this.uid, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar("Top Customers", onBack),
      body: FutureBuilder<CollectionReference>(
        future: _firestoreService.getStoreCollection('sales'),
        builder: (context, collectionSnapshot) {
          if (!collectionSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<QuerySnapshot>(
            stream: collectionSnapshot.data!.snapshots(),
            builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          Map<String, double> spend = {};
          for(var d in snapshot.data!.docs) {
            spend[d['customerName']??'Unknown'] = (spend[d['customerName']??'Unknown']??0) + (double.tryParse(d['total'].toString())??0);
          }
          var sorted = spend.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));

          return Column(
            children: [
              // BAR CHART FOR TOP 5
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                height: 280,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Top 5 Customers by Spending", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 16),
                    Expanded(
                      child: BarChart(
                        BarChartData(
                          gridData: FlGridData(show: true, drawVerticalLine: false),
                          borderData: FlBorderData(show: true, border: const Border(bottom: BorderSide(color: Colors.grey), left: BorderSide(color: Colors.grey))),
                          titlesData: FlTitlesData(
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              axisNameWidget: const Text('Customer', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 60,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() >= 0 && value.toInt() < sorted.length && value.toInt() < 5) {
                                    String name = sorted[value.toInt()].key;
                                    return Transform.rotate(
                                      angle: -0.5,
                                      child: Text(name.length > 8 ? '${name.substring(0, 8)}...' : name, style: const TextStyle(fontSize: 9)),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              axisNameWidget: const Text('₹', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) => Text("₹${value~/1000}k", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                              ),
                            ),
                          ),
                          barGroups: sorted.take(5).toList().asMap().entries.map((entry) {
                            return BarChartGroupData(
                              x: entry.key,
                              barRods: [BarChartRodData(toY: entry.value.value, color: kPrimaryBlue, width: 30)],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView.builder(
                    itemCount: sorted.length,
                    itemBuilder: (c, i) => ListTile(
                        leading: CircleAvatar(backgroundColor: kPrimaryBlue, child: Text("${i+1}", style: const TextStyle(color: Colors.white))),
                        title: Text(sorted[i].key),
                        trailing: Text("₹${sorted[i].value.toStringAsFixed(0)}")
                    )
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
}

// ==========================================
// 8. STOCK REPORT WITH STACKED BAR CHART
// ==========================================
class StockReportPage extends StatelessWidget {
  final VoidCallback onBack;
  final FirestoreService _firestoreService = FirestoreService();

  StockReportPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar("Stock Report", onBack),
      body: FutureBuilder<CollectionReference>(
        future: _firestoreService.getStoreCollection('Products'),
        builder: (context, collectionSnapshot) {
          if (!collectionSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<QuerySnapshot>(
            stream: collectionSnapshot.data!.snapshots(),
            builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          double totalVal = 0;
          Map<String, int> categoryStock = {};

          for(var d in snapshot.data!.docs) {
            double price = double.tryParse(d['price'].toString()) ?? 0;
            int stock = int.tryParse(d['currentStock'].toString()) ?? 0;
            totalVal += price * stock;
            String cat = d['category'] ?? 'Uncategorized';
            categoryStock[cat] = (categoryStock[cat] ?? 0) + stock;
          }

          return Column(
              children: [
                Container(
                    padding: const EdgeInsets.all(16),
                    color: kPrimaryBlue.withOpacity(0.1),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Inventory Value:", style:TextStyle(fontWeight: FontWeight.bold)),
                          Text("₹${totalVal.toStringAsFixed(0)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kPrimaryBlue))
                        ]
                    )
                ),

                // BAR CHART FOR CATEGORY DISTRIBUTION
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
                  height: 280,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      const Text("Stock by Category", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 16),
                      Expanded(
                        child: BarChart(
                          BarChartData(
                            gridData: FlGridData(show: true, drawVerticalLine: false),
                            borderData: FlBorderData(show: true, border: const Border(bottom: BorderSide(color: Colors.grey), left: BorderSide(color: Colors.grey))),
                            titlesData: FlTitlesData(
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                axisNameWidget: const Text('Category', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 60,
                                  getTitlesWidget: (value, meta) {
                                    if (value.toInt() >= 0 && value.toInt() < categoryStock.length) {
                                      String name = categoryStock.keys.elementAt(value.toInt());
                                      return Transform.rotate(
                                        angle: -0.5,
                                        child: Text(name.length > 8 ? '${name.substring(0, 8)}...' : name, style: const TextStyle(fontSize: 9)),
                                      );
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                axisNameWidget: const Text('Units', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 35,
                                  getTitlesWidget: (value, meta) => Text("${value.toInt()}", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                ),
                              ),
                            ),
                            barGroups: categoryStock.entries.toList().asMap().entries.map((entry) {
                              return BarChartGroupData(
                                x: entry.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: entry.value.value.toDouble(),
                                    color: kPrimaryBlue,
                                    width: 30,
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                    child: ListView.builder(
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (c, i) {
                          var d = snapshot.data!.docs[i];
                          return ListTile(
                              title: Text(d['itemName'] ?? 'Unknown'),
                              subtitle: Text("Price: ₹${d['price'] ?? 0}"),
                              trailing: Text("${d['currentStock'] ?? 0} Units")
                          );
                        }
                    )
                )
              ]
          );
        },
      );
        },
      ),
    );
  }
}

// ==========================================
// 9. LOW STOCK WITH INDICATOR BARS
// ==========================================
class LowStockPage extends StatelessWidget {
  final VoidCallback onBack;
  final FirestoreService _firestoreService = FirestoreService();

  LowStockPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar("Low Stock", onBack),
      body: FutureBuilder<CollectionReference>(
        future: _firestoreService.getStoreCollection('Products'),
        builder: (context, collectionSnapshot) {
          if (!collectionSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<QuerySnapshot>(
            stream: collectionSnapshot.data!.snapshots(),
            builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var low = snapshot.data!.docs.where((d) => (int.tryParse(d['currentStock'].toString())??0) < 5).toList();

          Map<String, int> lowStockData = {};
          for (var d in low) {
            lowStockData[d['itemName']] = int.tryParse(d['currentStock'].toString()) ?? 0;
          }

          return Column(
            children: [
              // HORIZONTAL BAR FOR LOW STOCK ITEMS
              if (lowStockData.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
                  height: 280,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Stock Levels (Critical Items)", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 16),
                      Expanded(
                        child: BarChart(
                          BarChartData(
                            gridData: FlGridData(show: true, drawVerticalLine: false),
                            borderData: FlBorderData(show: true, border: const Border(bottom: BorderSide(color: Colors.grey), left: BorderSide(color: Colors.grey))),
                            titlesData: FlTitlesData(
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                axisNameWidget: const Text('Product', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 60,
                                  getTitlesWidget: (value, meta) {
                                    if (value.toInt() >= 0 && value.toInt() < lowStockData.length) {
                                      String name = lowStockData.keys.elementAt(value.toInt());
                                      return Transform.rotate(
                                        angle: -0.5,
                                        child: Text(name.length > 8 ? '${name.substring(0, 8)}...' : name, style: const TextStyle(fontSize: 9), overflow: TextOverflow.ellipsis),
                                      );
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                axisNameWidget: const Text('Units', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 35,
                                  getTitlesWidget: (value, meta) => Text("${value.toInt()}", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                ),
                              ),
                            ),
                            barGroups: lowStockData.entries.toList().asMap().entries.map((entry) {
                              return BarChartGroupData(
                                x: entry.key,
                                barRods: [BarChartRodData(toY: entry.value.value.toDouble(), color: kExpenseRed, width: 30)],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: ListView.builder(
                    itemCount: low.length,
                    itemBuilder: (c, i) => ListTile(
                        leading: Icon(Icons.warning, color: kExpenseRed),
                        title: Text(low[i]['itemName']),
                        trailing: Text("${low[i]['currentStock']} Left", style:TextStyle(color: kExpenseRed, fontWeight: FontWeight.bold))
                    )
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
}

// ==========================================
// 10. TOP PRODUCTS WITH COLUMN CHART
// ==========================================
class TopProductsPage extends StatelessWidget {
  final String uid;
  final VoidCallback onBack;
  final FirestoreService _firestoreService = FirestoreService();

  TopProductsPage({super.key, required this.uid, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar("Top Products", onBack),
      body: FutureBuilder<CollectionReference>(
        future: _firestoreService.getStoreCollection('sales'),
        builder: (context, collectionSnapshot) {
          if (!collectionSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<QuerySnapshot>(
            stream: collectionSnapshot.data!.snapshots(),
            builder: (context, snapshot) {
          if(!snapshot.hasData) return const Center(child:CircularProgressIndicator());
          Map<String, int> qty = {};
          for(var d in snapshot.data!.docs) {
            for(var item in (d['items'] as List)) {
              qty[item['name']] = (qty[item['name']]??0) + (int.tryParse(item['quantity'].toString())??0);
            }
          }
          var sorted = qty.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));

          return Column(
            children: [
              // COLUMN CHART FOR TOP 5
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                height: 280,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    const Text("Top 5 Products by Sales Volume", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 16),
                    Expanded(
                      child: BarChart(
                        BarChartData(
                          gridData: FlGridData(show: true, drawVerticalLine: false),
                          borderData: FlBorderData(show: true, border: const Border(bottom: BorderSide(color: Colors.grey), left: BorderSide(color: Colors.grey))),
                          titlesData: FlTitlesData(
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              axisNameWidget: const Text('Product', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 60,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() >= 0 && value.toInt() < sorted.length && value.toInt() < 5) {
                                    String name = sorted[value.toInt()].key;
                                    return Transform.rotate(
                                      angle: -0.5,
                                      child: Text(name.length > 8 ? '${name.substring(0, 8)}...' : name, style: const TextStyle(fontSize: 9)),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              axisNameWidget: const Text('Qty', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 35,
                                getTitlesWidget: (value, meta) => Text("${value.toInt()}", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                              ),
                            ),
                          ),
                          barGroups: sorted.take(5).toList().asMap().entries.map((entry) {
                            return BarChartGroupData(
                              x: entry.key,
                              barRods: [BarChartRodData(toY: entry.value.value.toDouble(), color: kPrimaryBlue, width: 30)],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView.builder(
                    itemCount: sorted.length,
                    itemBuilder: (c, i) => ListTile(
                        leading: CircleAvatar(backgroundColor: kPrimaryBlue, child: Text("#${i+1}", style: const TextStyle(color: Colors.white))),
                        title: Text(sorted[i].key),
                        trailing: Text("${sorted[i].value} Sold")
                    )
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
}

// ==========================================
// 11. TOP CATEGORIES WITH BAR CHART
// ==========================================
class TopCategoriesPage extends StatelessWidget {
  final VoidCallback onBack;
  final FirestoreService _firestoreService = FirestoreService();

  TopCategoriesPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar("Top Categories", onBack),
      body: FutureBuilder<List<CollectionReference>>(
        future: Future.wait([
          _firestoreService.getStoreCollection('Products'),
          _firestoreService.getStoreCollection('sales'),
        ]),
        builder: (context, collectionsSnapshot) {
          if (!collectionsSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final productsCollection = collectionsSnapshot.data![0];
          final salesCollection = collectionsSnapshot.data![1];

          return StreamBuilder<QuerySnapshot>(
            stream: productsCollection.snapshots(),
            builder: (context, productSnap) {
              if (!productSnap.hasData) return const Center(child: CircularProgressIndicator());
              Map<String, String> prodCat = {};
              for (var doc in productSnap.data!.docs) prodCat[doc['itemName']] = doc['category'] ?? 'Uncategorised';

              return StreamBuilder<QuerySnapshot>(
                  stream: salesCollection.snapshots(),
                  builder: (context, salesSnap) {
                if (!salesSnap.hasData) return const Center(child: CircularProgressIndicator());
                Map<String, double> catRev = {};
                for (var doc in salesSnap.data!.docs) {
                  for (var item in (doc['items'] as List)) {
                    String cat = prodCat[item['name']] ?? 'Uncategorised';
                    catRev[cat] = (catRev[cat]??0) + (double.tryParse(item['total'].toString())??0);
                  }
                }
                var sorted = catRev.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));

                return Column(
                  children: [
                    // BAR CHART FOR CATEGORIES
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.all(16),
                      height: 280,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Category Revenue", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 16),
                          Expanded(
                            child: BarChart(
                              BarChartData(
                                gridData: FlGridData(show: true, drawVerticalLine: false),
                                borderData: FlBorderData(show: true, border: const Border(bottom: BorderSide(color: Colors.grey), left: BorderSide(color: Colors.grey))),
                                titlesData: FlTitlesData(
                                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    axisNameWidget: const Text('Category', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 60,
                                      getTitlesWidget: (value, meta) {
                                        if (value.toInt() >= 0 && value.toInt() < sorted.length) {
                                          String name = sorted[value.toInt()].key;
                                          return Transform.rotate(
                                            angle: -0.5,
                                            child: Text(name.length > 8 ? '${name.substring(0, 8)}...' : name, style: const TextStyle(fontSize: 9)),
                                          );
                                        }
                                        return const Text('');
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    axisNameWidget: const Text('₹', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                      getTitlesWidget: (value, meta) => Text("₹${value~/1000}k", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                    ),
                                  ),
                                ),
                                barGroups: sorted.asMap().entries.map((entry) {
                                  return BarChartGroupData(
                                    x: entry.key,
                                    barRods: [BarChartRodData(toY: entry.value.value, color: kPrimaryBlue, width: 30)],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: ListView.builder(
                          itemCount: sorted.length,
                          itemBuilder: (c, i) => ListTile(
                              title: Text(sorted[i].key),
                              trailing: Text("₹${sorted[i].value.toStringAsFixed(0)}")
                          )
                      ),
                    ),
                  ],
                );
              }
          );
        },
      );
        },
      ),
    );
  }
}

// ==========================================
// 12. EXPENSE REPORT WITH COLUMN CHART
// ==========================================
class ExpenseReportPage extends StatelessWidget {
  final VoidCallback onBack;
  final FirestoreService _firestoreService = FirestoreService();

  ExpenseReportPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar("Expense Report", onBack),
      body: FutureBuilder<CollectionReference>(
        future: _firestoreService.getStoreCollection('expenses'),
        builder: (context, collectionSnapshot) {
          if (!collectionSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<QuerySnapshot>(
            stream: collectionSnapshot.data!.snapshots(),
            builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No Expenses Recorded"));

          Map<String, double> categoryExpenses = {};
          for (var doc in snapshot.data!.docs) {
            String category = (doc.data() as Map).containsKey('category') ? doc['category'] : 'Other';
            categoryExpenses[category] = (categoryExpenses[category] ?? 0) + (double.tryParse(doc['amount'].toString()) ?? 0);
          }

          return Column(
            children: [
              // COLUMN CHART FOR EXPENSE BREAKDOWN
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                height: 280,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    const Text("Expense by Category", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 16),
                    Expanded(
                      child: BarChart(
                        BarChartData(
                          gridData: FlGridData(show: true, drawVerticalLine: false),
                          borderData: FlBorderData(show: true, border: const Border(bottom: BorderSide(color: Colors.grey), left: BorderSide(color: Colors.grey))),
                          titlesData: FlTitlesData(
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              axisNameWidget: const Text('Category', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 60,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() >= 0 && value.toInt() < categoryExpenses.length) {
                                    String name = categoryExpenses.keys.elementAt(value.toInt());
                                    return Transform.rotate(
                                      angle: -0.5,
                                      child: Text(name.length > 8 ? '${name.substring(0, 8)}...' : name, style: const TextStyle(fontSize: 9)),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              axisNameWidget: const Text('₹', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) => Text("₹${value~/1000}k", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                              ),
                            ),
                          ),
                          barGroups: categoryExpenses.entries.toList().asMap().entries.map((entry) {
                            return BarChartGroupData(
                              x: entry.key,
                              barRods: [
                                BarChartRodData(
                                  toY: entry.value.value,
                                  color: kExpenseRed,
                                  width: 30,
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (c, i) {
                      var d = snapshot.data!.docs[i];
                      return ListTile(
                          title: Text(d['title']??'Expense'),
                          subtitle: Text(d['category'] ?? 'Other'),
                          trailing: Text("- ₹${d['amount']}", style: TextStyle(color: kExpenseRed, fontWeight: FontWeight.bold))
                      );
                    }
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
}

// ==========================================
// 13. TAX REPORT WITH LINE CHART
// ==========================================
class TaxReportPage extends StatelessWidget {
  final VoidCallback onBack;
  final FirestoreService _firestoreService = FirestoreService();

  TaxReportPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar("Tax Report", onBack),
      body: FutureBuilder<CollectionReference>(
        future: _firestoreService.getStoreCollection('sales'),
        builder: (context, collectionSnapshot) {
          if (!collectionSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<QuerySnapshot>(
            stream: collectionSnapshot.data!.snapshots(),
            builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          double totalTax = 0;
          Map<int, double> dailyTax = {};

          for (var doc in snapshot.data!.docs) {
            double tax = double.tryParse((doc.data() as Map)['taxAmount'].toString()) ?? 0;
            totalTax += tax;
            DateTime? dt = DateTime.tryParse(doc['date'] ?? '');
            if (dt != null && DateTime.now().difference(dt).inDays <= 30) {
              dailyTax[dt.day] = (dailyTax[dt.day] ?? 0) + tax;
            }
          }

          return Column(
              children: [
                _summaryBox("Total Tax Collected", "₹${totalTax.toStringAsFixed(2)}", "", kIncomeGreen),

                // LINE CHART FOR TAX TREND
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Tax Collection Trend (Last 30 Days)", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 16),
                      Expanded(
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(show: true, drawVerticalLine: false),
                            borderData: FlBorderData(show: true, border: const Border(bottom: BorderSide(color: Colors.grey), left: BorderSide(color: Colors.grey))),
                            titlesData: FlTitlesData(
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                axisNameWidget: const Text('Day', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 5,
                                  getTitlesWidget: (value, meta) => Text("${value.toInt()}", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                ),
                              ),
                              leftTitles: AxisTitles(
                                axisNameWidget: const Text('₹', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) => Text("₹${value.toInt()}", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                ),
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: dailyTax.entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                                isCurved: true,
                                color: kIncomeGreen,
                                barWidth: 3,
                                dotData: FlDotData(show: true),
                                belowBarData: BarAreaData(show: true, color: kIncomeGreen.withOpacity(0.2)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                    child: ListView.builder(
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (c, i) {
                          var d = snapshot.data!.docs[i].data() as Map;
                          return ListTile(
                              title: Text("Inv #${d['invoiceNumber']}"),
                              trailing: Text("Tax: ₹${d['taxAmount']??0}", style: TextStyle(color: kIncomeGreen))
                          );
                        }
                    )
                )
              ]
          );
        },
      );
        },
      ),
    );
  }
}

// ==========================================
// 14. HSN REPORT WITH BAR CHART
// ==========================================
class HSNReportPage extends StatelessWidget {
  final VoidCallback onBack;
  final FirestoreService _firestoreService = FirestoreService();

  HSNReportPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar("HSN Report", onBack),
      body: FutureBuilder<CollectionReference>(
        future: _firestoreService.getStoreCollection('Products'),
        builder: (context, collectionSnapshot) {
          if (!collectionSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<QuerySnapshot>(
            stream: collectionSnapshot.data!.snapshots(),
            builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          Map<String, int> hsnMap = {};
          for(var d in snapshot.data!.docs) {
            String h = d['hsn']??'N/A';
            hsnMap[h] = (hsnMap[h]??0)+1;
          }

          return Column(
            children: [
              // BAR CHART FOR HSN DISTRIBUTION
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                height: 280,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    const Text("HSN Code Distribution", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 16),
                    Expanded(
                      child: BarChart(
                        BarChartData(
                          gridData: FlGridData(show: true, drawVerticalLine: false),
                          borderData: FlBorderData(show: true, border: const Border(bottom: BorderSide(color: Colors.grey), left: BorderSide(color: Colors.grey))),
                          titlesData: FlTitlesData(
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              axisNameWidget: const Text('HSN Code', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 60,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() >= 0 && value.toInt() < hsnMap.length) {
                                    String code = hsnMap.keys.elementAt(value.toInt());
                                    return Transform.rotate(
                                      angle: -0.5,
                                      child: Text(code, style: const TextStyle(fontSize: 9)),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              axisNameWidget: const Text('Count', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 35,
                                getTitlesWidget: (value, meta) => Text("${value.toInt()}", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                              ),
                            ),
                          ),
                          barGroups: hsnMap.entries.toList().asMap().entries.map((entry) {
                            return BarChartGroupData(
                              x: entry.key,
                              barRods: [
                                BarChartRodData(
                                  toY: entry.value.value.toDouble(),
                                  color: kPrimaryBlue,
                                  width: 30,
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView.builder(
                    itemCount: hsnMap.length,
                    itemBuilder: (c, i) => ListTile(
                        title: Text("HSN: ${hsnMap.keys.elementAt(i)}"),
                        trailing: Text("${hsnMap.values.elementAt(i)} Products")
                    )
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
}

// ==========================================
// 15. STAFF SALE REPORT WITH BAR CHART
// ==========================================
class StaffSaleReportPage extends StatelessWidget {
  final VoidCallback onBack;
  final FirestoreService _firestoreService = FirestoreService();

  StaffSaleReportPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar("Staff Sales", onBack),
      body: FutureBuilder<CollectionReference>(
        future: _firestoreService.getStoreCollection('sales'),
        builder: (context, collectionSnapshot) {
          if (!collectionSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<QuerySnapshot>(
            stream: collectionSnapshot.data!.snapshots(),
            builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          Map<String, double> staffPerf = {};
          for(var d in snapshot.data!.docs) {
            String s = (d.data() as Map).containsKey('staffName') ? d['staffName'] : 'Admin';
            staffPerf[s] = (staffPerf[s]??0) + (double.tryParse(d['total'].toString())??0);
          }

          return Column(
            children: [
              // BAR CHART FOR STAFF PERFORMANCE
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                height: 280,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Staff Performance", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 16),
                    Expanded(
                      child: BarChart(
                        BarChartData(
                          gridData: FlGridData(show: true, drawVerticalLine: false),
                          borderData: FlBorderData(show: true, border: const Border(bottom: BorderSide(color: Colors.grey), left: BorderSide(color: Colors.grey))),
                          titlesData: FlTitlesData(
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              axisNameWidget: const Text('Staff Member', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 60,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() >= 0 && value.toInt() < staffPerf.length) {
                                    String name = staffPerf.keys.elementAt(value.toInt());
                                    return Transform.rotate(
                                      angle: -0.5,
                                      child: Text(name.length > 8 ? '${name.substring(0, 8)}...' : name, style: const TextStyle(fontSize: 9)),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              axisNameWidget: const Text('₹', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) => Text("₹${value~/1000}k", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                              ),
                            ),
                          ),
                          barGroups: staffPerf.entries.toList().asMap().entries.map((entry) {
                            return BarChartGroupData(
                              x: entry.key,
                              barRods: [BarChartRodData(toY: entry.value.value, color: kPrimaryBlue, width: 30)],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView.builder(
                    itemCount: staffPerf.length,
                    itemBuilder: (c, i) => ListTile(
                        leading: CircleAvatar(backgroundColor: kPrimaryBlue, child: Text(staffPerf.keys.elementAt(i).substring(0, 1), style: const TextStyle(color: Colors.white))),
                        title: Text(staffPerf.keys.elementAt(i)),
                        trailing: Text("₹${staffPerf.values.elementAt(i).toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold))
                    )
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
}

// ==========================================
// UI HELPER WIDGETS
// ==========================================
AppBar _buildAppBar(String title, VoidCallback onBack) {
  return AppBar(
    leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: onBack),
    title: Text(title, style: const TextStyle(color: Colors.white)),
    backgroundColor: kPrimaryBlue,
    elevation: 0,
    centerTitle: true,
  );
}

Widget _summaryBox(String title, String value, String subtitle, Color color) {
  return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white70)),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12))
          ]
      )
  );
}
