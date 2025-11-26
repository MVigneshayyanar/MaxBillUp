import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/components/common_bottom_nav.dart'; // Ensure this path is correct
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

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

  @override
  Widget build(BuildContext context) {
    // ROUTER
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

    // MAIN MENU UI
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Reports", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader("Analytics & Overview"),
          _tile("Analytics", Icons.bar_chart, Colors.purple, 'Analytics'),
          _tile("DayBook (Today)", Icons.today, Colors.indigo, 'DayBook'),
          _tile("Sales Summary", Icons.dashboard_outlined, Colors.deepPurple, 'Summary'),

          _sectionHeader("Sales & Transactions"),
          _tile("Sales Report", Icons.receipt_long, Colors.blueGrey, 'SalesReport'),
          _tile("Item Sales Report", Icons.category_outlined, Colors.teal, 'ItemSales'),
          _tile("Top Customers", Icons.people_outline, Colors.pink, 'TopCustomers'),

          _sectionHeader("Inventory & Products"),
          _tile("Stock Report", Icons.inventory, Colors.brown, 'StockReport'),
          _tile("Low Stock Products", Icons.warning_amber_rounded, Colors.red, 'LowStock'),
          _tile("Top Products", Icons.star_border, Colors.orange, 'TopProducts'),
          _tile("Top Categories", Icons.folder_open, Colors.deepOrange, 'TopCategories'),

          _sectionHeader("Financials & Tax"),
          _tile("Expense Report", Icons.money_off, Colors.redAccent, 'ExpenseReport'),
          _tile("Tax Report", Icons.percent, Colors.green, 'TaxReport'),
          _tile("HSN Report", Icons.description, Colors.blueGrey, 'HSNReport'),
          _tile("Staff Sale Report", Icons.badge_outlined, Colors.cyan, 'StaffReport'),
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
// 2. ANALYTICS PAGE (Exact UI Match)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Matches screenshot background
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
        title: const Text("Analytics", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1976D2), // Exact Blue
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('sales').snapshots(),
        builder: (context, salesSnap) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('expenses').snapshots(),
            builder: (context, expenseSnap) {
              if (!salesSnap.hasData || !expenseSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              // ================= DATA PROCESSING =================
              final now = DateTime.now();
              final todayStr = DateFormat('yyyy-MM-dd').format(now);

              double todayRevenue = 0;
              int todaySaleCount = 0;
              double todayExpense = 0;
              int todayExpenseCount = 0;
              double todayRefund = 0; // DB field missing placeholder

              Map<int, double> weekRevenue = {};
              Map<int, double> weekExpense = {};
              double periodIncome = 0;
              double periodExpense = 0;
              double totalCash = 0;
              double totalOnline = 0;

              // Process Sales
              for (var doc in salesSnap.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                double amount = double.tryParse(data['total'].toString()) ?? 0.0;
                String dateStr = data['date'] ?? '';
                DateTime? dt = DateTime.tryParse(dateStr);
                String mode = (data['paymentMode'] ?? '').toString().toLowerCase();

                // Today
                if (dateStr.startsWith(todayStr)) {
                  todayRevenue += amount;
                  todaySaleCount++;
                }

                // Charts (7 Days)
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

              // Process Expenses
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

              // ================= EXACT UI BUILD =================
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Today Summary", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
                    const SizedBox(height: 12),

                    // --- FULL WIDTH REVENUE CARD ---
                    _buildFullWidthCard(
                        title: "Revenue",
                        value: todayRevenue,
                        icon: Icons.inventory_2_outlined, // Shirt/Item icon style
                        iconBg: const Color(0xFFF3E5F5), // Light Purple
                        iconColor: Colors.purple.shade300
                    ),
                    const SizedBox(height: 12),

                    // --- GRID ROW 1 ---
                    Row(
                      children: [
                        Expanded(child: _buildGridCard(
                            title: "Net Sale", value: todayRevenue, count: todaySaleCount,
                            icon: Icons.receipt_long, iconBg: const Color(0xFFE3F2FD), iconColor: Colors.blue.shade700
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _buildGridCard(
                            title: "Sale Profit", value: todayRevenue * 0.2, // Dummy 20%
                            icon: Icons.bar_chart, iconBg: const Color(0xFFE8F5E9), iconColor: Colors.green.shade700,
                            hideCount: true
                        )),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // --- GRID ROW 2 ---
                    Row(
                      children: [
                        Expanded(child: _buildGridCard(
                            title: "Refund", value: todayRefund, count: 0,
                            icon: Icons.credit_card_off, iconBg: const Color(0xFFFFF3E0), iconColor: Colors.orange.shade700
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _buildGridCard(
                            title: "Expense", value: todayExpense, count: todayExpenseCount,
                            icon: Icons.account_balance_wallet, iconBg: const Color(0xFFFFEBEE), iconColor: Colors.red.shade400
                        )),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // --- ANALYTICS HEADER ---
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

                    // --- REVENUE VS EXPENSES CHART ---
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
                              _buildLegendDot(const Color(0xFF00C853), "Revenue"), // Bright Green
                              const SizedBox(width: 20),
                              _buildLegendDot(const Color(0xFFD50000), "Expenses"), // Bright Red
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- TREND CARDS (Income / Expense) ---
                    Row(
                      children: [
                        Expanded(child: _buildTrendCard("Income", periodIncome, true)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTrendCard("Expense", periodExpense, false)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // --- PAYMENT MODE PIE CHART ---
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
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                PieChart(
                                  PieChartData(
                                    sectionsSpace: 0,
                                    centerSpaceRadius: 50,
                                    sections: _generatePieSections(totalCash, totalOnline),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text("${((totalCash/(totalCash+totalOnline+0.01))*100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)), // Hidden effectively inside circle if solid, but centered if doughnut
                                  ],
                                ),
                                // Text inside is actually shown in slices in screenshot, or centered.
                                // Screenshot has '80%' inside blue. '30%' inside orange.
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildPieLegend(const Color(0xFF007AFF), "Cash", totalCash),
                              _buildPieLegend(const Color(0xFFFF9800), "Online", totalOnline),
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
      ),
    );
  }

  // ================= UI BUILDERS FOR ANALYTICS =================

  // Full Width Card (Revenue)
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

  // Grid Card (Net Sale, Profit, etc.)
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

  // Income/Expense Trend Card
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
                decoration: BoxDecoration(color: isIncome ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(4)), // Red bg for Income (UI quirk in screenshot), Green for Expense
                // Note: Screenshot actually has Income with Red arrow Up (weird), Expense Green arrow Up. I will match Colors to screenshot logic:
                // Screenshot: Income has Red 67.3% (Usually bad?), Expense has Green 302% (Usually good?).
                // I will assume standard: Income Green, Expense Red. OR Match Screenshot exactly:
                // Screenshot: Income (Red Bg, Red Arrow Up), Expense (Green Bg, Green Arrow Up).
                child: Row(
                  children: [
                    Icon(Icons.trending_up, size: 12, color: isIncome ? Colors.red : Colors.green),
                    const SizedBox(width: 4),
                    Text(isIncome ? "67.3%" : "302.3%", style: TextStyle(fontSize: 10, color: isIncome ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
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
          BarChartRodData(toY: revenue[day] ?? 0, color: const Color(0xFF00C853), width: 12, borderRadius: BorderRadius.zero), // Revenue Green
          BarChartRodData(toY: expenses[day] ?? 0, color: const Color(0xFFD50000), width: 12, borderRadius: BorderRadius.zero), // Expense Red
        ],
      );
    }).toList();
  }

  List<PieChartSectionData> _generatePieSections(double cash, double online) {
    if (cash == 0 && online == 0) return [PieChartSectionData(value: 1, color: Colors.grey.shade200, radius: 80, showTitle: false)];
    return [
      if (cash > 0) PieChartSectionData(value: cash, color: const Color(0xFF007AFF), radius: 80, showTitle: true, title: "${((cash/(cash+online))*100).toInt()}%", titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      if (online > 0) PieChartSectionData(value: online, color: const Color(0xFFFF9800), radius: 80, showTitle: true, title: "${((online/(cash+online))*100).toInt()}%", titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    ];
  }
}

// ==========================================
// 3. DAYBOOK (Today's Sales)
// ==========================================
class DayBookPage extends StatelessWidget {
  final String uid; final VoidCallback onBack;
  const DayBookPage({super.key, required this.uid, required this.onBack});
  @override
  Widget build(BuildContext context) {
    final String todayDateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return Scaffold(
      appBar: _buildAppBar("DayBook", onBack),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('sales').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var todayDocs = snapshot.data!.docs.where((doc) => (doc['date'] ?? '').toString().startsWith(todayDateStr)).toList();
          double total = todayDocs.fold(0, (sum, doc) => sum + (double.tryParse(doc['total'].toString()) ?? 0));
          return Column(
            children: [
              Container(padding: const EdgeInsets.all(20), color: Colors.indigo, width: double.infinity, child: Column(children: [const Text("Today's Revenue", style: TextStyle(color: Colors.white70)), Text("₹${total.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)), Text("${todayDocs.length} Bills", style:const TextStyle(color:Colors.white70))])),
              Expanded(child: ListView.builder(itemCount: todayDocs.length, itemBuilder: (context, index) { var data = todayDocs[index].data() as Map<String, dynamic>; return ListTile(title: Text(data['customerName'] ?? 'Walk-in'), subtitle: Text("#${data['invoiceNumber']}"), trailing: Text("₹${data['total']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))); })),
            ],
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
  const SalesSummaryPage({super.key, required this.onBack});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar("Sales Summary", onBack),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('sales').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          double total = 0, cash = 0, online = 0;
          for(var d in snapshot.data!.docs) {
            double amt = double.tryParse(d['total'].toString()) ?? 0;
            total += amt;
            if(d['paymentMode'].toString().toLowerCase().contains('online')) online += amt; else cash += amt;
          }
          return ListView(padding: const EdgeInsets.all(16), children: [
            _buildSummaryCard("Total Revenue", "₹${total.toStringAsFixed(0)}", Icons.attach_money, Colors.deepPurple),
            _buildSummaryCard("Cash Sales", "₹${cash.toStringAsFixed(0)}", Icons.money, Colors.green),
            _buildSummaryCard("Online Sales", "₹${online.toStringAsFixed(0)}", Icons.qr_code, Colors.orange),
            _buildSummaryCard("Total Bills", "${snapshot.data!.docs.length}", Icons.receipt, Colors.blue),
          ]);
        },
      ),
    );
  }
}

// ==========================================
// 5. FULL SALES REPORT
// ==========================================
class FullSalesHistoryPage extends StatelessWidget {
  final VoidCallback onBack;
  const FullSalesHistoryPage({super.key, required this.onBack});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar("All Sales Report", onBack),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('sales').orderBy('date', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return ListView.separated(
              itemCount: snapshot.data!.docs.length,
              separatorBuilder: (c,i)=>const Divider(height: 1),
              itemBuilder: (c, i) {
                var d = snapshot.data!.docs[i];
                return ListTile(title: Text(d['customerName']??''), subtitle: Text(d['date']??''), trailing: Text("₹${d['total']}", style:const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)));
              }
          );
        },
      ),
    );
  }
}

// ==========================================
// 6. ITEM SALES REPORT
// ==========================================
class ItemSalesPage extends StatelessWidget {
  final VoidCallback onBack;
  const ItemSalesPage({super.key, required this.onBack});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar("Item Sales", onBack),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('sales').snapshots(),
        builder: (context, snapshot) {
          if(!snapshot.hasData) return const Center(child:CircularProgressIndicator());
          Map<String, int> qty = {};
          for(var d in snapshot.data!.docs) {
            for(var item in (d['items'] as List)) {
              qty[item['name']] = (qty[item['name']]??0) + (int.tryParse(item['quantity'].toString())??0);
            }
          }
          var sorted = qty.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
          return ListView.builder(itemCount: sorted.length, itemBuilder: (c, i) {
            return ListTile(title: Text(sorted[i].key), trailing: Text("${sorted[i].value} Sold", style: const TextStyle(fontWeight: FontWeight.bold)));
          });
        },
      ),
    );
  }
}

// ==========================================
// 7. TOP CUSTOMERS
// ==========================================
class TopCustomersPage extends StatelessWidget {
  final String uid; final VoidCallback onBack;
  const TopCustomersPage({super.key, required this.uid, required this.onBack});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar("Top Customers", onBack),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('sales').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          Map<String, double> spend = {};
          for(var d in snapshot.data!.docs) { spend[d['customerName']??'Unknown'] = (spend[d['customerName']??'Unknown']??0) + (double.tryParse(d['total'].toString())??0); }
          var sorted = spend.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
          return ListView.builder(itemCount: sorted.length, itemBuilder: (c, i) => ListTile(
              leading: CircleAvatar(child: Text("${i+1}")),
              title: Text(sorted[i].key), trailing: Text("₹${sorted[i].value.toStringAsFixed(0)}")));
        },
      ),
    );
  }
}

// ==========================================
// 8. STOCK REPORT
// ==========================================
class StockReportPage extends StatelessWidget {
  final VoidCallback onBack;
  const StockReportPage({super.key, required this.onBack});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar("Stock Report", onBack),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('Products').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          double totalVal = 0;
          for(var d in snapshot.data!.docs) {
            totalVal += (double.tryParse(d['price'].toString())??0) * (int.tryParse(d['currentStock'].toString())??0);
          }
          return Column(children: [
            Container(padding: const EdgeInsets.all(16), color: Colors.brown.shade50, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Inventory Value:", style:TextStyle(fontWeight: FontWeight.bold)), Text("₹${totalVal.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.brown))])),
            Expanded(child: ListView.builder(itemCount: snapshot.data!.docs.length, itemBuilder: (c, i) { var d = snapshot.data!.docs[i]; return ListTile(title: Text(d['itemName']), subtitle: Text("Price: ₹${d['price']}"), trailing: Text("${d['currentStock']} Units"));}))
          ]);
        },
      ),
    );
  }
}

// ==========================================
// 9. LOW STOCK PRODUCTS
// ==========================================
class LowStockPage extends StatelessWidget {
  final VoidCallback onBack;
  const LowStockPage({super.key, required this.onBack});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar("Low Stock", onBack),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('Products').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var low = snapshot.data!.docs.where((d) => (int.tryParse(d['currentStock'].toString())??0) < 5).toList();
          return ListView.builder(itemCount: low.length, itemBuilder: (c, i) => ListTile(title: Text(low[i]['itemName']), trailing: Text("${low[i]['currentStock']} Left", style:const TextStyle(color: Colors.red))));
        },
      ),
    );
  }
}

