import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:maxbillup/components/common_bottom_nav.dart'; // Keep your existing import
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Add intl to pubspec.yaml for formatting

class ReportsDashboard extends StatefulWidget {
  @override
  State<ReportsDashboard> createState() => _ReportsDashboardState();
}

class _ReportsDashboardState extends State<ReportsDashboard> {
  String? selectedFeature;

  final List<Map<String, dynamic>> features = [
    {'name': 'Analytics', 'icon': Icons.query_stats, 'color': Colors.blue},
    {'name': 'Top Products', 'icon': Icons.star, 'color': Colors.amber},
    {'name': 'Top Customers', 'icon': Icons.people, 'color': Colors.green},
    {'name': 'Sales Summary', 'icon': Icons.list_alt, 'color': Colors.purple},
    {'name': 'Sales Report', 'icon': Icons.receipt_long, 'color': Colors.indigo},
    // Placeholder features for now (require more complex logic/collections)
    {'name': 'Expense Report', 'icon': Icons.attach_money, 'color': Colors.red},
  ];

  Widget _getFeatureWidget(String featureName, String uid) {
    switch (featureName) {
      case 'Analytics':
        return AnalyticsWidget(uid: uid);
      case 'Top Products':
        return TopProductsWidget(uid: uid);
      case 'Top Customers':
        return TopCustomersWidget(uid: uid);
      case 'Sales Summary':
        return SalesSummaryWidget(uid: uid);
      case 'Sales Report':
        return SalesReportWidget(uid: uid);
      default:
        return PlaceholderWidget(title: featureName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String uid = args?['uid'] ?? '';
    final String? userEmail = args?['userEmail'];
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text(
          selectedFeature ?? 'Reports',
          style: const TextStyle(color: Colors.white),
        ),
        leading: selectedFeature != null
            ? IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => setState(() => selectedFeature = null),
        )
            : null,
      ),
      body: selectedFeature == null
          ? ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: features.length,
        itemBuilder: (context, index) {
          final feature = features[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (feature['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  feature['icon'] as IconData,
                  color: feature['color'] as Color,
                  size: 24,
                ),
              ),
              title: Text(
                feature['name'],
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                setState(() => selectedFeature = feature['name']);
              },
            ),
          );
        },
      )
          : _getFeatureWidget(selectedFeature!, uid),
      bottomNavigationBar: CommonBottomNav(
        uid: uid,
        userEmail: userEmail,
        currentIndex: 1,
        screenWidth: screenWidth,
      ),
    );
  }
}

// ==================== ANALYTICS WIDGET (REALTIME) ====================
class AnalyticsWidget extends StatelessWidget {
  final String uid;
  const AnalyticsWidget({Key? key, required this.uid}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('sales')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No sales data available"));
        }

        final docs = snapshot.data!.docs;
        final now = DateTime.now();
        final todayStr = DateFormat('yyyy-MM-dd').format(now);

        double totalRevenue = 0;
        double todayRevenue = 0;
        int totalSalesCount = docs.length;
        double cashSales = 0;
        double onlineSales = 0;

        // Graph Data Helpers
        // Map<DayOfMonth, Revenue>
        Map<int, double> last7DaysRevenue = {};

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;

          // Calculate Total (Handle String or Number format)
          double saleAmount = 0.0;
          if(data['total'] != null) {
            saleAmount = double.tryParse(data['total'].toString()) ?? 0.0;
          } else {
            // Fallback: sum items if total is missing
            List items = data['items'] ?? [];
            for(var item in items) {
              saleAmount += double.tryParse(item['total'].toString()) ?? 0.0;
            }
          }

          // Parse Date (ISO String from Screenshot: "2025-11-16T...")
          String dateStr = data['date'] ?? '';
          DateTime? saleDate;
          try {
            saleDate = DateTime.parse(dateStr);
          } catch (e) {
            saleDate = null;
          }

          // Global Totals
          totalRevenue += saleAmount;

          // Payment Mode Split
          String mode = (data['paymentMode'] ?? 'Cash').toString().toLowerCase();
          if (mode == 'online') {
            onlineSales += saleAmount;
          } else {
            cashSales += saleAmount;
          }

