import 'package:flutter/material.dart';
import 'package:maxbillup/Sales/saleall.dart';
import 'package:maxbillup/Sales/components/common_widgets.dart';
import 'package:maxbillup/Sales/NewSale.dart';

class InvoicePage extends StatelessWidget {
  final String uid;
  final String? userEmail;
  final String businessName;
  final String businessLocation;
  final String businessPhone;
  final String? businessGSTIN;
  final String invoiceNumber;
  final DateTime dateTime;
  final List<Map<String, dynamic>> items;
  final double subtotal;
  final double discount;
  final double cgst; // Central GST
  final double sgst; // State GST
  final double igst; // Integrated GST
  final double total;
  final String paymentMode;
  final double cashReceived;
  final String? customerName;
  final String? customerPhone;
  final String? customerGSTIN;

  const InvoicePage({
    super.key,
    required this.uid,
    this.userEmail,
    required this.businessName,
    required this.businessLocation,
    required this.businessPhone,
    this.businessGSTIN,
    required this.invoiceNumber,
    required this.dateTime,
    required this.items,
    required this.subtotal,
    required this.discount,
    this.cgst = 0.0,
    this.sgst = 0.0,
    this.igst = 0.0,
    required this.total,
    required this.paymentMode,
    required this.cashReceived,
    this.customerName,
    this.customerPhone,
    this.customerGSTIN,
  });

  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final displayHour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);

    return '$day-$month-$year ${displayHour.toString().padLeft(2, '0')}:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  margin: EdgeInsets.all(screenWidth * 0.04),
                  padding: EdgeInsets.all(screenWidth * 0.05),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      Container(
                        padding: EdgeInsets.all(screenWidth * 0.04),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              businessName.toUpperCase(),
                              style: TextStyle(
                                fontSize: screenWidth * 0.055,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.01),
                            Row(
                              children: [
                                Icon(Icons.location_on, color: Colors.white70, size: screenWidth * 0.04),
                                SizedBox(width: screenWidth * 0.02),
                                Expanded(
                                  child: Text(
                                    businessLocation,
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.035,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: screenHeight * 0.005),
                            Row(
                              children: [
                                Icon(Icons.phone, color: Colors.white70, size: screenWidth * 0.04),
                                SizedBox(width: screenWidth * 0.02),
                                Text(
                                  businessPhone,
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.035,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                            if (businessGSTIN != null) ...[
                              SizedBox(height: screenHeight * 0.005),
                              Row(
                                children: [
                                  Icon(Icons.account_balance, color: Colors.white70, size: screenWidth * 0.04),
                                  SizedBox(width: screenWidth * 0.02),
                                  Text(
                                    'GSTIN: $businessGSTIN',
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.035,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.025),

                      // Invoice Title and Details
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TAX INVOICE',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.055,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF2196F3),
                                  letterSpacing: 1.5,
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.008),
                              Text(
                                'INV-$invoiceNumber',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.038,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Date',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.032,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                _formatDateTime(dateTime),
                                style: TextStyle(
                                  fontSize: screenWidth * 0.035,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      SizedBox(height: screenHeight * 0.02),

                      // Customer Details
                      if (customerName != null || customerPhone != null) ...[
                        Container(
                          padding: EdgeInsets.all(screenWidth * 0.04),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BILL TO',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.035,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF2196F3),
                                  letterSpacing: 1,
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.01),
                              if (customerName != null)
                                Text(
                                  customerName!,
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.042,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              if (customerPhone != null)
                                Text(
                                  'Phone: $customerPhone',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.035,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              if (customerGSTIN != null)
                                Text(
                                  'GSTIN: $customerGSTIN',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.035,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.02),
                      ],

                      // Divider
                      Divider(thickness: 1.5, color: Colors.grey[300]),

                      SizedBox(height: screenHeight * 0.015),

                      // Table Header
                      Container(
                        padding: EdgeInsets.symmetric(vertical: screenHeight * 0.012, horizontal: screenWidth * 0.02),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                'Item',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.038,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1976D2),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                'Qty',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: screenWidth * 0.038,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1976D2),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Rate',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: screenWidth * 0.038,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1976D2),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Amount',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: screenWidth * 0.038,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1976D2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.01),

                      // Items List
                      ...items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return Container(
                          padding: EdgeInsets.symmetric(vertical: screenHeight * 0.012, horizontal: screenWidth * 0.02),
                          decoration: BoxDecoration(
                            color: index % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA),
                            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  item['name'],
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.038,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  item['quantity'].toString(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.038,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '₹${item['price'].toStringAsFixed(2)}',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.038,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '₹${item['total'].toStringAsFixed(2)}',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.038,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),

                      SizedBox(height: screenHeight * 0.02),

                      // Summary Section
                      Container(
                        padding: EdgeInsets.all(screenWidth * 0.04),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          children: [
                            _buildSummaryRow('Subtotal', subtotal, screenWidth, isBold: false),
                            if (discount > 0) ...[
                              SizedBox(height: screenHeight * 0.008),
                              _buildSummaryRow('Discount', -discount, screenWidth, isBold: false, isDiscount: true),
                            ],
                            if (cgst > 0) ...[
                              SizedBox(height: screenHeight * 0.008),
                              _buildSummaryRow('CGST', cgst, screenWidth, isBold: false),
                            ],
                            if (sgst > 0) ...[
                              SizedBox(height: screenHeight * 0.008),
                              _buildSummaryRow('SGST', sgst, screenWidth, isBold: false),
                            ],
                            if (igst > 0) ...[
                              SizedBox(height: screenHeight * 0.008),
                              _buildSummaryRow('IGST', igst, screenWidth, isBold: false),
                            ],
                            SizedBox(height: screenHeight * 0.015),
                            Divider(thickness: 1.5, color: Colors.grey[400]),
                            SizedBox(height: screenHeight * 0.01),
                            _buildSummaryRow('Total Amount', total, screenWidth, isBold: true, isTotal: true),
                          ],
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.02),

                      // Payment Details
                      Container(
                        padding: EdgeInsets.all(screenWidth * 0.04),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF4CAF50)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Payment Mode',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.032,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  paymentMode,
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.042,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Received',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.032,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '₹${cashReceived.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.042,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.025),

                      // Footer Message
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'Thank You For Your Business!',
                              style: TextStyle(
                                fontSize: screenWidth * 0.042,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF2196F3),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: screenHeight * 0.008),
                            Text(
                              'We appreciate your trust and look forward to serving you again',
                              style: TextStyle(
                                fontSize: screenWidth * 0.032,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Action Buttons
            _buildActionBar(context, screenWidth),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, double screenWidth, {bool isBold = false, bool isTotal = false, bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? screenWidth * 0.048 : screenWidth * 0.038,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
            color: isTotal ? const Color(0xFF1976D2) : Colors.black87,
          ),
        ),
        Text(
          '₹${amount.abs().toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isTotal ? screenWidth * 0.048 : screenWidth * 0.038,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
            color: isDiscount
                ? const Color(0xFFFF5252)
                : isTotal
                ? const Color(0xFF1976D2)
                : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar(BuildContext context, double screenWidth) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              context: context,
              icon: Icons.home,
              label: 'New Sale',
              color: const Color(0xFF4CAF50),
              onTap: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NewSalePage(uid: uid, userEmail: userEmail),
                  ),
                      (route) => false,
                );
              },
            ),
          ),
          SizedBox(width: screenWidth * 0.02),
          Expanded(
            child: _buildActionButton(
              context: context,
              icon: Icons.share,
              label: 'Share',
              color: const Color(0xFF2196F3),
              onTap: () {
                CommonWidgets.showSnackBar(
                  context,
                  'Share functionality coming soon!',
                  bgColor: const Color(0xFF2196F3),
                );
              },
            ),
          ),
          SizedBox(width: screenWidth * 0.02),
          Expanded(
            child: _buildActionButton(
              context: context,
              icon: Icons.print,
              label: 'Print',
              color: const Color(0xFFFF9800),
              onTap: () {
                CommonWidgets.showSnackBar(
                  context,
                  'Print functionality coming soon!',
                  bgColor: const Color(0xFFFF9800),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: screenWidth * 0.035),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: screenWidth * 0.07),
            SizedBox(height: screenWidth * 0.01),
            Text(
              label,
              style: TextStyle(
                fontSize: screenWidth * 0.032,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