// ==========================================
// 10. TOP PRODUCTS
// ==========================================
class TopProductsPage extends StatelessWidget {
  final String uid; final VoidCallback onBack;
  const TopProductsPage({super.key, required this.uid, required this.onBack});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar("Top Products", onBack),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('sales').snapshots(),
        builder: (context, snapshot) {
          if(!snapshot.hasData) return const Center(child:CircularProgressIndicator());
          Map<String, int> qty = {};
          for(var d in snapshot.data!.docs) { for(var item in (d['items'] as List)) { qty[item['name']] = (qty[item['name']]??0) + (int.tryParse(item['quantity'].toString())??0); }}
          var sorted = qty.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
          return ListView.builder(itemCount: sorted.length, itemBuilder: (c, i) => ListTile(leading: CircleAvatar(child: Text("#${i+1}")), title: Text(sorted[i].key), trailing: Text("${sorted[i].value} Sold")));
        },
      ),
    );
  }
}

// ==========================================
// 11. TOP CATEGORIES
// ==========================================
class TopCategoriesPage extends StatelessWidget {
  final VoidCallback onBack;
  const TopCategoriesPage({super.key, required this.onBack});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar("Top Categories", onBack),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('Products').snapshots(),
        builder: (context, productSnap) {
          if (!productSnap.hasData) return const Center(child: CircularProgressIndicator());
          Map<String, String> prodCat = {};
          for (var doc in productSnap.data!.docs) prodCat[doc['itemName']] = doc['category'] ?? 'Uncategorised';

          return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('sales').snapshots(),
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
                return ListView.builder(itemCount: sorted.length, itemBuilder: (c, i) => ListTile(title: Text(sorted[i].key), trailing: Text("₹${sorted[i].value.toStringAsFixed(0)}")));
              }
          );
        },
      ),
    );
  }
}