          // Today Logic
          if (saleDate != null) {
            String saleDateStr = DateFormat('yyyy-MM-dd').format(saleDate);
            if (saleDateStr == todayStr) {
              todayRevenue += saleAmount;
            }

            // Graph Logic (Last 7 days)
            // Simple bucket by day number for the chart
            if (now.difference(saleDate).inDays < 7) {
              last7DaysRevenue[saleDate.weekday] = (last7DaysRevenue[saleDate.weekday] ?? 0) + saleAmount;
            }
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Today Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _StatCard('Total Revenue', '₹${totalRevenue.toStringAsFixed(2)}', Icons.trending_up, Colors.purple.shade100, Colors.purple),
                  _StatCard('Today Sales', '₹${todayRevenue.toStringAsFixed(2)}', Icons.today, Colors.green.shade100, Colors.green),
                  _StatCard('Txn Count', '$totalSalesCount', Icons.receipt, Colors.blue.shade100, Colors.blue),
                  _StatCard('Avg Sale', '₹${totalSalesCount > 0 ? (totalRevenue / totalSalesCount).toStringAsFixed(0) : 0}', Icons.analytics, Colors.orange.shade100, Colors.orange),
                ],
              ),
              const SizedBox(height: 24),
              _ChartCard(
                title: 'Revenue (Last 7 Days)',
                child: SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      barGroups: last7DaysRevenue.entries.map((e) {
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [BarChartRodData(toY: e.value, color: Colors.blue, width: 16, borderRadius: BorderRadius.circular(4))],
                        );
                      }).toList(),
                      gridData: FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                              // Handle index out of bounds safely
                              int index = value.toInt() - 1;
                              if(index >= 0 && index < 7) return Text(days[index]);
                              return const Text('');
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _ChartCard(
                title: 'Payment Mode',
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 150,
                        child: PieChart(
                          PieChartData(
                            sections: [
                              if(cashSales > 0) PieChartSectionData(value: cashSales, color: Colors.blue, radius: 50, title: '', showTitle: false),
                              if(onlineSales > 0) PieChartSectionData(value: onlineSales, color: Colors.orange, radius: 50, title: '', showTitle: false),
                              if(cashSales == 0 && onlineSales == 0) PieChartSectionData(value: 1, color: Colors.grey.shade300, radius: 50, title: ''),
                            ],
                            sectionsSpace: 2,
                            centerSpaceRadius: 30,
                          ),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Legend('Cash', '₹${cashSales.toStringAsFixed(2)}', Colors.blue),
                        const SizedBox(height: 8),
                        _Legend('Online', '₹${onlineSales.toStringAsFixed(2)}', Colors.orange),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _StatCard(String label, String value, IconData icon, Color bgColor, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Icon(icon, size: 18, color: iconColor),
            ],
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _ChartCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }

  Widget _Legend(String label, String value, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

// ==================== TOP PRODUCTS WIDGET ====================
class TopProductsWidget extends StatelessWidget {
  final String uid;
  const TopProductsWidget({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('sales').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        // Aggregation Logic
        Map<String, int> productQty = {};
        Map<String, double> productRev = {};

        for (var doc in snapshot.data!.docs) {
          List items = doc['items'] ?? [];
          for (var item in items) {
            String name = item['name'] ?? 'Unknown';
            int qty = int.tryParse(item['quantity'].toString()) ?? 0;
            double total = double.tryParse(item['total'].toString()) ?? 0.0;

            productQty[name] = (productQty[name] ?? 0) + qty;
            productRev[name] = (productRev[name] ?? 0.0) + total;
          }
        }

        // Convert map to list and sort
        var sortedProducts = productQty.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)); // Sort by Qty Descending

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedProducts.length,
          itemBuilder: (context, index) {
            final name = sortedProducts[index].key;
            final qty = sortedProducts[index].value;
            final rev = productRev[name] ?? 0.0;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.amber.shade100,
                  child: Text('#${index+1}', style: TextStyle(color: Colors.amber.shade800)),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('$qty units sold'),
                trailing: Text('₹${rev.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              ),
            );
          },
        );
      },
    );
  }
}

// ==================== TOP CUSTOMERS WIDGET ====================
class TopCustomersWidget extends StatelessWidget {
  final String uid;
  const TopCustomersWidget({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('sales').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        Map<String, int> customerOrders = {};
        Map<String, double> customerSpend = {};

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          // Check for null names
          String? name = data['customerName'];
          // Use 'Walk-in Customer' if name is null or empty
          if (name == null || name.isEmpty) name = "Walk-in Customer";

          double total = double.tryParse(data['total'].toString()) ?? 0.0;

          customerOrders[name] = (customerOrders[name] ?? 0) + 1;
          customerSpend[name] = (customerSpend[name] ?? 0.0) + total;
        }

        var sortedCustomers = customerSpend.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)); // Sort by Spend Descending

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedCustomers.length,
          itemBuilder: (context, index) {
            final name = sortedCustomers[index].key;
            final spend = sortedCustomers[index].value;
            final orders = customerOrders[name] ?? 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('$orders Orders'),
                trailing: Text('₹${spend.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            );
          },
        );
      },
    );
  }
}

// ==================== SALES LIST WIDGET ====================
class SalesReportWidget extends StatelessWidget {
  final String uid;
  const SalesReportWidget({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('sales')
          .orderBy('date', descending: true) // Ensure you have an index or remove orderBy if it fails initially
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Customer')),
                DataColumn(label: Text('Payment')),
                DataColumn(label: Text('Amount')),
              ],
              rows: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                String dateStr = data['date'] ?? '';
                DateTime? dt = DateTime.tryParse(dateStr);
                String formattedDate = dt != null ? DateFormat('dd-MM HH:mm').format(dt) : '-';

                return DataRow(cells: [
                  DataCell(Text(formattedDate)),
                  DataCell(Text(data['customerName'] ?? '-')),
                  DataCell(Text(data['paymentMode'] ?? '-')),
                  DataCell(Text('₹${data['total']}')),
                ]);
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

// ==================== SALES SUMMARY WIDGET ====================
class SalesSummaryWidget extends StatelessWidget {
  final String uid;
  const SalesSummaryWidget({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('sales').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        double totalSales = 0;
        double cash = 0;
        double online = 0;

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          double amt = double.tryParse(data['total'].toString()) ?? 0.0;
          String mode = (data['paymentMode'] ?? 'Cash').toString().toLowerCase();

          totalSales += amt;
          if (mode == 'online') {
            online += amt;
          } else {
            cash += amt;
          }
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SummaryRow('Total Sales', '₹${totalSales.toStringAsFixed(2)}', Colors.green),
                  const Divider(),
                  _SummaryRow('Cash Sales', '₹${cash.toStringAsFixed(2)}', Colors.blue),
                  _SummaryRow('Online Sales', '₹${online.toStringAsFixed(2)}', Colors.orange),
                  const Divider(),
                  _SummaryRow('Net Sales', '₹${totalSales.toStringAsFixed(2)}', Colors.black),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _SummaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class PlaceholderWidget extends StatelessWidget {
  final String title;
  const PlaceholderWidget({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.construction, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Feature in development', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}