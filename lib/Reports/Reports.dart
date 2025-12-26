import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:maxbillup/components/common_bottom_nav.dart';
import 'package:maxbillup/utils/permission_helper.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/plan_permission_helper.dart';
import 'package:maxbillup/utils/plan_provider.dart';
import 'package:maxbillup/utils/translation_helper.dart';

// ==========================================
// MODERN DESIGN SYSTEM TOKENS
// ==========================================
const Color kPrimaryColor = Color(0xFF2F7CF6); // Material Blue
const Color kBackgroundColor = Colors.white; // Unified White Background
const Color kSurfaceColor = Colors.white;
const Color kTextPrimary = Color(0xFF1F2937); // Dark Grey
const Color kTextSecondary = Color(0xFF6B7280); // Cool Grey
final Color kBorderColor = Color(0xFFE3F2FD); // Subtle Border

// Feature Colors
const Color kIncomeGreen = Color(0xFF4CAF50);
const Color kExpenseRed = Color(0xFFFF5252);
const Color kWarningOrange = Color(0xFFFF9800);
const Color kPurpleCharts = Color(0xFF9C27B0);
const Color kTealCharts = Color(0xFF009688);

// Colorful Icon Palette (Diverse & Vibrant)
const Color kIndigoColor = Color(0xFF5C6BC0);
const Color kAmberColor = Color(0xFFFFA726);
const Color kCyanColor = Color(0xFF26C6DA);

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
      });
    }
  }

  bool get isAdmin => _role.toLowerCase() == 'admin' || _role.toLowerCase() == 'administrator';

  void _reset() => setState(() => _currentView = null);

  @override
  Widget build(BuildContext context) {
    // --- ROUTER LOGIC ---
    if (_currentView != null) {
      switch (_currentView) {
        case 'Analytics': return AnalyticsPage(uid: widget.uid, onBack: _reset);
        case 'DayBook': return DayBookPage(uid: widget.uid, onBack: _reset);
        case 'Summary': return SalesSummaryPage(onBack: _reset);
        case 'SalesReport': return FullSalesHistoryPage(onBack: _reset);
        case 'ExpenseReport': return ExpenseReportPage(onBack: _reset);
        case 'TopProducts': return TopProductsPage(uid: widget.uid, onBack: _reset);
        case 'LowStock': return LowStockPage(onBack: _reset);
        case 'ItemSales': return ItemSalesPage(onBack: _reset);
        case 'HSNReport': return HSNReportPage(onBack: _reset);
        case 'TopCategories': return TopCategoriesPage(onBack: _reset);
        case 'TopCustomers': return TopCustomersPage(uid: widget.uid, onBack: _reset);
        case 'StockReport': return StockReportPage(onBack: _reset);
        case 'StaffReport': return StaffSaleReportPage(onBack: _reset);
        case 'TaxReport': return TaxReportPage(onBack: _reset);
      }
    }

    // --- MAIN MENU UI - Always fetch fresh plan data from Firestore ---
    final planProvider = Provider.of<PlanProvider>(context);
    return FutureBuilder<String>(
      future: planProvider.getCurrentPlan(),
      builder: (context, snapshot) {
        final currentPlan = snapshot.data ?? 'Free';
        final isPaidPlan = currentPlan != 'Free';

        // Helper to check if feature available (fresh data every time)
        bool isFeatureAvailable(String permission) {
          if (isAdmin) return isPaidPlan;
          final userPerm = _permissions[permission] == true;
          return userPerm && isPaidPlan;
        }

        return Scaffold(
          backgroundColor: kBackgroundColor,
          appBar: AppBar(
            title: Text(context.tr('reports'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
            backgroundColor: kPrimaryColor,
            elevation: 0,
            centerTitle: true,
            automaticallyImplyLeading: false,
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
            children: [
              _sectionHeader(context.tr('analytics_overview')),
              _buildModernTile(context.tr('analytics'), Icons.insights_rounded, kPrimaryColor, 'Analytics', subtitle: 'Growth & Trends', isLocked: !isFeatureAvailable('analytics')),
              _buildModernTile(context.tr('daybook_today'), Icons.menu_book_rounded, kTealCharts, 'DayBook', subtitle: 'Daily transactions', isLocked: false), // FREE
              _buildModernTile(context.tr('sales_summary'), Icons.analytics_rounded, kIndigoColor, 'Summary', isLocked: !isFeatureAvailable('salesSummary')),

              // const SizedBox(height: 12),
              _sectionHeader(context.tr('sales_transactions')),
              _buildModernTile(context.tr('sales_report'), Icons.shopping_cart_rounded, kPurpleCharts, 'SalesReport', isLocked: !isFeatureAvailable('salesReport')),
              _buildModernTile(context.tr('item_sales_report'), Icons.shopping_bag_rounded, kCyanColor, 'ItemSales', isLocked: !isFeatureAvailable('itemSalesReport')),
              _buildModernTile(context.tr('top_customers'), Icons.emoji_events_rounded, kAmberColor, 'TopCustomers', isLocked: !isFeatureAvailable('topCustomer')),

              // const SizedBox(height: 12),
              _sectionHeader(context.tr('inventory_products')),
              _buildModernTile(context.tr('stock_report'), Icons.warehouse_rounded, kIndigoColor, 'StockReport', isLocked: !isFeatureAvailable('stockReport')),
              _buildModernTile(context.tr('low_stock_products'), Icons.inventory_rounded, kWarningOrange, 'LowStock', subtitle: 'Action Required', isLocked: !isFeatureAvailable('lowStockProduct')),
              _buildModernTile(context.tr('top_products'), Icons.trending_up_rounded, kIncomeGreen, 'TopProducts', isLocked: !isFeatureAvailable('topProducts')),
              _buildModernTile(context.tr('top_categories'), Icons.category_rounded, kPurpleCharts, 'TopCategories', isLocked: !isFeatureAvailable('topCategory')),

              // const SizedBox(height: 12),
              _sectionHeader(context.tr('financials_tax')),
              _buildModernTile(context.tr('expense_report'), Icons.account_balance_wallet_rounded, kExpenseRed, 'ExpenseReport', isLocked: !isFeatureAvailable('expensesReport')),
              _buildModernTile(context.tr('tax_report'), Icons.receipt_rounded, kIncomeGreen, 'TaxReport', isLocked: !isFeatureAvailable('taxReport')),
              _buildModernTile(context.tr('hsn_report'), Icons.assignment_rounded, kTealCharts, 'HSNReport', isLocked: !isFeatureAvailable('hsnReport')),
              _buildModernTile(context.tr('staff_sale_report'), Icons.person_rounded, kCyanColor, 'StaffReport', isLocked: !isFeatureAvailable('staffSalesReport')),
            ],
          ),
          bottomNavigationBar: CommonBottomNav(
            uid: widget.uid,
            userEmail: widget.userEmail,
            currentIndex: 1,
            screenWidth: MediaQuery.of(context).size.width,
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 12),
      child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.0)),
    );
  }

  Widget _buildModernTile(String title, IconData icon, Color iconColor, String viewName, {String? subtitle, bool isLocked = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 3, offset: const Offset(0, 1))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () {
            if (isLocked) {
              // Show upgrade dialog for locked reports with uid
              PlanPermissionHelper.showUpgradeDialog(context, title, uid: widget.uid);
            } else {
              setState(() => _currentView = viewName);
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: kTextPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle, style: const TextStyle(color: kTextSecondary, fontSize: 11)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  color: kTextSecondary.withOpacity(0.5),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// HELPER FUNCTIONS
// ==========================================

AppBar _buildModernAppBar(String title, VoidCallback onBack) {
  return AppBar(
    leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20), onPressed: onBack),
    title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
    backgroundColor: kPrimaryColor,
    elevation: 0,
    centerTitle: true,
  );
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
      backgroundColor: kBackgroundColor,
      appBar: _buildModernAppBar("Business Analytics", widget.onBack),
      body: FutureBuilder<List<Stream<QuerySnapshot>>>(
        future: Future.wait([
          _firestoreService.getCollectionStream('sales'),
          _firestoreService.getCollectionStream('expenses'),
          _firestoreService.getCollectionStream('stockPurchases'),
        ]),
        builder: (context, streamsSnapshot) {
          if (!streamsSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));

          final salesStream = streamsSnapshot.data![0];
          final expensesStream = streamsSnapshot.data![1];
          final stockPurchaseStream = streamsSnapshot.data![2];

          return StreamBuilder<QuerySnapshot>(
            stream: salesStream,
            builder: (context, salesSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: expensesStream,
                builder: (context, expenseSnap) {
                  return StreamBuilder<QuerySnapshot>(
                      stream: stockPurchaseStream,
                      builder: (context, stockSnap) {
                        if (!salesSnap.hasData || !expenseSnap.hasData || !stockSnap.hasData) {
                          return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                        }

                        final now = DateTime.now();
                        final todayStr = DateFormat('yyyy-MM-dd').format(now);

                        double todayRevenue = 0, todayExpense = 0, todayTax = 0;
                        double totalOnline = 0, totalCash = 0;
                        double periodIncome = 0, periodExpense = 0;
                        int todaySaleCount = 0, todayExpenseCount = 0;

                        Map<int, double> weekRevenue = {}, weekExpense = {};

                        // Process Sales
                        for (var doc in salesSnap.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          double amount = double.tryParse(data['total'].toString()) ?? 0.0;

                          // Use new totalTax structure with backward compatibility
                          double tax = double.tryParse(data['totalTax']?.toString() ?? '0') ?? 0.0;
                          if (tax == 0) {
                            tax = double.tryParse(data['taxAmount']?.toString() ?? data['tax']?.toString() ?? '0') ?? 0.0;
                          }

                          DateTime? dt;
                          if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                          else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());
                          String mode = (data['paymentMode'] ?? '').toString().toLowerCase();

                          if (dt != null) {
                            if (DateFormat('yyyy-MM-dd').format(dt) == todayStr) {
                              todayRevenue += amount;
                              todayTax += tax;
                              todaySaleCount++;
                            }
                            if (now.difference(dt).inDays <= 7) {
                              periodIncome += amount;
                              weekRevenue[dt.day] = (weekRevenue[dt.day] ?? 0) + amount;

                              // Payment Mode Stats for Pie Chart
                              if (mode.contains('online') || mode.contains('upi') || mode.contains('card')) {
                                totalOnline += amount;
                              } else {
                                totalCash += amount;
                              }
                            }
                          }
                        }

                        // Process Operational Expenses
                        for (var doc in expenseSnap.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          double amount = double.tryParse(data['amount'].toString()) ?? 0.0;
                          DateTime? dt;
                          if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                          else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());

                          if (dt != null) {
                            if (DateFormat('yyyy-MM-dd').format(dt) == todayStr) {
                              todayExpense += amount;
                              todayExpenseCount++;
                            }
                            if (now.difference(dt).inDays <= 7) {
                              periodExpense += amount;
                              weekExpense[dt.day] = (weekExpense[dt.day] ?? 0) + amount;
                            }
                          }
                        }

                        // Process Stock Purchases (as Expenses)
                        for (var doc in stockSnap.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          // Using 'total' or 'amount' field from stock purchase
                          double amount = double.tryParse(data['total']?.toString() ?? data['amount']?.toString() ?? '0') ?? 0.0;
                          DateTime? dt;
                          if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                          else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());

                          if (dt != null) {
                            if (DateFormat('yyyy-MM-dd').format(dt) == todayStr) {
                              todayExpense += amount; // Add to today's expense
                              todayExpenseCount++;
                            }
                            if (now.difference(dt).inDays <= 7) {
                              periodExpense += amount; // Add to period expense
                              weekExpense[dt.day] = (weekExpense[dt.day] ?? 0) + amount;
                            }
                          }
                        }

                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle("Today's Overview"),
                              const SizedBox(height: 12),
                              _buildHeroCard("Total Revenue", todayRevenue, Icons.payments_outlined, kPrimaryColor),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: _buildStatCard("Net Sales", "₹${todayRevenue.toStringAsFixed(0)}", "$todaySaleCount Orders", kPrimaryColor)),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildStatCard("Expenses", "₹${todayExpense.toStringAsFixed(0)}", "$todayExpenseCount records", kExpenseRed)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildStatCard("Tax Collected", "₹${todayTax.toStringAsFixed(2)}", "Today's Tax", kWarningOrange),

                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _sectionTitle("Analytics Trend"),
                                  DropdownButton<String>(
                                    value: _selectedDuration,
                                    underline: Container(),
                                    style: const TextStyle(fontSize: 12, color: kTextPrimary, fontWeight: FontWeight.bold),
                                    items: ['Last 7 Days', 'Last 30 Days'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                                    onChanged: (v) => setState(() => _selectedDuration = v!),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildChartContainer(
                                "Revenue vs Expense",
                                BarChart(
                                  BarChartData(
                                    gridData: FlGridData(show: false),
                                    borderData: FlBorderData(show: false),
                                    titlesData: FlTitlesData(
                                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: kTextSecondary))),
                                      ),
                                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    ),
                                    barTouchData: BarTouchData(
                                      touchTooltipData: BarTouchTooltipData(
                                        tooltipBgColor: kTextPrimary,
                                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                          return BarTooltipItem(
                                            rod.toY.toStringAsFixed(0),
                                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                          );
                                        },
                                      ),
                                    ),
                                    barGroups: _generateChartGroups(weekRevenue, weekExpense),
                                  ),
                                ),
                                height: 200,
                              ),
                              const SizedBox(height: 16),
                              _buildChartContainer(
                                "Payment Modes",
                                Row(
                                  children: [
                                    Expanded(
                                      child: AspectRatio(
                                        aspectRatio: 1,
                                        child: PieChart(
                                          PieChartData(
                                            sectionsSpace: 2,
                                            centerSpaceRadius: 30,
                                            sections: [
                                              PieChartSectionData(color: kPrimaryColor, value: totalCash, title: '${((totalCash/(totalCash+totalOnline == 0 ? 1 : totalCash+totalOnline))*100).toStringAsFixed(0)}%', radius: 40, titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                              PieChartSectionData(color: kPurpleCharts, value: totalOnline, title: '${((totalOnline/(totalCash+totalOnline == 0 ? 1 : totalCash+totalOnline))*100).toStringAsFixed(0)}%', radius: 40, titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        _buildLegendItem(kPrimaryColor, "Cash", totalCash),
                                        const SizedBox(height: 8),
                                        _buildLegendItem(kPurpleCharts, "Online", totalOnline),
                                      ],
                                    ),
                                    const SizedBox(width: 16),
                                  ],
                                ),
                                height: 150,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(child: _buildTrendCard("Income", periodIncome, true)),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildTrendCard("Expense", periodExpense, false)),
                                ],
                              ),
                            ],
                          ),
                        );
                      }
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, double value) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Text("₹${value.toStringAsFixed(0)}", style: const TextStyle(fontSize: 10, color: kTextSecondary)),
          ],
        )
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kTextSecondary, letterSpacing: 0.5));
  }

  Widget _buildHeroCard(String title, double value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              Text("₹${value.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white)),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [CircleAvatar(radius: 4, backgroundColor: color), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 12, color: kTextSecondary))]),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextPrimary)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
        ],
      ),
    );
  }

  Widget _buildChartContainer(String title, Widget chart, {double height = 200}) {
    return Container(
      height: height + 60,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kTextPrimary)),
          const SizedBox(height: 20),
          Expanded(child: chart),
        ],
      ),
    );
  }

  Widget _buildTrendCard(String title, double value, bool isIncome) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: kTextSecondary)),
            Icon(isIncome ? Icons.trending_up : Icons.trending_down, size: 16, color: isIncome ? kIncomeGreen : kExpenseRed)
          ]),
          const SizedBox(height: 8),
          Text("₹${value.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextPrimary)),
        ],
      ),
    );
  }

  List<BarChartGroupData> _generateChartGroups(Map<int, double> revenue, Map<int, double> expenses) {
    List<int> days = revenue.keys.toList()..addAll(expenses.keys.toList());
    days = days.toSet().toList()..sort();
    return days.map((day) {
      return BarChartGroupData(
        x: day,
        barRods: [
          BarChartRodData(
            toY: revenue[day] ?? 0,
            gradient: LinearGradient(
              colors: [kPrimaryColor, kPrimaryColor.withOpacity(0.6)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          BarChartRodData(
            toY: expenses[day] ?? 0,
            gradient: LinearGradient(
              colors: [kExpenseRed, kExpenseRed.withOpacity(0.6)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();
  }
}

// ==========================================
// 3. DAYBOOK
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
      backgroundColor: kBackgroundColor,
      appBar: _buildModernAppBar("DayBook", onBack),
      body: FutureBuilder<Stream<QuerySnapshot>>(
        future: _firestoreService.getCollectionStream('sales'),
        builder: (context, streamSnapshot) {
          if (!streamSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          return StreamBuilder<QuerySnapshot>(
            stream: streamSnapshot.data!,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));

              final allDocs = snapshot.data!.docs;
              var todayDocs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                DateTime? dt;
                if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());
                if (dt == null) return false;
                return DateFormat('yyyy-MM-dd').format(dt) == todayDateStr;
              }).toList();

              double total = todayDocs.fold(0, (sum, doc) {
                final data = doc.data() as Map<String, dynamic>;
                return sum + (double.tryParse(data['total']?.toString() ?? '0') ?? 0);
              });

              Map<int, double> hourlyRevenue = {};
              for (var doc in todayDocs) {
                final data = doc.data() as Map<String, dynamic>;
                DateTime? dt;
                if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                if (dt != null) {
                  double saleTotal = double.tryParse(data['total']?.toString() ?? '0') ?? 0;
                  hourlyRevenue[dt.hour] = (hourlyRevenue[dt.hour] ?? 0) + saleTotal;
                }
              }

              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kPrimaryColor, Color(0xFF64B5F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: kPrimaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text("Today's Revenue", style: TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text("₹${total.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                        ]),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Text("${todayDocs.length} Bills", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),

                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: kSurfaceColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        border: Border(top: BorderSide(color: kBorderColor)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, -2))
                        ],
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: SizedBox(
                              height: 150,
                              child: LineChart(
                                LineChartData(
                                  gridData: FlGridData(show: false),
                                  titlesData: FlTitlesData(show: false),
                                  borderData: FlBorderData(show: false),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: hourlyRevenue.entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                                      isCurved: true,
                                      gradient: LinearGradient(
                                        colors: [kPrimaryColor, kPrimaryColor.withOpacity(0.5)],
                                      ),
                                      barWidth: 4,
                                      isStrokeCapRound: true,
                                      dotData: FlDotData(show: true),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        gradient: LinearGradient(
                                          colors: [kPrimaryColor.withOpacity(0.2), kPrimaryColor.withOpacity(0.0)],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: todayDocs.length,
                              separatorBuilder: (c, i) => const Divider(height: 1, indent: 60),
                              itemBuilder: (context, index) {
                                var docData = todayDocs[index].data() as Map<String, dynamic>;
                                double saleTotal = double.tryParse(docData['total']?.toString() ?? '0') ?? 0;
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(backgroundColor: kBackgroundColor, child: Icon(Icons.receipt_long, size: 18, color: kTextSecondary)),
                                  title: Text(docData['customerName'] ?? 'Walk-in', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  subtitle: Text("#${docData['invoiceNumber'] ?? 'N/A'}", style: const TextStyle(fontSize: 12, color: kTextSecondary)),
                                  trailing: Text("₹${saleTotal.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryColor, fontSize: 15)),
                                );
                              },
                            ),
                          ),
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
}

// ==========================================
// 4. SALES SUMMARY
// ==========================================
class SalesSummaryPage extends StatelessWidget {
  final VoidCallback onBack;
  final FirestoreService _firestoreService = FirestoreService();

  SalesSummaryPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: _buildModernAppBar("Summary", onBack),
      body: FutureBuilder<List<Stream<QuerySnapshot>>>(
        future: Future.wait([_firestoreService.getCollectionStream('sales'), _firestoreService.getCollectionStream('expenses')]),
        builder: (context, streamsSnapshot) {
          if (!streamsSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          return StreamBuilder<QuerySnapshot>(
            stream: streamsSnapshot.data![0],
            builder: (context, salesSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: streamsSnapshot.data![1],
                builder: (context, expenseSnapshot) {
                  if (!salesSnapshot.hasData || !expenseSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));

                  final now = DateTime.now();
                  final todayStr = DateFormat('yyyy-MM-dd').format(now);
                  double todayIncome = 0, todayExpense = 0;

                  for (var doc in salesSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    DateTime? dt;
                    if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                    if (dt != null && DateFormat('yyyy-MM-dd').format(dt) == todayStr) {
                      todayIncome += double.tryParse(data['total'].toString()) ?? 0;
                    }
                  }

                  for (var doc in expenseSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    DateTime? dt;
                    if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                    if (dt != null && DateFormat('yyyy-MM-dd').format(dt) == todayStr) {
                      todayExpense += double.tryParse(data['amount'].toString()) ?? 0;
                    }
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryCard("Total Income Today", todayIncome, kIncomeGreen, Icons.trending_up),
                        const SizedBox(height: 16),
                        _buildSummaryCard("Total Expenses Today", todayExpense, kExpenseRed, Icons.trending_down),
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

  Widget _buildSummaryCard(String title, double value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: kSurfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBorderColor),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: kTextSecondary, fontSize: 13)),
              const SizedBox(height: 4),
              Text("₹${value.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: kTextPrimary)),
            ],
          )
        ],
      ),
    );
  }
}

// ==========================================
// 5. FULL SALES REPORT
// ==========================================
class FullSalesHistoryPage extends StatelessWidget {
  final VoidCallback onBack;
  final FirestoreService _firestoreService = FirestoreService();

  FullSalesHistoryPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: _buildModernAppBar("Sales Report", onBack),
      body: FutureBuilder<Stream<QuerySnapshot>>(
        future: _firestoreService.getCollectionStream('sales'),
        builder: (context, streamSnapshot) {
          if (!streamSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          return StreamBuilder<QuerySnapshot>(
            stream: streamSnapshot.data!,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
              List<DocumentSnapshot> docs = snapshot.data!.docs;

              // Calculate daily sales for chart
              Map<String, double> dailySales = {};
              for (var doc in docs) {
                var d = doc.data() as Map<String, dynamic>;
                if (d['timestamp'] != null) {
                  DateTime dt = (d['timestamp'] as Timestamp).toDate();
                  String dateKey = DateFormat('MMM dd').format(dt);
                  double total = double.tryParse(d['total']?.toString() ?? '0') ?? 0;
                  dailySales[dateKey] = (dailySales[dateKey] ?? 0) + total;
                }
              }
              var sortedDays = dailySales.entries.toList().take(7).toList();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Line Chart
                    Container(
                      height: 250,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: kSurfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorderColor)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Sales Trend (Last 7 Days)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 20),
                          Expanded(
                            child: LineChart(
                              LineChartData(
                                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: kBorderColor, strokeWidth: 1)),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (value, meta) {
                                    if (value.toInt() < 0 || value.toInt() >= sortedDays.length) return const Text('');
                                    return Text(sortedDays[value.toInt()].key, style: const TextStyle(fontSize: 9));
                                  })),
                                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50, getTitlesWidget: (value, meta) => Text('₹${(value / 1000).toStringAsFixed(0)}k', style: const TextStyle(fontSize: 9, color: kTextSecondary)))),
                                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(show: false),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: List.generate(sortedDays.length, (index) => FlSpot(index.toDouble(), sortedDays[index].value)),
                                    isCurved: true,
                                    color: kIncomeGreen,
                                    barWidth: 3,
                                    dotData: FlDotData(show: true),
                                    belowBarData: BarAreaData(show: true, color: kIncomeGreen.withValues(alpha: 0.1)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Sales List
                    ...docs.map((doc) {
                      var d = doc.data() as Map<String, dynamic>;
                      DateTime? dt;
                      if (d['timestamp'] != null) dt = (d['timestamp'] as Timestamp).toDate();
                      String dateStr = dt != null ? DateFormat('dd MMM, h:mm a').format(dt) : 'N/A';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(color: kSurfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorderColor)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          title: Text(d['customerName'] ?? 'Walk-in', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(dateStr, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
                          trailing: Text("₹${d['total']}", style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryColor, fontSize: 15)),
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
    );
  }
}

// ==========================================
// 6. TOP CUSTOMERS
// ==========================================
class TopCustomersPage extends StatelessWidget {
  final String uid;
  final VoidCallback onBack;
  final FirestoreService _firestoreService = FirestoreService();

  TopCustomersPage({super.key, required this.uid, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: _buildModernAppBar("Top Customers", onBack),
      body: FutureBuilder<Stream<QuerySnapshot>>(
        future: _firestoreService.getCollectionStream('sales'),
        builder: (context, streamSnapshot) {
          if (!streamSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          return StreamBuilder<QuerySnapshot>(
            stream: streamSnapshot.data!,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
              Map<String, double> spend = {};
              for (var d in snapshot.data!.docs) {
                var data = d.data() as Map<String, dynamic>;
                double amt = double.tryParse(data['total'].toString()) ?? 0;
                spend[data['customerName'] ?? 'Unknown'] = (spend[data['customerName'] ?? 'Unknown'] ?? 0) + amt;
              }
              var sorted = spend.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              var top5 = sorted.take(5).toList();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      height: 300,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: kSurfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorderColor)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Top Customers by Sales", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 20),
                          Expanded(
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: top5.isEmpty ? 100 : top5.first.value * 1.2,
                                barTouchData: BarTouchData(enabled: false),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        if (value.toInt() < 0 || value.toInt() >= top5.length) return const Text('');
                                        String name = top5[value.toInt()].key;
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text(
                                            name.length > 8 ? '${name.substring(0, 8)}...' : name,
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          '₹${(value / 1000).toStringAsFixed(0)}k',
                                          style: const TextStyle(fontSize: 10, color: kTextSecondary),
                                        );
                                      },
                                    ),
                                  ),
                                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  horizontalInterval: top5.isEmpty ? 20 : top5.first.value / 4,
                                  getDrawingHorizontalLine: (value) {
                                    return FlLine(color: kBorderColor, strokeWidth: 1);
                                  },
                                ),
                                borderData: FlBorderData(show: false),
                                barGroups: List.generate(top5.length, (index) {
                                  return BarChartGroupData(
                                    x: index,
                                    barRods: [
                                      BarChartRodData(
                                        toY: top5[index].value,
                                        color: Colors.primaries[index % Colors.primaries.length],
                                        width: 30,
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                      ),
                                    ],
                                  );
                                }),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...sorted.map((e) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(color: kSurfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorderColor)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.primaries[sorted.indexOf(e) % Colors.primaries.length].withOpacity(0.1),
                          child: Text(
                            e.key[0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.primaries[sorted.indexOf(e) % Colors.primaries.length],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: Text("₹${e.value.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryColor)),
                      ),
                    )).toList(),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ==========================================
// 7. STOCK REPORT
// ==========================================
class StockReportPage extends StatelessWidget {
  final VoidCallback onBack;
  final FirestoreService _firestoreService = FirestoreService();

  StockReportPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: _buildModernAppBar("Stock Report", onBack),
      body: FutureBuilder<Stream<QuerySnapshot>>(
        future: _firestoreService.getCollectionStream('Products'),
        builder: (context, streamSnapshot) {
          if (!streamSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          return StreamBuilder<QuerySnapshot>(
            stream: streamSnapshot.data!,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
              double totalVal = 0;
              int lowStockCount = 0;
              int outOfStockCount = 0;

              for (var d in snapshot.data!.docs) {
                var data = d.data() as Map<String, dynamic>;
                double price = double.tryParse(data['price'].toString()) ?? 0;
                double stock = double.tryParse(data['currentStock'].toString()) ?? 0; // Using double just in case
                if (stock > 0) totalVal += price * stock; // Ignore negative stock value
                if (stock <= 0) outOfStockCount++;
                else if (stock < 5) lowStockCount++;
              }

              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [kPrimaryColor, Color(0xFF64B5F6)]), borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        const Text("Total Inventory Value", style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 8),
                        Text("₹${totalVal.toStringAsFixed(0)}", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(child: _buildStockStatCard("Low Stock", "$lowStockCount", kWarningOrange)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStockStatCard("Out of Stock", "$outOfStockCount", kExpenseRed)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: snapshot.data!.docs.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 8),
                      itemBuilder: (c, i) {
                        var d = snapshot.data!.docs[i].data() as Map<String, dynamic>;
                        return Container(
                          decoration: BoxDecoration(color: kSurfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorderColor)),
                          child: ListTile(
                            title: Text(d['itemName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text("Price: ₹${d['price'] ?? 0}", style: const TextStyle(color: kTextSecondary)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                              child: Text("${d['currentStock'] ?? 0} Units", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
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
      ),
    );
  }

  Widget _buildStockStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kSurfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

// ==========================================
// 8. OTHER PAGES (Enhanced Functionality)
// ==========================================

class ItemSalesPage extends StatelessWidget {
  final VoidCallback onBack;
  final FirestoreService _firestoreService = FirestoreService();
  ItemSalesPage({super.key, required this.onBack});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBackgroundColor,
    appBar: _buildModernAppBar("Item Sales", onBack),
    body: FutureBuilder<Stream<QuerySnapshot>>(
      future: _firestoreService.getCollectionStream('sales'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
        return StreamBuilder<QuerySnapshot>(
          stream: snapshot.data!,
          builder: (context, salesSnap) {
            if (!salesSnap.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
            Map<String, int> qty = {};
            for (var d in salesSnap.data!.docs) {
              var data = d.data() as Map<String, dynamic>;
              if (data['items'] != null) {
                for (var item in (data['items'] as List)) {
                  qty[item['name']] = (qty[item['name']] ?? 0) + (int.tryParse(item['quantity'].toString()) ?? 0);
                }
              }
            }
            var sorted = qty.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
            var top5 = sorted.take(5).toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    height: 300,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: kSurfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorderColor)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Top Selling Items", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 20),
                        Expanded(
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: top5.isEmpty ? 100 : top5.first.value * 1.2,
                              barTouchData: BarTouchData(enabled: false),
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      if (value.toInt() < 0 || value.toInt() >= top5.length) return const Text('');
                                      String name = top5[value.toInt()].key;
                                      return Padding(padding: const EdgeInsets.only(top: 8), child: Text(name.length > 8 ? '${name.substring(0, 8)}...' : name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)));
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (value, meta) => Text('${value.toInt()}', style: const TextStyle(fontSize: 10, color: kTextSecondary)))),
                                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: kBorderColor, strokeWidth: 1)),
                              borderData: FlBorderData(show: false),
                              barGroups: List.generate(top5.length, (index) => BarChartGroupData(x: index, barRods: [BarChartRodData(toY: top5[index].value.toDouble(), color: Colors.primaries[index % Colors.primaries.length], width: 30, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))])),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...sorted.map((e) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(color: kSurfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorderColor)),
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: kPrimaryColor.withValues(alpha: 0.1), child: Text("#${sorted.indexOf(e) + 1}", style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryColor, fontSize: 12))),
                      title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: Text("${e.value} Sold", style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold)),
                    ),
                  )).toList(),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}

class LowStockPage extends StatelessWidget {
  final VoidCallback onBack;
  final FirestoreService _firestoreService = FirestoreService();
  LowStockPage({super.key, required this.onBack});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: _buildModernAppBar("Low Stock Alert", onBack),
      body: FutureBuilder<Stream<QuerySnapshot>>(
        future: _firestoreService.getCollectionStream('Products'),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          return StreamBuilder<QuerySnapshot>(
            stream: snapshot.data!,
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
              var lowStock = snap.data!.docs.where((d) => (double.tryParse((d.data() as Map)['currentStock'].toString()) ?? 0) < 5).toList();
              var sorted = lowStock.map((d) {
                var map = d.data() as Map<String, dynamic>;
                return MapEntry(map['itemName'] ?? 'Unknown', (map['currentStock'] ?? 0) as num);
              }).toList()..sort((a, b) => a.value.compareTo(b.value));
              var top5 = sorted.take(5).toList();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      height: 300,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: kSurfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorderColor)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Critical Stock Levels", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 20),
                          Expanded(
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: 10,
                                barTouchData: BarTouchData(enabled: false),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                                    if (value.toInt() < 0 || value.toInt() >= top5.length) return const Text('');
                                    String name = top5[value.toInt()].key;
                                    return Padding(padding: const EdgeInsets.only(top: 8), child: Text(name.length > 8 ? '${name.substring(0, 8)}...' : name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)));
                                  })),
                                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (value, meta) => Text('${value.toInt()}', style: const TextStyle(fontSize: 10, color: kTextSecondary)))),
                                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: kBorderColor, strokeWidth: 1)),
                                borderData: FlBorderData(show: false),
                                barGroups: List.generate(top5.length, (index) => BarChartGroupData(x: index, barRods: [BarChartRodData(toY: top5[index].value.toDouble(), color: kExpenseRed, width: 30, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))])),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...sorted.map((e) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(color: kSurfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorderColor)),
                      child: ListTile(
                        leading: const Icon(Icons.warning_amber_rounded, color: kExpenseRed),
                        title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(height: 8, width: 60, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)), child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: (e.value.toDouble() / 10).clamp(0, 1), child: Container(decoration: BoxDecoration(color: kExpenseRed, borderRadius: BorderRadius.circular(4))))),
                          const SizedBox(width: 8),
                          Text("${e.value} Left", style: const TextStyle(color: kExpenseRed, fontWeight: FontWeight.bold))
                        ]),
                      ),
                    )).toList(),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class TopProductsPage extends StatelessWidget {
  final String uid; final VoidCallback onBack;
  TopProductsPage({super.key, required this.uid, required this.onBack});
  @override
  Widget build(BuildContext context) => ItemSalesPage(onBack: onBack).build(context);
}

class TopCategoriesPage extends StatelessWidget {
  final VoidCallback onBack;
  final FirestoreService _firestoreService = FirestoreService();
  TopCategoriesPage({super.key, required this.onBack});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: _buildModernAppBar("Top Categories", onBack),
      body: FutureBuilder<Stream<QuerySnapshot>>(
        future: _firestoreService.getCollectionStream('Products'),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          return StreamBuilder<QuerySnapshot>(
            stream: snapshot.data!,
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
              Map<String, int> catCount = {};
              for (var d in snap.data!.docs) {
                var data = d.data() as Map<String, dynamic>;
                String cat = data['category'] ?? 'Uncategorized';
                catCount[cat] = (catCount[cat] ?? 0) + 1;
              }
              var sorted = catCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              var top5 = sorted.take(5).toList();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      height: 300,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: kSurfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorderColor)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Product Distribution by Category", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 20),
                          Expanded(
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: top5.isEmpty ? 100 : top5.first.value * 1.2,
                                barTouchData: BarTouchData(enabled: false),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                                    if (value.toInt() < 0 || value.toInt() >= top5.length) return const Text('');
                                    String name = top5[value.toInt()].key;
                                    return Padding(padding: const EdgeInsets.only(top: 8), child: Text(name.length > 8 ? '${name.substring(0, 8)}...' : name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)));
                                  })),
                                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (value, meta) => Text('${value.toInt()}', style: const TextStyle(fontSize: 10, color: kTextSecondary)))),
                                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: kBorderColor, strokeWidth: 1)),
                                borderData: FlBorderData(show: false),
                                barGroups: List.generate(top5.length, (index) => BarChartGroupData(x: index, barRods: [BarChartRodData(toY: top5[index].value.toDouble(), color: kTealCharts, width: 30, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))])),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...sorted.map((e) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(color: kSurfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorderColor)),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: kTealCharts.withValues(alpha: 0.1), child: const Icon(Icons.category, color: kTealCharts, size: 20)),
                        title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: Text("${e.value} Products", style: const TextStyle(color: kTealCharts, fontWeight: FontWeight.bold)),
                      ),
                    )).toList(),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ExpenseReportPage extends StatelessWidget {
  final VoidCallback onBack;
  final FirestoreService _firestoreService = FirestoreService();
  ExpenseReportPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: _buildModernAppBar("Total Expenses", onBack),
      body: FutureBuilder<List<Stream<QuerySnapshot>>>(
        future: Future.wait([_firestoreService.getCollectionStream('expenses'), _firestoreService.getCollectionStream('stockPurchases')]),
        builder: (context, streams) {
          if (!streams.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          return StreamBuilder<QuerySnapshot>(
            stream: streams.data![0],
            builder: (ctx, expSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: streams.data![1],
                builder: (ctx, stockSnap) {
                  if (!expSnap.hasData || !stockSnap.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));

                  List<Map<String, dynamic>> all = [];
                  double totalOp = 0;
                  double totalStock = 0;

                  for(var d in expSnap.data!.docs) {
                    var data = d.data() as Map<String, dynamic>;
                    double amt = double.tryParse(data['amount'].toString()) ?? 0;
                    totalOp += amt;
                    all.add({'title': data['title']??'Expense', 'amount': amt, 'type': 'Operational'});
                  }
                  for(var d in stockSnap.data!.docs) {
                    var data = d.data() as Map<String, dynamic>;
                    double amt = double.tryParse(data['total']?.toString() ?? data['amount']?.toString() ?? '0') ?? 0;
                    totalStock += amt;
                    all.add({'title': 'Stock Purchase', 'amount': amt, 'type': 'Stock'});
                  }

                  double totalExpenses = totalOp + totalStock;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Summary Cards
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: kSurfaceColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: kBorderColor),
                                  boxShadow: [BoxShadow(color: kExpenseRed.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.money_off, color: kExpenseRed, size: 20),
                                        const SizedBox(width: 8),
                                        const Text('Operational', style: TextStyle(fontSize: 12, color: kTextSecondary)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text('₹${totalOp.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kExpenseRed)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: kSurfaceColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: kBorderColor),
                                  boxShadow: [BoxShadow(color: kWarningOrange.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.inventory, color: kWarningOrange, size: 20),
                                        const SizedBox(width: 8),
                                        const Text('Stock', style: TextStyle(fontSize: 12, color: kTextSecondary)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text('₹${totalStock.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kWarningOrange)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 300,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: kSurfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorderColor)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Expense Breakdown", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 8),
                              Text("Total: ₹${totalExpenses.toStringAsFixed(0)}", style: const TextStyle(fontSize: 14, color: kTextSecondary)),
                              const SizedBox(height: 20),
                              Expanded(
                                child: BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    maxY: totalExpenses > 0 ? totalExpenses * 1.2 : 100,
                                    minY: 0,
                                    barTouchData: BarTouchData(enabled: false),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            if (value == 0) return const Padding(padding: EdgeInsets.only(top: 8), child: Text('Operational', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)));
                                            if (value == 1) return const Padding(padding: EdgeInsets.only(top: 8), child: Text('Stock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)));
                                            return const Text('');
                                          },
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 50,
                                          getTitlesWidget: (value, meta) {
                                            if (value >= 1000) {
                                              return Text('₹${(value / 1000).toStringAsFixed(0)}k', style: const TextStyle(fontSize: 10, color: kTextSecondary));
                                            }
                                            return Text('₹${value.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: kTextSecondary));
                                          },
                                        ),
                                      ),
                                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    ),
                                    gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: kBorderColor, strokeWidth: 1)),
                                    borderData: FlBorderData(show: false),
                                    barGroups: [
                                      BarChartGroupData(
                                        x: 0,
                                        barRods: [BarChartRodData(
                                          toY: totalOp > 0 ? totalOp : 0.1,
                                          color: kExpenseRed,
                                          width: 60,
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8))
                                        )]
                                      ),
                                      BarChartGroupData(
                                        x: 1,
                                        barRods: [BarChartRodData(
                                          toY: totalStock > 0 ? totalStock : 0.1,
                                          color: kWarningOrange,
                                          width: 60,
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8))
                                        )]
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...all.map((e) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(color: kSurfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorderColor)),
                          child: ListTile(
                            leading: Icon(e['type'] == 'Stock' ? Icons.inventory : Icons.money_off, color: kExpenseRed),
                            title: Text(e['title']),
                            subtitle: Text(e['type'], style: const TextStyle(fontSize: 12, color: kTextSecondary)),
                            trailing: Text("- ₹${e['amount']}", style: const TextStyle(color: kExpenseRed, fontWeight: FontWeight.bold)),
                          ),
                        ))
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
}

class TaxReportPage extends StatelessWidget {
  final VoidCallback onBack;
  final FirestoreService _firestoreService = FirestoreService();

  TaxReportPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: _buildModernAppBar("Tax Report", onBack),
      body: FutureBuilder<Stream<QuerySnapshot>>(
        future: _firestoreService.getCollectionStream('sales'),
        builder: (context, streamSnapshot) {
          if (!streamSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          return StreamBuilder<QuerySnapshot>(
            stream: streamSnapshot.data!,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));

              double totalTaxAmount = 0;
              Map<String, double> taxBreakdown = {}; // Tax type -> total amount
              var taxableDocs = <Map<String, dynamic>>[];

              for (var d in snapshot.data!.docs) {
                var data = d.data() as Map<String, dynamic>;

                // Get total tax from the new structure
                double saleTax = double.tryParse(data['totalTax']?.toString() ?? '0') ?? 0;

                // If totalTax doesn't exist, try old structure for backward compatibility
                if (saleTax == 0) {
                  saleTax = double.tryParse(data['taxAmount']?.toString() ?? data['tax']?.toString() ?? '0') ?? 0;
                }

                if (saleTax > 0) {
                  totalTaxAmount += saleTax;

                  // Process tax breakdown by type
                  if (data['taxes'] != null && data['taxes'] is List) {
                    List<dynamic> taxes = data['taxes'] as List<dynamic>;
                    for (var taxItem in taxes) {
                      if (taxItem is Map<String, dynamic>) {
                        String taxName = taxItem['name']?.toString() ?? 'Tax';
                        double taxAmount = double.tryParse(taxItem['amount']?.toString() ?? '0') ?? 0;
                        taxBreakdown[taxName] = (taxBreakdown[taxName] ?? 0) + taxAmount;
                      }
                    }
                  } else {
                    // Fallback: if no breakdown, add to "Tax" category
                    taxBreakdown['Tax'] = (taxBreakdown['Tax'] ?? 0) + saleTax;
                  }

                  // Add document with tax info for display
                  data['calculatedTax'] = saleTax;
                  taxableDocs.add(data);
                }
              }

              // Sort tax breakdown by amount (highest first)
              var sortedTaxTypes = taxBreakdown.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              return Column(
                children: [
                  // Total Tax Card
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [kIncomeGreen, Color(0xFF81C784)]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: kIncomeGreen.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                    ),
                    child: Column(
                      children: [
                        const Text("Total Tax Collected", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Text("₹${totalTaxAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text("${taxableDocs.length} taxable transactions", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),

                  // Tax Breakdown by Type
                  if (sortedTaxTypes.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Tax Breakdown", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextPrimary)),
                          const SizedBox(height: 12),
                          ...sortedTaxTypes.map((entry) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: kSurfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: kBorderColor),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: kIncomeGreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600, color: kIncomeGreen, fontSize: 13)),
                                ),
                                const Spacer(),
                                Text("₹${entry.value.toStringAsFixed(2)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextPrimary)),
                              ],
                            ),
                          )).toList(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Individual Transactions Header
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Taxable Transactions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextPrimary)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Individual Transactions List
                  Expanded(
                    child: taxableDocs.isEmpty
                      ? const Center(child: Text("No taxable transactions found", style: TextStyle(color: kTextSecondary)))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: taxableDocs.length,
                          separatorBuilder: (c, i) => const SizedBox(height: 8),
                          itemBuilder: (c, i) {
                            var d = taxableDocs[i];

                            // Get tax details for this transaction
                            String taxDetails = '';
                            if (d['taxes'] != null && d['taxes'] is List) {
                              List<dynamic> taxes = d['taxes'] as List<dynamic>;
                              taxDetails = taxes.map((t) {
                                if (t is Map<String, dynamic>) {
                                  return "${t['name']}: ₹${double.tryParse(t['amount']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'}";
                                }
                                return '';
                              }).where((s) => s.isNotEmpty).join(', ');
                            }

                            return Container(
                              decoration: BoxDecoration(
                                color: kSurfaceColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: kBorderColor)
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                title: Row(
                                  children: [
                                    Text("Inv #${d['invoiceNumber'] ?? 'N/A'}", style: const TextStyle(fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 8),
                                    if (d['date'] != null)
                                      Text(
                                        _formatDate(d['date']),
                                        style: const TextStyle(fontSize: 11, color: kTextSecondary),
                                      ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(d['customerName'] ?? 'Walk-in Customer', style: const TextStyle(fontSize: 12, color: kTextSecondary)),
                                    if (taxDetails.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(taxDetails, style: const TextStyle(fontSize: 11, color: kIncomeGreen, fontWeight: FontWeight.w500)),
                                    ],
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text("₹${(d['calculatedTax'] ?? 0).toStringAsFixed(2)}",
                                      style: const TextStyle(color: kIncomeGreen, fontWeight: FontWeight.bold, fontSize: 15)),
                                    const SizedBox(height: 2),
                                    Text("Total: ₹${(double.tryParse(d['total']?.toString() ?? '0') ?? 0).toStringAsFixed(2)}",
                                      style: const TextStyle(fontSize: 11, color: kTextSecondary)),
                                  ],
                                ),
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
      ),
    );
  }

  String _formatDate(dynamic date) {
    try {
      if (date is Timestamp) {
        return DateFormat('dd MMM').format(date.toDate());
      } else if (date is String) {
        return DateFormat('dd MMM').format(DateTime.parse(date));
      }
    } catch (e) {
      // Ignore
    }
    return '';
  }
}

class HSNReportPage extends StatelessWidget {
  final VoidCallback onBack;
  final FirestoreService _firestoreService = FirestoreService();
  HSNReportPage({super.key, required this.onBack});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: _buildModernAppBar("HSN Summary", onBack),
      body: FutureBuilder<Stream<QuerySnapshot>>(
        future: _firestoreService.getCollectionStream('Products'),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          return StreamBuilder<QuerySnapshot>(
            stream: snapshot.data!,
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
              Map<String, int> hsnMap = {};
              for (var d in snap.data!.docs) {
                var data = d.data() as Map<String, dynamic>;
                String h = data['hsnCode']?.toString() ?? data['hsn']?.toString() ?? 'N/A';
                if (h.isNotEmpty && h != 'N/A') hsnMap[h] = (hsnMap[h] ?? 0) + 1;
              }
              var sorted = hsnMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              var top5 = sorted.take(5).toList();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      height: 300,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: kSurfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorderColor)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Top HSN Codes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 20),
                          Expanded(
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: top5.isEmpty ? 100 : top5.first.value * 1.2,
                                barTouchData: BarTouchData(enabled: false),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                                    if (value.toInt() < 0 || value.toInt() >= top5.length) return const Text('');
                                    return Padding(padding: const EdgeInsets.only(top: 8), child: Text(top5[value.toInt()].key, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)));
                                  })),
                                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (value, meta) => Text('${value.toInt()}', style: const TextStyle(fontSize: 10, color: kTextSecondary)))),
                                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: kBorderColor, strokeWidth: 1)),
                                borderData: FlBorderData(show: false),
                                barGroups: List.generate(top5.length, (index) => BarChartGroupData(x: index, barRods: [BarChartRodData(toY: top5[index].value.toDouble(), color: kPurpleCharts, width: 30, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))])),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...sorted.map((e) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(color: kSurfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorderColor)),
                      child: ListTile(
                        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kPurpleCharts.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.tag, color: kPurpleCharts, size: 20)),
                        title: Text('HSN: ${e.key}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: Text("${e.value} Products", style: const TextStyle(color: kPurpleCharts, fontWeight: FontWeight.bold)),
                      ),
                    )).toList(),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class StaffSaleReportPage extends StatelessWidget {
  final VoidCallback onBack;
  StaffSaleReportPage({super.key, required this.onBack});
  @override
  Widget build(BuildContext context) => _SimpleListReport("Staff Performance", onBack, 'sales', (docs) {
    Map<String, double> staffPerf = {};
    for (var d in docs) {
      final data = d.data() as Map<String, dynamic>;
      final staffName = data['staffName']?.toString() ?? 'Admin'; // Default if null
      final total = double.tryParse(data['total']?.toString() ?? '0') ?? 0.0;
      staffPerf[staffName] = (staffPerf[staffName] ?? 0) + total;
    }
    return staffPerf.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }, (item) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(height: 8, width: 50, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)), child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: 0.8, child: Container(decoration: BoxDecoration(color: kIncomeGreen, borderRadius: BorderRadius.circular(4))))),
    const SizedBox(width: 8),
    Text("₹${item.value.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold))
  ]));
}

// Helper for simple list-based reports to reduce boilerplate
class _SimpleListReport extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final String collection;
  final List<MapEntry<dynamic, dynamic>> Function(List<DocumentSnapshot>) process;
  final Widget Function(MapEntry<dynamic, dynamic>) trailing;

  const _SimpleListReport(this.title, this.onBack, this.collection, this.process, this.trailing);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: _buildModernAppBar(title, onBack),
      body: FutureBuilder<Stream<QuerySnapshot>>(
        future: FirestoreService().getCollectionStream(collection),
        builder: (context, streamSnapshot) {
          if (!streamSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          return StreamBuilder<QuerySnapshot>(
            stream: streamSnapshot.data!,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
              final items = process(snapshot.data!.docs);
              if (items.isEmpty) return const Center(child: Text("No Data Available", style: TextStyle(color: kTextSecondary)));
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (c, i) => const SizedBox(height: 8),
                itemBuilder: (c, i) => Container(
                  decoration: BoxDecoration(
                    color: kSurfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorderColor),
                  ),
                  child: ListTile(
                    title: Text(items[i].key.toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: trailing(items[i]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}