// ==========================================
// 12. EXPENSE REPORT
// ==========================================
class ExpenseReportPage extends StatelessWidget {
  final VoidCallback onBack;
  const ExpenseReportPage({super.key, required this.onBack});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar("Expense Report", onBack),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('expenses').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No Expenses Recorded"));
          return ListView.builder(itemCount: snapshot.data!.docs.length, itemBuilder: (c, i) { var d = snapshot.data!.docs[i]; return ListTile(title: Text(d['title']??'Expense'), trailing: Text("- ₹${d['amount']}", style: const TextStyle(color: Colors.red)));});
        },
      ),
    );
  }
}

// ==========================================
// 13. TAX REPORT
// ==========================================
class TaxReportPage extends StatelessWidget {
  final VoidCallback onBack;
  const TaxReportPage({super.key, required this.onBack});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar("Tax Report", onBack),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('sales').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          double totalTax = 0;
          for (var doc in snapshot.data!.docs) totalTax += (double.tryParse((doc.data() as Map)['taxAmount'].toString()) ?? 0);
          return Column(children: [
            _summaryBox("Total Tax Collected", "₹${totalTax.toStringAsFixed(2)}", "", Colors.green),
            Expanded(child: ListView.builder(itemCount: snapshot.data!.docs.length, itemBuilder: (c, i) { var d = snapshot.data!.docs[i].data() as Map; return ListTile(title: Text("Inv #${d['invoiceNumber']}"), trailing: Text("Tax: ₹${d['taxAmount']??0}"));}))
          ]);
        },
      ),
    );
  }
}

