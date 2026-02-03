import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Colors.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:maxbillup/components/common_bottom_nav.dart';
import 'package:maxbillup/utils/permission_helper.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/plan_permission_helper.dart';
import 'package:maxbillup/utils/plan_provider.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:permission_handler/permission_handler.dart';

// ==========================================
// MODERN DESIGN SYSTEM TOKENS
// ==========================================
 // Material Blue
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

// Chart Colors Palette (Varied & Distinct)
const Color kChartBlue = Color(0xFF2196F3);
const Color kChartGreen = Color(0xFF66BB6A);
const Color kChartOrange = Color(0xFFFF7043);
const Color kChartPurple = Color(0xFFAB47BC);
const Color kChartTeal = Color(0xFF26A69A);
const Color kChartPink = Color(0xFFEC407A);
const Color kChartIndigo = Color(0xFF5C6BC0);
const Color kChartAmber = Color(0xFFFFCA28);
const Color kChartCyan = Color(0xFF00BCD4);
const Color kChartRed = Color(0xFFEF5350);
const Color kChartLime = Color(0xFFD4E157);
const Color kChartDeepOrange = Color(0xFFFF5722);

// Chart Colors List for easy iteration
const List<Color> kChartColorsList = [
  kChartBlue,
  kChartGreen,
  kChartOrange,
  kChartPurple,
  kChartTeal,
  kChartPink,
  kChartIndigo,
  kChartAmber,
  kChartCyan,
  kChartRed,
  kChartLime,
  kChartDeepOrange,
];

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
  bool _permissionsLoaded = false;  // Track if permissions are loaded

  final ScrollController _scrollController = ScrollController();
  double _savedScrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    final userData = await PermissionHelper.getUserPermissions(widget.uid);
    if (mounted) {
      setState(() {
        _permissions = userData['permissions'] as Map<String, dynamic>? ?? {};
        _role = userData['role'] as String? ?? 'staff';
        _permissionsLoaded = true;  // Mark permissions as loaded
      });
    }
  }

  bool get isAdmin => _role.toLowerCase() == 'owner' || _role.toLowerCase() == 'administrator';

  void _reset() {
    setState(() {
      _currentView = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_savedScrollOffset);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // 0ns Latency Check: Synchronous access via PlanProvider
    final planProvider = context.watch<PlanProvider>();

    // IMPORTANT: Don't show lock icons until provider AND permissions are loaded
    // This prevents the brief flash of lock icons when navigating to this page
    final isProviderReady = planProvider.isInitialized;
    final isFullyLoaded = isProviderReady && _permissionsLoaded;
    final isPaidPlan = isProviderReady ? planProvider.canAccessReports() : true; // Assume unlocked until initialized

    if (_currentView != null) {
      _savedScrollOffset = _scrollController.hasClients ? _scrollController.offset : 0.0;

      // Wrap sub-pages with PopScope to handle Android back button
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            _reset();
          }
        },
        child: _buildSubPage(),
      );
    }

    return _buildMainReportsPage(context, isFullyLoaded, isPaidPlan);
  }

  Widget _buildSubPage() {
    switch (_currentView) {
      case 'Analytics': return AnalyticsPage(uid: widget.uid, onBack: _reset);
      case 'DayBook': return DayBookPage(uid: widget.uid, onBack: _reset);
      case 'Summary': return IncomeSummaryPage(onBack: _reset);
      case 'SalesSummary': return SalesSummaryPage(onBack: _reset);
      case 'SalesReport': return FullSalesHistoryPage(onBack: _reset);
      case 'ExpenseReport': return ExpenseReportPage(onBack: _reset);
      case 'TopProducts': return TopProductsPage(uid: widget.uid, onBack: _reset);
      case 'LowStock': return LowStockPage(uid: widget.uid, onBack: _reset);
      case 'ItemSales': return ItemSalesPage(onBack: _reset);
      case 'TopCategories': return TopCategoriesPage(onBack: _reset);
      case 'TopCustomers': return TopCustomersPage(uid: widget.uid, onBack: _reset);
      case 'StockReport': return StockReportPage(onBack: _reset);
      case 'StaffReport': return StaffSaleReportPage(onBack: _reset);
      case 'TaxReport': return TaxReportPage(onBack: _reset);
      case 'PaymentReport': return PaymentReportPage(onBack: _reset);
      case 'GSTReport': return TaxReportPage(onBack: _reset); // Unified with Tax Report
      default: return _buildMainReportsPage(context, true, true);
    }
  }

  Widget _buildMainReportsPage(BuildContext context, bool isFullyLoaded, bool isPaidPlan) {
    bool isFeatureAvailable(String permission) {
      // If not fully loaded yet, assume feature is available (no lock shown)
      if (!isFullyLoaded) return true;

      if (permission == 'DayBook') return true;
      // Show all cards for admins - upgrade prompt will be shown on click if needed
      if (isAdmin) return true;
      final userPerm = _permissions[permission] == true;
      return userPerm && isPaidPlan;
    }

    // Check if any item in a section is visible
    bool hasAnalyticsItems = isFeatureAvailable('analytics') || isFeatureAvailable('salesSummary');
    bool hasSalesItems = isFeatureAvailable('salesReport') || isFeatureAvailable('itemSalesReport') || isFeatureAvailable('topCustomer') || isFeatureAvailable('staffSalesReport');
    bool hasInventoryItems = isFeatureAvailable('stockReport') || isFeatureAvailable('lowStockProduct') || isFeatureAvailable('topProducts') || isFeatureAvailable('topCategory');
    bool hasFinancialsItems = isFeatureAvailable('expensesReport') || isFeatureAvailable('taxReport');

    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: Text(context.tr('reports'),
            style: const TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.0)),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Analytics Overview Section
          if (hasAnalyticsItems) _buildSectionLabel(context.tr('analytics_overview')),
          if (isFeatureAvailable('analytics'))
            _buildReportTile(context.tr('Business  Summary'), Icons.insights_rounded, kPrimaryColor, 'Analytics', subtitle: 'Growth & data trends'),
          _buildReportTile(context.tr('daybook_today'), Icons.menu_book_rounded, const Color(0xFF009688), 'DayBook', subtitle: 'Daily transaction log'),
          if (isFeatureAvailable('salesSummary'))
            _buildReportTile('Summary', Icons.summarize_rounded, const Color(0xFF3F51B5), 'Summary', subtitle: 'Income, expense & dues'),
          if (isFeatureAvailable('salesSummary'))
            _buildReportTile(context.tr('Sales Report'), Icons.analytics_rounded, const Color(0xFF673AB7), 'SalesSummary', subtitle: 'Sales performance'),
          if (isFeatureAvailable('salesSummary'))
            _buildReportTile('Payment Summary', Icons.payments_rounded, const Color(0xFF00897B), 'PaymentReport', subtitle: 'Cash & online breakdown'),

          // Sales & Transactions Section
          if (hasSalesItems) ...[
            const SizedBox(height: 12),
            _buildSectionLabel(context.tr('sales_transactions')),
          ],
          if (isFeatureAvailable('salesReport'))
            _buildReportTile(context.tr('Sales Record'), Icons.shopping_cart_rounded, const Color(0xFF9C27B0), 'SalesReport', subtitle: 'Detailed invoice history'),
          if (isFeatureAvailable('itemSalesReport'))
            _buildReportTile(context.tr('item_sales_report'), Icons.shopping_bag_rounded, const Color(0xFF00BCD4), 'ItemSales', subtitle: 'Sales by product'),
          if (isFeatureAvailable('topCustomer'))
            _buildReportTile(context.tr('top_customers'), Icons.emoji_events_rounded, const Color(0xFFFFC107), 'TopCustomers', subtitle: 'Best performing clients'),
          if (isFeatureAvailable('staffSalesReport'))
            _buildReportTile(context.tr('staff_sale_report'), Icons.person_rounded, const Color(0xFF607D8B), 'StaffReport', subtitle: 'Performance by user'),

          // Inventory & Products Section
          if (hasInventoryItems) ...[
            const SizedBox(height: 12),
            _buildSectionLabel(context.tr('inventory_products')),
          ],
          if (isFeatureAvailable('stockReport'))
            _buildReportTile(context.tr('stock_report'), Icons.warehouse_rounded, const Color(0xFF303F9F), 'StockReport', subtitle: 'Full inventory valuation'),
          if (isFeatureAvailable('lowStockProduct'))
            _buildReportTile(context.tr('low_stock_products'), Icons.inventory_rounded, kOrange, 'LowStock', subtitle: 'Restock action required'),
          if (isFeatureAvailable('topProducts'))
            _buildReportTile(context.tr('Product Summary'), Icons.trending_up_rounded, kGoogleGreen, 'TopProducts', subtitle: 'Most sold items'),
          if (isFeatureAvailable('topCategory'))
            _buildReportTile(context.tr('top_categories'), Icons.category_rounded, const Color(0xFFE91E63), 'TopCategories', subtitle: 'Department performance'),

          // Financials & Tax Section
          if (hasFinancialsItems) ...[
            const SizedBox(height: 12),
            _buildSectionLabel(context.tr('financials_tax')),
          ],
          if (isFeatureAvailable('expensesReport'))
            _buildReportTile(context.tr('expense_report'), Icons.account_balance_wallet_rounded, kErrorColor, 'ExpenseReport', subtitle: 'Operating costs tracking'),
          if (isFeatureAvailable('taxReport'))
            _buildReportTile(context.tr('tax_report'), Icons.receipt_rounded, kGoogleGreen, 'TaxReport', subtitle: 'Taxable sales compliance'),
          //if (isFeatureAvailable('taxReport'))
           // _buildReportTile('GST Report', Icons.description_rounded, const Color(0xFF4455DF), 'GSTReport', subtitle: 'GST on sales & purchases'),
          const SizedBox(height: 40),
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

  Widget _buildSectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 12, top: 12),
    child: Text(text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 1.5)),
  );

  Widget _buildReportTile(String title, IconData icon, Color color, String viewName, {String? subtitle}) {
    // Get current plan from provider
    final planProvider = context.watch<PlanProvider>();
    final currentPlan = planProvider.cachedPlan;
    final isPaidPlan = planProvider.canAccessReports();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGrey200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Check if DayBook - always allow access
            if (viewName == 'DayBook') {
              setState(() => _currentView = viewName);
              return;
            }

            // For admins on free/starter plan, show upgrade dialog
            if (isAdmin && !isPaidPlan) {
              PlanPermissionHelper.showUpgradeDialog(
                context,
                title,
                uid: widget.uid,
                currentPlan: currentPlan,
              );
              return;
            }

            // For staff, check user permissions
            if (!isAdmin) {
              // Staff must have both permission AND paid plan
              final hasPermission = _permissions[_getPermissionKey(viewName)] == true;
              if (!hasPermission || !isPaidPlan) {
                PlanPermissionHelper.showUpgradeDialog(
                  context,
                  title,
                  uid: widget.uid,
                  currentPlan: currentPlan,
                );
                return;
              }
            }

            // All checks passed, open the report
            setState(() => _currentView = viewName);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: kBlack87),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle, style: const TextStyle(color: kBlack54, fontSize: 11, fontWeight: FontWeight.w500)),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: kGrey400, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to map view names to permission keys
  String _getPermissionKey(String viewName) {
    switch (viewName) {
      case 'Analytics': return 'analytics';
      case 'SalesSummary': return 'salesSummary';
      case 'SalesReport': return 'salesReport';
      case 'ItemSales': return 'itemSalesReport';
      case 'TopCustomers': return 'topCustomer';
      case 'StaffReport': return 'staffSalesReport';
      case 'StockReport': return 'stockReport';
      case 'LowStock': return 'lowStockProduct';
      case 'TopProducts': return 'topProducts';
      case 'TopCategories': return 'topCategory';
      case 'ExpenseReport': return 'expensesReport';
      case 'TaxReport': return 'taxReport';
      default: return viewName.toLowerCase();
    }
  }
}
// ==========================================
// HELPER FUNCTIONS
// ==========================================

// Date filter options enum
enum DateFilterOption {
  today,
  yesterday,
  thisWeek,
  last7Days,
  last30Days,
  thisMonth,
  lastMonth,
  custom,
  customDate,
  customPeriod,
  customMonth,
}

// --- MODERN EXECUTIVE DATE FILTER ---
class DateFilterWidget extends StatefulWidget {
  final DateFilterOption selectedOption;
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(DateFilterOption, DateTime, DateTime) onDateChanged;
  final bool showSortButton;
  final VoidCallback? onSortPressed;
  final bool isDescending;

  const DateFilterWidget({
    super.key,
    required this.selectedOption,
    this.startDate,
    this.endDate,
    required this.onDateChanged,
    this.showSortButton = false,
    this.onSortPressed,
    this.isDescending = true,
  });

  @override
  State<DateFilterWidget> createState() => _DateFilterWidgetState();
}

class _DateFilterWidgetState extends State<DateFilterWidget> {
  // Theme Tokens
  static const Color kGreyBg = Color(0xFFF5F5F7);
  static const Color kWhite = Colors.white;
  static const Color kTextSecondary = Color(0xFF757575);

  String _getFilterLabel(DateFilterOption option) {
    switch (option) {
      case DateFilterOption.today: return 'Today';
      case DateFilterOption.yesterday: return 'Yesterday';
      case DateFilterOption.thisWeek: return 'Week';
      case DateFilterOption.last7Days: return '7 Days';
      case DateFilterOption.last30Days: return '30 Days';
      case DateFilterOption.thisMonth: return 'Month';
      case DateFilterOption.lastMonth: return 'Last Month';
      case DateFilterOption.custom: return 'Custom';
      case DateFilterOption.customDate: return 'Date';
      case DateFilterOption.customPeriod: return 'Range';
      case DateFilterOption.customMonth: return 'Target';
    }
  }

  void _handleQuickSelect(DateFilterOption option) {
    final now = DateTime.now();
    DateTime start = now;
    DateTime end = now;

    switch (option) {
      case DateFilterOption.today:
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case DateFilterOption.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        start = DateTime(yesterday.year, yesterday.month, yesterday.day);
        end = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
        break;
      case DateFilterOption.thisWeek:
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case DateFilterOption.thisMonth:
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      default:
        _showAdvancedFilterModal();
        return;
    }
    widget.onDateChanged(option, start, end);
  }

  // --- PICKERS ---

