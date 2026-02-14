import 'package:flutter/material.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/utils/translation_helper.dart';

class PlanComparisonPage extends StatelessWidget {
  const PlanComparisonPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kWhite, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'COMPARE PLANS',
          style: const TextStyle(
            color: kWhite,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 8.0,
                  right: 8.0,
                  top: 16.0,
                  bottom: 100.0,
                ),
                child: _buildComparisonTable(constraints.maxWidth - 16),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildComparisonTable(double screenWidth) {
    // Calculate column widths to fit screen - feature column gets more space
    final double totalWidth = screenWidth;
    final double featureColumnWidth = totalWidth * 0.35; // 35% for feature names
    final double planColumnWidth = (totalWidth - featureColumnWidth) / 4; // Divide remaining among 4 plans

    return Table(
      defaultColumnWidth: FixedColumnWidth(planColumnWidth),
      columnWidths: {
        0: FixedColumnWidth(featureColumnWidth),
      },
      border: TableBorder.all(
        color: kGrey200,
        width: 1,
      ),
      children: [
        // Header Row
        TableRow(
          decoration: BoxDecoration(
            color: kPrimaryColor.withOpacity(0.1),
          ),
          children: [
            _buildHeaderCell('', isFirst: true),
            _buildHeaderCell('Free'),
            _buildHeaderCell('MAX Lite'),
            _buildHeaderCell('MAX Plus'),
            _buildHeaderCell('MAX MAX Pro'),
          ],
        ),
        // Feature Rows
        _buildFeatureRow(
          'No. of. Users (Admin+ Users)',
          ['1', '1', 'Admin +\n2 users', 'Admin +\n9 users'],
        ),
        _buildFeatureRow(
          'POS Billing',
          [true, true, true, true],
        ),
        _buildFeatureRow(
          'Purchases',
          [true, true, true, true],
        ),
        _buildFeatureRow(
          'Expenses',
          [true, true, true, true],
        ),
        _buildFeatureRow(
          'Credit Sales',
          [true, true, true, true],
        ),
        _buildFeatureRow(
          'Cloud Backup',
          [true, true, true, true],
        ),
        _buildFeatureRow(
          'Unlimited Products',
          [true, true, true, true],
        ),
        _buildFeatureRow(
          'Bill History',
          ['upto 15 days', true, true, true],
        ),
        _buildFeatureRow(
          'Edit Bill',
          [false, true, true, true],
        ),
        _buildFeatureRow(
          'Reports',
          [false, true, true, true],
        ),
        _buildFeatureRow(
          'Tax Reports',
          [false, true, true, true],
        ),
        _buildFeatureRow(
          'Quotation / Estimation',
          [false, true, true, true],
        ),
        _buildFeatureRow(
          'Import Customers',
          [false, true, true, true],
        ),
        _buildFeatureRow(
          'Support',
          [false, true, true, true],
        ),
        _buildFeatureRow(
          'Customer Dues',
          [false, true, true, true],
        ),
        _buildFeatureRow(
          'Import Customers',
          [false, true, true, true],
        ),
        _buildFeatureRow(
          'Bulk Product Upload',
          [false, true, true, true],
        ),
        _buildFeatureRow(
          'Logo on Bill',
          [false, true, true, true],
        ),
        _buildFeatureRow(
          'Remove Watermark',
          [false, true, true, true],
        ),
      ],
    );
  }

  Widget _buildHeaderCell(String text, {bool isFirst = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: isFirst ? kWhite : kPrimaryColor.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: kGrey200, width: 1),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: isFirst ? 10 : 11,
          color: kBlack87,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  TableRow _buildFeatureRow(String feature, List<dynamic> values) {
    return TableRow(
      children: [
        _buildFeatureCell(feature),
        ...values.map((value) => _buildValueCell(value)),
      ],
    );
  }

  Widget _buildFeatureCell(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: kGreyBg,
        border: Border(
          bottom: BorderSide(color: kGrey200, width: 1),
        ),
      ),
      child: Text(
        text,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 10,
          color: kBlack87,
        ),
      ),
    );
  }

  Widget _buildValueCell(dynamic value) {
    Widget content;

    if (value is bool) {
      content = Icon(
        value ? Icons.check_circle : Icons.cancel,
        color: value ? kGoogleGreen : kErrorColor,
        size: 18,
      );
    } else {
      content = Text(
        value.toString(),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 9,
          color: kBlack87,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: kGrey200, width: 1),
        ),
      ),
      child: Center(child: content),
    );
  }
}

