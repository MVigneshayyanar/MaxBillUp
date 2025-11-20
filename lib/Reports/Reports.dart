import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text('Analytics', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _StatCard('Revenue', 'Rs 0.00', Icons.trending_up, Colors.purple.shade100, Colors.purple),
                _StatCard('Net Sale', 'Rs 0.00', Icons.shopping_cart, Colors.blue.shade100, Colors.blue),
                _StatCard('Gross', 'Rs 0.00', Icons.attach_money, Colors.green.shade100, Colors.green),
                _StatCard('Sale Profit', 'Rs 0.00', Icons.bar_chart, Colors.green.shade100, Colors.green),
                _StatCard('Refund', 'Rs 0.00', Icons.refresh, Colors.orange.shade100, Colors.orange),
                _StatCard('Expense', 'Rs 0.00', Icons.payment, Colors.red.shade100, Colors.red),
              ],
            ),
            SizedBox(height: 24),
            _ChartCard(
              title: 'Revenue vs Expenses',
              child: SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    barGroups: [
                      BarChartGroupData(x: 9, barRods: [BarChartRodData(toY: 240, color: Colors.red, width: 16)]),
                      BarChartGroupData(x: 11, barRods: [BarChartRodData(toY: 180, color: Colors.red, width: 16)]),
                      BarChartGroupData(x: 15, barRods: [BarChartRodData(toY: 80, color: Colors.green, width: 16)]),
                    ],
                    gridData: FlGridData(show: true),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('Revenue  ↑ 67.3%', style: TextStyle(color: Colors.red)),
                Text('Expense  ↑ 383.3%', style: TextStyle(color: Colors.green)),
              ],
            ),
            SizedBox(height: 8),
            Center(child: Text('Rs 239000.00', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            SizedBox(height: 24),
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
                            PieChartSectionData(value: 80, color: Colors.blue, radius: 50),
                            PieChartSectionData(value: 20, color: Colors.orange, radius: 50),
                          ],
                          sectionsSpace: 0,
                        ),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Legend('Cash', 'Rs239.00', Colors.blue),
                      SizedBox(height: 8),
                      _Legend('Online', 'Rs119.00', Colors.orange),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            _ChartCard(
              title: 'Top Products',
              child: Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        barGroups: List.generate(5, (i) =>
                            BarChartGroupData(x: i, barRods: [
                              BarChartRodData(toY: [700, 550, 350, 280, 320][i].toDouble(), color: Colors.blue, width: 24)
                            ])
                        ),
                        gridData: FlGridData(show: true),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  ...List.generate(5, (i) => _ListItem('Deleted Product', '2', '700.00')),
                  TextButton(onPressed: () {}, child: Text('Show more')),
                ],
              ),
            ),
            SizedBox(height: 24),
            _ChartCard(
              title: 'Top Categories',
              child: Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        barGroups: [
                          BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 2000, color: Colors.blue, width: 32)]),
                          BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 210, color: Colors.blue, width: 32)]),
                        ],
                        gridData: FlGridData(show: true),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                      ),
                    ),
                  ),
                  _ListItem('UnCategorized', '11', '2080.00'),
                  _ListItem('BAG', '6', '210.00'),
                  TextButton(onPressed: () {}, child: Text('Show more')),
                ],
              ),
            ),
            SizedBox(height: 24),
            _ChartCard(
              title: 'Top Staffs',
              child: Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        barGroups: List.generate(5, (i) =>
                            BarChartGroupData(x: i, barRods: [
                              BarChartRodData(toY: [700, 550, 400, 230, 380][i].toDouble(), color: Colors.blue, width: 24)
                            ])
                        ),
                        gridData: FlGridData(show: true),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                      ),
                    ),
                  ),
                  _ListItem('Admin', '2', '700.00'),
                  _ListItem('Admin', '2', '700.00'),
                  _ListItem('Admin', '2', '700.00'),
                  _ListItem('Vishal', '2', '700.00'),
                  TextButton(onPressed: () {}, child: Text('Show more')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _StatCard(String label, String value, IconData icon, Color bgColor, Color iconColor) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(label, style: TextStyle(color: Colors.grey, fontSize: 12))),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ],
          ),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _ChartCard({required String title, required Widget child}) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _Legend(String label, String value, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12)),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _ListItem(String name, String qty, String amount) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name),
          Text(qty),
          Text(amount, style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}