  Future<void> _selectCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => _applyTheme(child!),
    );
    if (picked != null) {
      widget.onDateChanged(DateFilterOption.customDate, picked, DateTime(picked.year, picked.month, picked.day, 23, 59, 59));
    }
  }

  Future<void> _selectCustomPeriod() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: widget.startDate != null && widget.endDate != null
          ? DateTimeRange(start: widget.startDate!, end: widget.endDate!)
          : null,
      builder: (context, child) => _applyTheme(child!),
    );
    if (range != null) {
      widget.onDateChanged(DateFilterOption.customPeriod, range.start, DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59));
    }
  }

  Future<void> _selectCustomMonth() async {
    final now = DateTime.now();
    int selectedYear = now.year;

    await showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildIconBtn(Icons.chevron_left, () => setModalState(() => selectedYear--)),
                  Text('$selectedYear', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kPrimaryColor)),
                  _buildIconBtn(Icons.chevron_right, selectedYear < now.year ? () => setModalState(() => selectedYear++) : null),
                ],
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.4),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final month = index + 1;
                  final isDisabled = selectedYear == now.year && month > now.month;
                  return InkWell(
                    onTap: isDisabled ? null : () {
                      final first = DateTime(selectedYear, month, 1);
                      final last = DateTime(selectedYear, month + 1, 0, 23, 59, 59);
                      widget.onDateChanged(DateFilterOption.customMonth, first, last);
                      Navigator.pop(context);
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDisabled ? Colors.transparent : kPrimaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDisabled ? Colors.grey.shade200 : kPrimaryColor.withOpacity(0.15)),
                      ),
                      child: Text(
                        DateFormat('MMM').format(DateTime(2024, month)),
                        style: TextStyle(fontWeight: FontWeight.w900, color: isDisabled ? Colors.grey : kPrimaryColor, fontSize: 12),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAdvancedFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 8.0, bottom: 12),
              child: Text("ADVANCED AUDIT TIMEFRAME", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kPrimaryColor, letterSpacing: 1.5)),
            ),
            _buildModalItem(DateFilterOption.last7Days, Icons.date_range_rounded, () {
              final now = DateTime.now();
              widget.onDateChanged(DateFilterOption.last7Days, now.subtract(const Duration(days: 6)), now);
              Navigator.pop(context);
            }),
            _buildModalItem(DateFilterOption.last30Days, Icons.av_timer_rounded, () {
              final now = DateTime.now();
              widget.onDateChanged(DateFilterOption.last30Days, now.subtract(const Duration(days: 29)), now);
              Navigator.pop(context);
            }),
            _buildModalItem(DateFilterOption.lastMonth, Icons.calendar_month_rounded, () {
              final lastMonth = DateTime(DateTime.now().year, DateTime.now().month - 1, 1);
              widget.onDateChanged(DateFilterOption.lastMonth, lastMonth, DateTime(DateTime.now().year, DateTime.now().month, 0, 23, 59, 59));
              Navigator.pop(context);
            }),
            _buildModalItem(DateFilterOption.customDate, Icons.event_note_rounded, () {
              Navigator.pop(context);
              _selectCustomDate();
            }),
            _buildModalItem(DateFilterOption.customMonth, Icons.grid_view_rounded, () {
              Navigator.pop(context);
              _selectCustomMonth();
            }),
            _buildModalItem(DateFilterOption.customPeriod, Icons.date_range_rounded, () {
              Navigator.pop(context);
              _selectCustomPeriod();
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // --- UI HELPERS ---

  Widget _buildModalItem(DateFilterOption option, IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: kGreyBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, size: 18, color: kPrimaryColor),
        title: Text(_getFilterLabel(option), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black87)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  Widget _applyTheme(Widget child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(primary: kPrimaryColor, onPrimary: kWhite, onSurface: Colors.black87),
        textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: kPrimaryColor)),
        dialogTheme: DialogThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
      child: child,
    );
  }

  Widget _buildIconBtn(IconData icon, VoidCallback? onPressed) {
    return Container(
      decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(12)),
      child: IconButton(icon: Icon(icon, size: 18, color: kPrimaryColor), onPressed: onPressed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<DateFilterOption> quickOptions = [
      DateFilterOption.today,
      DateFilterOption.yesterday,
      DateFilterOption.thisWeek,
      DateFilterOption.thisMonth,
    ];

    return Container(
      color: kWhite,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16), // Reduced vertical padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Executive Info Bar (Compact)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getFilterLabel(widget.selectedOption),
                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kPrimaryColor, letterSpacing: 0.8), // Smaller label
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.startDate != null
                          ? (widget.startDate == widget.endDate || widget.endDate == null
                          ? '${DateFormat('dd MMM yyyy').format(widget.startDate!)} — ${DateFormat('dd MMM yyyy').format(widget.startDate!)}'
                          : '${DateFormat('dd MMM yyyy').format(widget.startDate!)} — ${DateFormat('dd MMM yyyy').format(widget.endDate!)}')
                          : 'Set Period',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black87), // Smaller date text
                    ),
                  ],
                ),
              ),
              if (widget.showSortButton)
                _buildActionSquare(
                  widget.isDescending ? Icons.south_rounded : Icons.north_rounded,
                  widget.onSortPressed,
                ),
            ],
          ),

          const SizedBox(height: 8), // Reduced gap between rows

          // 2. Executive Quick Tiling (More compact height)
          Row(
            children: [
              ...quickOptions.map((opt) {
                bool isSelected = widget.selectedOption == opt;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _handleQuickSelect(opt),
                    child: Container(
                      margin: const EdgeInsets.only(right: 5), // Tightened margin
                      padding: const EdgeInsets.symmetric(vertical: 6), // Reduced tile height
                      decoration: BoxDecoration(
                        color: isSelected ? kPrimaryColor : kGreyBg,
                        borderRadius: BorderRadius.circular(10), // Slightly smaller radius for compact look
                        border: Border.all(
                          color: isSelected ? kPrimaryColor : Colors.transparent,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _getFilterLabel(opt),
                          style: TextStyle(
                            color: isSelected ? kWhite : Colors.black87,
                            fontSize: 10, // Smaller font
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
              // Integrated ALL Button
              Expanded(
                child: GestureDetector(
                  onTap: _showAdvancedFilterModal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: kGreyBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("ALL", style: TextStyle(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.w900)),
                        SizedBox(width: 2),
                        Icon(Icons.tune_rounded, size: 12, color: kPrimaryColor),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Divider(height: 1, color: Colors.grey.shade100, thickness: 1),
        ],
      ),
    );
  }

  Widget _buildActionSquare(IconData icon, VoidCallback? onPressed) {
    return Container(
      height: 32, // Reduced from 38
      width: 32,  // Reduced from 38
      decoration: BoxDecoration(
        color: kGreyBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: IconButton(
        icon: Icon(icon, color: kPrimaryColor, size: 16), // Smaller icon
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }
}

// Empty state widget with illustration
class EmptyStateWidget extends StatelessWidget {
  final String message;

  const EmptyStateWidget({super.key, this.message = 'Sorry, no data for this period'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Simple chart illustration with sad face
          SizedBox(
            height: 100,
            width: 150,
            child: CustomPaint(
              painter: _EmptyChartPainter(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: kTextSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kPrimaryColor.withOpacity(0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw bars
    final barWidth = 6.0;
    final spacing = 10.0;
    final baseY = size.height - 20;
    final heights = [30.0, 50.0, 25.0, 60.0, 35.0, 45.0, 20.0, 55.0, 30.0];

    for (int i = 0; i < heights.length; i++) {
      final x = 20 + i * (barWidth + spacing);
      canvas.drawLine(
        Offset(x, baseY),
        Offset(x, baseY - heights[i]),
        paint,
      );
    }

    // Draw sad face
    final facePaint = Paint()
      ..color = kPrimaryColor.withOpacity(0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final centerX = size.width / 2 + 20;
    final centerY = size.height / 2 - 10;

    // Face circle
    canvas.drawCircle(Offset(centerX, centerY), 20, facePaint);

    // Eyes
    canvas.drawCircle(Offset(centerX - 7, centerY - 5), 2, facePaint..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(centerX + 7, centerY - 5), 2, facePaint);

    // Sad mouth
    final mouthPath = Path()
      ..moveTo(centerX - 8, centerY + 10)
      ..quadraticBezierTo(centerX, centerY + 3, centerX + 8, centerY + 10);
    canvas.drawPath(mouthPath, facePaint..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

 AppBar _buildModernAppBar(String title, VoidCallback onBack, {VoidCallback? onDownload}) {
   return AppBar(
     // Rounded bottom corners for modern look
     shape: const RoundedRectangleBorder(
       borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
     ),
     leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20), onPressed: onBack),
     title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
     backgroundColor: kPrimaryColor,
     elevation: 0,
     centerTitle: true,
     actions: onDownload != null
         ? [
             IconButton(
               icon: const Icon(Icons.download_rounded, color: Colors.white, size: 22),
               onPressed: onDownload,
               tooltip: 'Download PDF',
             ),
             const SizedBox(width: 8),
           ]
         : null,
   );
 }

// ==========================================
// PDF REPORT GENERATOR HELPER
// ==========================================
class ReportPdfGenerator {
  static Future<void> generateAndDownloadPdf({
    required BuildContext context,
    required String reportTitle,
    required List<String> headers,
    required List<List<String>> rows,
    String? summaryTitle,
    String? summaryValue,
    Map<String, String>? additionalSummary,
  }) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
      );

      final pdf = pw.Document();
      final now = DateTime.now();
      final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(now);
      final shortDate = DateFormat('dd MMM yyyy').format(now);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              // Modern Header with gradient-like effect
              pw.Container(
                decoration: pw.BoxDecoration(
                  gradient: const pw.LinearGradient(
                    colors: [PdfColors.blue800, PdfColors.blue900],
                    begin: pw.Alignment.topLeft,
                    end: pw.Alignment.bottomRight,
                  ),
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                padding: const pw.EdgeInsets.all(20),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            reportTitle,
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.blue700,
                              borderRadius: pw.BorderRadius.circular(20),
                            ),
                            child: pw.Text(
                              '$shortDate',
                              style: const pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Text(
                        'MAXmybill',
                        style: pw.TextStyle(
                          color: PdfColors.blue800,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 24),

              // Modern Summary Cards
              if (summaryTitle != null && summaryValue != null) ...[
                pw.Container(
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(12),
                    border: pw.Border.all(color: PdfColors.grey300, width: 1),
                  ),
                  child: pw.Column(
                    children: [
                      // Main Summary
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(20),
                        decoration: pw.BoxDecoration(
                          gradient: const pw.LinearGradient(
                            colors: [PdfColors.blue50, PdfColors.blue100],
                            begin: pw.Alignment.topLeft,
                            end: pw.Alignment.bottomRight,
                          ),
                          borderRadius: const pw.BorderRadius.only(
                            topLeft: pw.Radius.circular(12),
                            topRight: pw.Radius.circular(12),
                          ),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              summaryTitle,
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue800,
                                letterSpacing: 1,
                              ),
                            ),
                            pw.SizedBox(height: 8),
                            pw.Text(
                              summaryValue,
                              style: pw.TextStyle(
                                fontSize: 32,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue900,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Additional Summary Grid
                      if (additionalSummary != null && additionalSummary.isNotEmpty) ...[
                        pw.Container(
                          padding: const pw.EdgeInsets.all(20),
                          child: pw.Wrap(
                            spacing: 16,
                            runSpacing: 12,
                            children: additionalSummary.entries.map((e) {
                              return pw.Container(
                                width: 150,
                                padding: const pw.EdgeInsets.all(12),
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.grey100,
                                  borderRadius: pw.BorderRadius.circular(8),
                                  border: pw.Border.all(color: PdfColors.grey200),
                                ),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  mainAxisAlignment: pw.MainAxisAlignment.center,
                                  children: [
                                    pw.Text(
                                      e.key,
                                      style: const pw.TextStyle(
                                        fontSize: 8,
                                        color: PdfColors.grey600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    pw.SizedBox(height: 4),
                                    pw.Text(
                                      e.value,
                                      style: pw.TextStyle(
                                        fontSize: 12,
                                        fontWeight: pw.FontWeight.bold,
                                        color: PdfColors.grey900,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),
              ],

              // Modern Table
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(color: PdfColors.grey300, width: 1),
                ),
                child: pw.Table(
                  border: pw.TableBorder(
                    horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 1),
                    left: pw.BorderSide.none,
                    right: pw.BorderSide.none,
                    top: pw.BorderSide.none,
                    bottom: pw.BorderSide.none,
                  ),
                  columnWidths: {
                    for (int i = 0; i < headers.length; i++)
                      i: const pw.FlexColumnWidth(),
                  },
                  children: [
                    // Header
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        gradient: pw.LinearGradient(
                          colors: [PdfColors.blue800, PdfColors.blue900],
                        ),
                      ),
                      children: headers.map((header) {
                        return pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          child: pw.Text(
                            header,
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    // Data Rows
                    ...rows.asMap().entries.map((entry) {
                      final isEven = entry.key % 2 == 0;
                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: isEven ? PdfColors.white : PdfColors.grey50,
                        ),
                        children: entry.value.map((cell) {
                          return pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: pw.Text(
                              cell,
                              style: const pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.grey800,
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    }).toList(),
                  ],
                ),
              ),

              pw.SizedBox(height: 24),

              // Modern Footer
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  gradient: const pw.LinearGradient(
                    colors: [PdfColors.grey50, PdfColors.grey100],
                  ),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blue800,
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Text(
                            '${rows.length}',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Text(
                          'Total Records',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Generated by MAXmybill',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue800,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          dateStr,
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      Navigator.pop(context);

      final fileName = '${reportTitle.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf';
      final pdfBytes = await pdf.save();

      if (Platform.isAndroid) {
        var storageStatus = await Permission.storage.status;
        if (!storageStatus.isGranted) {
          storageStatus = await Permission.storage.request();
          if (!storageStatus.isGranted) {
            final manageStatus = await Permission.manageExternalStorage.request();
            if (!manageStatus.isGranted) {
              final openSettings = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Permission Required', style: TextStyle(fontSize: 18))),
                    ],
                  ),
                  content: const Text(
                    'Storage permission is needed to save PDF reports to Downloads folder.\n\nPlease enable storage permission in app settings.',
                    style: TextStyle(fontSize: 14, color: kTextSecondary, height: 1.5),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Open Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
              if (openSettings == true) await openAppSettings();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(child: Text('Storage permission denied. Cannot save PDF.')),
                    ],
                  ),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  duration: const Duration(seconds: 3),
                ),
              );
              return;
            }
          }
        }
      }

      String? savedPath;
      bool savedToDownloads = false;

      if (Platform.isAndroid) {
        try {
          print('=== PDF SAVE DEBUG ===');
          print('Attempting to save PDF: $fileName');
          final downloadsPath = '/storage/emulated/0/Download';
          final downloadsDir = Directory(downloadsPath);

          if (await downloadsDir.exists()) {
            print('Downloads directory exists: ${downloadsDir.path}');

            // Create MAXmybill folder inside Downloads
            final maxmybillDir = Directory('${downloadsDir.path}/MAXmybill');
            if (!await maxmybillDir.exists()) {
              await maxmybillDir.create(recursive: true);
              print('✓ Created MAXmybill folder: ${maxmybillDir.path}');
            } else {
              print('MAXmybill folder already exists: ${maxmybillDir.path}');
            }

            // Save file in MAXmybill folder
            final file = File('${maxmybillDir.path}/$fileName');
            await file.writeAsBytes(pdfBytes, flush: true);
            if (await file.exists()) {
              final fileSize = await file.length();
              print('✓ PDF saved to Downloads/MAXmybill: ${file.path}, Size: $fileSize bytes');
              savedPath = file.path;
              savedToDownloads = true;
            }
          } else {
            final extDir = await getExternalStorageDirectory();
            if (extDir != null) {
              final parts = extDir.path.split('/');
              final storageIndex = parts.indexOf('Android');
              if (storageIndex > 0) {
                final basePath = parts.sublist(0, storageIndex).join('/');
                final downloadDir = Directory('$basePath/Download');
                if (await downloadDir.exists()) {
                  // Create MAXmybill folder
                  final maxmybillDir = Directory('${downloadDir.path}/MAXmybill');
                  if (!await maxmybillDir.exists()) {
                    await maxmybillDir.create(recursive: true);
                  }

                  final file = File('${maxmybillDir.path}/$fileName');
                  await file.writeAsBytes(pdfBytes, flush: true);
                  if (await file.exists()) {
                    savedPath = file.path;
                    savedToDownloads = true;
                    print('✓ PDF saved to Downloads/MAXmybill (fallback): ${file.path}');
                  }
                }
              }
            }
          }
          if (savedPath == null) {
            print('Fallback: Saving to cache directory');
            final cacheDir = await getTemporaryDirectory();
            final tempFile = File('${cacheDir.path}/$fileName');
            await tempFile.writeAsBytes(pdfBytes, flush: true);
            if (await tempFile.exists()) {
              print('✓ PDF saved to cache: ${tempFile.path}');
              savedPath = tempFile.path;
            }
          }
          print('=== END PDF SAVE DEBUG ===');
        } catch (e, stackTrace) {
          print('ERROR saving PDF: $e');
          print('Stack trace: $stackTrace');
          try {
            final cacheDir = await getTemporaryDirectory();
            final tempFile = File('${cacheDir.path}/$fileName');
            await tempFile.writeAsBytes(pdfBytes, flush: true);
            savedPath = tempFile.path;
          } catch (e2) {
            print('Cache fallback failed: $e2');
          }
        }
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(pdfBytes);
        savedPath = file.path;
      }

      if (savedPath != null) {
        final file = File(savedPath);
        showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [kIncomeGreen, kIncomeGreen.withOpacity(0.7)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: kIncomeGreen.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.check_circle_outline, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Success!',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    savedToDownloads
                        ? 'Your PDF report has been saved to Downloads/MAXmybill folder'
                        : 'Your PDF report has been generated successfully',
                    style: const TextStyle(fontSize: 14, color: kTextSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade50, Colors.blue.shade100],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: kPrimaryColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fileName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(pdfBytes.length / 1024).toStringAsFixed(1)} KB',
                                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (savedToDownloads) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: kIncomeGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kIncomeGreen.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.folder_outlined, color: kIncomeGreen, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Check Downloads/MAXmybill folder',
                              style: TextStyle(fontSize: 14, color: kIncomeGreen, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: const Text('Close', style: TextStyle(color: kTextSecondary, fontSize: 14)),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    await Share.shareXFiles(
                      [XFile(file.path)],
                      subject: '$reportTitle Report',
                      text: '$reportTitle - Generated on $dateStr',
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share PDF', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                ),
              ],
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Error: Could not generate PDF file')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Error generating PDF: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
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
  String _selectedDuration = 'Last 7 Days or Last Week';
  final FirestoreService _firestoreService = FirestoreService();

  int get _durationDays {
    switch (_selectedDuration) {
      case 'Today': return 0;
      case 'Yesterday': return 1;
      case 'Last 7 Days or Last Week': return 7;
      case 'Last 30 Days': return 30;
      case 'This Month': return DateTime.now().day;
      case 'Last 3 Months': return 90;
      default: return 7;
    }
  }

  bool _isInPeriod(DateTime? dt) {
    if (dt == null) return false;
    final now = DateTime.now();
    if (_selectedDuration == 'Today') {
      return DateFormat('yyyy-MM-dd').format(dt) == DateFormat('yyyy-MM-dd').format(now);
    } else if (_selectedDuration == 'Yesterday') {
      final yesterday = now.subtract(const Duration(days: 1));
      return DateFormat('yyyy-MM-dd').format(dt) == DateFormat('yyyy-MM-dd').format(yesterday);
    } else if (_selectedDuration == 'This Month') {
      return dt.year == now.year && dt.month == now.month;
    } else if (_selectedDuration == 'Last 3 Months') {
      return now.difference(dt).inDays <= 90;
    }
    return now.difference(dt).inDays <= _durationDays;
  }

  // Store calculated data for PDF download
  double _todayRevenue = 0, _todayExpense = 0, _todayTax = 0;
  double _totalOnline = 0, _totalCash = 0;
  double _periodIncome = 0, _periodExpense = 0;
  double _totalRefunds = 0;
  int _todaySaleCount = 0;

  void _downloadPdf(BuildContext context) {
    final rows = [
      ['Today Revenue', ' ${_todayRevenue.toStringAsFixed(2)}'],
      ['Today Expense', ' ${_todayExpense.toStringAsFixed(2)}'],
      ['Today Tax Collected', ' ${_todayTax.toStringAsFixed(2)}'],
      ['Period Income', ' ${_periodIncome.toStringAsFixed(2)}'],
      ['Period Expense', ' ${_periodExpense.toStringAsFixed(2)}'],
      ['Cash Collection', ' ${_totalCash.toStringAsFixed(2)}'],
      ['Online Collection', ' ${_totalOnline.toStringAsFixed(2)}'],
      ['Total Refunds', ' ${_totalRefunds.toStringAsFixed(2)}'],
    ];

    ReportPdfGenerator.generateAndDownloadPdf(
      context: context,
      reportTitle: 'Business Analytics Report',
      headers: ['Metric', 'Amount'],
      rows: rows,
      summaryTitle: "Net Profit",
      summaryValue: " ${(_periodIncome - _periodExpense).toStringAsFixed(2)}",
      additionalSummary: {
        'Period': _selectedDuration,
        'Total Bills': '$_todaySaleCount',
        'Refunds': ' ${_totalRefunds.toStringAsFixed(2)}',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: _buildModernAppBar("Business  Summary", widget.onBack, onDownload: () => _downloadPdf(context)),
      body: FutureBuilder<List<Stream<QuerySnapshot>>>(
        future: Future.wait([
          _firestoreService.getCollectionStream('sales'),
          _firestoreService.getCollectionStream('expenses'),
          _firestoreService.getCollectionStream('stockPurchases'),
        ]),
        builder: (context, streamsSnapshot) {
          if (!streamsSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2));
          }

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

                      double totalRefunds = 0;

                      // --- Process Sales ---
                      for (var doc in salesSnap.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        double amount = double.tryParse(data['total'].toString()) ?? 0.0;
                        double tax = double.tryParse(data['totalTax']?.toString() ?? '0') ?? 0.0;
                        if (tax == 0) {
                          tax = double.tryParse(data['taxAmount']?.toString() ?? data['tax']?.toString() ?? '0') ?? 0.0;
                        }

                        DateTime? dt;
                        if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                        else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());
                        String mode = (data['paymentMode'] ?? '').toString().toLowerCase();

                        // Check if bill is cancelled, returned or edited
                        final String status = (data['status'] ?? '').toString().toLowerCase();
                        final bool isCancelled = status == 'cancelled';
                        final bool isReturned = status == 'returned' || data['hasBeenReturned'] == true;
                        final bool isEdited = status == 'edited' || data['hasBeenEdited'] == true;
                        final bool isRefunded = isCancelled || isReturned;

                        if (dt != null) {
                          if (DateFormat('yyyy-MM-dd').format(dt) == todayStr) {
                            if (!isRefunded) {
                              todayRevenue += amount;
                              todayTax += tax;
                              todaySaleCount++;
                            } else {
                              // Count refunds for today
                              totalRefunds += amount;
                            }
                          }
                          if (_isInPeriod(dt)) {
                            if (!isRefunded) {
                              periodIncome += amount;
                              weekRevenue[dt.day] = (weekRevenue[dt.day] ?? 0) + amount;

                              // Handle Split payments separately
                              if (mode == 'split') {
                                double splitCash = double.tryParse(data['cashReceived_split']?.toString() ?? '0') ?? 0;
                                double splitOnline = double.tryParse(data['onlineReceived_split']?.toString() ?? '0') ?? 0;
                                totalCash += splitCash;
                                totalOnline += splitOnline;
                              } else if (mode.contains('online') || mode.contains('upi') || mode.contains('card')) {
                                totalOnline += amount;
                              } else if (!mode.contains('credit')) {
                                // Cash payment (exclude credit from cash)
                                totalCash += amount;
                              }
                            } else {
                              // Add to refunds instead of cash/online
                              totalRefunds += amount;
                            }
                          }
                        }
                      }

                      // --- Process Expenses ---
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
                          if (_isInPeriod(dt)) {
                            periodExpense += amount;
                            weekExpense[dt.day] = (weekExpense[dt.day] ?? 0) + amount;
                          }
                        }
                      }

                      // Store values for PDF download
                      _todayRevenue = todayRevenue;
                      _todayExpense = todayExpense;
                      _todayTax = todayTax;
                      _totalOnline = totalOnline;
                      _totalCash = totalCash;
                      _periodIncome = periodIncome;
                      _periodExpense = periodExpense;
                      _totalRefunds = totalRefunds;
                      _todaySaleCount = todaySaleCount;

                      return CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          // Executive KPI Ribbon
                          SliverToBoxAdapter(
                            child: _buildExecutiveRibbon(todayRevenue, todaySaleCount),
                          ),

                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                // 2x2 Matrix for daily stats
                                _buildSectionHeader("Daily Breakdown"),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(child: _buildMetricTile("Expenses", todayExpense, kExpenseRed, Icons.outbox_rounded)),
                                    const SizedBox(width: 8),
                                    Expanded(child: _buildMetricTile("Tax Coll.", todayTax, kWarningOrange, Icons.description_outlined)),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Analytics Trend Section
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildSectionHeader("Financial Velocity"),
                                    _buildDurationFilter(),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _buildChartCard(
                                  child: _buildCombinedBarChart(weekRevenue, weekExpense),
                                ),
                                const SizedBox(height: 20),

                                // Payment Composition
                                _buildSectionHeader("Settlement Channels"),
                                const SizedBox(height: 10),
                                _buildChartCard(
                                  child: _buildDonutChart(totalCash, totalOnline, totalRefunds),
                                ),
                                const SizedBox(height: 20),

                                // Period Trends
                                Row(
                                  children: [
                                    Expanded(child: _buildCompactTrendTile("Total Income", periodIncome, true)),
                                    const SizedBox(width: 10),
                                    Expanded(child: _buildCompactTrendTile("Total Expense", periodExpense, false)),
                                  ],
                                ),
                                const SizedBox(height: 30),
                              ]),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // --- REFINED UI COMPONENTS ---

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: kTextSecondary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildExecutiveRibbon(double revenue, int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Today's Revenue", style: TextStyle(color: kTextSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const SizedBox(height: 2),
              Text(" ${revenue.toStringAsFixed(2)}", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kPrimaryColor, letterSpacing: -1)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kPrimaryColor.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Text("$count", style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900, fontSize: 16)),
                const Text("Orders", style: TextStyle(color: kTextSecondary, fontSize: 7, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, double value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: kTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                Text("${value.toStringAsFixed(0)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderColor.withOpacity(0.7)),
      ),
      child: child,
    );
  }

  Widget _buildDurationFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: kBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorderColor),
      ),
      child: DropdownButton<String>(
        value: _selectedDuration,
        underline: const SizedBox(),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 14),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kPrimaryColor),
        items: ['Today', 'Yesterday', 'Last 7 Days or Last Week', 'Last 30 Days', 'This Month', 'Last 3 Months'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) => setState(() => _selectedDuration = v!),
      ),
    );
  }

  Widget _buildCombinedBarChart(Map<int, double> revenue, Map<int, double> expenses) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildSmallLegend(kPrimaryColor, "Income"),
            const SizedBox(width: 12),
            _buildSmallLegend(kExpenseRed, "Expense"),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: kBorderColor.withOpacity(0.15), strokeWidth: 1)),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (v, m) => Text(v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0), style: const TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.bold)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              barGroups: _generateChartGroups(revenue, expenses),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDonutChart(double cash, double online, [double refunds = 0]) {
    double total = cash + online + refunds;
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: SizedBox(
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 30,
                    sections: [
                      if (cash > 0) PieChartSectionData(color: kChartGreen, value: cash, title: '', radius: 15),
                      if (online > 0) PieChartSectionData(color: kChartBlue, value: online, title: '', radius: 15),
                      if (refunds > 0) PieChartSectionData(color: kChartPurple, value: refunds, title: '', radius: 15),
                      if (total == 0) PieChartSectionData(color: kBorderColor, value: 1, title: '', radius: 15),
                    ],
                  ),
                ),
                const Icon(Icons.pie_chart_outline_rounded, color: kTextSecondary, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendRow(kChartGreen, "Cash", cash),
              const SizedBox(height: 8),
              _buildLegendRow(kChartBlue, "Online", online),
              if (refunds > 0) ...[
                const SizedBox(height: 8),
                _buildLegendRow(kChartPurple, "Refunds", refunds),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendRow(Color color, String label, double value) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: kTextSecondary, fontWeight: FontWeight.bold))),
        Text("${value.toStringAsFixed(0)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildSmallLegend(Color color, String label) {
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kTextSecondary)),
      ],
    );
  }

  Widget _buildCompactTrendTile(String label, double value, bool isPositive) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: kTextSecondary, fontSize: 9, fontWeight: FontWeight.bold)),
              Icon(isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 14, color: isPositive ? kIncomeGreen : kExpenseRed),
            ],
          ),
          const SizedBox(height: 4),
          Text("${value.toStringAsFixed(0)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
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
            color: kChartGreen,
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
          ),
          BarChartRodData(
            toY: expenses[day] ?? 0,
            color: kChartOrange,
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
          ),
        ],
      );
    }).toList();
  }
}

// ==========================================
// 3. DAYBOOK
// ==========================================
class DayBookPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;

  const DayBookPage({super.key, required this.uid, required this.onBack});

  @override
  State<DayBookPage> createState() => _DayBookPageState();
}

class _DayBookPageState extends State<DayBookPage> {
  final FirestoreService _firestoreService = FirestoreService();
  DateTime _selectedDate = DateTime.now();

  // Store data for PDF download
  List<DocumentSnapshot> _todayDocs = [];
  double _total = 0;
  // Transaction filter for the timeline: All, Cash, Online, Split, Credit
  String _txnFilter = 'All';
  final List<String> _txnFilterOptions = ['All', 'Cash', 'Online', 'Split', 'Credit'];

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _downloadPdf(BuildContext context) {
    if (_todayDocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to download'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Preparing a high-density table for the PDF
    final rows = _todayDocs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      DateTime? dt;
      if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
      final timeStr = dt != null ? DateFormat('hh:mm a').format(dt) : 'N/A';
      final saleTotal = double.tryParse(data['total']?.toString() ?? '0') ?? 0;

      return [
        (data['invoiceNumber']?.toString() ?? '-').padLeft(5, '0'),
        timeStr,
        (data['customerName']?.toString() ?? 'Guest'),
        (data['paymentMode']?.toString() ?? 'Cash'),
        "INR ${saleTotal.toStringAsFixed(2)}",
      ];
    }).toList();

    ReportPdfGenerator.generateAndDownloadPdf(
      context: context,
      reportTitle: 'Executive Daybook - ${DateFormat('dd MMMM yyyy').format(DateTime.now())}',
      headers: ['Invoice', 'Time', 'Customer Name', 'Payment', 'Amount'],
      rows: rows,
      summaryTitle: "Total Settlement",
      summaryValue: " ${_total.toStringAsFixed(2)}",
      additionalSummary: {
        'Total Invoices': '${_todayDocs.length}',
        'Avg. Ticket Size': ' ${(_todayDocs.isNotEmpty ? _total / _todayDocs.length : 0).toStringAsFixed(2)}',
        'Status': 'Closed'
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: _buildModernAppBar(
          "DayBook",
          widget.onBack,
          onDownload: () => _downloadPdf(context)
      ),
      body: FutureBuilder<List<Stream<QuerySnapshot>>>(
        future: Future.wait([
          _firestoreService.getCollectionStream('sales'),
          _firestoreService.getCollectionStream('expenses'),
          _firestoreService.getCollectionStream('stockPurchases'),
          _firestoreService.getCollectionStream('credits'),
          _firestoreService.getCollectionStream('purchaseCreditNotes'),
        ]),
        builder: (context, streamsSnapshot) {
          if (!streamsSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2));
          }
          return StreamBuilder<QuerySnapshot>(
            stream: streamsSnapshot.data![0],
            builder: (context, salesSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: streamsSnapshot.data![1],
                builder: (context, expenseSnapshot) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: streamsSnapshot.data![2],
                    builder: (context, purchaseSnapshot) {
                      return StreamBuilder<QuerySnapshot>(
                        stream: streamsSnapshot.data![3],
                        builder: (context, creditsSnapshot) {
                          return StreamBuilder<QuerySnapshot>(
                            stream: streamsSnapshot.data![4],
                            builder: (context, purchaseCreditsSnapshot) {
                      if (!salesSnapshot.hasData || !expenseSnapshot.hasData || !purchaseSnapshot.hasData || !creditsSnapshot.hasData || !purchaseCreditsSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                      }

                      // Filter data for selected date
                      final filteredSales = salesSnapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        DateTime? dt;
                        if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                        else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());
                        if (dt == null) return false;
                        return DateFormat('yyyy-MM-dd').format(dt) == selectedDateStr;
                      }).toList();

                      final filteredExpenses = expenseSnapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        DateTime? dt;
                        if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                        else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());
                        if (dt == null) return false;
                        return DateFormat('yyyy-MM-dd').format(dt) == selectedDateStr;
                      }).toList();

                      final filteredPurchases = purchaseSnapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        DateTime? dt;
                        if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                        else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());
                        if (dt == null) return false;
                        return DateFormat('yyyy-MM-dd').format(dt) == selectedDateStr;
                      }).toList();

                      // Filter credits for selected date
                      final filteredCredits = creditsSnapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        DateTime? dt;
                        if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                        else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());
                        if (dt == null) return false;
                        return DateFormat('yyyy-MM-dd').format(dt) == selectedDateStr;
                      }).toList();

                      // Filter purchase credits for selected date
                      final filteredPurchaseCredits = purchaseCreditsSnapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        DateTime? dt;
                        if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                        else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());
                        if (dt == null) return false;
                        return DateFormat('yyyy-MM-dd').format(dt) == selectedDateStr;
                      }).toList();

                      // Calculate comprehensive stats
                      int totalSalesCount = 0, totalExpensesCount = 0, totalPurchasesCount = 0;
                      double totalSalesAmount = 0, totalExpensesAmount = 0, totalPurchasesAmount = 0;
                      double saleCreditGiven = 0, saleCreditReceived = 0;
                      double purchaseCreditAdded = 0, purchaseCreditPaid = 0;

                      // Payment breakdown
                      double paymentOutCash = 0, paymentOutOnline = 0;
                      double paymentInCash = 0, paymentInOnline = 0;

                      // Build transaction rows
                      List<Map<String, dynamic>> allTransactions = [];

                      // Process Sales
                      for (var doc in filteredSales) {
                        final data = doc.data() as Map<String, dynamic>;
                        final String status = (data['status'] ?? '').toString().toLowerCase();
                        if (status == 'cancelled' || status == 'returned' || data['hasBeenReturned'] == true) {
                          continue;
                        }

                        double total = double.tryParse(data['total']?.toString() ?? '0') ?? 0;
                        String mode = (data['paymentMode'] ?? 'Cash').toString().toLowerCase();

                        totalSalesCount++;
                        totalSalesAmount += total;

                        // Track cash in
                        if (mode.contains('cash')) {
                          paymentInCash += total;
                        } else if (mode.contains('online') || mode.contains('upi') || mode.contains('card')) {
                          paymentInOnline += total;
                        } else if (mode.contains('credit')) {
                          saleCreditGiven += total;
                        }

                        allTransactions.add({
                          'category': 'Sale',
                          'particulars': data['invoiceNumber']?.toString() ?? 'N/A',
                          'name': data['customerName']?.toString() ?? 'Guest',
                          'total': total,
                          'cashIn': mode.contains('credit') ? 0.0 : total,
                          'cashOut': 0.0,
                          'timestamp': data['timestamp'],
                          'paymentMode': mode,
                        });
                      }

                      // Process Credits (for Sale Credit Received)
                      for (var doc in filteredCredits) {
                        final data = doc.data() as Map<String, dynamic>;
                        final type = (data['type'] ?? '').toString().toLowerCase();
                        final amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0;
                        final method = (data['method'] ?? 'Cash').toString().toLowerCase();

                        if (type == 'payment_received') {
                          // Customer paid back credit
                          saleCreditReceived += amount;

                          // Track payment method
                          if (method.contains('cash')) {
                            paymentInCash += amount;
                          } else if (method.contains('online') || method.contains('upi') || method.contains('card')) {
                            paymentInOnline += amount;
                          }

                          allTransactions.add({
                            'category': 'Credit Received',
                            'particulars': data['invoiceNumber']?.toString() ?? 'Payment',
                            'name': data['customerName']?.toString() ?? 'Customer',
                            'total': amount,
                            'cashIn': amount,
                            'cashOut': 0.0,
                            'timestamp': data['timestamp'],
                            'paymentMode': method,
                          });
                        }
                      }

                      // Process Purchase Credits
                      for (var doc in filteredPurchaseCredits) {
                        final data = doc.data() as Map<String, dynamic>;
                        final type = (data['type'] ?? '').toString().toLowerCase();
                        final amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0;
                        final status = (data['status'] ?? '').toString().toLowerCase();
                        final paidAmount = double.tryParse(data['paidAmount']?.toString() ?? '0') ?? 0;

                        if (type.contains('purchase') || type.contains('expense')) {
                          // Purchase on credit
                          purchaseCreditAdded += amount;

                          // If there's a paid amount, track it as purchase credit paid
                          if (paidAmount > 0) {
                            purchaseCreditPaid += paidAmount;
                            paymentOutCash += paidAmount; // Assume cash payment
                          }

                          allTransactions.add({
                            'category': 'Purchase Credit',
                            'particulars': data['invoiceNumber']?.toString() ?? data['creditNoteNumber']?.toString() ?? '--',
                            'name': data['supplierName']?.toString() ?? 'Supplier',
                            'total': amount,
                            'cashIn': 0.0,
                            'cashOut': paidAmount,
                            'timestamp': data['timestamp'],
                            'paymentMode': 'credit',
                          });
                        }
                      }

                      // Process Expenses
                      for (var doc in filteredExpenses) {
                        final data = doc.data() as Map<String, dynamic>;
                        double amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0;
                        String mode = (data['paymentMode'] ?? 'Cash').toString().toLowerCase();

                        totalExpensesCount++;
                        totalExpensesAmount += amount;

                        // Track cash out
                        if (mode.contains('cash')) {
                          paymentOutCash += amount;
                        } else if (mode.contains('online') || mode.contains('upi') || mode.contains('card')) {
                          paymentOutOnline += amount;
                        }

                        allTransactions.add({
                          'category': 'Expense',
                          'particulars': data['category']?.toString() ?? 'VI EXPENSE',
                          'name': data['name']?.toString() ?? 'SELF',
                          'total': amount,
                          'cashIn': 0.0,
                          'cashOut': amount,
                          'timestamp': data['timestamp'],
                          'paymentMode': mode,
                        });
                      }

                      // Process Purchases
                      for (var doc in filteredPurchases) {
                        final data = doc.data() as Map<String, dynamic>;
                        double amount = double.tryParse(data['totalAmount']?.toString() ?? '0') ?? 0;
                        String mode = (data['paymentMode'] ?? 'Cash').toString().toLowerCase();

                        totalPurchasesCount++;
                        totalPurchasesAmount += amount;

                        // Track cash out
                        if (mode.contains('cash')) {
                          paymentOutCash += amount;
                        } else if (mode.contains('online') || mode.contains('upi') || mode.contains('card')) {
                          paymentOutOnline += amount;
                        }

                        allTransactions.add({
                          'category': 'Purchase',
                          'particulars': data['invoiceNumber']?.toString() ?? '--',
                          'name': data['supplierName']?.toString() ?? 'Supplier',
                          'total': amount,
                          'cashIn': 0.0,
                          'cashOut': amount,
                          'timestamp': data['timestamp'],
                          'paymentMode': mode,
                        });
                      }

                      // Sort transactions by time
                      allTransactions.sort((a, b) {
                        DateTime? dtA, dtB;
                        if (a['timestamp'] != null) dtA = (a['timestamp'] as Timestamp).toDate();
                        if (b['timestamp'] != null) dtB = (b['timestamp'] as Timestamp).toDate();
                        if (dtA == null || dtB == null) return 0;
                        return dtA.compareTo(dtB);
                      });

                      return Column(
                        children: [
                          // Date Selector
                          _buildDayBookDateSelector(),

                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                children: [
                                  // Summary Cards
                                  _buildDayBookSummaryCards(
                                    totalSalesCount, totalSalesAmount,
                                    totalExpensesCount, totalExpensesAmount,
                                    totalPurchasesCount, totalPurchasesAmount,
                                    saleCreditGiven, saleCreditReceived,
                                    purchaseCreditAdded, purchaseCreditPaid,
                                  ),

                                  const SizedBox(height: 20),

                                  // Payment Breakdown
                                  _buildDayBookPaymentBreakdown(
                                    paymentOutCash, paymentOutOnline,
                                    paymentInCash, paymentInOnline,
                                  ),

                                  const SizedBox(height: 20),

                                  // Transaction Timeline
                                  _buildDayBookTransactionTable(allTransactions),

                                  const SizedBox(height: 30),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // --- EXECUTIVE UI COMPONENTS ---

  Widget _buildExecutiveKpiHeader(double total, int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Net Cashflow", style: TextStyle(color: kTextSecondary, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 2),
                Text(" ${total.toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kPrimaryColor, letterSpacing: -1)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: kBackgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorderColor),
            ),
            child: Column(
              children: [
                Text("$count", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: kPrimaryColor)),
                const Text("Invoices", style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: kTextSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactAnalytics(Map<int, double> data) {
    final Map<int, double> activeHours = {};
    for(int i = 7; i <= 22; i++) {
      activeHours[i] = data[i] ?? 0.0;
    }

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Hourly Performance", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 1.2)),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: BarChart(_getProfessionalBarData(activeHours)),
          ),
        ],
      ),
    );
  }

  BarChartData _getProfessionalBarData(Map<int, double> data) {
    return BarChartData(
      barTouchData: BarTouchData(enabled: true),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 5000,
        getDrawingHorizontalLine: (v) => FlLine(color: kBorderColor.withOpacity(0.15), strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            getTitlesWidget: (v, m) {
              if (v == 0) return const SizedBox();
              String text = v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0);
              return Text(text, style: const TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.bold));
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            getTitlesWidget: (v, m) {
              int h = v.toInt();
              if (h % 3 != 0) return const SizedBox();
              String suffix = h >= 12 ? ' PM' : ' AM';
              int displayHour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
              if (h == 12) displayHour = 12;
              return SideTitleWidget(meta: m, space: 4, child: Text('$displayHour$suffix', style: const TextStyle(fontSize: 7, color: kTextSecondary, fontWeight: FontWeight.w900)));
            },
          ),
        ),
      ),
      barGroups: data.entries.toList().asMap().entries.map((entry) {
        final e = entry.value;
        final colorIndex = entry.key % kChartColorsList.length;
        return BarChartGroupData(
          x: e.key,
          barRods: [
            BarChartRodData(
              toY: e.value,
              color: kChartColorsList[colorIndex],
              width: 8,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
            )
          ],
        );
      }).toList(),
    );
  }

  Widget _buildHighDensityLedgerRow(Map<String, dynamic> data, bool isLast) {
    double saleTotal = double.tryParse(data['total']?.toString() ?? '0') ?? 0;
    double discount = double.tryParse(data['discount']?.toString() ?? '0') ?? 0;
    double tax = double.tryParse(data['totalTax']?.toString() ?? data['taxAmount']?.toString() ?? '0') ?? 0;
    String mode = (data['paymentMode'] ?? 'Cash').toString().toLowerCase();
    String status = (data['status'] ?? '').toString().toLowerCase();
    bool isCancelled = status == 'cancelled';
    bool isReturned = status == 'returned' || data['hasBeenReturned'] == true;

    Color modeColor = kIncomeGreen;
    if (mode.contains('online') || mode.contains('upi') || mode.contains('card')) modeColor = kPrimaryColor;
    else if (mode.contains('credit')) modeColor = kWarningOrange;

    Color statusColor = kIncomeGreen;
    String statusText = 'COMPLETED';
    if (isCancelled) {
      statusColor = kExpenseRed;
      statusText = 'CANCELLED';
    } else if (isReturned) {
      statusColor = kWarningOrange;
      statusText = 'RETURNED';
    }

    DateTime? dt;
    if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
    final timeStr = dt != null ? DateFormat('hh:mm a').format(dt) : '--:--';
    final dateStr = dt != null ? DateFormat('dd MMM').format(dt) : '--/--';

    // Get items list
    List<dynamic> items = data['items'] ?? [];
    int itemCount = items.length;

    // Get customer details
    String customerName = (data['customerName'] ?? 'Guest').toString();
    String customerPhone = (data['customerPhone'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isCancelled || isReturned ? statusColor.withOpacity(0.3) : kBorderColor.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: modeColor.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // Invoice Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: modeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_rounded, size: 14, color: modeColor),
                      const SizedBox(width: 6),
                      Text(
                        '#${data['invoiceNumber'] ?? 'N/A'}',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: modeColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Time Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kBackgroundColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time_rounded, size: 12, color: kTextSecondary),
                      const SizedBox(width: 4),
                      Text(timeStr, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kTextSecondary)),
                    ],
                  ),
                ),
                const Spacer(),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),

          // Customer & Items Section
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer Info
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.person_rounded, size: 16, color: kPrimaryColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (customerPhone.isNotEmpty)
                            Text(
                              customerPhone,
                              style: const TextStyle(fontSize: 10, color: kTextSecondary, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Items Summary
                if (itemCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kBackgroundColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kBorderColor.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shopping_bag_outlined, size: 14, color: kTextSecondary),
                            const SizedBox(width: 6),
                            Text(
                              '$itemCount ITEM${itemCount > 1 ? 'S' : ''}',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...items.take(3).map((item) {
                          String itemName = item['name']?.toString() ?? 'Item';
                          int qty = int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
                          double itemPrice = double.tryParse(item['total']?.toString() ?? '0') ?? 0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    color: kPrimaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '$itemName × $qty',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  ' ${itemPrice.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kPrimaryColor),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        if (itemCount > 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '+${itemCount - 3} more items...',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: kTextSecondary, fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Financial Details Row
                Row(
                  children: [
                    // Payment Method
                    Expanded(
                      child: _buildDetailTile(
                        icon: mode.contains('online') || mode.contains('upi')
                            ? Icons.credit_card_rounded
                            : mode.contains('credit')
                                ? Icons.event_note_rounded
                                : Icons.money_rounded,
                        label: 'PAYMENT',
                        value: mode,
                        color: modeColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Discount (if any)
                    if (discount > 0)
                      Expanded(
                        child: _buildDetailTile(
                          icon: Icons.local_offer_rounded,
                          label: 'DISCOUNT',
                          value: ' ${discount.toStringAsFixed(0)}',
                          color: kWarningOrange,
                        ),
                      ),
                    if (discount > 0) const SizedBox(width: 8),
                    // Tax (if any)
                    if (tax > 0)
                      Expanded(
                        child: _buildDetailTile(
                          icon: Icons.receipt_long_rounded,
                          label: 'TAX',
                          value: ' ${tax.toStringAsFixed(0)}',
                          color: kIncomeGreen,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Footer with Total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: modeColor.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border(
                top: BorderSide(color: kBorderColor.withOpacity(0.3)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL AMOUNT',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.8),
                ),
                Text(
                  ' ${saleTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isCancelled || isReturned ? Colors.grey : modeColor,
                    letterSpacing: -0.5,
                    decoration: isCancelled || isReturned ? TextDecoration.lineThrough : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTile({required IconData icon, required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 10, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.3)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // --- MODERN DAYBOOK UI COMPONENTS ---

  Widget _buildDayBookDateSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimaryColor.withOpacity(0.85), const Color(0xFF00695C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daybook',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.white70,
                  letterSpacing: 1.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => _selectDate(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.calendar_month_rounded, color: kPrimaryColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selected Date',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('dd MMM yyyy, EEEE').format(_selectedDate),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios_rounded, color: kPrimaryColor, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayBookSummaryCards(
    int salesCount, double salesAmount,
    int expensesCount, double expensesAmount,
    int purchasesCount, double purchasesAmount,
    double saleCreditGiven, double saleCreditReceived,
    double purchaseCreditAdded, double purchaseCreditPaid,
  ) {
    final netCashFlow = salesAmount - expensesAmount - purchasesAmount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Net Cash Flow Highlight Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: netCashFlow >= 0
                  ? [const Color(0xFF81C784), const Color(0xFF66BB6A)]  // Soft green
                  : [const Color(0xFFE57373), const Color(0xFFEF5350)],  // Soft red
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (netCashFlow >= 0 ? const Color(0xFF81C784) : const Color(0xFFE57373)).withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        netCashFlow >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Net Cash Flow',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${netCashFlow.abs().toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  netCashFlow >= 0 ? 'Positive Balance' : 'Negative Balance',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Main Transaction Cards Grid
          Row(
            children: [
              Expanded(
                child: _buildModernSummaryCard(
                  'Sales',
                  salesAmount,
                  salesCount,
                  Icons.point_of_sale_rounded,
                  const Color(0xFF64B5F6),  // Soft blue
                  const Color(0xFF42A5F5),  // Mild blue
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModernSummaryCard(
                  'Expenses',
                  expensesAmount,
                  expensesCount,
                  Icons.shopping_cart_rounded,
                  const Color(0xFFEF9A9A),  // Soft red/pink
                  const Color(0xFFE57373),  // Mild red
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildModernSummaryCard(
                  'Purchases',
                  purchasesAmount,
                  purchasesCount,
                  Icons.inventory_2_rounded,
                  const Color(0xFFFFB74D),  // Soft orange
                  const Color(0xFFFFA726),  // Mild orange
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModernSummaryCard(
                  'Credit',
                  saleCreditGiven + purchaseCreditAdded,
                  0,
                  Icons.account_balance_wallet_rounded,
                  const Color(0xFFBA68C8),  // Soft purple
                  const Color(0xFFAB47BC),  // Mild purple
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Credit Details Expansion
          Container(
            decoration: BoxDecoration(
              color: kSurfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorderColor.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                _buildCreditDetailRow('Sale On Credit', saleCreditGiven, Icons.arrow_upward_rounded, const Color(0xFFEF9A9A)),  // Soft red
                Divider(height: 1, color: kBorderColor.withOpacity(0.3)),
                _buildCreditDetailRow('Sale Credit Collected', saleCreditReceived, Icons.arrow_downward_rounded, const Color(0xFF81C784)),  // Soft green
                Divider(height: 1, color: kBorderColor.withOpacity(0.3)),
                _buildCreditDetailRow('Purchase Credit', purchaseCreditAdded, Icons.add_circle_outline_rounded, const Color(0xFFFFB74D)),  // Soft orange
                Divider(height: 1, color: kBorderColor.withOpacity(0.3)),
                _buildCreditDetailRow('Purchase Credit Paid', purchaseCreditPaid, Icons.check_circle_outline_rounded, const Color(0xFF64B5F6)),  // Soft blue
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSummaryCard(
    String label,
    double amount,
    int count,
    IconData icon,
    Color color1,
    Color color2,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color1, color2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color1.withOpacity(0.15),  // Very soft shadow
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${amount.toStringAsFixed(1)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditDetailRow(String label, double amount, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Text(
            '${amount.toStringAsFixed(1)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayBookPaymentBreakdown(double outCash, double outOnline, double inCash, double inOnline) {
    final totalOut = outCash + outOnline;
    final totalIn = inCash + inOnline;
    final outCashPercent = totalOut > 0 ? (outCash / totalOut) : 0.0;
    final inCashPercent = totalIn > 0 ? (inCash / totalIn) : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.payments_rounded, color: kPrimaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                'Payment Breakdown',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              // Payment Out
              Expanded(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: CircularProgressIndicator(
                            value: outCashPercent,
                            strokeWidth: 10,
                            backgroundColor: const Color(0xFFFFE0B2),  // Keep soft peach background
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFB74D)),  // Soft orange
                          ),
                        ),
                        Column(
                          children: [
                            const Icon(Icons.arrow_circle_up_rounded, color: Color(0xFFFFB74D), size: 28),  // Soft orange
                            const SizedBox(height: 4),
                            Text(
                              '${totalOut.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Payment Out',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFFB74D),  // Soft orange
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildPaymentMethodRow('Cash', outCash, const Color(0xFFFFB74D), outCashPercent),  // Soft orange
                    const SizedBox(height: 6),
                    _buildPaymentMethodRow('Online', outOnline, const Color(0xFFFFA726), 1 - outCashPercent),  // Mild orange
                  ],
                ),
              ),

              const SizedBox(width: 24),

              // Payment In
              Expanded(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: CircularProgressIndicator(
                            value: inCashPercent,
                            strokeWidth: 10,
                            backgroundColor: const Color(0xFFC8E6C9),  // Keep soft green background
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF81C784)),  // Soft green
                          ),
                        ),
                        Column(
                          children: [
                            const Icon(Icons.arrow_circle_down_rounded, color: Color(0xFF81C784), size: 28),  // Soft green
                            const SizedBox(height: 4),
                            Text(
                              '${totalIn.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Payment In',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF81C784),  // Soft green
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildPaymentMethodRow('Cash', inCash, const Color(0xFF81C784), inCashPercent),  // Soft green
                    const SizedBox(height: 6),
                    _buildPaymentMethodRow('Online', inOnline, const Color(0xFF66BB6A), 1 - inCashPercent),  // Mild green
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodRow(String method, double amount, Color color, double percent) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            method,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: kTextSecondary,
            ),
          ),
        ),
        Text(
          '${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${(percent * 100).toStringAsFixed(0)}%',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: kTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDayBookTransactionTable(List<Map<String, dynamic>> transactions) {
    // Apply selected transaction filter
    final filteredTransactions = transactions.where((txn) {
      if (_txnFilter == 'All') return true;

      final pm = (txn['paymentMode'] ?? '').toString().toLowerCase();
      final category = txn['category']?.toString().toLowerCase() ?? '';

      switch (_txnFilter) {
        case 'Cash':
          return pm.contains('cash');
        case 'Online':
          return pm.contains('online') || pm.contains('upi') || pm.contains('card');
        case 'Split':
          return pm.contains('split');
        case 'Credit':
          // credit may appear in paymentMode or category names
          return pm.contains('credit') || category.contains('credit');
        default:
          return true;
      }
    }).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kPrimaryColor.withOpacity(0.1), kPrimaryColor.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kPrimaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Transaction Timeline',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${filteredTransactions.length} of ${transactions.length} Transactions',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: kTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Filter chips row
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _txnFilterOptions.map((opt) {
                    final selected = _txnFilter == opt;
                    return ChoiceChip(
                      label: Text(
                        opt,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : kPrimaryColor,
                        ),
                      ),
                      selected: selected,
                      selectedColor: kPrimaryColor,
                      backgroundColor: kSurfaceColor,
                      showCheckmark: false,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      onSelected: (_) => setState(() => _txnFilter = opt),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Transactions List
          if (filteredTransactions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 48, color: kTextSecondary.withOpacity(0.3)),
                    const SizedBox(height: 12),
                    Text(
                      _txnFilter == 'All'
                        ? 'No transactions for this date'
                        : 'No $_txnFilter transactions found',
                      style: const TextStyle(
                        color: kTextSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: filteredTransactions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _buildDayBookTransactionCard(filteredTransactions[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildDayBookTransactionCard(Map<String, dynamic> txn) {
    final category = txn['category'].toString();
    final isIncome = category == 'Sale';
    final cashFlow = isIncome ? txn['cashIn'] as double : txn['cashOut'] as double;

    DateTime? dt;
    if (txn['timestamp'] != null) dt = (txn['timestamp'] as Timestamp).toDate();
    final timeStr = dt != null ? DateFormat('hh:mm a').format(dt) : 'N/A';

    Color categoryColor = const Color(0xFF81C784);  // Soft green
    Color bgColor = const Color(0xFFE8F5E9);
    IconData categoryIcon = Icons.point_of_sale_rounded;

    if (category == 'Expense') {
      categoryColor = const Color(0xFFEF9A9A);  // Soft red/pink
      bgColor = const Color(0xFFFFEBEE);
      categoryIcon = Icons.shopping_cart_rounded;
    } else if (category == 'Purchase') {
      categoryColor = const Color(0xFFFFB74D);  // Soft orange
      bgColor = const Color(0xFFFFF3E0);
      categoryIcon = Icons.inventory_2_rounded;
    } else if (category == 'Credit Received') {
      categoryColor = const Color(0xFF81C784);  // Soft green
      bgColor = const Color(0xFFE8F5E9);
      categoryIcon = Icons.account_balance_wallet_rounded;
    } else if (category == 'Purchase Credit') {
      categoryColor = const Color(0xFFBA68C8);  // Soft purple
      bgColor = const Color(0xFFF3E5F5);
      categoryIcon = Icons.credit_card_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: categoryColor.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon & Timeline
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: categoryColor,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: categoryColor.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(categoryIcon, color: Colors.white, size: 20),
                ),
              ],
            ),

            const SizedBox(width: 14),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: categoryColor,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: categoryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    txn['name'].toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    txn['particulars'].toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kTextSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Payment Mode Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: categoryColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              txn['paymentMode'].toString().contains('cash')
                                ? Icons.money_rounded
                                : Icons.credit_card_rounded,
                              size: 12,
                              color: categoryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              txn['paymentMode'].toString(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: categoryColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Amount
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${(txn['total'] as double).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
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
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 4. SALES SUMMARY (Enhanced with all features from screenshot)
// ==========================================
class SalesSummaryPage extends StatefulWidget {
  final VoidCallback onBack;

  const SalesSummaryPage({super.key, required this.onBack});

  @override
  State<SalesSummaryPage> createState() => _SalesSummaryPageState();
}

class _SalesSummaryPageState extends State<SalesSummaryPage> {
  final FirestoreService _firestoreService = FirestoreService();
  DateFilterOption _selectedFilter = DateFilterOption.today;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  void _onDateChanged(DateFilterOption option, DateTime start, DateTime end) {
    setState(() {
      _selectedFilter = option;
      _startDate = start;
      _endDate = end;
    });
  }

  bool _isInDateRange(DateTime? dt) {
    if (dt == null) return false;
    return dt.isAfter(_startDate.subtract(const Duration(seconds: 1))) &&
        dt.isBefore(_endDate.add(const Duration(seconds: 1)));
  }

  // Store calculated data for PDF download
  double _grossSale = 0, _discount = 0, _netSale = 0, _productCost = 0;
  double _cash = 0, _online = 0, _creditNote = 0, _credit = 0, _unsettled = 0, _refunds = 0;
  int _saleCount = 0;

  void _downloadPdf(BuildContext context) {
    final rows = [
      ['Gross Sales', ' ${_grossSale.toStringAsFixed(2)}'],
      ['Discount', ' ${_discount.toStringAsFixed(2)}'],
      ['Net Sales', ' ${_netSale.toStringAsFixed(2)}'],
      ['Product Cost', ' ${_productCost.toStringAsFixed(2)}'],
      ['Cash', ' ${_cash.toStringAsFixed(2)}'],
      ['Online', ' ${_online.toStringAsFixed(2)}'],
      ['Credit Note/Refunds', ' ${_creditNote.toStringAsFixed(2)}'],
      ['Credit', ' ${_credit.toStringAsFixed(2)}'],
      ['Unsettled', ' ${_unsettled.toStringAsFixed(2)}'],
    ];

    ReportPdfGenerator.generateAndDownloadPdf(
      context: context,
      reportTitle: 'Financial Insights Report',
      headers: ['Metric', 'Amount'],
      rows: rows,
      summaryTitle: "Net Profit",
      summaryValue: " ${(_netSale - _productCost).toStringAsFixed(2)}",
      additionalSummary: {
        'Period': '${DateFormat('dd/MM/yy').format(_startDate)} - ${DateFormat('dd/MM/yy').format(_endDate)}',
        'Total Bills': '$_saleCount',
        'Refunds': ' ${_refunds.toStringAsFixed(2)}',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: _buildModernAppBar("Financial Insights", widget.onBack, onDownload: () => _downloadPdf(context)),
      body: FutureBuilder<List<Stream<QuerySnapshot>>>(
        future: Future.wait([
          _firestoreService.getCollectionStream('sales'),
          _firestoreService.getCollectionStream('expenses'),
        ]),
        builder: (context, streamsSnapshot) {
          if (!streamsSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2));
          }
          return StreamBuilder<QuerySnapshot>(
            stream: streamsSnapshot.data![0],
            builder: (context, salesSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: streamsSnapshot.data![1],
                builder: (context, expenseSnapshot) {
                  if (!salesSnapshot.hasData || !expenseSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                  }

                  // --- Calculation Logic ---
                  double grossSale = 0, discount = 0, netSale = 0, productCost = 0;
                  double cash = 0, online = 0, creditNote = 0, credit = 0, unsettled = 0;
                  double refunds = 0; // Track cancelled/returned bills
                  Map<int, double> hourlyRevenue = {};
                  int saleCount = 0;

                  for (var doc in salesSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    DateTime? dt;
                    if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                    else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());

                    if (_isInDateRange(dt)) {
                      double total = double.tryParse(data['total']?.toString() ?? '0') ?? 0;
                      double discountAmt = double.tryParse(data['discount']?.toString() ?? '0') ?? 0;
                      double cost = double.tryParse(data['productCost']?.toString() ?? '0') ?? 0;
                      String mode = (data['paymentMode'] ?? 'Cash').toString().toLowerCase();

                      // Check if bill is cancelled or returned
                      final String status = (data['status'] ?? '').toString().toLowerCase();
                      final bool isCancelled = status == 'cancelled';
                      final bool isReturned = status == 'returned' || data['hasBeenReturned'] == true;
                      final bool isRefunded = isCancelled || isReturned;

                      if (isRefunded) {
                        // Add to refunds instead of regular sales
                        refunds += total;
                        continue; // Skip adding to other totals
                      }

                      grossSale += total + discountAmt;
                      discount += discountAmt;
                      netSale += total;
                      productCost += cost;
                      saleCount++;

                      // Handle Split payments separately
                      if (mode == 'split') {
                        // For split payments, get the individual amounts
                        double splitCash = double.tryParse(data['cashReceived_split']?.toString() ?? '0') ?? 0;
                        double splitOnline = double.tryParse(data['onlineReceived_split']?.toString() ?? '0') ?? 0;
                        double splitCredit = double.tryParse(data['creditIssued_split']?.toString() ?? '0') ?? 0;
                        cash += splitCash;
                        online += splitOnline;
                        credit += splitCredit;
                      } else if (mode.contains('online') || mode.contains('upi') || mode.contains('card')) {
                        online += total;
                      } else if (mode.contains('credit') && mode.contains('note')) {
                        creditNote += total;
                      } else if (mode.contains('credit')) {
                        credit += total;
                      } else if (mode.contains('unsettled')) {
                        unsettled += total;
                      } else {
                        // Cash payment
                        cash += total;
                      }

                      if (dt != null) hourlyRevenue[dt.hour] = (hourlyRevenue[dt.hour] ?? 0) + total;
                    }
                  }

                  // Add refunds to creditNote for display (purple section)
                  creditNote += refunds;

                  double profit = netSale - productCost;

                  // Store values for PDF download
                  _grossSale = grossSale;
                  _discount = discount;
                  _netSale = netSale;
                  _productCost = productCost;
                  _cash = cash;
                  _online = online;
                  _creditNote = creditNote;
                  _credit = credit;
                  _unsettled = unsettled;
                  _refunds = refunds;
                  _saleCount = saleCount;

                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: DateFilterWidget(
                          selectedOption: _selectedFilter,
                          startDate: _startDate,
                          endDate: _endDate,
                          onDateChanged: _onDateChanged,
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            // Top Profit Ribbon
                            _buildExecutiveProfitCard(profit, netSale),
                            const SizedBox(height: 16),

                            // Metrics Grid
                            _buildMetricsGrid(netSale, grossSale, productCost, discount, saleCount),

                            const SizedBox(height: 24),
                            _buildSectionLabel("Revenue Timeline"),
                            const SizedBox(height: 10),
                            _buildDashboardCard(
                              child: _buildBarChart(hourlyRevenue),
                            ),

                            const SizedBox(height: 24),
                            _buildSectionLabel("Payment Structure"),
                            const SizedBox(height: 10),
                            _buildDashboardCard(
                              child: _buildDonutChartSection(netSale, cash, online, creditNote, credit, unsettled),
                            ),
                            const SizedBox(height: 30),
                          ]),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // --- MODERN UI COMPONENTS ---

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: kTextSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildExecutiveProfitCard(double profit, double netSale) {
    final margin = netSale > 0 ? (profit / netSale) * 100 : 0.0;
    final bool isPositive = profit >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderColor.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Estimated Profit",
                  style: TextStyle(color: kTextSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                ),
                const SizedBox(height: 4),
                Text(
                  "${profit.toStringAsFixed(2)}",
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: isPositive ? kIncomeGreen : kExpenseRed,
                      letterSpacing: -0.8
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (isPositive ? kIncomeGreen : kExpenseRed).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: (isPositive ? kIncomeGreen : kExpenseRed).withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Text(
                  "${margin.toStringAsFixed(1)}%",
                  style: TextStyle(color: isPositive ? kIncomeGreen : kExpenseRed, fontWeight: FontWeight.w900, fontSize: 14),
                ),
                const Text("Margin", style: TextStyle(color: kTextSecondary, fontSize: 8, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(double net, double gross, double cost, double disc, int count) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildMetricTile("Net Revenue", net, kPrimaryColor, Icons.account_balance_wallet_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _buildMetricTile("Total Sales", gross, const Color(0xFF5C6BC0), Icons.receipt_rounded)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildMetricTile("Cost Value", cost, kExpenseRed, Icons.inventory_2_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _buildMetricTile("Discounts", disc, kWarningOrange, Icons.confirmation_number_rounded)),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile(String title, double val, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color.withOpacity(0.7), size: 14),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(color: kTextSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "${val.toStringAsFixed(0)}",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderColor.withOpacity(0.7)),
      ),
      child: child,
    );
  }

  Widget _buildBarChart(Map<int, double> data) {
    return SizedBox(
      height: 140,
      child: data.isEmpty
          ? const Center(child: Text('No trend data', style: TextStyle(color: kTextSecondary, fontSize: 14)))
          : BarChart(
        BarChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 5000,
            getDrawingHorizontalLine: (v) => FlLine(color: kBorderColor.withOpacity(0.2), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (v, m) {
                  int h = v.toInt();
                  if (h % 6 != 0) return const SizedBox();
                  String label = '${h > 12 ? h - 12 : (h == 0 ? 12 : h)}${h >= 12 ? 'pm' : 'am'}';
                  return SideTitleWidget(meta: m, space: 4, child: Text(label, style: const TextStyle(fontSize: 9, color: kTextSecondary, fontWeight: FontWeight.bold)));
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, m) {
                  if (v == 0) return const SizedBox();
                  return Text(v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0), style: const TextStyle(fontSize: 8, color: kTextSecondary));
                },
              ),
            ),
          ),
          barGroups: data.entries.toList().asMap().entries.map((entry) {
            final e = entry.value;
            final colorIndex = entry.key % kChartColorsList.length;
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value,
                  color: kChartColorsList[colorIndex],
                  width: 8,
                  borderRadius: BorderRadius.circular(2),
                )
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDonutChartSection(double net, double cash, double online, double cn, double credit, double unsettled) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: SizedBox(
            height: 130,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 32,
                    sections: [
                      if (cash > 0) PieChartSectionData(color: kChartGreen, value: cash, title: '', radius: 14),
                      if (online > 0) PieChartSectionData(color: kChartBlue, value: online, title: '', radius: 14),
                      if (cn > 0) PieChartSectionData(color: kChartPurple, value: cn, title: '', radius: 14),
                      if (credit > 0) PieChartSectionData(color: kChartRed, value: credit, title: '', radius: 14),
                      if (unsettled > 0) PieChartSectionData(color: kChartAmber, value: unsettled, title: '', radius: 14),
                      if (net == 0) PieChartSectionData(color: kBorderColor.withValues(alpha: 0.3), value: 1, title: '', radius: 14),
                    ],
                  ),
                ),
                const Icon(Icons.pie_chart_outline_rounded, color: kTextSecondary, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendRow(kChartGreen, 'Cash', cash),
              _buildLegendRow(kChartBlue, 'Online', online),
              _buildLegendRow(kChartPurple, 'Refunds', cn),
              _buildLegendRow(kChartRed, 'Credit', credit),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildLegendRow(Color color, String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 10, color: kTextSecondary, fontWeight: FontWeight.w600))),
          Text("${value.toStringAsFixed(0)}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
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

  void _downloadPdf(BuildContext context, List<DocumentSnapshot> docs) {
    // Filter out cancelled and returned bills for PDF
    final filteredDocs = docs.where((doc) {
      final d = doc.data() as Map<String, dynamic>;
      final String status = (d['status'] ?? '').toString().toLowerCase();
      final bool isCancelled = status == 'cancelled';
      final bool isReturned = status == 'returned' || d['hasBeenReturned'] == true;
      return !isCancelled && !isReturned;
    }).toList();

    double totalSales = 0;
    final rows = filteredDocs.map((doc) {
      final d = doc.data() as Map<String, dynamic>;
      DateTime? dt;
      if (d['timestamp'] != null) dt = (d['timestamp'] as Timestamp).toDate();
      final dateStr = dt != null ? DateFormat('dd MMM yyyy').format(dt) : 'N/A';
      final total = double.tryParse(d['total']?.toString() ?? '0') ?? 0;
      totalSales += total;
      return [
        (d['invoiceNumber']?.toString() ?? 'N/A').padLeft(5, '0'),
        dateStr,
        (d['customerName']?.toString() ?? 'GUEST'),
        (d['paymentMode']?.toString() ?? 'CASH'),
        "${total.toStringAsFixed(2)}",
      ];
    }).toList();

    ReportPdfGenerator.generateAndDownloadPdf(
      context: context,
      reportTitle: 'Executive Sales Audit Log',
      headers: ['Invoice', 'Date', 'Customer Name', 'Mode', 'Amount'],
      rows: rows,
      summaryTitle: 'Total Amount Settlement',
      summaryValue: "${totalSales.toStringAsFixed(2)}",
      additionalSummary: {
        'Invoices Closed': '${filteredDocs.length}',
        'Audit Date': DateFormat('dd MMM yyyy').format(DateTime.now()),
        'Status': 'Verified'
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Stream<QuerySnapshot>>(
      future: _firestoreService.getCollectionStream('sales'),
      builder: (context, streamSnapshot) {
        if (!streamSnapshot.hasData) {
          return Scaffold(
            backgroundColor: kBackgroundColor,
            appBar: _buildModernAppBar("Sales History", onBack),
            body: const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2)),
          );
        }
        return StreamBuilder<QuerySnapshot>(
          stream: streamSnapshot.data!,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Scaffold(
                backgroundColor: kBackgroundColor,
                appBar: _buildModernAppBar("Sales History", onBack),
                body: const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
              );
            }

            List<DocumentSnapshot> docs = snapshot.data!.docs;

            // Sort by timestamp newest first
            docs.sort((a, b) {
              final da = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
              final db = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
              return (db?.toDate() ?? DateTime.now()).compareTo(da?.toDate() ?? DateTime.now());
            });

            double grandTotal = 0;
            Map<String, double> dailySales = {};

            for (var doc in docs) {
              var d = doc.data() as Map<String, dynamic>;
              double total = double.tryParse(d['total']?.toString() ?? '0') ?? 0;
              grandTotal += total;

              if (d['timestamp'] != null) {
                DateTime dt = (d['timestamp'] as Timestamp).toDate();
                String dateKey = DateFormat('MM/dd').format(dt);
                dailySales[dateKey] = (dailySales[dateKey] ?? 0) + total;
              }
            }

            // Get last 7 unique days for the trend chart
            var sortedTrendEntries = dailySales.entries.toList();
            sortedTrendEntries.sort((a, b) => a.key.compareTo(b.key));
            var displayTrend = sortedTrendEntries.length > 7
                ? sortedTrendEntries.sublist(sortedTrendEntries.length - 7)
                : sortedTrendEntries;

            return Scaffold(
              backgroundColor: kBackgroundColor,
              appBar: _buildModernAppBar(
                  "Sales History",
                  onBack,
                  onDownload: () => _downloadPdf(context, docs)
              ),
              body: Column(
                children: [
                  _buildExecutiveHistoryHeader(grandTotal, docs.length),
                  Expanded(
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        if (displayTrend.isNotEmpty) ...[
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            sliver: SliverToBoxAdapter(child: _buildSectionHeader("Financial Velocity Trend")),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 10)),
                          SliverToBoxAdapter(
                            child: _buildTrendAreaChart(displayTrend),
                          ),
                        ],

                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          sliver: SliverToBoxAdapter(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSectionHeader("Full Audit Ledger"),
                                Text(
                                  "${docs.length} INVOICES",
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kPrimaryColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),

                        docs.isEmpty
                            ? const SliverFillRemaining(child: Center(child: Text("No transactions recorded", style: TextStyle(color: kTextSecondary))))
                            : SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 0),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                                  (context, index) => _buildHighDensityHistoryRow(docs[index].data() as Map<String, dynamic>),
                              childCount: docs.length,
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 40)),
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
  }

  // --- EXECUTIVE UI COMPONENTS ---

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 1.2),
    );
  }

  Widget _buildExecutiveHistoryHeader(double total, int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Net Settlement Value", style: TextStyle(color: kTextSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const SizedBox(height: 2),
              Text("${total.toStringAsFixed(2)}", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kPrimaryColor, letterSpacing: -1)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kPrimaryColor.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Text("$count", style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900, fontSize: 16)),
                const Text("Closed", style: TextStyle(color: kTextSecondary, fontSize: 7, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendAreaChart(List<MapEntry<String, double>> trend) {
    // Explicitly calculate maxVal to prevent type inference errors
    final double maxVal = trend.isEmpty
        ? 1000
        : trend.fold<double>(0, (prev, element) => element.value > prev ? element.value : prev);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(12, 24, 20, 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderColor.withOpacity(0.7)),
      ),
      child: SizedBox(
        height: 160,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (v) => FlLine(color: kBorderColor.withOpacity(0.2), strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (v, m) {
                    if (v == 0) return const SizedBox();
                    String text = v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0);
                    return Text(text, style: const TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.bold));
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (v, m) {
                    int index = v.toInt();
                    if (index < 0 || index >= trend.length) return const SizedBox();
                    return SideTitleWidget(
                      meta: m,
                      space: 8,
                      child: Text(trend[index].key, style: const TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.w900)),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                // FIX: Access e.value.value because 'trend' is a List<MapEntry<String, double>>
                // When we call asMap().entries, the value is the MapEntry itself.
                spots: trend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
                isCurved: true,
                curveSmoothness: 0.35,
                color: kIncomeGreen,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                    radius: 3,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: kIncomeGreen,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [kIncomeGreen.withOpacity(0.15), kIncomeGreen.withOpacity(0)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighDensityHistoryRow(Map<String, dynamic> data) {
    final double total = double.tryParse(data['total']?.toString() ?? '0') ?? 0.0;
    final String mode = (data['paymentMode'] ?? 'Cash').toString().toLowerCase();

    Color modeColor = kIncomeGreen;
    if (mode.contains('online') || mode.contains('upi') || mode.contains('card')) modeColor = kPrimaryColor;
    else if (mode.contains('credit')) modeColor = kWarningOrange;

    DateTime? dt;
    if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
    final timeStr = dt != null ? DateFormat('dd MMM • hh:mm a').format(dt) : '--/--';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 24,
            decoration: BoxDecoration(color: modeColor, borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (data['customerName'] ?? 'Guest').toString(),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                    "Invoice${data['invoiceNumber'] ?? 'N/A'}  •  $timeStr",
                    style: const TextStyle(fontSize: 9, color: kTextSecondary, fontWeight: FontWeight.bold)
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                  "${total.toStringAsFixed(0)}",
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black87, letterSpacing: -0.5)
              ),
              Text(
                  mode,
                  style: TextStyle(fontSize: 7, color: modeColor, fontWeight: FontWeight.w900, letterSpacing: 0.5)
              ),
            ],
          ),
        ],
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

  void _downloadPdf(BuildContext context, List<MapEntry<String, double>> sorted) {
    final rows = sorted.asMap().entries.map((e) => [
      '${e.key + 1}',
      e.value.key,
      "${e.value.value.toStringAsFixed(2)}",
    ]).toList();

    final totalSpend = sorted.fold<double>(0, (sum, e) => sum + e.value);

    ReportPdfGenerator.generateAndDownloadPdf(
      context: context,
      reportTitle: 'Customer Contribution Audit',
      headers: ['RANK', 'CUSTOMER NAME', 'TOTAL SPEND'],
      rows: rows,
      summaryTitle: 'GRAND TOTAL SETTLEMENT',
      summaryValue: "${totalSpend.toStringAsFixed(2)}",
      additionalSummary: {
        'Customer Base': '${sorted.length} Unique Clients',
        'Audit Date': DateFormat('dd MMM yyyy').format(DateTime.now()),
        'Status': 'Certified'
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Stream<QuerySnapshot>>(
      future: _firestoreService.getCollectionStream('sales'),
      builder: (context, streamSnapshot) {
        if (!streamSnapshot.hasData) {
          return Scaffold(
            backgroundColor: kBackgroundColor,
            appBar: _buildModernAppBar("Customer Analytics", onBack),
            body: const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2)),
          );
        }
        return StreamBuilder<QuerySnapshot>(
          stream: streamSnapshot.data!,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Scaffold(
                backgroundColor: kBackgroundColor,
                appBar: _buildModernAppBar("Customer Analytics", onBack),
                body: const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
              );
            }

            // --- Aggregation Logic ---
            Map<String, double> spendMap = {};
            for (var d in snapshot.data!.docs) {
              var data = d.data() as Map<String, dynamic>;

              // Skip cancelled or returned bills
              final String status = (data['status'] ?? '').toString().toLowerCase();
              if (status == 'cancelled' || status == 'returned' || data['hasBeenReturned'] == true) {
                continue;
              }

              double amt = double.tryParse(data['total']?.toString() ?? '0') ?? 0;
              String name = data['customerName'] ?? 'Guest';

              // Skip "Guest" customers - only count named customers
              if (name.toLowerCase() == 'guest') {
                continue;
              }

              spendMap[name] = (spendMap[name] ?? 0) + amt;
            }

            var sorted = spendMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
            var top6 = sorted.take(6).toList();
            double grandTotalSpend = sorted.fold(0, (sum, e) => sum + e.value);

            return Scaffold(
              backgroundColor: kBackgroundColor,
              appBar: _buildModernAppBar(
                  "Customer Analytics",
                  onBack,
                  onDownload: () => _downloadPdf(context, sorted)
              ),
              body: Column(
                children: [
                  _buildExecutiveCustomerHeader(grandTotalSpend, sorted.length),
                  Expanded(
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        if (top6.isNotEmpty) ...[
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            sliver: SliverToBoxAdapter(child: _buildSectionHeader("Revenue contribution")),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 10)),
                          SliverToBoxAdapter(
                            child: _buildContributionGraph(top6),
                          ),
                        ],

                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          sliver: SliverToBoxAdapter(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSectionHeader("Customer Valuation Ledger"),
                                Text(
                                  "${sorted.length} CLIENTS ANALYZED",
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kPrimaryColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),

                        sorted.isEmpty
                            ? const SliverFillRemaining(child: Center(child: Text("No customer transaction data available", style: TextStyle(color: kTextSecondary))))
                            : SliverToBoxAdapter(
                          child: _buildHighDensityCustomerTable(sorted),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 40)),
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
  }

  // --- EXECUTIVE UI COMPONENTS ---

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 1.2),
    );
  }

  Widget _buildExecutiveCustomerHeader(double total, int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("GRAND TOTAL SPEND", style: TextStyle(color: kTextSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const SizedBox(height: 2),
              Text("${total.toStringAsFixed(2)}", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kPrimaryColor, letterSpacing: -1)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kPrimaryColor.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Text("$count", style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900, fontSize: 16)),
                const Text("CLIENTS", style: TextStyle(color: kTextSecondary, fontSize: 7, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContributionGraph(List<MapEntry<String, double>> top6) {
    final double maxVal = top6.isEmpty ? 100 : top6.first.value;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderColor.withOpacity(0.7)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxVal > 0 ? maxVal / 4 : 5,
                  getDrawingHorizontalLine: (v) => FlLine(color: kBorderColor.withOpacity(0.2), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, m) {
                        if (v == 0) return const SizedBox();
                        return Text(v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.bold));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, m) {
                        int index = v.toInt();
                        if (index < 0 || index >= top6.length) return const SizedBox();
                        String label = top6[index].key;
                        if (label.length > 6) label = label.substring(0, 5) + "..";
                        return SideTitleWidget(
                          meta: m,
                          space: 8,
                          child: Text(label, style: const TextStyle(fontSize: 7, color: kTextSecondary, fontWeight: FontWeight.w900)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: top6.asMap().entries.map((e) {
                  final colorIndex = e.key % kChartColorsList.length;
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.value,
                        color: kChartColorsList[colorIndex],
                        width: 16,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 0,
                          color: kBorderColor.withValues(alpha: 0.1),
                        ),
                      )
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text("Financial weight of top customers by total settlement", style: TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildHighDensityCustomerTable(List<MapEntry<String, double>> rows) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border.symmetric(horizontal: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Column(
        children: [
          Container(
            color: kBackgroundColor.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: const [
                Expanded(flex: 1, child: Text("RANK", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
                Expanded(flex: 3, child: Text("CUSTOMER NAME", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text("TOTAL SPEND", textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
              ],
            ),
          ),
          ...rows.asMap().entries.map((e) => _buildCustomerTableRow(e.value, e.key + 1)).toList(),
        ],
      ),
    );
  }

  Widget _buildCustomerTableRow(MapEntry<String, double> entry, int rank) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              "$rank",
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: rank <= 3 ? kPrimaryColor : kTextSecondary),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              entry.key,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "${entry.value.toStringAsFixed(0)}",
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kPrimaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 7. STOCK REPORT (Enhanced with all features from screenshot)
// ==========================================
class StockReportPage extends StatefulWidget {
  final VoidCallback onBack;

  const StockReportPage({super.key, required this.onBack});

  @override
  State<StockReportPage> createState() => _StockReportPageState();
}

class _StockReportPageState extends State<StockReportPage> {
  final FirestoreService _firestoreService = FirestoreService();
  String _searchQuery = '';
  bool _isDescending = true;
  String _sortBy = 'name'; // name, stock, price

  void _downloadPdf(BuildContext context, List<DocumentSnapshot> docs, double totalInvValue, int stockCount, double retailValue, double potentialProfit) {
    final rows = docs.map((doc) {
      final d = doc.data() as Map<String, dynamic>;
      final cost = double.tryParse(d['cost']?.toString() ?? d['purchasePrice']?.toString() ?? '0') ?? 0;
      final price = double.tryParse(d['price']?.toString() ?? '0') ?? 0;
      final stock = double.tryParse(d['currentStock']?.toString() ?? '0') ?? 0;
      return [
        (d['itemName']?.toString() ?? 'Unknown'),
        d['itemId']?.toString() ?? 'N/A',
        stock.toStringAsFixed(0),
        "${cost.toStringAsFixed(2)}",
        "${price.toStringAsFixed(2)}",
        "${(price * stock).toStringAsFixed(2)}",
      ];
    }).toList();

    ReportPdfGenerator.generateAndDownloadPdf(
      context: context,
      reportTitle: 'Executive Stock Valuation Audit',
      headers: ['PRODUCT NAME', 'ID', 'STOCK', 'COST', 'RETAIL', 'VALUATION'],
      rows: rows,
      summaryTitle: 'TOTAL RETAIL VALUE',
      summaryValue: '${retailValue.toStringAsFixed(2)}',
      additionalSummary: {
        'Inventory Cost': '${totalInvValue.toStringAsFixed(2)}',
        'Stock Count': '$stockCount Units',
        'Potential Profit': '${potentialProfit.toStringAsFixed(2)}',
        'Audit Date': DateFormat('dd MMM yyyy').format(DateTime.now()),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Stream<QuerySnapshot>>(
      future: _firestoreService.getCollectionStream('Products'),
      builder: (context, streamSnapshot) {
        if (!streamSnapshot.hasData) {
          return Scaffold(
            backgroundColor: kBackgroundColor,
            appBar: _buildModernAppBar("Stock Inventory Audit", widget.onBack),
            body: const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2)),
          );
        }
        return StreamBuilder<QuerySnapshot>(
          stream: streamSnapshot.data!,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
            }

            double totalInventoryValue = 0; // Cost * Stock
            double totalRetailValue = 0; // Price * Stock
            int totalStockCount = 0;

            List<DocumentSnapshot> allDocs = snapshot.data!.docs;

            for (var d in allDocs) {
              var data = d.data() as Map<String, dynamic>;
              double cost = double.tryParse(data['cost']?.toString() ?? data['purchasePrice']?.toString() ?? '0') ?? 0;
              double price = double.tryParse(data['price']?.toString() ?? '0') ?? 0;
              double stock = double.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;

              if (stock > 0) {
                totalInventoryValue += cost * stock;
                totalRetailValue += price * stock;
                totalStockCount += stock.toInt();
              }
            }

            double potentialProfit = totalRetailValue - totalInventoryValue;

            // --- Search & Filter logic ---
            var filteredDocs = allDocs.where((d) {
              var data = d.data() as Map<String, dynamic>;
              String query = _searchQuery.toLowerCase();
              return (data['itemName']?.toString().toLowerCase() ?? '').contains(query) ||
                  (data['itemId']?.toString().toLowerCase() ?? '').contains(query) ||
                  (data['category']?.toString().toLowerCase() ?? '').contains(query);
            }).toList();

            filteredDocs.sort((a, b) {
              var dataA = a.data() as Map<String, dynamic>;
              var dataB = b.data() as Map<String, dynamic>;
              int result = 0;
              switch (_sortBy) {
                case 'name':
                  result = (dataA['itemName'] ?? '').toString().compareTo((dataB['itemName'] ?? '').toString());
                  break;
                case 'stock':
                  result = (double.tryParse(dataA['currentStock']?.toString() ?? '0') ?? 0).compareTo(double.tryParse(dataB['currentStock']?.toString() ?? '0') ?? 0);
                  break;
                case 'price':
                  result = (double.tryParse(dataA['price']?.toString() ?? '0') ?? 0).compareTo(double.tryParse(dataB['price']?.toString() ?? '0') ?? 0);
                  break;
              }
              return _isDescending ? -result : result;
            });

            return Scaffold(
              backgroundColor: kBackgroundColor,
              appBar: _buildModernAppBar(
                "Inventory Valuation",
                widget.onBack,
                onDownload: () => _downloadPdf(context, filteredDocs, totalInventoryValue, totalStockCount, totalRetailValue, potentialProfit),
              ),
              body: Column(
                children: [
                  _buildExecutiveValuationRibbon(totalInventoryValue, totalRetailValue, potentialProfit, totalStockCount),
                  _buildIntegratedControlStrip(),
                  Expanded(
                    child: filteredDocs.isEmpty
                        ? const Center(child: Text("No inventory items match your audit criteria", style: TextStyle(color: kTextSecondary)))
                        : CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),
                        SliverToBoxAdapter(
                          child: _buildHighDensityStockLedger(filteredDocs),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 40)),
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
  }

  // --- EXECUTIVE UI COMPONENTS ---

  Widget _buildExecutiveValuationRibbon(double cost, double retail, double profit, int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildRibbonSegment("INV. VALUE (COST)", "${cost.toStringAsFixed(0)}", kTextSecondary),
          _buildRibbonSegment("RETAIL VALUE", "${retail.toStringAsFixed(0)}", kPrimaryColor),
          _buildRibbonSegment("POTENTIAL PROFIT", "${profit.toStringAsFixed(0)}", kIncomeGreen),
          _buildRibbonSegment("TOTAL STOCK", "$count", kPurpleCharts),
        ],
      ),
    );
  }

  Widget _buildRibbonSegment(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5)),
      ],
    );
  }

  Widget _buildIntegratedControlStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: kBackgroundColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorderColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 16, color: kTextSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(
                        hintText: 'FILTER BY NAME, ID OR CATEGORY...',
                        hintStyle: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildSortAction(),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => setState(() => _isDescending = !_isDescending),
            icon: Icon(_isDescending ? Icons.south_rounded : Icons.north_rounded, size: 18, color: kPrimaryColor),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSortAction() {
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text("SORT INVENTORY BY", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1, color: kTextSecondary)),
              ),
              ListTile(title: const Text('Alphabetical Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), leading: const Icon(Icons.sort_by_alpha_rounded), selected: _sortBy == 'name', onTap: () { setState(() => _sortBy = 'name'); Navigator.pop(context); }),
              ListTile(title: const Text('Stock Quantity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), leading: const Icon(Icons.inventory_2_rounded), selected: _sortBy == 'stock', onTap: () { setState(() => _sortBy = 'stock'); Navigator.pop(context); }),
              ListTile(title: const Text('Retail Price', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), leading: const Icon(Icons.sell_rounded), selected: _sortBy == 'price', onTap: () { setState(() => _sortBy = 'price'); Navigator.pop(context); }),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            const Icon(Icons.tune_rounded, size: 14, color: kPrimaryColor),
            const SizedBox(width: 6),
            Text(_sortBy, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kPrimaryColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildHighDensityStockLedger(List<DocumentSnapshot> docs) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border.symmetric(horizontal: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            color: kBackgroundColor.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: const [
                Expanded(flex: 3, child: Text("ITEM DESCRIPTION", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
                Expanded(flex: 1, child: Text("STOCK", textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text("RETAIL VAL", textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
              ],
            ),
          ),
          ...docs.map((doc) => _buildStockLedgerRow(doc.data() as Map<String, dynamic>)).toList(),
        ],
      ),
    );
  }

  Widget _buildStockLedgerRow(Map<String, dynamic> data) {
    final double stock = double.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;
    final double price = double.tryParse(data['price']?.toString() ?? '0') ?? 0;
    final double cost = double.tryParse(data['cost']?.toString() ?? data['purchasePrice']?.toString() ?? '0') ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (data['itemName'] ?? 'Unknown').toString(),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "ID: ${data['itemId'] ?? 'N/A'} • COST: ${cost.toStringAsFixed(0)}",
                  style: const TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              stock.toStringAsFixed(0),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextSecondary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${(price * stock).toStringAsFixed(0)}",
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kPrimaryColor),
                ),
                Text(
                  "${price.toStringAsFixed(0)} / UNIT",
                  style: const TextStyle(fontSize: 7, color: kTextSecondary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
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

  void _downloadPdf(BuildContext context, List<MapEntry<String, int>> sorted) {
    final rows = sorted.asMap().entries.map((e) => [
      '${e.key + 1}',
      e.value.key,
      e.value.value.toString(),
    ]).toList();

    final totalQty = sorted.fold<int>(0, (sum, e) => sum + e.value);

    ReportPdfGenerator.generateAndDownloadPdf(
      context: context,
      reportTitle: 'Item Sales Velocity Audit',
      headers: ['RANK', 'ITEM DESCRIPTION', 'UNITS SOLD'],
      rows: rows,
      summaryTitle: 'TOTAL UNIT SETTLEMENT',
      summaryValue: '$totalQty UNITS',
      additionalSummary: {
        'Inventory Scope': '${sorted.length} Unique SKUs',
        'Audit Date': DateFormat('dd MMM yyyy').format(DateTime.now()),
        'Status': 'Verified'
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Stream<QuerySnapshot>>(
      future: _firestoreService.getCollectionStream('sales'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: kBackgroundColor,
            appBar: _buildModernAppBar("Item Sales Velocity", onBack),
            body: const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2)),
          );
        }
        return StreamBuilder<QuerySnapshot>(
          stream: snapshot.data!,
          builder: (context, salesSnap) {
            if (!salesSnap.hasData) {
              return Scaffold(
                backgroundColor: kBackgroundColor,
                appBar: _buildModernAppBar("Item Sales Velocity", onBack),
                body: const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
              );
            }

            // --- Aggregation Logic ---
            Map<String, int> qtyMap = {};
            for (var d in salesSnap.data!.docs) {
              var data = d.data() as Map<String, dynamic>;

              // Skip cancelled or returned bills
              final String status = (data['status'] ?? '').toString().toLowerCase();
              if (status == 'cancelled' || status == 'returned' || data['hasBeenReturned'] == true) {
                continue;
              }

              if (data['items'] != null) {
                for (var item in (data['items'] as List)) {
                  String name = item['name']?.toString() ?? 'Unknown';

                  // Skip quick items (item1, item2, etc.) - only count properly named items
                  if (name.toLowerCase().startsWith('item') &&
                      RegExp(r'^item\d+$', caseSensitive: false).hasMatch(name.toLowerCase())) {
                    continue; // Skip quick items
                  }

                  int q = int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
                  qtyMap[name] = (qtyMap[name] ?? 0) + q;
                }
              }
            }
            var sorted = qtyMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
            var top6 = sorted.take(6).toList();
            int grandTotal = sorted.fold(0, (sum, e) => sum + e.value);

            return Scaffold(
              backgroundColor: kBackgroundColor,
              appBar: _buildModernAppBar(
                  "Item Sales Velocity",
                  onBack,
                  onDownload: () => _downloadPdf(context, sorted)
              ),
              body: Column(
                children: [
                  _buildExecutiveSalesHeader(grandTotal, sorted.length),
                  Expanded(
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        if (top6.isNotEmpty) ...[
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            sliver: SliverToBoxAdapter(child: _buildSectionHeader("Sales Velocity Chart")),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 10)),
                          SliverToBoxAdapter(
                            child: _buildPerformanceChart(top6),
                          ),
                        ],

                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          sliver: SliverToBoxAdapter(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSectionHeader("Product Ranking Ledger"),
                                Text(
                                  "${sorted.length} SKUs ANALYZED",
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kPrimaryColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),

                        sorted.isEmpty
                            ? const SliverFillRemaining(child: Center(child: Text("No sales recorded", style: TextStyle(color: kTextSecondary))))
                            : SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 0),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                                  (context, index) => _buildHighDensityItemRow(sorted[index], index + 1),
                              childCount: sorted.length,
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 40)),
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
  }

  // --- EXECUTIVE UI COMPONENTS ---

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 1.2),
    );
  }

  Widget _buildExecutiveSalesHeader(int totalQty, int uniqueCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("TOTAL UNITS SOLD", style: TextStyle(color: kTextSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const SizedBox(height: 2),
              Text("$totalQty", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kPrimaryColor, letterSpacing: -1)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kPrimaryColor.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Text("$uniqueCount", style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900, fontSize: 16)),
                const Text("VARIETIES", style: TextStyle(color: kTextSecondary, fontSize: 7, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceChart(List<MapEntry<String, int>> top6) {
    final double maxVal = top6.isEmpty ? 10 : top6.first.value.toDouble();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderColor.withOpacity(0.7)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxVal > 0 ? maxVal / 4 : 5,
                  getDrawingHorizontalLine: (v) => FlLine(color: kBorderColor.withOpacity(0.2), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, m) {
                        if (v == 0) return const SizedBox();
                        return Text(v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.bold));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, m) {
                        int index = v.toInt();
                        if (index < 0 || index >= top6.length) return const SizedBox();
                        String label = top6[index].key;
                        if (label.length > 6) label = label.substring(0, 5) + "..";
                        return SideTitleWidget(
                          meta: m,
                          space: 8,
                          child: Text(label, style: const TextStyle(fontSize: 7, color: kTextSecondary, fontWeight: FontWeight.w900)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: top6.asMap().entries.map((e) {
                  final colorIndex = e.key % kChartColorsList.length;
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.value.toDouble(),
                        color: kChartColorsList[colorIndex],
                        width: 14,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 0,
                          color: kBorderColor.withValues(alpha: 0.1),
                        ),
                      )
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text("Top selling SKUs by unit quantity movement", style: TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildHighDensityItemRow(MapEntry<String, int> entry, int rank) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rank <= 3 ? kPrimaryColor.withOpacity(0.1) : kBackgroundColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              "$rank",
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: rank <= 3 ? kPrimaryColor : kTextSecondary
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              entry.key,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${entry.value}",
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kPrimaryColor),
              ),
              const Text("UNITS", style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: kTextSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================
// LOW STOCK PRODUCTS (Enhanced with all features from screenshot)
// ==========================================
class LowStockPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;

  const LowStockPage({super.key, required this.uid, required this.onBack});

  @override
  State<LowStockPage> createState() => _LowStockPageState();
}

class _LowStockPageState extends State<LowStockPage> {
  final FirestoreService _firestoreService = FirestoreService();
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];

  void _downloadPdf(BuildContext context, List<Map<String, dynamic>> low, List<Map<String, dynamic>> out) {
    final rows = [
      ...low.map((e) => [
        e['itemId'].toString(),
        e['name'].toString(),
        (e['minStock'] is num ? (e['minStock'] as num).toDouble() : 0.0).toStringAsFixed(0),
        (e['currentStock'] is num ? (e['currentStock'] as num).toDouble() : 0.0).toStringAsFixed(0),
        'LOW STOCK'
      ]),
      ...out.map((e) => [
        e['itemId'].toString(),
        e['name'].toString(),
        (e['minStock'] is num ? (e['minStock'] as num).toDouble() : 0.0).toStringAsFixed(0),
        (e['currentStock'] is num ? (e['currentStock'] as num).toDouble() : 0.0).toStringAsFixed(0),
        'OUT OF STOCK'
      ]),
    ];

    ReportPdfGenerator.generateAndDownloadPdf(
      context: context,
      reportTitle: 'Stock Replenishment Audit',
      headers: ['ITEM ID', 'PRODUCT NAME', 'MIN REQUIRED', 'ON HAND', 'STATUS'],
      rows: rows,
      summaryTitle: 'TOTAL ALERTS',
      summaryValue: '${low.length + out.length} ITEMS',
      additionalSummary: {
        'Critical (Out)': '${out.length}',
        'Warning (Low)': '${low.length}',
        'Audit Date': DateFormat('dd MMM yyyy').format(DateTime.now()),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Stream<QuerySnapshot>>(
      future: _firestoreService.getCollectionStream('Products'),
      builder: (context, streamSnapshot) {
        if (!streamSnapshot.hasData) {
          return Scaffold(
            backgroundColor: kBackgroundColor,
            appBar: _buildModernAppBar("Inventory Audit", widget.onBack),
            body: const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2)),
          );
        }
        return StreamBuilder<QuerySnapshot>(
          stream: streamSnapshot.data!,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Scaffold(
                backgroundColor: kBackgroundColor,
                appBar: _buildModernAppBar("Inventory Audit", widget.onBack),
                body: const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
              );
            }

            List<Map<String, dynamic>> lowStockItems = [];
            List<Map<String, dynamic>> outOfStockItems = [];
            Set<String> categorySet = {'All'};

            for (var doc in snapshot.data!.docs) {
              var data = doc.data() as Map<String, dynamic>;
              String category = data['category']?.toString() ?? 'Uncategorized';
              categorySet.add(category);

              if (!(data['stockEnabled'] ?? false)) continue;

              final currentStock = double.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;
              final minStock = double.tryParse(data['lowStockAlert']?.toString() ?? '0') ?? 0;
              final alertLevel = minStock > 0 ? minStock : 5;

              if (_selectedCategory != 'All' && category != _selectedCategory) continue;

              if (currentStock <= alertLevel) {
                Map<String, dynamic> item = {
                  'itemId': data['itemId']?.toString() ?? 'N/A',
                  'name': data['itemName']?.toString() ?? 'Unknown',
                  'minStock': alertLevel,
                  'currentStock': currentStock,
                  'category': category,
                };
                if (currentStock <= 0) {
                  outOfStockItems.add(item);
                } else {
                  lowStockItems.add(item);
                }
              }
            }

            _categories = categorySet.toList()..sort();

            return Scaffold(
              backgroundColor: kBackgroundColor,
              appBar: _buildModernAppBar(
                "Inventory Audit",
                widget.onBack,
                onDownload: () => _downloadPdf(context, lowStockItems, outOfStockItems),
              ),
              body: Column(
                children: [
                  _buildExecutiveStockHeader(lowStockItems.length, outOfStockItems.length),
                  _buildCompactFilterBar(),
                  Expanded(
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        if (outOfStockItems.isNotEmpty) ...[
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            sliver: SliverToBoxAdapter(child: _buildSectionHeader("Critical: Out of Stock")),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 8)),
                          SliverToBoxAdapter(child: _buildHighDensityInventoryTable(outOfStockItems, kExpenseRed)),
                        ],
                        if (lowStockItems.isNotEmpty) ...[
                          const SliverToBoxAdapter(child: SizedBox(height: 24)),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            sliver: SliverToBoxAdapter(child: _buildSectionHeader("Warning: Low Stock Level")),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 8)),
                          SliverToBoxAdapter(child: _buildHighDensityInventoryTable(lowStockItems, kWarningOrange)),
                        ],
                        if (lowStockItems.isEmpty && outOfStockItems.isEmpty)
                          const SliverFillRemaining(child: Center(child: Text("Inventory levels are optimal", style: TextStyle(color: kTextSecondary)))),
                        const SliverToBoxAdapter(child: SizedBox(height: 40)),
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
  }

  // --- EXECUTIVE UI COMPONENTS ---

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 1.2),
    );
  }

  Widget _buildExecutiveStockHeader(int low, int out) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("ITEMS REQUIRING ATTENTION", style: TextStyle(color: kTextSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const SizedBox(height: 2),
              Text("${low + out}", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kPrimaryColor, letterSpacing: -1)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: kExpenseRed.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kExpenseRed.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Text("$out", style: const TextStyle(color: kExpenseRed, fontWeight: FontWeight.w900, fontSize: 16)),
                const Text("CRITICAL", style: TextStyle(color: kTextSecondary, fontSize: 7, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_list_rounded, size: 16, color: kTextSecondary),
          const SizedBox(width: 10),
          const Text("SEGMENT:", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5)),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 30,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kPrimaryColor),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v!),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighDensityInventoryTable(List<Map<String, dynamic>> items, Color accentColor) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border.symmetric(horizontal: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            color: kBackgroundColor.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: const [
                Expanded(flex: 3, child: Text("ITEM DESCRIPTION", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
                Expanded(flex: 1, child: Text("MIN", textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
                Expanded(flex: 1, child: Text("STOCK", textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
              ],
            ),
          ),
          ...items.map((item) => _buildInventoryRow(item, accentColor)).toList(),
        ],
      ),
    );
  }

  Widget _buildInventoryRow(Map<String, dynamic> item, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'].toString(),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "ID: ${item['itemId']} • ${item['category'].toString()}",
                  style: const TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              (item['minStock'] is num ? (item['minStock'] as num).toDouble() : 0.0).toStringAsFixed(0),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextSecondary),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              (item['currentStock'] is num ? (item['currentStock'] as num).toDouble() : 0.0).toStringAsFixed(0),
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: accentColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// TOP PRODUCTS (Enhanced with all features from screenshot)
// ==========================================
class TopProductsPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;

  const TopProductsPage({super.key, required this.uid, required this.onBack});

  @override
  State<TopProductsPage> createState() => _TopProductsPageState();
}

class _TopProductsPageState extends State<TopProductsPage> {
  final FirestoreService _firestoreService = FirestoreService();
  DateFilterOption _selectedFilter = DateFilterOption.today;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _isDescending = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  void _onDateChanged(DateFilterOption option, DateTime start, DateTime end) {
    setState(() {
      _selectedFilter = option;
      _startDate = start;
      _endDate = end;
    });
  }

  bool _isInDateRange(DateTime? dt) {
    if (dt == null) return false;
    return dt.isAfter(_startDate.subtract(const Duration(seconds: 1))) &&
        dt.isBefore(_endDate.add(const Duration(seconds: 1)));
  }

  void _downloadPdf(BuildContext context, List<MapEntry<String, Map<String, dynamic>>> products, double totalRev, double totalProfit) {
    final rows = products.map((e) => [
      e.key,
      (e.value['quantity'] as double).toStringAsFixed(2),
      "${(e.value['amount'] as double).toStringAsFixed(2)}",
      "${(e.value['profit'] as double).toStringAsFixed(2)}",
    ]).toList();

    ReportPdfGenerator.generateAndDownloadPdf(
      context: context,
      reportTitle: 'Product Performance Audit',
      headers: ['PRODUCT NAME', 'QTY', 'REVENUE', 'PROFIT'],
      rows: rows,
      summaryTitle: 'NET PRODUCT REVENUE',
      summaryValue: "${totalRev.toStringAsFixed(2)}",
      additionalSummary: {
        'Period': '${DateFormat('dd/MM/yy').format(_startDate)} - ${DateFormat('dd/MM/yy').format(_endDate)}',
        'Total Profit': '${totalProfit.toStringAsFixed(2)}',
        'Audit Status': 'Certified'
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Stream<QuerySnapshot>>(
      future: _firestoreService.getCollectionStream('sales'),
      builder: (context, streamSnapshot) {
        if (!streamSnapshot.hasData) {
          return Scaffold(
            backgroundColor: kBackgroundColor,
            appBar: _buildModernAppBar("Product Analytics", widget.onBack),
            body: const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2)),
          );
        }
        return StreamBuilder<QuerySnapshot>(
          stream: streamSnapshot.data!,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Scaffold(
                backgroundColor: kBackgroundColor,
                appBar: _buildModernAppBar("Product Analytics", widget.onBack),
                body: const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
              );
            }

            // --- Aggregation Logic ---
            Map<String, Map<String, dynamic>> productData = {};
            double grandTotalRevenue = 0;
            double grandTotalProfit = 0;

            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              DateTime? dt;
              if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
              else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());

              if (_isInDateRange(dt)) {
                // Skip cancelled or returned bills
                final String status = (data['status'] ?? '').toString().toLowerCase();
                if (status == 'cancelled' || status == 'returned' || data['hasBeenReturned'] == true) {
                  continue;
                }

                if (data['items'] != null && data['items'] is List) {
                  for (var item in (data['items'] as List)) {
                    String name = item['name']?.toString() ?? 'Unknown';
                    double qty = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
                    double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
                    double cost = double.tryParse(item['cost']?.toString() ?? '0') ?? 0;
                    double total = double.tryParse(item['total']?.toString() ?? '0') ?? 0;
                    if (total == 0) total = price * qty;
                    double profit = (price - cost) * qty;

                    if (!productData.containsKey(name)) {
                      productData[name] = {'quantity': 0.0, 'amount': 0.0, 'profit': 0.0};
                    }
                    productData[name]!['quantity'] = (productData[name]!['quantity'] as double) + qty;
                    productData[name]!['amount'] = (productData[name]!['amount'] as double) + total;
                    productData[name]!['profit'] = (productData[name]!['profit'] as double) + profit;
                    grandTotalRevenue += total;
                    grandTotalProfit += profit;
                  }
                }
              }
            }

            var sortedProducts = productData.entries.toList();
            sortedProducts.sort((a, b) {
              int result = (a.value['amount'] as double).compareTo(b.value['amount'] as double);
              return _isDescending ? -result : result;
            });

            return Scaffold(
              backgroundColor: kBackgroundColor,
              appBar: _buildModernAppBar(
                "Product Analytics",
                widget.onBack,
                onDownload: () => _downloadPdf(context, sortedProducts, grandTotalRevenue, grandTotalProfit),
              ),
              body: Column(
                children: [
                  _buildExecutiveProductHeader(grandTotalRevenue, grandTotalProfit),
                  DateFilterWidget(
                    selectedOption: _selectedFilter,
                    startDate: _startDate,
                    endDate: _endDate,
                    onDateChanged: _onDateChanged,
                    showSortButton: true,
                    isDescending: _isDescending,
                    onSortPressed: () => setState(() => _isDescending = !_isDescending),
                  ),
                  Expanded(
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        if (sortedProducts.isNotEmpty) ...[
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            sliver: SliverToBoxAdapter(child: _buildSectionHeader("Revenue contribution")),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 10)),
                          SliverToBoxAdapter(
                            child: _buildContributionGraph(sortedProducts, 'amount', kPrimaryColor),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 20)),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            sliver: SliverToBoxAdapter(child: _buildSectionHeader("Quantity contribution")),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 10)),
                          SliverToBoxAdapter(
                            child: _buildContributionGraph(sortedProducts, 'quantity', kWarningOrange),
                          ),
                        ],

                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          sliver: SliverToBoxAdapter(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSectionHeader("Product Performance Ledger"),
                                Text(
                                  "${sortedProducts.length} ITEMS",
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kPrimaryColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),

                        sortedProducts.isEmpty
                            ? const SliverFillRemaining(child: Center(child: Text("No entries found", style: TextStyle(color: kTextSecondary))))
                            : SliverToBoxAdapter(
                          child: _buildHighDensityProductTable(sortedProducts),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 40)),
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
  }

  // --- EXECUTIVE UI COMPONENTS ---

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 1.2),
    );
  }

  Widget _buildExecutiveProductHeader(double revenue, double profit) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Total Product Revenue", style: TextStyle(color: kTextSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const SizedBox(height: 2),
              Text("${revenue.toStringAsFixed(2)}", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kPrimaryColor, letterSpacing: -1)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: kIncomeGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kIncomeGreen.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Text("${profit.toStringAsFixed(0)}", style: const TextStyle(color: kIncomeGreen, fontWeight: FontWeight.w900, fontSize: 16)),
                const Text("Est. Profit", style: TextStyle(color: kTextSecondary, fontSize: 7, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContributionGraph(List<MapEntry<String, Map<String, dynamic>>> data, String key, Color barColor) {
    // Top 6 products for chart clarity
    final chartData = data.take(6).toList();
    final double maxVal = _getMaxValue(chartData, key);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderColor.withOpacity(0.7)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxVal > 0 ? maxVal / 4 : 10,
                  getDrawingHorizontalLine: (v) => FlLine(color: kBorderColor.withOpacity(0.2), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, m) {
                        if (v == 0) return const SizedBox();
                        String text = v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0);
                        return Text(text, style: const TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.bold));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, m) {
                        int index = v.toInt();
                        if (index < 0 || index >= chartData.length) return const SizedBox();
                        String label = chartData[index].key;
                        if (label.length > 6) label = label.substring(0, 5) + "..";
                        return SideTitleWidget(
                          meta: m,
                          space: 8,
                          child: Text(label, style: const TextStyle(fontSize: 7, color: kTextSecondary, fontWeight: FontWeight.w900)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: chartData.asMap().entries.map((e) {
                  final colorIndex = e.key % kChartColorsList.length;
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.value[key],
                        color: kChartColorsList[colorIndex],
                        width: 16,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 0,
                          color: kBorderColor.withValues(alpha: 0.1),
                        ),
                      )
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
              "Top selling products by ${key == 'Amount' ? 'Revenue Contribution' : 'Unit Quantity Sold'}",
              style: const TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.bold, letterSpacing: 0.5)
          ),
        ],
      ),
    );
  }

  double _getMaxValue(List<MapEntry<String, Map<String, dynamic>>> data, String key) {
    if (data.isEmpty) return 100;
    double max = 0;
    for (var e in data) {
      if (e.value[key] > max) max = e.value[key];
    }
    return max == 0 ? 100 : max;
  }

  Widget _buildHighDensityProductTable(List<MapEntry<String, Map<String, dynamic>>> rows) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border.symmetric(horizontal: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Column(
        children: [
          Container(
            color: kBackgroundColor.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: const [
                Expanded(flex: 3, child: Text("Product Name", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
                Expanded(flex: 1, child: Text("Qty", textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text("Revenue", textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text("Profit", textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
              ],
            ),
          ),
          ...rows.map((row) => _buildProductTableRow(row)).toList(),
        ],
      ),
    );
  }

  Widget _buildProductTableRow(MapEntry<String, Map<String, dynamic>> entry) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              entry.key,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              (entry.value['quantity'] as double).toStringAsFixed(0),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextSecondary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "${(entry.value['amount'] as double).toStringAsFixed(0)}",
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kPrimaryColor),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "${(entry.value['profit'] as double).toStringAsFixed(0)}",
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kIncomeGreen),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// TOP CATEGORIES (Enhanced with all features from screenshot)
// ==========================================
class TopCategoriesPage extends StatefulWidget {
  final VoidCallback onBack;

  const TopCategoriesPage({super.key, required this.onBack});

  @override
  State<TopCategoriesPage> createState() => _TopCategoriesPageState();
}

class _TopCategoriesPageState extends State<TopCategoriesPage> {
  final FirestoreService _firestoreService = FirestoreService();
  DateFilterOption _selectedFilter = DateFilterOption.today;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _isDescending = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  void _onDateChanged(DateFilterOption option, DateTime start, DateTime end) {
    setState(() {
      _selectedFilter = option;
      _startDate = start;
      _endDate = end;
    });
  }

  bool _isInDateRange(DateTime? dt) {
    if (dt == null) return false;
    return dt.isAfter(_startDate.subtract(const Duration(seconds: 1))) &&
        dt.isBefore(_endDate.add(const Duration(seconds: 1)));
  }

  void _downloadPdf(BuildContext context, List<MapEntry<String, Map<String, dynamic>>> categories, double totalRevenue) {
    final rows = categories.map((e) => [
      e.key,
      (e.value['quantity'] as double).toStringAsFixed(2),
      "${(e.value['amount'] as double).toStringAsFixed(2)}",
    ]).toList();

    ReportPdfGenerator.generateAndDownloadPdf(
      context: context,
      reportTitle: 'CATEGORY PERFORMANCE AUDIT',
      headers: ['CATEGORY NAME', 'QTY SOLD', 'REVENUE AMT'],
      rows: rows,
      summaryTitle: 'TOTAL CATEGORY SALES',
      summaryValue: "${totalRevenue.toStringAsFixed(2)}",
      additionalSummary: {
        'Period': '${DateFormat('dd/MM/yy').format(_startDate)} - ${DateFormat('dd/MM/yy').format(_endDate)}',
        'Unique Categories': '${categories.length}',
        'Report Status': 'Finalized'
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Stream<QuerySnapshot>>(
      future: _firestoreService.getCollectionStream('sales'),
      builder: (context, streamSnapshot) {
        if (!streamSnapshot.hasData) {
          return Scaffold(
            backgroundColor: kBackgroundColor,
            appBar: _buildModernAppBar("Category Analytics", widget.onBack),
            body: const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2)),
          );
        }
        return StreamBuilder<QuerySnapshot>(
          stream: streamSnapshot.data!,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Scaffold(
                backgroundColor: kBackgroundColor,
                appBar: _buildModernAppBar("Category Analytics", widget.onBack),
                body: const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
              );
            }

            Map<String, Map<String, dynamic>> categoryData = {};
            double totalRevenue = 0;
            double totalQty = 0;

            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              DateTime? dt;
              if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
              else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());

              if (_isInDateRange(dt)) {
                // Skip cancelled or returned bills
                final String status = (data['status'] ?? '').toString().toLowerCase();
                if (status == 'cancelled' || status == 'returned' || data['hasBeenReturned'] == true) {
                  continue;
                }

                if (data['items'] != null && data['items'] is List) {
                  for (var item in (data['items'] as List)) {
                    String category = item['category']?.toString() ?? 'Uncategorized';
                    double qty = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
                    double total = double.tryParse(item['total']?.toString() ?? '0') ?? 0;
                    if (total == 0) {
                      double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
                      total = price * qty;
                    }

                    if (!categoryData.containsKey(category)) {
                      categoryData[category] = {'quantity': 0.0, 'amount': 0.0};
                    }
                    categoryData[category]!['quantity'] = (categoryData[category]!['quantity'] as double) + qty;
                    categoryData[category]!['amount'] = (categoryData[category]!['amount'] as double) + total;
                    totalRevenue += total;
                    totalQty += qty;
                  }
                }
              }
            }

            var sortedCategories = categoryData.entries.toList();
            sortedCategories.sort((a, b) {
              int result = (a.value['amount'] as double).compareTo(b.value['amount'] as double);
              return _isDescending ? -result : result;
            });

            return Scaffold(
              backgroundColor: kBackgroundColor,
              appBar: _buildModernAppBar(
                "Category Analytics",
                widget.onBack,
                onDownload: () => _downloadPdf(context, sortedCategories, totalRevenue),
              ),
              body: Column(
                children: [
                  _buildExecutiveCategoryHeader(totalRevenue, sortedCategories.length),
                  DateFilterWidget(
                    selectedOption: _selectedFilter,
                    startDate: _startDate,
                    endDate: _endDate,
                    onDateChanged: _onDateChanged,
                    showSortButton: true,
                    isDescending: _isDescending,
                    onSortPressed: () => setState(() => _isDescending = !_isDescending),
                  ),
                  Expanded(
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        if (sortedCategories.isNotEmpty) ...[
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            sliver: SliverToBoxAdapter(child: _buildSectionHeader("Revenue contribution")),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 10)),
                          SliverToBoxAdapter(
                            child: _buildSingleBarDashboard(sortedCategories),
                          ),
                        ],

                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          sliver: SliverToBoxAdapter(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSectionHeader("Detailed Inventory Ledger"),
                                Text(
                                  "${sortedCategories.length} GROUPS",
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kPrimaryColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),

                        sortedCategories.isEmpty
                            ? const SliverFillRemaining(child: Center(child: Text("No entries found", style: TextStyle(color: kTextSecondary))))
                            : SliverToBoxAdapter(
                          child: _buildHighDensityTable(sortedCategories),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 40)),
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
  }

  // --- EXECUTIVE UI COMPONENTS ---

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 1.2),
    );
  }

  Widget _buildExecutiveCategoryHeader(double revenue, int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("TOTAL CATEGORY REVENUE", style: TextStyle(color: kTextSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const SizedBox(height: 2),
              Text("${revenue.toStringAsFixed(2)}", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kPrimaryColor, letterSpacing: -1)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kPrimaryColor.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Text("$count", style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900, fontSize: 16)),
                const Text("GROUPS", style: TextStyle(color: kTextSecondary, fontSize: 7, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleBarDashboard(List<MapEntry<String, Map<String, dynamic>>> data) {
    // Take top 6 categories for the chart to keep it clean
    final chartData = data.take(6).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderColor.withOpacity(0.7)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 10000,
                  getDrawingHorizontalLine: (v) => FlLine(color: kBorderColor.withOpacity(0.2), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, m) {
                        if (v == 0) return const SizedBox();
                        return Text(v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.bold));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, m) {
                        int index = v.toInt();
                        if (index < 0 || index >= chartData.length) return const SizedBox();
                        String label = chartData[index].key;
                        if (label.length > 6) label = label.substring(0, 5) + "..";
                        return SideTitleWidget(
                          meta: m,
                          space: 8,
                          child: Text(label, style: const TextStyle(fontSize: 7, color: kTextSecondary, fontWeight: FontWeight.w900)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: chartData.asMap().entries.map((e) {
                  final colorIndex = e.key % kChartColorsList.length;
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.value['amount'],
                        color: kChartColorsList[colorIndex],
                        width: 16,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 0,
                          color: kBorderColor.withValues(alpha: 0.1),
                        ),
                      )
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text("Financial performance by top category segments", style: TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildHighDensityTable(List<MapEntry<String, Map<String, dynamic>>> rows) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border.symmetric(horizontal: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Column(
        children: [
          Container(
            color: kBackgroundColor.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: const [
                Expanded(flex: 3, child: Text("CATEGORY NAME", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text("QTY SOLD", textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text("NET REVENUE", textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5))),
              ],
            ),
          ),
          ...rows.map((row) => _buildTableRow(row)).toList(),
        ],
      ),
    );
  }

  Widget _buildTableRow(MapEntry<String, Map<String, dynamic>> entry) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              entry.key,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              (entry.value['quantity'] as double).toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextSecondary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "${(entry.value['amount'] as double).toStringAsFixed(0)}",
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kPrimaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

class ExpenseReportPage extends StatelessWidget {
  final VoidCallback onBack;
  final FirestoreService _firestoreService = FirestoreService();

  ExpenseReportPage({super.key, required this.onBack});

  void _downloadPdf(BuildContext context, List<Map<String, dynamic>> all, double totalOp, double totalStock) {
    final rows = all.map((e) => [
      e['title']?.toString() ?? 'N/A',
      e['type']?.toString() ?? 'N/A',
      "${(e['amount'] as double).toStringAsFixed(2)}",
    ]).toList();

    ReportPdfGenerator.generateAndDownloadPdf(
      context: context,
      reportTitle: 'EXECUTIVE EXPENSE AUDIT - ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
      headers: ['DESCRIPTION', 'CATEGORY', 'AMOUNT'],
      rows: rows,
      summaryTitle: 'TOTAL EXPENDITURE',
      summaryValue: "${(totalOp + totalStock).toStringAsFixed(2)}",
      additionalSummary: {
        'Operational': '${totalOp.toStringAsFixed(2)}',
        'Stock Purchase': '${totalStock.toStringAsFixed(2)}',
        'Audit Count': '${all.length} Records'
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: FutureBuilder<List<Stream<QuerySnapshot>>>(
        future: Future.wait([
          _firestoreService.getCollectionStream('expenses'),
          _firestoreService.getCollectionStream('stockPurchases')
        ]),
        builder: (context, streams) {
          if (!streams.hasData) {
            return Scaffold(
              appBar: _buildModernAppBar("Expense Ledger", onBack),
              body: const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2)),
            );
          }
          return StreamBuilder<QuerySnapshot>(
            stream: streams.data![0],
            builder: (ctx, expSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: streams.data![1],
                builder: (ctx, stockSnap) {
                  if (!expSnap.hasData || !stockSnap.hasData) {
                    return Scaffold(
                      appBar: _buildModernAppBar("Expense Ledger", onBack),
                      body: const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
                    );
                  }

                  List<Map<String, dynamic>> all = [];
                  double totalOp = 0;
                  double totalStock = 0;

                  for (var d in expSnap.data!.docs) {
                    var data = d.data() as Map<String, dynamic>;
                    double amt = double.tryParse(data['amount'].toString()) ?? 0;
                    totalOp += amt;
                    all.add({
                      'title': data['title'] ?? 'Operational Expense',
                      'amount': amt,
                      'type': 'Operational',
                      'date': data['timestamp'] ?? data['date'],
                    });
                  }
                  for (var d in stockSnap.data!.docs) {
                    var data = d.data() as Map<String, dynamic>;
                    double amt = double.tryParse(data['totalAmount']?.toString() ?? '0') ?? 0;
                    totalStock += amt;
                    all.add({
                      'title': 'Inventory Purchase',
                      'amount': amt,
                      'type': 'Stock',
                      'date': data['timestamp'] ?? data['date'],
                    });
                  }

                  // Sort by date newest first
                  all.sort((a, b) => (b['date'] is Timestamp ? (b['date'] as Timestamp).toDate() : DateTime.now())
                      .compareTo(a['date'] is Timestamp ? (a['date'] as Timestamp).toDate() : DateTime.now()));

                  return Scaffold(
                    backgroundColor: kBackgroundColor,
                    appBar: _buildModernAppBar(
                        "Expense Ledger",
                        onBack,
                        onDownload: () => _downloadPdf(context, all, totalOp, totalStock)
                    ),
                    body: Column(
                      children: [
                        _buildExecutiveRibbon(totalOp, totalStock, all.length),
                        Expanded(
                          child: CustomScrollView(
                            physics: const BouncingScrollPhysics(),
                            slivers: [
                              const SliverToBoxAdapter(child: SizedBox(height: 16)),

                              SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                sliver: SliverToBoxAdapter(child: _buildSectionHeader("Spending Analysis")),
                              ),
                              const SliverToBoxAdapter(child: SizedBox(height: 10)),
                              SliverToBoxAdapter(
                                child: _buildChartContainer(totalOp, totalStock),
                              ),

                              const SliverToBoxAdapter(child: SizedBox(height: 24)),
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                sliver: SliverToBoxAdapter(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildSectionHeader("Audit Trail"),
                                      Text(
                                        "${all.length} RECORDS FOUND",
                                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kTextSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SliverToBoxAdapter(child: SizedBox(height: 8)),

                              SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                        (context, index) => _buildHighDensityExpenseRow(all[index]),
                                    childCount: all.length,
                                  ),
                                ),
                              ),
                              const SliverToBoxAdapter(child: SizedBox(height: 40)),
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

  // --- EXECUTIVE UI COMPONENTS ---

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 1.2),
    );
  }

  Widget _buildExecutiveRibbon(double op, double stock, int count) {
    final total = op + stock;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("TOTAL EXPENDITURE", style: TextStyle(color: kTextSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 2),
              Text("${total.toStringAsFixed(2)}", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kExpenseRed, letterSpacing: -1)),
            ],
          ),
          Row(
            children: [
              _buildSmallSummaryItem("OP", op, kExpenseRed),
              const SizedBox(width: 12),
              _buildSmallSummaryItem("STOCK", stock, kWarningOrange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallSummaryItem(String label, double val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text("${val.toStringAsFixed(0)}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: kTextSecondary)),
      ],
    );
  }

  Widget _buildChartContainer(double op, double stock) {
    final maxVal = op > stock ? op : stock;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderColor.withOpacity(0.6)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal > 0 ? maxVal * 1.2 : 100,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, m) {
                        final label = v == 0 ? "OPERATIONAL" : "STOCK PURCHASE";
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, m) {
                        if (v == 0) return const SizedBox();
                        return Text(v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0), style: const TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.bold));
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 5000, getDrawingHorizontalLine: (v) => FlLine(color: kBorderColor.withOpacity(0.15), strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _makeBarGroup(0, op, kChartRed),
                  _makeBarGroup(1, stock, kChartOrange),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y > 0 ? y : 1,
          color: color,
          width: 32,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          backDrawRodData: BackgroundBarChartRodData(show: true, toY: 0, color: kBorderColor.withValues(alpha: 0.1)),
        ),
      ],
    );
  }

  Widget _buildHighDensityExpenseRow(Map<String, dynamic> data) {
    final bool isStock = data['type'] == 'Stock';
    final Color color = isStock ? kWarningOrange : kExpenseRed;

    String dateStr = '--/--';
    if (data['date'] is Timestamp) {
      dateStr = DateFormat('dd MMM').format((data['date'] as Timestamp).toDate());
    } else if (data['date'] is String) {
      dateStr = DateFormat('dd MMM').format(DateTime.parse(data['date']));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(isStock ? Icons.inventory_2_outlined : Icons.outbox_rounded, color: color, size: 16),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['title'].toString(),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                    "$dateStr • ${data['type'].toString()}",
                    style: const TextStyle(fontSize: 9, color: kTextSecondary, fontWeight: FontWeight.bold)
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("- ${(data['amount'] as double).toStringAsFixed(0)}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: color, letterSpacing: -0.5)),
              const Text("SETTLED", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5)),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================
// UNIFIED TAX REPORT PAGE (Tax + GST Combined)
// ==========================================
class TaxReportPage extends StatefulWidget {
  final VoidCallback onBack;

  const TaxReportPage({super.key, required this.onBack});

  @override
  State<TaxReportPage> createState() => _TaxReportPageState();
}

class _TaxReportPageState extends State<TaxReportPage> {
  final FirestoreService _firestoreService = FirestoreService();
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _showReport = false;

  Future<void> _selectFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _fromDate = picked);
    }
  }

  Future<void> _selectToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: _fromDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _toDate = picked);
    }
  }

  bool _isInDateRange(DateTime? dt) {
    if (dt == null || _fromDate == null || _toDate == null) return false;
    return dt.isAfter(_fromDate!.subtract(const Duration(days: 1))) &&
        dt.isBefore(_toDate!.add(const Duration(days: 1)));
  }

  void _downloadPdf({
    required BuildContext context,
    required List<Map<String, dynamic>> taxableDocs,
    required double totalTaxAmount,
    required Map<String, double> taxBreakdown,
    required List<Map<String, dynamic>> salesRows,
    required List<Map<String, dynamic>> purchaseRows,
    required double totalSalesGST,
    required double totalPurchaseGST,
    required double netLiability,
  }) {
    // Create comprehensive tax rows combining sales tax and GST data
    final List<List<String>> allRows = [];
    
    // Add Sales Tax Data
    for (var d in taxableDocs) {
      allRows.add([
        DateFormat('dd/MM/yy').format(d['timestamp'] is Timestamp ? (d['timestamp'] as Timestamp).toDate() : DateTime.now()),
        'TAX - SALES',
        d['invoiceNumber']?.toString() ?? 'N/A',
        d['customerName']?.toString() ?? 'Guest',
        (double.tryParse(d['total']?.toString() ?? '0') ?? 0).toStringAsFixed(2),
        (d['calculatedTax'] as double).toStringAsFixed(2),
      ]);
    }

    // Add GST Sales Data
    for (var row in salesRows) {
      allRows.add([
        DateFormat('dd/MM/yy').format(row['date']),
        'GST - ${row['category']}',
        row['invoice'],
        row['gstNumber'],
        "${(row['amount'] as double).toStringAsFixed(2)}",
        "${(row['gst'] as double).toStringAsFixed(2)}",
      ]);
    }

    // Add GST Purchase Data
    for (var row in purchaseRows) {
      allRows.add([
        DateFormat('dd/MM/yy').format(row['date']),
        'GST - ${row['category']}',
        row['invoice'],
        row['gstNumber'],
        "${(row['amount'] as double).toStringAsFixed(2)}",
        "${(row['gst'] as double).toStringAsFixed(2)}",
      ]);
    }

    ReportPdfGenerator.generateAndDownloadPdf(
      context: context,
      reportTitle: 'COMPREHENSIVE TAX & GST REPORT',
      headers: ['DATE', 'TYPE', 'INVOICE', 'PARTY', 'TOTAL', 'TAX/GST'],
      rows: allRows,
      summaryTitle: 'NET TAX LIABILITY',
      summaryValue: "${(totalTaxAmount + netLiability).toStringAsFixed(2)}",
      additionalSummary: {
        'Period': '${DateFormat('dd/MM/yy').format(_fromDate!)} to ${DateFormat('dd/MM/yy').format(_toDate!)}',
        'Sales Tax': '${totalTaxAmount.toStringAsFixed(2)}',
        'Sales GST': '${totalSalesGST.toStringAsFixed(2)}',
        'Purchase GST': '${totalPurchaseGST.toStringAsFixed(2)}',
        'Net GST Liability': '${netLiability.toStringAsFixed(2)}',
        'Transaction Count': '${taxableDocs.length + salesRows.length + purchaseRows.length}',
        'Audit Status': 'Verified'
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show date selection screen if report not yet generated
    if (!_showReport) {
      return Scaffold(
        backgroundColor: kBackgroundColor,
        appBar: _buildModernAppBar("Tax Report Period", widget.onBack),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              _buildSectionHeader("Select Tax Report Duration"),
              const SizedBox(height: 12),
              _buildDateTile("START DATE", _fromDate, _selectFromDate),
              const SizedBox(height: 12),
              _buildDateTile("END DATE", _toDate, _selectToDate),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_fromDate != null && _toDate != null)
                      ? () => setState(() => _showReport = true)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('GENERATE TAX REPORT', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      );
    }

    // Show comprehensive tax report
    return FutureBuilder<List<Stream<QuerySnapshot>>>(
      future: Future.wait([
        _firestoreService.getCollectionStream('sales'),
        _firestoreService.getCollectionStream('expenses'),
        _firestoreService.getCollectionStream('stockPurchases'),
        _firestoreService.getCollectionStream('creditNotes'),
      ]),
      builder: (context, streamsSnapshot) {
        if (!streamsSnapshot.hasData) {
          return Scaffold(
            backgroundColor: kBackgroundColor,
            appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                onPressed: () => setState(() => _showReport = false),
              ),
              title: const Text('Tax Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              backgroundColor: kPrimaryColor,
              centerTitle: true,
            ),
            body: const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2)),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: streamsSnapshot.data![0],
          builder: (context, salesSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: streamsSnapshot.data![1],
              builder: (context, expenseSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                  stream: streamsSnapshot.data![2],
                  builder: (context, purchaseSnapshot) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: streamsSnapshot.data![3],
                      builder: (context, creditNoteSnapshot) {
                        if (!salesSnapshot.hasData || !expenseSnapshot.hasData || !purchaseSnapshot.hasData) {
                          return const Scaffold(body: Center(child: CircularProgressIndicator(color: kPrimaryColor)));
                        }

                        // --- Process Sales Tax Data ---
                        double totalTaxAmount = 0;
                        Map<String, double> taxBreakdown = {};
                        var taxableDocs = <Map<String, dynamic>>[];

                        for (var d in salesSnapshot.data!.docs) {
                          var data = d.data() as Map<String, dynamic>;
                          DateTime? dt;
                          if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                          else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());

                          if (_isInDateRange(dt)) {
                            // Skip cancelled or returned bills
                            final String status = (data['status'] ?? '').toString().toLowerCase();
                            if (status == 'cancelled' || status == 'returned' || data['hasBeenReturned'] == true) {
                              continue;
                            }

                            double saleTax = double.tryParse(data['totalTax']?.toString() ?? '0') ?? 0;
                            if (saleTax == 0) {
                              saleTax = double.tryParse(data['taxAmount']?.toString() ?? data['tax']?.toString() ?? '0') ?? 0;
                            }

                            if (saleTax > 0) {
                              totalTaxAmount += saleTax;
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
                                taxBreakdown['Tax'] = (taxBreakdown['Tax'] ?? 0) + saleTax;
                              }
                              data['calculatedTax'] = saleTax;
                              taxableDocs.add(data);
                            }
                          }
                        }

                        // --- Process GST Sales Data ---
                        List<Map<String, dynamic>> salesRows = [];
                        double totalSalesAmount = 0, totalSalesGST = 0;

                        for (var doc in salesSnapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          DateTime? dt;
                          if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                          else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());

                          if (_isInDateRange(dt)) {
                            final String status = (data['status'] ?? '').toString().toLowerCase();
                            if (status == 'cancelled' || status == 'returned' || data['hasBeenReturned'] == true) {
                              continue;
                            }

                            double total = double.tryParse(data['total']?.toString() ?? '0') ?? 0;
                            double gst = double.tryParse(data['totalTax']?.toString() ?? data['taxAmount']?.toString() ?? '0') ?? 0;
                            salesRows.add({
                              'date': dt,
                              'category': 'SALE',
                              'invoice': data['invoiceNumber']?.toString() ?? 'N/A',
                              'gstNumber': data['customerGST']?.toString() ?? '--',
                              'amount': total,
                              'gst': gst,
                              'cancelled': false,
                            });
                            totalSalesAmount += total;
                            totalSalesGST += gst;
                          }
                        }

                        // --- Process GST Inward Data (Purchases) ---
                        List<Map<String, dynamic>> purchaseRows = [];
                        double totalPurchaseAmount = 0, totalPurchaseGST = 0;

                        void addInward(QueryDocumentSnapshot doc, String cat, String amtKey, String gstKey, String gstNumKey) {
                          final data = doc.data() as Map<String, dynamic>;
                          DateTime? dt;
                          if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                          else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());
                          if (_isInDateRange(dt)) {
                            double amount = double.tryParse(data[amtKey]?.toString() ?? '0') ?? 0;
                            double gst = double.tryParse(data[gstKey]?.toString() ?? '0') ?? 0;
                            purchaseRows.add({
                              'date': dt,
                              'category': cat,
                              'invoice': data['invoiceNumber']?.toString() ?? '--',
                              'gstNumber': data[gstNumKey]?.toString() ?? '--',
                              'amount': amount,
                              'gst': gst,
                              'cancelled': false,
                            });
                            totalPurchaseAmount += amount;
                            totalPurchaseGST += gst;
                          }
                        }

                        for (var doc in expenseSnapshot.data!.docs) {
                          addInward(doc, 'EXPENSE', 'amount', 'gst', '--');
                        }
                        for (var doc in purchaseSnapshot.data!.docs) {
                          addInward(doc, 'PURCHASE', 'totalAmount', 'gst', 'supplierGST');
                        }
                        if (creditNoteSnapshot.hasData) {
                          for (var doc in creditNoteSnapshot.data!.docs) {
                            addInward(doc, 'CREDIT NOTE', 'amount', 'gst', '--');
                          }
                        }

                        double gstNetLiability = totalSalesGST - totalPurchaseGST;
                        double totalNetTax = totalTaxAmount + gstNetLiability;
                        var sortedTaxTypes = taxBreakdown.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

                        return Scaffold(
                          backgroundColor: kBackgroundColor,
                          appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
                            leading: IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                              onPressed: () => setState(() => _showReport = false),
                            ),
                            title: const Text('Tax Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                            backgroundColor: kPrimaryColor,
                            elevation: 0,
                            centerTitle: true,
                            actions: [
                              IconButton(
                                icon: const Icon(Icons.file_download_outlined, color: Colors.white),
                                onPressed: () => _downloadPdf(
                                  context: context,
                                  taxableDocs: taxableDocs,
                                  totalTaxAmount: totalTaxAmount,
                                  taxBreakdown: taxBreakdown,
                                  salesRows: salesRows,
                                  purchaseRows: purchaseRows,
                                  totalSalesGST: totalSalesGST,
                                  totalPurchaseGST: totalPurchaseGST,
                                  netLiability: gstNetLiability,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                          body: Column(
                            children: [
                              _buildUnifiedTaxHeader(totalNetTax, totalTaxAmount, totalSalesGST, totalPurchaseGST, gstNetLiability),

                              Expanded(
                                child: CustomScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  slivers: [
                                    SliverPadding(
                                      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                                      sliver: SliverList(
                                        delegate: SliverChildListDelegate([
                                          // Tax Type Breakdown Section
                                          if (sortedTaxTypes.isNotEmpty) ...[
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14),
                                              child: _buildSectionHeader("Tax Type Breakdown"),
                                            ),
                                            const SizedBox(height: 10),
                                            _buildBreakdownMatrix(sortedTaxTypes),
                                            const SizedBox(height: 24),
                                          ],

                                          // Taxable Sales Ledger
                                          if (taxableDocs.isNotEmpty) ...[
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  _buildSectionHeader("Sales Tax Ledger"),
                                                  Text(
                                                    "${taxableDocs.length} BILLS",
                                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kPrimaryColor),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            ...taxableDocs.map((doc) => Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                              child: _buildTaxLedgerRow(doc),
                                            )).toList(),
                                            const SizedBox(height: 24),
                                          ],

                                          // GST on Outward Supplies
                                          if (salesRows.isNotEmpty) ...[
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14),
                                              child: _buildSectionHeader("GST on Outward Supplies (Sales)"),
                                            ),
                                            const SizedBox(height: 8),
                                            _buildGstTable(salesRows),
                                            const SizedBox(height: 24),
                                          ],

                                          // GST on Inward Supplies
                                          if (purchaseRows.isNotEmpty) ...[
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14),
                                              child: _buildSectionHeader("GST on Inward Supplies (Purchases)"),
                                            ),
                                            const SizedBox(height: 8),
                                            _buildGstTable(purchaseRows),
                                            const SizedBox(height: 24),
                                          ],

                                          // Compliance Summary
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 14),
                                            child: _buildSectionHeader("Tax Compliance Summary"),
                                          ),
                                          const SizedBox(height: 8),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            child: _buildComprehensiveSummary(
                                              totalTaxAmount,
                                              totalSalesAmount,
                                              totalSalesGST,
                                              totalPurchaseAmount,
                                              totalPurchaseGST,
                                              gstNetLiability,
                                              totalNetTax,
                                            ),
                                          ),
                                          const SizedBox(height: 40),
                                        ]),
                                      ),
                                    ),
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
            );
          },
        );
      },
    );
  }

  // --- EXECUTIVE UI COMPONENTS ---

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 1.2),
    );
  }

  Widget _buildUnifiedTaxHeader(double totalNet, double salesTax, double salesGST, double purchaseGST, double gstNet) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("TOTAL TAX LIABILITY", style: TextStyle(color: kTextSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 2),
                  Text(" ${totalNet.toStringAsFixed(2)}", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: totalNet >= 0 ? kIncomeGreen : kExpenseRed, letterSpacing: -1)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("SALES TAX: ${salesTax.toStringAsFixed(0)}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kIncomeGreen)),
                  const SizedBox(height: 2),
                  Text("GST NET: ${gstNet.toStringAsFixed(0)}", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: gstNet >= 0 ? kExpenseRed : kIncomeGreen)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: kIncomeGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text("GST OUT: ${salesGST.toStringAsFixed(0)}", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kIncomeGreen)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: kExpenseRed.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text("GST IN: ${purchaseGST.toStringAsFixed(0)}", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kExpenseRed)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownMatrix(List<MapEntry<String, double>> types) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor.withOpacity(0.6)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: types.map((entry) {
          return Container(
            width: 160,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: kBackgroundColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorderColor.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.key, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(" ${entry.value.toStringAsFixed(2)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black87)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDateTile(String label, DateTime? date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSurfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorderColor),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kTextSecondary, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(date != null ? DateFormat('dd MMMM yyyy').format(date) : 'SELECT DATE',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: date != null ? Colors.black87 : kTextSecondary)),
              ],
            ),
            const Spacer(),
            Icon(Icons.calendar_month_rounded, color: kPrimaryColor.withOpacity(0.5), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildGstTable(List<Map<String, dynamic>> rows) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border.symmetric(horizontal: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Column(
        children: [
          Container(
            color: kBackgroundColor.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              children: const [
                Expanded(flex: 2, child: Text("DATE", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary))),
                Expanded(flex: 3, child: Text("INVOICE/GSTIN", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary))),
                Expanded(flex: 2, child: Text("TOTAL", textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary))),
                Expanded(flex: 2, child: Text("GST", textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary))),
              ],
            ),
          ),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text("No data available", style: TextStyle(fontSize: 14, color: kTextSecondary)),
            )
          else
            ...rows.map((row) => _buildGstTableRow(row)).toList(),
        ],
      ),
    );
  }

  Widget _buildGstTableRow(Map<String, dynamic> row) {
    final String gstin = row['gstNumber'].toString();
    final String inv = row['invoice'].toString();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              DateFormat('dd MMM yyyy').format(row['date']),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inv,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kPrimaryColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  gstin == "--" ? "UNREGISTERED" : gstin,
                  style: const TextStyle(fontSize: 8, color: kTextSecondary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              " ${(row['amount'] as double).toStringAsFixed(0)}",
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              " ${(row['gst'] as double).toStringAsFixed(1)}",
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComprehensiveSummary(
    double salesTax,
    double salesAmount,
    double salesGST,
    double purchaseAmount,
    double purchaseGST,
    double gstNet,
    double totalNet,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        children: [
          _buildSummaryRow("Sales Tax Collected", salesTax),
          const SizedBox(height: 8),
          _buildSummaryRow("Sales GST (Outward)", salesGST),
          const SizedBox(height: 8),
          _buildSummaryRow("Purchase GST (Inward)", purchaseGST),
          const Divider(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: totalNet >= 0 ? [kIncomeGreen, kIncomeGreen.withOpacity(0.7)] : [kExpenseRed, kExpenseRed.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total Tax Liability", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5)),
                Text(" ${totalNet.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kTextSecondary)),
        Text(" ${amount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
      ],
    );
  }

  Widget _buildTaxLedgerRow(Map<String, dynamic> data) {
    final double tax = data['calculatedTax'] ?? 0.0;
    final double total = double.tryParse(data['total']?.toString() ?? '0') ?? 0.0;

    String taxDetailStr = '';
    if (data['taxes'] != null && data['taxes'] is List) {
      taxDetailStr = (data['taxes'] as List).map((t) => "${t['name']}: ${t['amount']}").join(" • ");
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: kIncomeGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.description_outlined, color: kIncomeGreen, size: 16),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (data['customerName'] ?? 'Guest').toString(),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.black87),
                  maxLines: 1,
                ),
                Text(
                    "Invoice${data['invoiceNumber'] ?? 'N/A'} • ${_formatDate(data['date'])}",
                    style: const TextStyle(fontSize: 9, color: kTextSecondary, fontWeight: FontWeight.bold)
                ),
                if (taxDetailStr.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(taxDetailStr, style: const TextStyle(fontSize: 7, color: kIncomeGreen, fontWeight: FontWeight.w900, letterSpacing: 0.2)),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("TAX: ${tax.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: kIncomeGreen)),
              Text("VAL: ${total.toStringAsFixed(0)}", style: const TextStyle(fontSize: 9, color: kTextSecondary, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    try {
      if (date is Timestamp) return DateFormat('dd MMM yyyy').format(date.toDate());
      if (date is String) return DateFormat('dd MMM yyyy').format(DateTime.parse(date));
    } catch (e) {}
    return '-- --- ----';
  }
}

class StaffSaleReportPage extends StatefulWidget {
  final VoidCallback onBack;

  const StaffSaleReportPage({super.key, required this.onBack});

  @override
  State<StaffSaleReportPage> createState() => _StaffSaleReportPageState();
}

class _StaffSaleReportPageState extends State<StaffSaleReportPage> {
  final FirestoreService _firestoreService = FirestoreService();
  DateFilterOption _selectedFilter = DateFilterOption.today;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _isDescending = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  void _onDateChanged(DateFilterOption option, DateTime start, DateTime end) {
    setState(() {
      _selectedFilter = option;
      _startDate = start;
      _endDate = end;
    });
  }

  bool _isInDateRange(DateTime? dt) {
    if (dt == null) return false;
    return dt.isAfter(_startDate.subtract(const Duration(seconds: 1))) &&
        dt.isBefore(_endDate.add(const Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: _buildModernAppBar("Staff Performance", widget.onBack),
      body: FutureBuilder<Stream<QuerySnapshot>>(
        future: _firestoreService.getCollectionStream('sales'),
        builder: (context, streamSnapshot) {
          if (!streamSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2));
          }
          return StreamBuilder<QuerySnapshot>(
            stream: streamSnapshot.data!,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
              }

              // --- Process staff data ---
              Map<String, Map<String, dynamic>> staffData = {};
              double grandTotal = 0;
              int grandBills = 0;

              for (var doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                DateTime? dt;
                if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());

                if (_isInDateRange(dt)) {
                  // Skip cancelled or returned bills
                  final String status = (data['status'] ?? '').toString().toLowerCase();
                  if (status == 'cancelled' || status == 'returned' || data['hasBeenReturned'] == true) {
                    continue;
                  }

                  String staffName = data['staffName']?.toString() ?? 'owner';
                  double total = double.tryParse(data['total']?.toString() ?? '0') ?? 0;
                  double discount = double.tryParse(data['discount']?.toString() ?? '0') ?? 0;
                  String paymentMode = (data['paymentMode'] ?? 'Cash').toString().toLowerCase();

                  grandTotal += total;
                  grandBills++;

                  if (!staffData.containsKey(staffName)) {
                    staffData[staffName] = {
                      'salesCount': 0,
                      'totalAmount': 0.0,
                      'cashCount': 0,
                      'cashAmount': 0.0,
                      'onlineCount': 0,
                      'onlineAmount': 0.0,
                      'creditCount': 0,
                      'creditAmount': 0.0,
                      'creditNoteCount': 0,
                      'creditNoteAmount': 0.0,
                      'totalDiscount': 0.0,
                    };
                  }

                  staffData[staffName]!['salesCount'] = (staffData[staffName]!['salesCount'] as int) + 1;
                  staffData[staffName]!['totalAmount'] = (staffData[staffName]!['totalAmount'] as double) + total;
                  staffData[staffName]!['totalDiscount'] = (staffData[staffName]!['totalDiscount'] as double) + discount;

                  // Handle Split payments separately
                  if (paymentMode == 'split') {
                    double splitCash = double.tryParse(data['cashReceived_split']?.toString() ?? '0') ?? 0;
                    double splitOnline = double.tryParse(data['onlineReceived_split']?.toString() ?? '0') ?? 0;
                    double splitCredit = double.tryParse(data['creditIssued_split']?.toString() ?? '0') ?? 0;
                    if (splitCash > 0) {
                      staffData[staffName]!['cashCount'] = (staffData[staffName]!['cashCount'] as int) + 1;
                      staffData[staffName]!['cashAmount'] = (staffData[staffName]!['cashAmount'] as double) + splitCash;
                    }
                    if (splitOnline > 0) {
                      staffData[staffName]!['onlineCount'] = (staffData[staffName]!['onlineCount'] as int) + 1;
                      staffData[staffName]!['onlineAmount'] = (staffData[staffName]!['onlineAmount'] as double) + splitOnline;
                    }
                    if (splitCredit > 0) {
                      staffData[staffName]!['creditCount'] = (staffData[staffName]!['creditCount'] as int) + 1;
                      staffData[staffName]!['creditAmount'] = (staffData[staffName]!['creditAmount'] as double) + splitCredit;
                    }
                  } else if (paymentMode.contains('online') || paymentMode.contains('upi') || paymentMode.contains('card')) {
                    staffData[staffName]!['onlineCount'] = (staffData[staffName]!['onlineCount'] as int) + 1;
                    staffData[staffName]!['onlineAmount'] = (staffData[staffName]!['onlineAmount'] as double) + total;
                  } else if (paymentMode.contains('credit') && paymentMode.contains('note')) {
                    staffData[staffName]!['creditNoteCount'] = (staffData[staffName]!['creditNoteCount'] as int) + 1;
                    staffData[staffName]!['creditNoteAmount'] = (staffData[staffName]!['creditNoteAmount'] as double) + total;
                  } else if (paymentMode.contains('credit')) {
                    staffData[staffName]!['creditCount'] = (staffData[staffName]!['creditCount'] as int) + 1;
                    staffData[staffName]!['creditAmount'] = (staffData[staffName]!['creditAmount'] as double) + total;
                  } else {
                    staffData[staffName]!['cashCount'] = (staffData[staffName]!['cashCount'] as int) + 1;
                    staffData[staffName]!['cashAmount'] = (staffData[staffName]!['cashAmount'] as double) + total;
                  }
                }
              }

              var sortedEntries = staffData.entries.toList();
              sortedEntries.sort((a, b) {
                int result = (a.value['totalAmount'] as double).compareTo(b.value['totalAmount'] as double);
                return _isDescending ? -result : result;
              });

              return Column(
                children: [
                  _buildStaffExecutiveHeader(grandTotal, grandBills),
                  DateFilterWidget(
                    selectedOption: _selectedFilter,
                    startDate: _startDate,
                    endDate: _endDate,
                    onDateChanged: _onDateChanged,
                    showSortButton: true,
                    isDescending: _isDescending,
                    onSortPressed: () => setState(() => _isDescending = !_isDescending),
                  ),
                  Expanded(
                    child: sortedEntries.isEmpty
                        ? const Center(child: Text("No staff sales recorded for this period", style: TextStyle(color: kTextSecondary)))
                        : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      itemCount: sortedEntries.length,
                      itemBuilder: (context, index) {
                        final entry = sortedEntries[index];
                        return _buildStaffPerformanceCard(entry.key, entry.value);
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

  // --- EXECUTIVE UI COMPONENTS ---

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 1.2),
    );
  }

  Widget _buildStaffExecutiveHeader(double total, int bills) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("TOTAL STAFF REVENUE", style: TextStyle(color: kTextSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 2),
              Text("${total.toStringAsFixed(2)}", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kPrimaryColor, letterSpacing: -1)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kPrimaryColor.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Text("$bills", style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900, fontSize: 16)),
                const Text("BILLS", style: TextStyle(color: kTextSecondary, fontSize: 7, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffPerformanceCard(String name, Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderColor.withOpacity(0.7)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: kPrimaryColor.withOpacity(0.1),
                    child: Text(name[0], style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black87)),
                      Text("${data['salesCount']} TRANSACTIONS", style: const TextStyle(fontSize: 9, color: kTextSecondary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("${(data['totalAmount'] as double).toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: kPrimaryColor, letterSpacing: -0.5)),
                  const Text("TOTAL CONTRIBUTION", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: kTextSecondary, letterSpacing: 0.5)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionHeader("Payment Breakdown"),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildMiniStatTile("CASH", data['cashAmount'], kIncomeGreen)),
              const SizedBox(width: 8),
              Expanded(child: _buildMiniStatTile("ONLINE", data['onlineAmount'], kPrimaryColor)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildMiniStatTile("CREDIT", data['creditAmount'], kWarningOrange)),
              const SizedBox(width: 8),
              Expanded(child: _buildMiniStatTile("DISCOUNT", data['totalDiscount'], kExpenseRed)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatTile(String label, double val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: kBackgroundColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kTextSecondary)),
          Text("${val.toStringAsFixed(0)}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color.withOpacity(0.8))),
        ],
      ),
    );
  }
}



// Helper for simple list-based reports to reduce boilerplate


// ==========================================
// INCOME SUMMARY PAGE (Enhanced with all features from screenshot)
// ==========================================
class IncomeSummaryPage extends StatelessWidget {
  final VoidCallback onBack;
  final FirestoreService _firestoreService = FirestoreService();

  IncomeSummaryPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: _buildModernAppBar("Financial Summary", onBack),
      body: FutureBuilder<List<Stream<QuerySnapshot>>>(
        future: Future.wait([
          _firestoreService.getCollectionStream('sales'),
          _firestoreService.getCollectionStream('expenses'),
          _firestoreService.getCollectionStream('stockPurchases'),
        ]),
        builder: (context, streamsSnapshot) {
          if (!streamsSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2));
          }
          return StreamBuilder<QuerySnapshot>(
            stream: streamsSnapshot.data![0],
            builder: (context, salesSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: streamsSnapshot.data![1],
                builder: (context, expenseSnapshot) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: streamsSnapshot.data![2],
                    builder: (context, purchaseSnapshot) {
                      if (!salesSnapshot.hasData || !expenseSnapshot.hasData || !purchaseSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                      }

                      final now = DateTime.now();
                      final todayStart = DateTime(now.year, now.month, now.day);
                      final yesterday = now.subtract(const Duration(days: 1));
                      final yesterdayStart = DateTime(yesterday.year, yesterday.month, yesterday.day);
                      final last7Days = now.subtract(const Duration(days: 7));
                      final thisMonthStart = DateTime(now.year, now.month, 1);
                      final decemberStart = DateTime(now.year - (now.month == 1 ? 1 : 0), 12, 1);
                      final decemberEnd = DateTime(now.year - (now.month == 1 ? 1 : 0), 12, 31, 23, 59, 59);

                      double incomeToday = 0, incomeYesterday = 0, incomeLast7Days = 0, incomeThisMonth = 0, incomeDecember = 0;
                      double expenseToday = 0, expenseYesterday = 0, expenseLast7Days = 0, expenseThisMonth = 0, expenseDecember = 0;
                      double salesDues = 0, purchaseDues = 0;

                      // --- Process Sales ---
                      for (var doc in salesSnapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        DateTime? dt;
                        if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                        else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());

                        double total = double.tryParse(data['total']?.toString() ?? '0') ?? 0;
                        salesDues += double.tryParse(data['dueAmount']?.toString() ?? '0') ?? 0;

                        if (dt != null) {
                          if (dt.isAfter(todayStart)) incomeToday += total;
                          if (dt.isAfter(yesterdayStart) && dt.isBefore(todayStart)) incomeYesterday += total;
                          if (dt.isAfter(last7Days)) incomeLast7Days += total;
                          if (dt.isAfter(thisMonthStart)) incomeThisMonth += total;
                          if (dt.isAfter(decemberStart) && dt.isBefore(decemberEnd)) incomeDecember += total;
                        }
                      }

                      // --- Process Expenses ---
                      for (var doc in expenseSnapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        DateTime? dt;
                        if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                        else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());

                        double amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0;

                        if (dt != null) {
                          if (dt.isAfter(todayStart)) expenseToday += amount;
                          if (dt.isAfter(yesterdayStart) && dt.isBefore(todayStart)) expenseYesterday += amount;
                          if (dt.isAfter(last7Days)) expenseLast7Days += amount;
                          if (dt.isAfter(thisMonthStart)) expenseThisMonth += amount;
                          if (dt.isAfter(decemberStart) && dt.isBefore(decemberEnd)) expenseDecember += amount;
                        }
                      }

                      // --- Process Purchases ---
                      for (var doc in purchaseSnapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        purchaseDues += double.tryParse(data['dueAmount']?.toString() ?? '0') ?? 0;
                      }

                      return Column(
                        children: [
                          // Executive Status Header
                          _buildDailyCashStrip(incomeToday, expenseToday),

                          Expanded(
                            child: CustomScrollView(
                              physics: const BouncingScrollPhysics(),
                              slivers: [
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  sliver: SliverList(
                                    delegate: SliverChildListDelegate([
                                      _buildSectionHeader("Revenue Comparison"),
                                      const SizedBox(height: 8),
                                      _buildComparisonGrid(incomeToday, incomeYesterday, incomeLast7Days, incomeThisMonth, kIncomeGreen),

                                      const SizedBox(height: 24),
                                      _buildSectionHeader("Expense Comparison"),
                                      const SizedBox(height: 8),
                                      _buildComparisonGrid(expenseToday, expenseYesterday, expenseLast7Days, expenseThisMonth, kExpenseRed),

                                      const SizedBox(height: 24),
                                      _buildSectionHeader("Settlement Monitor"),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(child: _buildDuesTile("Receivables", salesDues, kIncomeGreen, Icons.call_received_rounded)),
                                          const SizedBox(width: 8),
                                          Expanded(child: _buildDuesTile("Payables", purchaseDues, kExpenseRed, Icons.call_made_rounded)),
                                        ],
                                      ),

                                      const SizedBox(height: 24),
                                      _buildSectionHeader("Archived Insights"),
                                      const SizedBox(height: 8),
                                      _buildYearlyInsightRow("December 2024", incomeDecember, expenseDecember),
                                      const SizedBox(height: 30),
                                    ]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // --- EXECUTIVE UI COMPONENTS ---

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: kTextSecondary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildDailyCashStrip(double income, double expense) {
    final net = income - expense;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Net Cash Position Today", style: TextStyle(color: kTextSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 2),
              Text("${net.toStringAsFixed(2)}", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: net >= 0 ? kIncomeGreen : kExpenseRed, letterSpacing: -1)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("${income.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: kIncomeGreen)),
              Text("${expense.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: kExpenseRed)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonGrid(double today, double yesterday, double week, double month, Color themeColor) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildMetricTile("Today", today, themeColor)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTile("Yesterday", yesterday, themeColor)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildMetricTile("Last 7 Days", week, themeColor)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTile("This Month", month, themeColor)),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: kTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            "${value.toStringAsFixed(0)}",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildDuesTile(String label, double value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                Text("${value.toStringAsFixed(0)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearlyInsightRow(String period, double income, double expense) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(period, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Row(
            children: [
              Text("${income.toStringAsFixed(0)}", style: const TextStyle(color: kIncomeGreen, fontWeight: FontWeight.w900, fontSize: 14)),
              const Text("  /  ", style: TextStyle(color: kTextSecondary)),
              Text("${expense.toStringAsFixed(0)}", style: const TextStyle(color: kExpenseRed, fontWeight: FontWeight.w900, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================
// Payment Summary PAGE (Enhanced with all features from screenshot)
// ==========================================
class PaymentReportPage extends StatefulWidget {
  final VoidCallback onBack;

  const PaymentReportPage({super.key, required this.onBack});

  @override
  State<PaymentReportPage> createState() => _PaymentReportPageState();
}

class _PaymentReportPageState extends State<PaymentReportPage> {
  final FirestoreService _firestoreService = FirestoreService();
  DateFilterOption _selectedFilter = DateFilterOption.today;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  void _onDateChanged(DateFilterOption option, DateTime start, DateTime end) {
    setState(() {
      _selectedFilter = option;
      _startDate = start;
      _endDate = end;
    });
  }

  bool _isInDateRange(DateTime? dt) {
    if (dt == null) return false;
    return dt.isAfter(_startDate.subtract(const Duration(seconds: 1))) &&
        dt.isBefore(_endDate.add(const Duration(seconds: 1)));
  }

  // Store calculated data for PDF download
  double _incomeCash = 0, _incomeOnline = 0, _incomeCredit = 0;
  double _expenseCash = 0, _expenseOnline = 0;
  int _incomeCashCount = 0, _incomeOnlineCount = 0, _incomeCreditCount = 0;
  int _expenseCashCount = 0, _expenseOnlineCount = 0;

  void _downloadPdf(BuildContext context) {
    final rows = [
      ['Income - Cash', ' ${_incomeCash.toStringAsFixed(2)}', '$_incomeCashCount txns'],
      ['Income - Online', ' ${_incomeOnline.toStringAsFixed(2)}', '$_incomeOnlineCount txns'],
      ['Income - Credit', ' ${_incomeCredit.toStringAsFixed(2)}', '$_incomeCreditCount txns'],
      ['Expense - Cash', ' ${_expenseCash.toStringAsFixed(2)}', '$_expenseCashCount txns'],
      ['Expense - Online', ' ${_expenseOnline.toStringAsFixed(2)}', '$_expenseOnlineCount txns'],
    ];

    double totalNet = (_incomeCash + _incomeOnline) - (_expenseCash + _expenseOnline);

    ReportPdfGenerator.generateAndDownloadPdf(
      context: context,
      reportTitle: 'Payment Analytics Report',
      headers: ['Type', 'Amount', 'Transactions'],
      rows: rows,
      summaryTitle: "Net Cash Position",
      summaryValue: " ${totalNet.toStringAsFixed(2)}",
      additionalSummary: {
        'Period': '${DateFormat('dd/MM/yy').format(_startDate)} - ${DateFormat('dd/MM/yy').format(_endDate)}',
        'Total Inflow': ' ${(_incomeCash + _incomeOnline).toStringAsFixed(2)}',
        'Total Outflow': ' ${(_expenseCash + _expenseOnline).toStringAsFixed(2)}',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: _buildModernAppBar("Payment Analytics", widget.onBack, onDownload: () => _downloadPdf(context)),
      body: FutureBuilder<List<Stream<QuerySnapshot>>>(
        future: Future.wait([
          _firestoreService.getCollectionStream('sales'),
          _firestoreService.getCollectionStream('expenses'),
        ]),
        builder: (context, streamsSnapshot) {
          if (!streamsSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2));
          }
          return StreamBuilder<QuerySnapshot>(
            stream: streamsSnapshot.data![0],
            builder: (context, salesSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: streamsSnapshot.data![1],
                builder: (context, expenseSnapshot) {
                  if (!salesSnapshot.hasData || !expenseSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                  }

                  // --- Income Calculations ---
                  double incomeCash = 0, incomeOnline = 0, incomeCredit = 0;
                  int incomeCashCount = 0, incomeOnlineCount = 0, incomeCreditCount = 0;

                  for (var doc in salesSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    DateTime? dt;
                    if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                    else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());

                    if (_isInDateRange(dt)) {
                      // Skip cancelled or returned bills
                      final String status = (data['status'] ?? '').toString().toLowerCase();
                      if (status == 'cancelled' || status == 'returned' || data['hasBeenReturned'] == true) {
                        continue;
                      }

                      double total = double.tryParse(data['total']?.toString() ?? '0') ?? 0;
                      String mode = (data['paymentMode'] ?? 'Cash').toString().toLowerCase();

                      // Handle Split payments separately
                      if (mode == 'split') {
                        double splitCash = double.tryParse(data['cashReceived_split']?.toString() ?? '0') ?? 0;
                        double splitOnline = double.tryParse(data['onlineReceived_split']?.toString() ?? '0') ?? 0;
                        double splitCredit = double.tryParse(data['creditIssued_split']?.toString() ?? '0') ?? 0;
                        if (splitCash > 0) {
                          incomeCash += splitCash;
                          incomeCashCount++;
                        }
                        if (splitOnline > 0) {
                          incomeOnline += splitOnline;
                          incomeOnlineCount++;
                        }
                        if (splitCredit > 0) {
                          incomeCredit += splitCredit;
                          incomeCreditCount++;
                        }
                      } else if (mode.contains('online') || mode.contains('upi') || mode.contains('card')) {
                        incomeOnline += total;
                        incomeOnlineCount++;
                      } else if (mode.contains('credit')) {
                        incomeCredit += total;
                        incomeCreditCount++;
                      } else {
                        incomeCash += total;
                        incomeCashCount++;
                      }
                    }
                  }

                  // --- Expense Calculations ---
                  double expenseCash = 0, expenseOnline = 0;
                  int expenseCashCount = 0, expenseOnlineCount = 0;

                  for (var doc in expenseSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    DateTime? dt;
                    if (data['timestamp'] != null) dt = (data['timestamp'] as Timestamp).toDate();
                    else if (data['date'] != null) dt = DateTime.tryParse(data['date'].toString());

                    if (_isInDateRange(dt)) {
                      double amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0;
                      String mode = (data['paymentMode'] ?? 'Cash').toString().toLowerCase();

                      if (mode.contains('online') || mode.contains('upi') || mode.contains('card')) {
                        expenseOnline += amount;
                        expenseOnlineCount++;
                      } else {
                        expenseCash += amount;
                        expenseCashCount++;
                      }
                    }
                  }

                  double totalNet = (incomeCash + incomeOnline) - (expenseCash + expenseOnline);

                  // Store values for PDF download
                  _incomeCash = incomeCash;
                  _incomeOnline = incomeOnline;
                  _incomeCredit = incomeCredit;
                  _expenseCash = expenseCash;
                  _expenseOnline = expenseOnline;
                  _incomeCashCount = incomeCashCount;
                  _incomeOnlineCount = incomeOnlineCount;
                  _incomeCreditCount = incomeCreditCount;
                  _expenseCashCount = expenseCashCount;
                  _expenseOnlineCount = expenseOnlineCount;

                  return Column(
                    children: [
                      DateFilterWidget(
                        selectedOption: _selectedFilter,
                        startDate: _startDate,
                        endDate: _endDate,
                        onDateChanged: _onDateChanged,
                      ),
                      Expanded(
                        child: CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            // Executive Net Strip
                            SliverToBoxAdapter(
                              child: _buildNetPositionStrip(totalNet, incomeCash + incomeOnline, expenseCash + expenseOnline),
                            ),

                            SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              sliver: SliverList(
                                delegate: SliverChildListDelegate([
                                  _buildSectionHeader("Income Analysis"),
                                  const SizedBox(height: 8),
                                  _buildFlowAnalyticsCard(
                                    "Total Receipts",
                                    incomeCash + incomeOnline,
                                    incomeCash,
                                    incomeOnline,
                                    kIncomeGreen,
                                    incomeCashCount + incomeOnlineCount,
                                  ),

                                  if (incomeCredit > 0) ...[
                                    const SizedBox(height: 12),
                                    _buildCreditCard("Credit Sales", incomeCredit, incomeCreditCount, kWarningOrange),
                                  ],

                                  const SizedBox(height: 24),
                                  _buildSectionHeader(" Expenses Analysis"),
                                  const SizedBox(height: 8),
                                  _buildFlowAnalyticsCard(
                                    "Total Payments",
                                    expenseCash + expenseOnline,
                                    expenseCash,
                                    expenseOnline,
                                    kExpenseRed,
                                    expenseCashCount + expenseOnlineCount,
                                  ),

                                  const SizedBox(height: 24),
                                  _buildSectionHeader("Settlement Summary"),
                                  const SizedBox(height: 8),
                                  _buildLedgerRow("Cash Position", incomeCash, expenseCash, kIncomeGreen),
                                  const SizedBox(height: 4),
                                  _buildLedgerRow("Online Balance", incomeOnline, expenseOnline, kPrimaryColor),
                                  if (incomeCredit > 0) ...[
                                    const SizedBox(height: 4),
                                    _buildLedgerRow("Credit Outstanding", incomeCredit, 0, kWarningOrange),
                                  ],
                                  const SizedBox(height: 40),
                                ]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // --- EXECUTIVE UI COMPONENTS ---

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: kTextSecondary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildNetPositionStrip(double net, double income, double expense) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor.withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("NET CASH POSITION", style: TextStyle(color: kTextSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 2),
              Text(" ${net.toStringAsFixed(2)}", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: net >= 0 ? kIncomeGreen : kExpenseRed, letterSpacing: -1)),
            ],
          ),
          Row(
            children: [
              _buildSmallTrend(income, kIncomeGreen, Icons.arrow_downward_rounded),
              const SizedBox(width: 12),
              _buildSmallTrend(expense, kExpenseRed, Icons.arrow_upward_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallTrend(double val, Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 4),
            Text(" ${val.toStringAsFixed(0)}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
        Text(color == kIncomeGreen ? "IN" : "OUT", style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: kTextSecondary)),
      ],
    );
  }

  Widget _buildFlowAnalyticsCard(String label, double total, double cash, double online, Color themeColor, int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderColor.withOpacity(0.6)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: kTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                  Text("${total.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text("$count TXNS", style: TextStyle(color: themeColor, fontSize: 10, fontWeight: FontWeight.w900)),
              )
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 28,
                          sections: [
                            PieChartSectionData(color: kChartGreen, value: cash, title: '', radius: 12),
                            PieChartSectionData(color: kChartBlue, value: online, title: '', radius: 12),
                            if (total == 0) PieChartSectionData(color: kBorderColor, value: 1, title: '', radius: 12),
                          ],
                        ),
                      ),
                      const Icon(Icons.donut_large_rounded, size: 16, color: kTextSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    _buildCompactDistributionRow("Cash Mode", cash, total, kChartGreen),
                    const SizedBox(height: 8),
                    _buildCompactDistributionRow("Online Mode", online, total, kChartBlue),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDistributionRow(String label, double val, double total, Color color) {
    final percent = total > 0 ? (val / total) * 100 : 0.0;
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: kTextSecondary, fontWeight: FontWeight.w600)),
              Text("${val.toStringAsFixed(0)}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        Text("${percent.toStringAsFixed(0)}%", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }

  Widget _buildLedgerRow(String label, double income, double expense, Color themeColor) {
    final net = income - expense;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(width: 3, height: 24, decoration: BoxDecoration(color: themeColor, borderRadius: BorderRadius.circular(10))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                Text(
                  "IN: ${income.toStringAsFixed(0)} • OUT: ${expense.toStringAsFixed(0)}",
                  style: const TextStyle(fontSize: 9, color: kTextSecondary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Text(
            "${net.toStringAsFixed(0)}",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: net >= 0 ? kIncomeGreen : kExpenseRed),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCard(String label, double amount, int count, Color themeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: themeColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.credit_card_rounded, color: themeColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                Text("$count transactions", style: const TextStyle(fontSize: 9, color: kTextSecondary, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Text("${amount.toStringAsFixed(0)}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: themeColor)),
        ],
      ),
    );
  }
}

// ==========================================
// GST REPORT NOW MERGED INTO TAX REPORT
// Use TaxReport for comprehensive tax and GST reporting
// ==========================================