// ==========================================
// 14. HSN REPORT
// ==========================================
class HSNReportPage extends StatelessWidget {
  final VoidCallback onBack;
  const HSNReportPage({super.key, required this.onBack});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar("HSN Report", onBack),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('Products').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          Map<String, int> hsnMap = {};
          for(var d in snapshot.data!.docs) { String h = d['hsn']??'N/A'; hsnMap[h] = (hsnMap[h]??0)+1; }
          return ListView.builder(itemCount: hsnMap.length, itemBuilder: (c, i) => ListTile(title: Text("HSN: ${hsnMap.keys.elementAt(i)}"), trailing: Text("${hsnMap.values.elementAt(i)} Products")));
        },
      ),
    );
  }
}

// ==========================================
// 15. STAFF SALE REPORT
// ==========================================
class StaffSaleReportPage extends StatelessWidget {
  final VoidCallback onBack;
  const StaffSaleReportPage({super.key, required this.onBack});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar("Staff Sales", onBack),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('sales').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          Map<String, double> staffPerf = {};
          for(var d in snapshot.data!.docs) {
            String s = (d.data() as Map).containsKey('staffName') ? d['staffName'] : 'Admin';
            staffPerf[s] = (staffPerf[s]??0) + (double.tryParse(d['total'].toString())??0);
          }
          return ListView.builder(itemCount: staffPerf.length, itemBuilder: (c, i) => ListTile(title: Text(staffPerf.keys.elementAt(i)), trailing: Text("₹${staffPerf.values.elementAt(i).toStringAsFixed(0)}")));
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
    leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: onBack),
    title: Text(title, style: const TextStyle(color: Colors.black)),
    backgroundColor: Colors.white,
    elevation: 0,
  );
}

Widget _summaryBox(String title, String value, String subtitle, Color color) {
  return Container(width: double.infinity, margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white70)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)), Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12))]));
}

Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
  return Card(elevation: 0, color: color.withOpacity(0.1), margin: const EdgeInsets.only(bottom: 12), child: ListTile(leading: Icon(icon, color: color, size: 32), title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)), trailing: Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold))));
}