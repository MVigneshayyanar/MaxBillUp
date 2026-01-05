import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Colors.dart';
import 'package:provider/provider.dart';
import 'package:maxbillup/Auth/SubscriptionPlanPage.dart';
import 'package:maxbillup/Sales/Bill.dart';
import 'package:maxbillup/Sales/Invoice.dart';
import 'package:maxbillup/Sales/QuotationsList.dart';
import 'package:maxbillup/Menu/CustomerManagement.dart';
import 'package:maxbillup/Menu/AddCustomer.dart';
import 'package:maxbillup/Menu/KnowledgePage.dart';
import 'package:maxbillup/components/common_bottom_nav.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/Stocks/StockPurchase.dart';
import 'package:maxbillup/Stocks/ExpenseCategories.dart';
import 'package:maxbillup/Stocks/Expenses.dart';
import 'package:maxbillup/Stocks/Vendors.dart';
import 'package:maxbillup/Settings/StaffManagement.dart' hide kPrimaryColor, kErrorColor;
import 'package:maxbillup/Reports/Reports.dart' hide kPrimaryColor;
import 'package:maxbillup/Stocks/Stock.dart';
import 'package:maxbillup/Settings/Profile.dart'; // For SettingsPage
import 'package:maxbillup/utils/permission_helper.dart';
import 'package:maxbillup/utils/plan_permission_helper.dart';
import 'package:maxbillup/utils/plan_provider.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/Sales/NewSale.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/services/number_generator_service.dart';
// ignore: uri_does_not_exist
import 'package:url_launcher/url_launcher.dart' as launcher;

import '../Sales/components/common_widgets.dart';




// ==========================================
// VIDEO TUTORIAL PAGE
// ==========================================
class MenuPage extends StatefulWidget {
  final String uid;
  final String? userEmail;

  const MenuPage({super.key, required this.uid, this.userEmail});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  String? _currentView;
  String _businessName = "Loading...";
  String _email = "";
  String _role = "staff";
  String? _logoUrl;
  Map<String, dynamic> _permissions = {};

  StreamSubscription<DocumentSnapshot>? _userSubscription;
  StreamSubscription<DocumentSnapshot>? _storeSubscription;

  @override
  void initState() {
    super.initState();
    _email = widget.userEmail ?? "";
    _initFastFetch();
    _loadPermissions();
    _initStoreLogo();
  }

  /// FAST FETCH: Instant cache retrieval with reactive listener
  void _initFastFetch() {
    final fs = FirestoreService();

    // 1. Immediate Cache Fetch
    FirebaseFirestore.instance.collection('users').doc(widget.uid).get(
        const GetOptions(source: Source.cache)
    ).then((doc) {
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _businessName = data['businessName'] ?? data['name'] ?? 'My Business';
          _role = data['role'] ?? 'Staff';
        });
      }
    });

    // 2. Live Sync Listener
    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _businessName = data['businessName'] ?? data['name'] ?? 'My Business';
          if (data.containsKey('email')) _email = data['email'];
          _role = data['role'] ?? 'Staff';
        });
      }
    });
  }

  /// Initialize store logo listener
  void _initStoreLogo() async {
    final storeId = await FirestoreService().getCurrentStoreId();
    if (storeId == null) return;

    // Immediate cache fetch
    FirebaseFirestore.instance.collection('store').doc(storeId).get(
        const GetOptions(source: Source.cache)
    ).then((doc) {
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          setState(() {
            _logoUrl = data['logoUrl'] as String?;
          });
        }
      }
    });

    // Live sync listener
    _storeSubscription = FirebaseFirestore.instance
        .collection('store')
        .doc(storeId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data() as Map<String, dynamic>?;
        if (data != null) {
          setState(() {
            _logoUrl = data['logoUrl'] as String?;
          });
        }
      }
    });
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

  @override
  void dispose() {
    _userSubscription?.cancel();
    _storeSubscription?.cancel();
    super.dispose();
  }

  bool _hasPermission(String permission) => _permissions[permission] == true;

  @override
  Widget build(BuildContext context) {
    return Consumer<PlanProvider>(
      builder: (context, planProvider, child) {
        bool isAdmin = _role.toLowerCase() == 'admin' || _role.toLowerCase() == 'administrator';

        // IMPORTANT: Don't show lock icons until provider is initialized
        // This prevents the brief flash of lock icons when navigating to this page
        final isProviderReady = planProvider.isInitialized;

        // Use cached plan for instant access - auto-updates when subscription changes
        final currentPlan = planProvider.cachedPlan;

        // Determine plan rank: Starter=0, Essential=1, Growth=2, Pro=3
        // If provider not ready, assume max rank to avoid flash of locks
        int planRank = isProviderReady ? 0 : 3;
        if (isProviderReady) {
          if (currentPlan.toLowerCase().contains('essential')) {
            planRank = 1;
          } else if (currentPlan.toLowerCase().contains('growth')) {
            planRank = 2;
          } else if (currentPlan.toLowerCase().contains('pro') || currentPlan.toLowerCase().contains('premium')) {
            planRank = 3;
          } else if (currentPlan.toLowerCase().contains('starter') || currentPlan.toLowerCase().contains('free')) {
            planRank = 0;
          }
        }

        // Helper function to check if feature is available based on plan
        bool isFeatureAvailable(String permission, {int requiredRank = 1}) {
          // Check plan rank first
          if (planRank < requiredRank) return false;

          // If admin and has required plan, allow access
          if (isAdmin) return true;

          // Check user permission
          final userPerm = _permissions[permission] == true;
          return userPerm;
        }

        // Conditional Rendering
        if (_currentView != null) {
          return _handleViewRouting(isAdmin, planProvider);
        }

        return Scaffold(
          backgroundColor: kGreyBg,
          body: Column(
            children: [
              _buildEnterpriseHeader(context, planProvider),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSectionLabel("Core Operations"),
                    if (_hasPermission('billHistory') || isAdmin)
                      _buildMenuTile(
                          context.tr('billhistory'),
                          Icons.receipt_long_rounded,
                          kGoogleGreen,
                          'BillHistory',
                          subtitle: (currentPlan.toLowerCase() == 'free' || currentPlan.toLowerCase() == 'starter')
                              ? "Last 7 days only"
                              : "View and manage invoices",
                          isLocked: false  // Available to all, but with 7-day limit for free/starter users
                      ),
                    if (_hasPermission('customerManagement') || isAdmin)
                      _buildMenuTile(context.tr('customers'), Icons.people_alt_rounded, const Color(0xFF9C27B0), 'Customers', subtitle: "Directory & balances", isLocked: !isFeatureAvailable('customerManagement', requiredRank: 1)),
                    _buildMenuTile(context.tr('credit_notes'), Icons.confirmation_number_rounded, kOrange, 'CreditNotes', subtitle: "Sales returns & returns", isLocked: planRank < 1),

                    const SizedBox(height: 12),
                    _buildSectionLabel("Financials"),
                    if (_hasPermission('expenses') || isAdmin)
                      _buildExpenseExpansionTile(context),
                    if (_hasPermission('creditDetails') || isAdmin)
                      _buildMenuTile(context.tr('creditdetails'), Icons.credit_card_outlined, const Color(0xFF00796B), 'CreditDetails', subtitle: "Outstanding dues tracker", isLocked: !isFeatureAvailable('creditDetails', requiredRank: 2)),
                    if (_hasPermission('quotation') || isAdmin)
                      _buildMenuTile(context.tr('quotation'), Icons.description_rounded, kPrimaryColor, 'Quotation', subtitle: "Estimates & proforma", isLocked: !isFeatureAvailable('quotation', requiredRank: 1)),

                    const SizedBox(height: 12),
                    _buildSectionLabel("Administration"),
                    if (isAdmin || _hasPermission('staffManagement'))
                      _buildMenuTile(context.tr('staff_management'), Icons.badge_rounded, const Color(0xFF607D8B), 'StaffManagement', subtitle: "Roles & permissions", isLocked: !isFeatureAvailable('staffManagement', requiredRank: 2)),

                    const SizedBox(height: 12),
                    _buildSectionLabel("Support"),
                    _buildMenuTile(context.tr('video_tutorials'), Icons.ondemand_video_rounded, const Color(0xFF2F7CF6), 'VideoTutorial', subtitle: "How-to guides"),
                    _buildMenuTile(context.tr('knowledge_base'), Icons.school_rounded, const Color(0xFFE6AE00), 'Knowledge', subtitle: "Documentation & tips"),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: CommonBottomNav(uid: widget.uid, userEmail: widget.userEmail, currentIndex: 0, screenWidth: MediaQuery.of(context).size.width),
        );
      },
    );
  }

  Widget _buildEnterpriseHeader(BuildContext context, PlanProvider planProvider) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20, bottom: 24, left: 20, right: 20),
      decoration: const BoxDecoration(color: kPrimaryColor),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: kWhite.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
            child: Image.asset('assets/MAX_my_bill_mic.png', width: 68, height: 68, fit: BoxFit.contain),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_businessName, style: const TextStyle(color: kWhite, fontSize: 18, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: kWhite.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                      child: Text(_role[0].toUpperCase() + _role.substring(1).toLowerCase(), style: const TextStyle(color: kWhite, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    ),
                    const SizedBox(width: 8),
                    _buildPlanBadge(planProvider),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_email, style: TextStyle(color: kWhite.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Store logo - clickable to navigate to profile
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => SettingsPage(uid: widget.uid, userEmail: widget.userEmail),
                ),
              );
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: kWhite.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kWhite.withOpacity(0.3), width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _logoUrl != null && _logoUrl!.isNotEmpty
                    ? Image.network(
                  _logoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.store_rounded, size: 28, color: kWhite);
                  },
                )
                    : const Icon(Icons.store_rounded, size: 28, color: kWhite),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanBadge(PlanProvider planProvider) {
    // Use cached plan for instant access - auto-updates when subscription changes
    final plan = planProvider.cachedPlan;
    final isPremium = !plan.toLowerCase().contains('free') && !plan.toLowerCase().contains('starter');
    return GestureDetector(
      onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => SubscriptionPlanPage(uid: widget.uid, currentPlan: plan))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: isPremium ? kGoogleGreen : kOrange, borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, color: kWhite, size: 10),
            const SizedBox(width: 4),
            Text(plan[0].toUpperCase() + plan.substring(1).toLowerCase(), style: const TextStyle(color: kWhite, fontSize: 9, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12, left: 4),
    child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 1.5)),
  );

  Widget _buildMenuTile(String title, IconData icon, Color color, String viewKey, {String? subtitle, bool isLocked = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: kGrey200)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isLocked) {
              PlanPermissionHelper.showUpgradeDialog(context, title, uid: widget.uid);
            } else {
              setState(() => _currentView = viewKey);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kBlack87)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle, style: const TextStyle(color: kBlack54, fontSize: 11, fontWeight: FontWeight.w500)),
                      ],
                    ],
                  ),
                ),
                if (isLocked)
                  Icon(Icons.lock_rounded, color: kGrey400.withOpacity(0.5), size: 18)
                else
                  const Icon(Icons.arrow_forward_ios_rounded, color: kGrey400, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseExpansionTile(BuildContext context) {
    const Color color = Color(0xFFE91E63);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: kGrey200)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.account_balance_wallet_rounded, color: color, size: 22),
          ),
          title: Text(context.tr('expenses'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kBlack87)),
          childrenPadding: const EdgeInsets.only(left: 58, right: 12, bottom: 12),
          children: [
            _buildSubMenuItem(context.tr('stock_purchase'), 'StockPurchase'),
            _buildSubMenuItem(context.tr('expenses'), 'Expenses'),
            _buildSubMenuItem(context.tr('expense_category'), 'ExpenseCategories'),
            _buildSubMenuItem('Vendors Management', 'Vendors'),
          ],
        ),
      ),
    );
  }

  Widget _buildSubMenuItem(String text, String viewKey) {
    return ListTile(
      onTap: () => setState(() => _currentView = viewKey),
      title: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kBlack54)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: kGrey300),
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
    );
  }

  Widget _handleViewRouting(bool isAdmin, PlanProvider planProvider) {
    void reset() => setState(() => _currentView = null);

    switch (_currentView) {
      case 'NewSale': return NewSalePage(uid: widget.uid, userEmail: widget.userEmail);
      case 'BillHistory': return SalesHistoryPage(uid: widget.uid, userEmail: widget.userEmail, onBack: reset);
      case 'Customers': return CustomersPage(uid: widget.uid, onBack: reset);
      case 'StockPurchase': return StockPurchasePage(uid: widget.uid, onBack: reset);
      case 'Expenses': return ExpensesPage(uid: widget.uid, onBack: reset);
      case 'ExpenseCategories': return ExpenseCategoriesPage(uid: widget.uid, onBack: reset);
      case 'Vendors': return VendorsPage(uid: widget.uid, onBack: reset);
      case 'Knowledge': return KnowledgePage(onBack: reset);
      case 'VideoTutorial': return VideoTutorialPage(onBack: reset);

      case 'Quotation':
        return _buildAsyncRoute(planProvider.canAccessQuotationAsync(), 'Quotation', reset, QuotationsListPage(uid: widget.uid, userEmail: widget.userEmail, onBack: reset));
      case 'CreditNotes':
        return _buildAsyncRoute(planProvider.canAccessCustomerCreditAsync(), 'Customer Credit', reset, CreditNotesPage(uid: widget.uid, onBack: reset));
      case 'CreditDetails':
        return _buildAsyncRoute(planProvider.canAccessCustomerCreditAsync(), 'Customer Credit', reset, CreditDetailsPage(uid: widget.uid, onBack: reset));
      case 'StaffManagement':
        return _buildAsyncRoute(planProvider.canAccessStaffManagementAsync(), 'Staff Management', reset, StaffManagementPage(uid: widget.uid, userEmail: widget.userEmail, onBack: reset));
    }
    return Container();
  }

  Widget _buildAsyncRoute(Future<bool> future, String featureName, VoidCallback reset, Widget targetPage) {
    return FutureBuilder<bool>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (!snapshot.data!) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            PlanPermissionHelper.showUpgradeDialog(context, featureName, uid: widget.uid);
            reset();
          });
          return Container();
        }
        return targetPage;
      },
    );
  }
}

// ==========================================
// VIDEO TUTORIAL PAGE (STYLIZED)
// ==========================================
class VideoTutorialPage extends StatelessWidget {
  final VoidCallback onBack;
  const VideoTutorialPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(
        title: const Text('Tutorials', style: TextStyle(color: kWhite,fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: kPrimaryColor, centerTitle: true, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 18), onPressed: onBack),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.05), shape: BoxShape.circle),
              child: const Icon(Icons.play_circle_filled_rounded, size: 80, color: kPrimaryColor),
            ),
            const SizedBox(height: 32),
            const Text('Master Your Business', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kBlack87)),
            const SizedBox(height: 12),
            const Text('Watch our comprehensive video guide to learn how to manage inventory, sales, and staff effectively.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: kBlack54, height: 1.5, fontWeight: FontWeight.w500)),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Watch on YouTube', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  final url = Uri.parse('https://www.youtube.com');
                  if (await launcher.canLaunchUrl(url)) await launcher.launchUrl(url, mode: launcher.LaunchMode.externalApplication);
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
        backgroundColor: const Color(0xFF2F7CF6),
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

enum SortOption { dateNewest, dateOldest, amountHigh, amountLow }

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  // Streams
  Stream<List<QueryDocumentSnapshot>>? _combinedStream;
  StreamController<List<QueryDocumentSnapshot>>? _controller;
  StreamSubscription? _salesSub;
  StreamSubscription? _savedOrdersSub;

  // Search & Filter State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  SortOption _currentSort = SortOption.dateNewest;

  // Filter options
  String _statusFilter = 'all'; // all, settled, unsettled, cancelled, edited, returned
  String _paymentFilter = 'all';
  String _selectedDateFilter = 'All Time';
  DateTimeRange? _customDateRange;

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

  Future<void> _initializeCombinedStream() async {
    try {
      final salesCollection = await FirestoreService().getStoreCollection('sales');
      final savedOrdersCollection = await FirestoreService().getStoreCollection('savedOrders');

      final salesStream = salesCollection.snapshots();
      final savedOrdersStream = savedOrdersCollection.snapshots();

      List<QueryDocumentSnapshot> salesDocs = [];
      List<QueryDocumentSnapshot> savedOrdersDocs = [];

      void updateController() {
        if (_controller == null || _controller!.isClosed) return;
        final allDocs = [...salesDocs, ...savedOrdersDocs];
        _controller!.add(allDocs);
      }

      _controller = StreamController<List<QueryDocumentSnapshot>>.broadcast();
      _salesSub = salesStream.listen((snapshot) { salesDocs = snapshot.docs; updateController(); });
      _savedOrdersSub = savedOrdersStream.listen((snapshot) { savedOrdersDocs = snapshot.docs; updateController(); });

      if (mounted) setState(() => _combinedStream = _controller!.stream);
    } catch (e) {
      if (mounted) setState(() => _combinedStream = Stream.value([]));
    }
  }

  List<QueryDocumentSnapshot> _processList(List<QueryDocumentSnapshot> docs, int historyLimit) {
    final now = DateTime.now();
    final historyLimitDate = now.subtract(Duration(days: historyLimit));

    // 1. Filter
    var filtered = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['timestamp'] as Timestamp?;
      if (timestamp != null && timestamp.toDate().isBefore(historyLimitDate)) return false;

      // Status logic
      final paymentStatus = data['paymentStatus'];
      final isSettled = paymentStatus != null ? paymentStatus != 'unsettled' : (data.containsKey('paymentMode'));
      final isCancelled = data['status'] == 'cancelled';
      final isEdited = data['status'] == 'edited';
      final isReturned = data['status'] == 'returned';

      if (_statusFilter == 'settled' && (!isSettled || isCancelled || isEdited || isReturned)) return false;
      if (_statusFilter == 'unsettled' && (isSettled || isCancelled || isEdited || isReturned)) return false;
      if (_statusFilter == 'cancelled' && !isCancelled) return false;
      if (_statusFilter == 'edited' && !isEdited) return false;
      if (_statusFilter == 'returned' && !isReturned) return false;

      // Search
      if (_searchQuery.isNotEmpty) {
        final inv = (data['invoiceNumber'] ?? '').toString().toLowerCase();
        final customer = (data['customerName'] ?? '').toString().toLowerCase();
        if (!inv.contains(_searchQuery) && !customer.contains(_searchQuery)) return false;
      }

      return true;
    }).toList();

    // 2. Sort
    filtered.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;

      switch (_currentSort) {
        case SortOption.amountHigh:
          return (dataB['total'] ?? 0.0).compareTo(dataA['total'] ?? 0.0);
        case SortOption.amountLow:
          return (dataA['total'] ?? 0.0).compareTo(dataB['total'] ?? 0.0);
        case SortOption.dateOldest:
          return (dataA['timestamp'] as Timestamp? ?? Timestamp.now()).compareTo(dataB['timestamp'] as Timestamp? ?? Timestamp.now());
        case SortOption.dateNewest:
        default:
          return (dataB['timestamp'] as Timestamp? ?? Timestamp.now()).compareTo(dataA['timestamp'] as Timestamp? ?? Timestamp.now());
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kWhite, size: 22),
          onPressed: widget.onBack,
        ),
        title: Text(context.tr('billhistory'),
            style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: Column(
        children: [
          _buildHeaderSection(),
          Expanded(
            child: FutureBuilder<int>(
              future: PlanPermissionHelper.getBillHistoryDaysLimit(),
              builder: (context, planSnap) {
                final limit = planSnap.data ?? 7;
                return StreamBuilder<List<QueryDocumentSnapshot>>(
                  stream: _combinedStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                    final list = _processList(snapshot.data!, limit);
                    if (list.isEmpty) return _buildEmpty();

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 10),
                      itemBuilder: (c, i) => _buildBillCard(list[i]),
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

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: kWhite,
        border: Border(bottom: BorderSide(color: kGrey200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kGrey200),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: context.tr('search'),
                  hintStyle: TextStyle(color: kBlack54, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: kPrimaryColor, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 7),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildHeaderActionBtn(Icons.sort_rounded, _showSortMenu),
          const SizedBox(width: 8),
          _buildHeaderActionBtn(Icons.tune_rounded, _showFilterMenu),
        ],
      ),
    );
  }

  Widget _buildHeaderActionBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 46, width: 46,
        decoration: BoxDecoration(
          color: kPrimaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kGrey200),
        ),
        child: Icon(icon, color: kPrimaryColor, size: 22),
      ),
    );
  }

  Widget _buildBillCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final inv = data['invoiceNumber'] ?? 'N/A';
    final total = (data['total'] ?? 0.0).toDouble();
    final customerName = data['customerName'] ?? 'Guest';
    final staffName = data['staffName'] ?? 'Staff';

    final timestamp = data['timestamp'] as Timestamp?;
    final formattedDateTime = timestamp != null
        ? DateFormat('dd-MM-yyyy • hh:mm a').format(timestamp.toDate())
        : '--';

    final paymentStatus = data['paymentStatus'];
    final bool isSettled = paymentStatus != null ? paymentStatus != 'unsettled' : (data.containsKey('paymentMode'));
    final bool isCancelled = data['status'] == 'cancelled';
    final bool isEdited = data['status'] == 'edited';
    final bool isReturned = data['status'] == 'returned';

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleOnTap(doc, data, isSettled, isCancelled, total),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text("Invoice $inv", style: const TextStyle(fontWeight: FontWeight.w900, color: kPrimaryColor, fontSize: 13)),
                  Text(formattedDateTime, style: const TextStyle(fontSize: 10.5, color: Colors.black, fontWeight: FontWeight.w500))
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: kGreyBg, shape: BoxShape.circle),
                    child: const Icon(Icons.person_rounded, size: 16, color: kBlack54),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kOrange)),
                  ),
                  Text("${total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: kPrimaryColor)),
                ]),
                const Divider(height: 20, color: kGreyBg),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Billed by", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: kBlack54, letterSpacing: 0.5)),
                    Text(staffName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: kBlack87))
                  ]),
                  _badge(isSettled, isCancelled, isEdited, isReturned)
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(bool settled, bool cancelled, bool edited, bool returned) {
    if (cancelled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: kBlack54.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: const Text("Cancelled", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kBlack54)),
      );
    }
    if (edited) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withOpacity(0.2))),
        child: const Text("Edited", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.blue)),
      );
    }
    if (returned) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withOpacity(0.2))),
        child: const Text("Returned", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.orange)),
      );
    }
    // Logic: Unsettled (Open) is Green, Settled (Closed) is Red
    final Color statusColor = settled ? kErrorColor : kGoogleGreen;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withOpacity(0.2))),
        child: Text(settled ? "Settled" : "Unsettled",
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: statusColor)));
  }

  void _handleOnTap(QueryDocumentSnapshot doc, Map<String, dynamic> data, bool isSettled, bool isCancelled, double total) {
    // Allow editing only if unsettled and not cancelled/edited/returned
    final bool isEdited = data['status'] == 'edited';
    final bool isReturned = data['status'] == 'returned';

    if (!isSettled && !isCancelled && !isEdited && !isReturned) {
      final List<CartItem> cartItems = (data['items'] as List<dynamic>? ?? [])
          .map((item) => CartItem(
        productId: item['productId'] ?? '',
        name: item['name'] ?? '',
        price: (item['price'] ?? 0).toDouble(),
        quantity: item['quantity'] is int ? item['quantity'] : int.tryParse(item['quantity'].toString()) ?? 1,
      ))
          .toList();

      final isUnsettledSale = data.containsKey('paymentStatus') && data['paymentStatus'] == 'unsettled';

      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => BillPage(
            uid: widget.uid,
            cartItems: cartItems,
            totalAmount: total,
            userEmail: widget.userEmail,
            savedOrderId: isUnsettledSale ? null : doc.id,
            existingInvoiceNumber: data['invoiceNumber'],
            unsettledSaleId: isUnsettledSale ? doc.id : null,
            discountAmount: (data['discount'] ?? 0.0).toDouble(),
            customerPhone: data['customerPhone'],
            customerName: data['customerName'],
            customerGST: data['customerGST'],
            quotationId: data['quotationId'],
          ),
        ),
      );
    } else {
      Navigator.push(context, CupertinoPageRoute(builder: (context) => SalesDetailPage(documentId: doc.id, initialData: data, uid: widget.uid)));
    }
  }

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sort History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kBlack87)),
              const SizedBox(height: 16),
              _sortItem("Newest First", SortOption.dateNewest),
              _sortItem("Oldest First", SortOption.dateOldest),
              _sortItem("Amount: High to Low", SortOption.amountHigh),
              _sortItem("Amount: Low to High", SortOption.amountLow),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sortItem(String label, SortOption option) {
    bool isSelected = _currentSort == option;
    return ListTile(
      onTap: () { setState(() => _currentSort = option); Navigator.pop(context); },
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? kPrimaryColor : kBlack87)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: kPrimaryColor) : null,
    );
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filter Bills', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kBlack87)),
              const SizedBox(height: 16),
              _filterItem("All Records", 'all'),
              _filterItem("Settled Only", 'settled'),
              _filterItem("Unsettled Only", 'unsettled'),
              _filterItem("Cancelled Only", 'cancelled'),
              _filterItem("Edited Only", 'edited'),
              _filterItem("Returned Only", 'returned'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterItem(String label, String value) {
    bool isSelected = _statusFilter == value;
    return ListTile(
      onTap: () { setState(() => _statusFilter = value); Navigator.pop(context); },
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? kPrimaryColor : kBlack87)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: kPrimaryColor) : null,
    );
  }

  Widget _buildEmpty() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.receipt_long, size: 64, color: kGrey300), const SizedBox(height: 16), Text(context.tr('nobillsfound'), style: const TextStyle(color: kBlack54, fontWeight: FontWeight.w600))]));
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

  // ==========================================
  // LOGIC METHODS (PRESERVED BIT-BY-BIT)
  // ==========================================

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

  // Check user permissions for actions
  Future<Map<String, dynamic>> _getUserPermissions() async {
    try {
      // Use the same method that MenuPage uses to load permissions
      final userData = await PermissionHelper.getUserPermissions(uid);
      final role = userData['role'] as String;
      final permissions = userData['permissions'] as Map<String, dynamic>;

      debugPrint('Permission Check: role = $role');
      debugPrint('Staff permissions retrieved: $permissions');

      // Check if user is admin
      final isAdmin = role.toLowerCase() == 'admin' || role.toLowerCase() == 'administrator';
      debugPrint('User is admin: $isAdmin');

      if (isAdmin) {
        debugPrint('User is admin - granting all permissions');
        return {
          'canSaleReturn': true,
          'canCancelBill': true,
          'canEditBill': true,
          'isAdmin': true,
        };
      }

      final result = {
        'canSaleReturn': permissions['saleReturn'] == true,
        'canCancelBill': permissions['cancelBill'] == true,
        'canEditBill': permissions['editBill'] == true,
        'isAdmin': false,
      };

      debugPrint('Final permission result: $result');
      return result;
    } catch (e) {
      debugPrint('Error getting user permissions: $e');
      return {
        'canSaleReturn': false,
        'canCancelBill': false,
        'canEditBill': false,
        'isAdmin': false,
      };
    }
  }

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
            .collection('store')  // FIXED: Changed from 'stores' to 'store'
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

      // Prepare items for invoice page with complete tax information
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((item) => {
        'name': item['name'] ?? '',
        'quantity': item['quantity'] ?? 0,
        'price': (item['price'] ?? 0).toDouble(),
        'total': ((item['price'] ?? 0) * (item['quantity'] ?? 1)).toDouble(),
        'productId': item['productId'] ?? '',
        'taxName': item['taxName'],
        'taxPercentage': (item['taxPercentage'] ?? 0).toDouble(),
        'taxAmount': (item['taxAmount'] ?? 0).toDouble(),
        'taxType': item['taxType'],
      })
          .toList();

      // Get timestamp
      DateTime dateTime = DateTime.now();
      if (data['timestamp'] != null) {
        dateTime = (data['timestamp'] as Timestamp).toDate();
      } else if (data['date'] != null) {
        dateTime = DateTime.tryParse(data['date'].toString()) ?? DateTime.now();
      }

      // Calculate tax information from items
      final taxCalculations = _calculateTaxTotals(items.cast<Map<String, dynamic>>());
      final taxBreakdown = taxCalculations['taxBreakdown'] as Map<String, double>;
      final taxList = taxBreakdown.entries
          .map((e) => {'name': e.key, 'amount': e.value})
          .toList();

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
              subtotal: taxCalculations['subtotalWithoutTax'] as double,
              discount: (data['discount'] ?? 0).toDouble(),
              taxes: taxList.isNotEmpty ? taxList : null,
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

  void _showCancelBillDialog(BuildContext context, String documentId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Are you sure ?',
          style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),
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
                style: const TextStyle(fontSize: 14, color: Color(0xFF2F7CF6)),
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

                // 3. Mark the sales document as cancelled (don't delete)
                final salesCollection = await FirestoreService().getStoreCollection('sales');
                await salesCollection.doc(documentId).update({
                  'status': 'cancelled',
                  'cancelledAt': FieldValue.serverTimestamp(),
                  'cancelledBy': data['staffName'] ?? 'Admin',
                  'cancelReason': 'Bill Cancelled',
                });

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

  // ==========================================
  // UI BUILD METHODS (QUOTATION PAGE STYLE)
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimaryColor, // Primary color background like QuotationPage entry
      appBar: AppBar(
        title: const Text('Invoice Details', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 22), onPressed: () => Navigator.pop(context)),
      ),
      body: FutureBuilder<DocumentReference>(
        future: FirestoreService().getDocumentReference('sales', documentId),
        builder: (context, docRefSnapshot) {
          if (!docRefSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kWhite));

          return StreamBuilder<DocumentSnapshot>(
            stream: docRefSnapshot.data!.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kWhite));
              if (!snapshot.hasData || !snapshot.data!.exists) return Center(child: Text(context.tr('bill_not_found'), style: const TextStyle(color: kWhite)));

              final data = snapshot.data!.data() as Map<String, dynamic>;
              final ts = data['timestamp'] as Timestamp?;
              final dateStr = ts != null ? DateFormat('dd-MM-yy • hh:mm a').format(ts.toDate()) : '--';
              final items = (data['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

              // Calculate tax from items (for new sales with tax fields)
              final taxInfo = _calculateTaxTotals(items);
              double subtotalWithoutTax = taxInfo['subtotalWithoutTax'] as double;
              Map<String, double> taxBreakdown = taxInfo['taxBreakdown'] as Map<String, double>;

              // Fallback: If no tax in items, check if document has taxes field (backward compatibility)
              if (taxBreakdown.isEmpty && data['taxes'] != null) {
                final docTaxes = data['taxes'] as List<dynamic>?;
                if (docTaxes != null) {
                  for (var tax in docTaxes) {
                    final taxName = tax['name'] as String?;
                    final taxAmount = (tax['amount'] ?? 0).toDouble();
                    if (taxName != null && taxAmount > 0) {
                      taxBreakdown[taxName] = taxAmount;
                    }
                  }
                }
                // Use stored subtotal if available
                if (data['subtotal'] != null) {
                  subtotalWithoutTax = (data['subtotal'] ?? 0).toDouble();
                }
              }

              // Fallback: If still no tax but totalTax exists
              if (taxBreakdown.isEmpty && data['totalTax'] != null) {
                final totalTax = (data['totalTax'] ?? 0).toDouble();
                if (totalTax > 0) {
                  taxBreakdown['Tax'] = totalTax;
                }
              }

              final status = data['paymentStatus'];
              final bool settled = status != null ? status != 'unsettled' : (data.containsKey('paymentMode'));
              final bool isCancelled = data['status'] == 'cancelled';
              final bool isEdited = data['status'] == 'edited';
              final bool isReturned = data['status'] == 'returned';

              return Column(
                children: [
                  // Top Floating Card: Customer Info (Reduced vertical gap)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12,0, 12, 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: kWhite,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                              backgroundColor: kOrange.withOpacity(0.1),
                              radius: 18,
                              child: const Icon(Icons.person, color: kOrange, size: 18)
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['customerName'] ?? 'Guest',
                                  style: const TextStyle(color: kOrange, fontSize: 15, fontWeight: FontWeight.w700),
                                ),
                                if (data['customerPhone'] != null)
                                  Text(data['customerPhone'], style: const TextStyle(color: kBlack54, fontSize: 11)),
                              ],
                            ),
                          ),
                          _buildStatusTag(settled, isCancelled, isEdited, isReturned),
                        ],
                      ),
                    ),
                  ),

                  // Main Body: White Container extending to bottom
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: kWhite,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text('Billing overview', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: kBlack54, letterSpacing: 0.5)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: kSuccessGreen.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: kSuccessGreen.withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          '${items.length} ${items.length == 1 ? 'Item' : 'Items'}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: kSuccessGreen,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(Icons.receipt_long_rounded, 'Invoice No', 'Invoice-${data['invoiceNumber']}'),
                                  _buildDetailRow(Icons.badge_rounded, 'Billed By', data['staffName'] ?? 'Admin'),
                                  _buildDetailRow(Icons.calendar_month_rounded, 'Date Issued', dateStr),
                                  _buildDetailRow(Icons.payment_rounded, 'Payment Mode', data['paymentMode'] ?? 'Not Set'),

                                  // Display custom note/description if available
                                  if (data['customNote'] != null && (data['customNote'] as String).trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: kOrange.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: kOrange.withOpacity(0.2)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Row(
                                              children: [
                                                Icon(Icons.note_alt_outlined, size: 14, color: kOrange),
                                                SizedBox(width: 6),
                                                Text('Notes', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kOrange, letterSpacing: 0.5)),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              data['customNote'] as String,
                                              style: const TextStyle(fontSize: 12, color: kBlack87, fontWeight: FontWeight.w500, height: 1.4),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                  const Padding(padding: EdgeInsets.symmetric(vertical: 0), child: Divider(color: kGreyBg, thickness: 1)),

                                  // Table-formatted Item List
                                  const Text('Items list', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: kBlack54, letterSpacing: 0.5)),
                                  const SizedBox(height: 8),
                                  _buildTableHeader(),
                                  ...items.map((item) => _buildItemTableRow(item)).toList(),

                                  const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Divider(color: kGreyBg, thickness: 1)),

                                  const Text('Valuation summary', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: kBlack54, letterSpacing: 0.5)),
                                  const SizedBox(height: 8),
                                  _buildPriceRow('Subtotal (Net)', subtotalWithoutTax),
                                  if ((data['discount'] ?? 0.0) > 0)
                                    _buildPriceRow(context.tr('discount'), -(data['discount'] ?? 0.0).toDouble(), valueColor: kErrorColor),

                                  // Tax Breakdown
                                  ...taxBreakdown.entries.map((e) => _buildPriceRow(e.key, e.value)).toList(),

                                  const SizedBox(height: 32),
                                ],
                              ),
                            ),
                          ),
                          _buildFixedBottomArea(context, data),
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


  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: kGrey400),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(color: kBlack54, fontSize: 11, fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: kBlack87), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(8)),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('Product', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54))),
          Expanded(flex: 1, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54))),
          Expanded(flex: 2, child: Text('Rate', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54))),
          Expanded(flex: 1, child: Text('Tax %', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54))),
          Expanded(flex: 2, child: Text('Tax amt', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54))),
          Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54))),
        ],
      ),
    );
  }

  Widget _buildItemTableRow(Map<String, dynamic> item) {
    final price = (item['price'] ?? 0).toDouble();
    final quantity = (item['quantity'] ?? 1);
    final itemSubtotal = price * quantity;

    // Try to get tax info from item
    double taxVal = (item['taxAmount'] ?? 0.0).toDouble();
    int taxPerc = ((item['taxPercentage'] ?? 0) as num).toInt();
    String? taxName = item['taxName'] as String?;
    final taxType = item['taxType'] as String?;

    debugPrint('📊 Item: ${item['name']}, taxVal=$taxVal, taxPerc=$taxPerc, taxType=$taxType');

    // Calculate based on taxType if we have percentage but no amount
    if (taxVal == 0 && taxPerc > 0 && taxType != null) {
      if (taxType == 'Price includes Tax') {
        final baseAmount = itemSubtotal / (1 + taxPerc / 100);
        taxVal = itemSubtotal - baseAmount;
      } else if (taxType == 'Price is without Tax') {
        taxVal = itemSubtotal * (taxPerc / 100);
      }
      debugPrint('   ✅ Calculated tax from type: $taxVal');
    }

    final itemTotalWithTax = itemSubtotal + taxVal;

    debugPrint('   Final: taxPerc=$taxPerc, taxVal=$taxVal, total=$itemTotalWithTax');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kGreyBg))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
              flex: 3,
              child: Text(
                  item['name'] ?? 'Item',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: kBlack87),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis
              )
          ),
          Expanded(
              flex: 1,
              child: Text(
                  '${item['quantity']}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w700)
              )
          ),
          Expanded(
              flex: 2,
              child: Text(
                  price.toStringAsFixed(2),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w700)
              )
          ),
          Expanded(
              flex: 1,
              child: Text(
                  taxPerc > 0 ? '$taxPerc%' : '0%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, color: kBlack87, fontWeight: FontWeight.w700)
              )
          ),
          Expanded(
              flex: 2,
              child: Text(
                  taxVal > 0.01 ? taxVal.toStringAsFixed(2) : '0',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10,  color: kBlack87, fontWeight: FontWeight.w700)
              )
          ),
          Expanded(
              flex: 2,
              child: Text(
                  itemTotalWithTax.toStringAsFixed(2),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800,  color: kPrimaryColor)
              )
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double val, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kBlack54)),
          Text('${val.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: valueColor ?? kBlack87)),
        ],
      ),
    );
  }

  Widget _buildFixedBottomArea(BuildContext context, Map<String, dynamic> data) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
            color: kWhite,
            border: const Border(top: BorderSide(color: kGrey200)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))]
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: Net Amount Fixed at Bottom
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Final Total Payable', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: kBlack54)),
                Text('${(data['total'] ?? 0.0).toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kPrimaryColor)),
              ],
            ),
            const SizedBox(height: 12),
            // Row 2: Square Action Buttons (Reordered)
            _buildActionGrid(context, data),
          ],
        ),
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context, Map<String, dynamic> data) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getUserPermissions(),
      builder: (context, permSnap) {
        if (!permSnap.hasData) return const SizedBox.shrink();
        final perms = permSnap.data!;
        final bool isCancelled = data['status'] == 'cancelled';

        List<Widget> actions = [];

        // 1. Receipt
        actions.add(_squareActionButton(Icons.receipt_long_rounded, 'Receipt', kPrimaryColor, () => _printInvoiceReceipt(context, documentId, data)));

        // 2. Edit
        if (!isCancelled && (perms['canEditBill'] || perms['isAdmin'])) {
          actions.add(_squareActionButton(Icons.edit_note_rounded, 'Edit', kPrimaryColor, () async {
            if ((data['editCount'] ?? 0) >= 2) {
              showDialog(context: context, builder: (_) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), title: const Text('Limit Reached'), content: const Text('This bill has been edited 2 times. Please cancel and create a new bill for further changes.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
              return;
            }
            if (await PlanPermissionHelper.canEditBill()) {
              if (context.mounted) Navigator.push(context, CupertinoPageRoute(builder: (_) => EditBillPage(documentId: documentId, invoiceData: data)));
            } else {
              if (context.mounted) PlanPermissionHelper.showUpgradeDialog(context, 'Edit Bill', uid: uid);
            }
          }));
        }

        // 3. Return
        if (!isCancelled && (perms['canSaleReturn'] || perms['isAdmin'])) {
          actions.add(_squareActionButton(Icons.keyboard_return_rounded, 'Return', kPrimaryColor, () => Navigator.push(context, CupertinoPageRoute(builder: (_) => SaleReturnPage(documentId: documentId, invoiceData: data)))));
        }

        // 4. Cancel
        if (!isCancelled && (perms['canCancelBill'] || perms['isAdmin'])) {
          actions.add(_squareActionButton(Icons.cancel_outlined, 'Cancel', kErrorColor, () => _showCancelBillDialog(context, documentId, data)));
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: actions,
        );
      },
    );
  }

  Widget _squareActionButton(IconData icon, String lbl, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 68, height: 68,
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2))
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(lbl, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTag(bool settled, bool cancelled, bool edited, bool returned) {
    // Priority order: cancelled > returned > edited > settled/unsettled
    if (cancelled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: kBlack54.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBlack54.withOpacity(0.2)),
        ),
        child: const Text("Cancelled", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kBlack54)),
      );
    }
    if (returned) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.2)),
        ),
        child: const Text("Returned", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.orange)),
      );
    }
    if (edited) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withOpacity(0.2)),
        ),
        child: const Text("Edited", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.blue)),
      );
    }
    // Default: settled/unsettled status
    final Color statusColor = settled ? kErrorColor : kGoogleGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Text(
        settled ? "Settled" : "Unsettled",
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: statusColor),
      ),
    );
  }
}// Close BillHistoryPage class

// ==========================================
// 4. CUSTOMER RELATED PAGES


// --- Global Theme Constants (Pure White BG, Standard Blue AppBar) ---
const Color kPrimaryColor = Color(0xFF4A5DF9);
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
      backgroundColor: kGreyBg,
      appBar: AppBar(
        title: Text(context.tr('credit_notes'),
            style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kWhite, size: 22),
          onPressed: widget.onBack,
        ),
      ),
      body: Column(
        children: [
          // ENTERPRISE SEARCH & FILTER HEADER
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: const BoxDecoration(
              color: kWhite,
              border: Border(bottom: BorderSide(color: kGrey200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kGrey200),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: kBlack87, fontWeight: FontWeight.w600, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: context.tr('search'),
                        hintStyle: const TextStyle(color: kBlack54, fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: kPrimaryColor, size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 7),
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
                if (!collectionSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));

                return StreamBuilder<QuerySnapshot>(
                  stream: collectionSnapshot.data!.orderBy('timestamp', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));

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

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 10),
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
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: kPrimaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filterStatus,
          dropdownColor: kWhite,
          icon: const Icon(Icons.tune_rounded, color: kPrimaryColor, size: 20),
          items: ['All', 'Available', 'Used'].map((s) => DropdownMenuItem(
              value: s,
              child: Text(s, style: const TextStyle(color: kBlack87,fontWeight: FontWeight.bold, fontSize: 13))
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
    final dateStr = timestamp != null ? DateFormat('dd-MM-yyyy • hh:mm a').format(timestamp.toDate()) : '--';
    final isAvailable = status.toLowerCase() == 'available';

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => _CreditNoteDetailPage(documentId: doc.id, creditNoteData: data))),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(data['creditNoteNumber'] ?? 'CN-N/A', style: const TextStyle(fontWeight: FontWeight.w900, color: kPrimaryColor, fontSize: 13)),
                    Text(dateStr, style: const TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: kGreyBg, shape: BoxShape.circle),
                      child: const Icon(Icons.note_rounded, size: 16, color: kBlack54),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(data['customerName'] ?? 'Guest',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kOrange)),
                    ),
                    Text("${amount.toStringAsFixed(2)}",
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: kPrimaryColor)),
                  ],
                ),
                const Divider(height: 20, color: kGrey100),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("For invoice", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: kBlack54, letterSpacing: 0.5)),
                          Text(data['invoiceNumber'] ?? 'Manual Entry', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: kBlack87))
                        ],
                      ),
                    ),
                    _statusBadge(isAvailable),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(bool available) {
    final Color c = available ? kGoogleGreen : kErrorColor;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: c.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.withOpacity(0.2))),
        child: Text(available ? "Available" : "Used",
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: c)));
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: kGrey300),
          const SizedBox(height: 16),
          Text(context.tr('no_records_found'), style: const TextStyle(color: kBlack54, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ==========================================
// INTERNAL SUB-PAGE: CREDIT NOTE DETAIL
// ==========================================
class _CreditNoteDetailPage extends StatelessWidget {
  final String documentId;
  final Map<String, dynamic> creditNoteData;

  const _CreditNoteDetailPage({required this.documentId, required this.creditNoteData});

  @override
  Widget build(BuildContext context) {
    final amount = (creditNoteData['amount'] ?? 0.0) as num;
    final status = creditNoteData['status'] ?? 'Available';
    final items = (creditNoteData['items'] as List<dynamic>? ?? []);
    final ts = creditNoteData['timestamp'] as Timestamp?;
    final dateStr = ts != null ? DateFormat('dd-MM-yy • hh:mm a').format(ts.toDate()) : 'N/A';
    final bool isAvailable = status.toLowerCase() == 'available';

    return Scaffold(
      backgroundColor: kPrimaryColor,
      appBar: AppBar(
        title: const Text('Credit Note Info', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 22), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  CircleAvatar(backgroundColor: kOrange.withOpacity(0.1), radius: 18, child: const Icon(Icons.person, color: kOrange, size: 18)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(creditNoteData['customerName'] ?? 'Guest', style: const TextStyle(color: kOrange, fontSize: 15, fontWeight: FontWeight.w700)),
                      Text(creditNoteData['customerPhone'] ?? '--', style: const TextStyle(color: kBlack54, fontSize: 11)),
                    ]),
                  ),
                  _buildStatusTag(isAvailable),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(color: kWhite, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Note information', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: kBlack54, letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.receipt_long_rounded, 'Reference ID', creditNoteData['creditNoteNumber'] ?? 'N/A'),
                    _buildDetailRow(Icons.history_rounded, 'Against Invoice', creditNoteData['invoiceNumber'] ?? 'Manual'),
                    _buildDetailRow(Icons.calendar_month_rounded, 'Date Issued', dateStr),
                    _buildDetailRow(Icons.info_outline_rounded, 'Reason', creditNoteData['reason'] ?? 'Not Specified'),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: kGrey100, thickness: 1)),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Total credit value', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: kBlack54)),
                      Text('${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kPrimaryColor)),
                    ]),
                    const SizedBox(height: 24),
                    const Text('Returned items', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: kBlack54, letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    ...items.map((i) => _buildItemTile(i)).toList(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildStatusTag(bool available) {
    final Color c = available ? kGoogleGreen : kErrorColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(available ? "Available" : "Used", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: c)),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [Icon(icon, size: 14, color: kGrey400), const SizedBox(width: 10), Text('$label: ', style: const TextStyle(color: kBlack54, fontSize: 11, fontWeight: FontWeight.w500)), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: kBlack87), overflow: TextOverflow.ellipsis))]));

  Widget _buildItemTile(Map<String, dynamic> i) => Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kGrey100))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(i['name'] ?? 'Item', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kBlack87)), Text("${i['quantity']} ×${(i['price'] ?? 0).toStringAsFixed(0)}", style: const TextStyle(color: kBlack54, fontSize: 11))])), Text("${((i['price'] ?? 0) * (i['quantity'] ?? 1)).toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kBlack87))]));
}

class LedgerEntry {
  final DateTime date; final String type; final String desc; final double debit; final double credit; double balance;
  LedgerEntry({required this.date, required this.type, required this.desc, required this.debit, required this.credit, this.balance = 0});
}

class CustomerLedgerPage extends StatefulWidget {
  final String customerId; final String customerName;
  const CustomerLedgerPage({super.key, required this.customerId, required this.customerName});
  @override State<CustomerLedgerPage> createState() => _CustomerLedgerPageState();
}

class _CustomerLedgerPageState extends State<CustomerLedgerPage> {
  List<LedgerEntry> _entries = []; bool _loading = true;

  @override
  void initState() { super.initState(); _loadLedger(); }

  Future<void> _loadLedger() async {
    final sales = await FirestoreService().getStoreCollection('sales').then((c) => c.where('customerPhone', isEqualTo: widget.customerId).get());
    final credits = await FirestoreService().getStoreCollection('credits').then((c) => c.where('customerId', isEqualTo: widget.customerId).get());
    List<LedgerEntry> entries = [];
    for (var doc in sales.docs) {
      final d = doc.data() as Map<String, dynamic>;
      final date = (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      final total = (d['total'] ?? 0.0).toDouble();
      final mode = d['paymentMode'] ?? 'Unknown';
      entries.add(LedgerEntry(date: date, type: 'INV', desc: "Invoice #${d['invoiceNumber']}", debit: total, credit: 0));
      if (mode == 'Cash' || mode == 'Online') {
        entries.add(LedgerEntry(date: date, type: 'PAY', desc: "Immediate Payment", debit: 0, credit: total));
      } else if (mode == 'Split') {
        final paid = (d['cashReceived'] ?? 0.0).toDouble();
        if (paid > 0) entries.add(LedgerEntry(date: date, type: 'PAY', desc: "Partial Payment", debit: 0, credit: paid));
      }
    }
    for (var doc in credits.docs) {
      final d = doc.data() as Map<String, dynamic>;
      final date = (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      final amt = (d['amount'] ?? 0.0).toDouble();
      final type = d['type'] ?? '';
      final method = d['method'] ?? '';
      if (type == 'payment_received') {
        entries.add(LedgerEntry(date: date, type: 'CR', desc: "Payment (${method.isNotEmpty ? method : 'Cash'})", debit: 0, credit: amt));
      } else if (type == 'add_credit') {
        entries.add(LedgerEntry(date: date, type: 'DR', desc: "Sales Credit Added (${method.isNotEmpty ? method : 'Manual'})", debit: amt, credit: 0));
      }
    }
    entries.sort((a, b) => a.date.compareTo(b.date));
    double running = 0;
    for (var e in entries) {
      running += (e.debit - e.credit);
      e.balance = running;
    }
    if (mounted) setState(() { _entries = entries.reversed.toList(); _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(title: Text("${widget.customerName} Ledger", style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 16)), backgroundColor: kPrimaryColor, centerTitle: true, elevation: 0, iconTheme: const IconThemeData(color: kWhite)),
      body: _loading ? const Center(child: CircularProgressIndicator(color: kPrimaryColor)) : Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          color: kPrimaryColor.withOpacity(0.05),
          child: const Row(children: [
            Expanded(flex: 2, child: Text("Date", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5))),
            Expanded(flex: 3, child: Text("PARTICULARS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5))),
            Expanded(flex: 2, child: Text("Debit", textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kErrorColor))),
            Expanded(flex: 2, child: Text("Credit", textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kGoogleGreen))),
            Expanded(flex: 2, child: Text("Balance", textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kBlack54))),
          ]),
        ),
        Expanded(child: ListView.separated(
          itemCount: _entries.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: kGrey100),
          itemBuilder: (c, i) {
            final e = _entries[i];
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: Row(children: [
                Expanded(flex: 2, child: Text(DateFormat('dd/MM/yy').format(e.date), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kBlack87))),
                Expanded(flex: 3, child: Text(e.desc, style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Expanded(flex: 2, child: Text(e.debit > 0 ? e.debit.toStringAsFixed(0) : "-", textAlign: TextAlign.right, style: const TextStyle(color: kErrorColor, fontSize: 11, fontWeight: FontWeight.w900))),
                Expanded(flex: 2, child: Text(e.credit > 0 ? e.credit.toStringAsFixed(0) : "-", textAlign: TextAlign.right, style: const TextStyle(color: kGoogleGreen, fontSize: 11, fontWeight: FontWeight.w900))),
                Expanded(flex: 2, child: Text(e.balance.toStringAsFixed(0), textAlign: TextAlign.right, style: TextStyle(color: e.balance > 0 ? kErrorColor : kGoogleGreen, fontSize: 12, fontWeight: FontWeight.w900))),
              ]),
            );
          },
        )),
        _buildClosingBar(),
      ]),
    );
  }

  Widget _buildClosingBar() {
    final bal = _entries.isNotEmpty ? _entries.first.balance : 0.0;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        decoration: BoxDecoration(color: kWhite, border: const Border(top: BorderSide(color: kGrey200))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Current Closing Balance:", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: kBlack54)),
          Text("${bal.toStringAsFixed(2)}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: bal > 0 ? kErrorColor : kGoogleGreen)),
        ]),
      ),
    );
  }
}
class CustomerBillsPage extends StatelessWidget {
  final String phone; const CustomerBillsPage({super.key, required this.phone});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(title: const Text("Billing History", style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 16)), backgroundColor: kPrimaryColor, elevation: 0, centerTitle: true, iconTheme: const IconThemeData(color: kWhite)),
      body: FutureBuilder<QuerySnapshot>(
        future: FirestoreService().getStoreCollection('sales').then((c) => c.where('customerPhone', isEqualTo: phone).get()),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("No bills found", style: TextStyle(color: kBlack54,fontWeight: FontWeight.bold)));
          return ListView.separated(
            padding: const EdgeInsets.all(16), itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final date = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
              return Container(
                decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
                child: ListTile(
                  title: Text("Invoice #${data['invoiceNumber']}", style: const TextStyle(fontWeight: FontWeight.w900, color: kPrimaryColor, fontSize: 14)),
                  subtitle: Text(DateFormat('dd-MM-yyyy').format(date), style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w600)),
                  trailing: Text("${data['total']}", style: const TextStyle(fontWeight: FontWeight.w900, color: kBlack87, fontSize: 15)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CustomerCreditsPage extends StatelessWidget {
  final String customerId; const CustomerCreditsPage({super.key, required this.customerId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(title: const Text("Payment Log", style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 16)), backgroundColor: kPrimaryColor, elevation: 0, centerTitle: true, iconTheme: const IconThemeData(color: kWhite)),
      body: FutureBuilder<QuerySnapshot>(
        future: _fetchCredits(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history_rounded, size: 64, color: kGrey300), const SizedBox(height: 16), const Text("No transaction history", style: TextStyle(color: kBlack54,fontWeight: FontWeight.bold))]));
          final docs = snapshot.data!.docs;
          return ListView.separated(
            padding: const EdgeInsets.all(16), itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              bool isPayment = data['type'] == 'payment_received';
              final date = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
              return Container(
                decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: (isPayment ? kGoogleGreen : kErrorColor).withOpacity(0.1), radius: 18, child: Icon(isPayment ? Icons.arrow_downward : Icons.arrow_upward, color: isPayment ? kGoogleGreen : kErrorColor, size: 16)),
                  title: Text(isPayment ? "Payment Received" : "Credit Added", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: kBlack87)),
                  subtitle: Text("${DateFormat('dd-MM-yy • HH:mm').format(date)} • ${data['method'] ?? 'Manual'}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kBlack54)),
                  trailing: Text("${data['amount']}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: isPayment ? kGoogleGreen : kErrorColor)),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<QuerySnapshot> _fetchCredits() async {
    try {
      final collection = await FirestoreService().getStoreCollection('credits');
      return await collection.where('customerId', isEqualTo: customerId).orderBy('timestamp', descending: true).get();
    } catch (e) {
      final collection = await FirestoreService().getStoreCollection('credits');
      return await collection.where('customerId', isEqualTo: customerId).get();
    }
  }
}
class _ReceiveCreditPage extends StatefulWidget {
  final String customerId; final Map<String, dynamic> customerData; final double currentBalance;
  const _ReceiveCreditPage({required this.customerId, required this.customerData, required this.currentBalance});
  @override State<_ReceiveCreditPage> createState() => _ReceiveCreditPageState();
}

class _ReceiveCreditPageState extends State<_ReceiveCreditPage> {
  final TextEditingController _amountController = TextEditingController();
  double _amt = 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: kGreyBg,
        appBar: AppBar(title: const Text("Receive Payment", style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)), backgroundColor: kPrimaryColor, centerTitle: true, elevation: 0, iconTheme: const IconThemeData(color: kWhite)),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.customerData['name'] ?? 'Customer', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kOrange)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text("Credit due", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack54)),
                Text("${widget.currentBalance.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kErrorColor)),
              ]),
            ),
            const SizedBox(height: 32),
            const Text("Enter Amount Received", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: kBlack54, letterSpacing: 0.5)),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => setState(() => _amt = double.tryParse(v) ?? 0.0),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: kPrimaryColor),
              decoration: InputDecoration(prefixText: "", filled: true, fillColor: kWhite, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrey300)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryColor, width: 2))),
            ),
            const Spacer(),
            SafeArea(
              top: false,
              child: SizedBox(width: double.infinity, height: 60, child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  if (_amt <= 0) return;
                  final cCol = await FirestoreService().getStoreCollection('customers');
                  final crCol = await FirestoreService().getStoreCollection('credits');
                  await cCol.doc(widget.customerId).update({'balance': widget.currentBalance - _amt});
                  await crCol.add({'customerId': widget.customerId, 'customerName': widget.customerData['name'], 'amount': _amt, 'type': 'payment_received', 'method': 'Cash', 'timestamp': FieldValue.serverTimestamp()});
                  if (mounted) Navigator.pop(context);
                },
                child: const Text("Save payment", style: TextStyle(color: kWhite, fontSize: 16, fontWeight: FontWeight.w900)),
              )),
            ),
          ],
          ),
        )
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
    final dateString = timestamp != null ? DateFormat('dd-MM-yyyy • h:mm a').format(timestamp.toDate()) : 'N/A';

    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(
        title: const Text('Detail Overview',
            style: TextStyle(color: kWhite,fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: kPrimaryColor,
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
                  _buildIconRow(Icons.receipt_long, "Invoice ID", "#${creditNoteData['invoiceNumber']}", kPrimaryColor),
                  const Divider(height: 32),
                  _buildIconRow(Icons.person, "Customer", creditNoteData['customerName'] ?? 'Guest', kSuccessGreen),
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
        color: kPrimaryColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: kPrimaryColor.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(id, style: const TextStyle(color: Colors.white,fontWeight: FontWeight.bold)),
              _buildStatusPill(status, isInverse: true),
            ],
          ),
          const SizedBox(height: 20),
          const Text("Refund amount", style: TextStyle(color: Colors.white70,fontWeight: FontWeight.bold, fontSize: 11)),
          const SizedBox(height: 4),
          Text("${amount.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 32)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Confirm Refund', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select refund method:', style: TextStyle(color: kMediumBlue)),
              const SizedBox(height: 24),
              _buildDialogOption(onSelect: () => setState(() => mode = "Cash"), mode: "Cash", current: mode, icon: Icons.payments, color: kSuccessGreen),
              const SizedBox(height: 12),
              _buildDialogOption(onSelect: () => setState(() => mode = "Online"), mode: "Online", current: mode, icon: Icons.account_balance, color: kPrimaryColor),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: kErrorRed))),
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
              child: const Text('Confirm'),
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


// --- UI CONSTANTS (Matching Quotations Style) ---
const Color _primaryColor = Color(0xFF2F7CF6);
const Color _successColor = Color(0xFF4CAF50);
const Color _errorColor = Color(0xFFEF4444);
const Color _cardBorder = Color(0xFFE3F2FD);
const Color _bgColor = Colors.white;

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
  bool _isSearching = false;

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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: kGreyBg,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: kPrimaryColor,
          iconTheme: const IconThemeData(color: kWhite),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 22),
            onPressed: widget.onBack,
          ),
          title: _isSearching
              ? TextField(
            controller: _searchController,
            autofocus: true,
            style: const TextStyle(color: kWhite, fontSize: 16),
            decoration: const InputDecoration(
              hintText: "Search name or contact...",
              hintStyle: TextStyle(color: Colors.white70),
              border: InputBorder.none,
            ),
          )
              : const Text(
            'Credit Tracker',
            style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search, size: 22),
              onPressed: () => setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchController.clear();
              }),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: kWhite,
            indicatorWeight: 4,
            labelStyle: TextStyle(fontWeight: FontWeight.w800, color: kWhite, fontSize: 12, letterSpacing: 0.5),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, color: Colors.white70, fontSize: 12),
            tabs: [
              Tab(text: "Sales credit"),
              Tab(text: "Purchase credit"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSalesList(),
            _buildPurchaseList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesList() {
    return FutureBuilder<CollectionReference>(
      future: FirestoreService().getStoreCollection('customers'),
      builder: (context, collectionSnapshot) {
        if (!collectionSnapshot.hasData) return _buildLoading();
        return StreamBuilder<QuerySnapshot>(
          stream: collectionSnapshot.data!.where('balance', isGreaterThan: 0).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return _buildLoading();

            final docs = snapshot.data?.docs ?? [];
            final filtered = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              final name = (data['name'] ?? '').toString().toLowerCase();
              final phone = (data['phone'] ?? '').toString().toLowerCase();
              return name.contains(_searchQuery) || phone.contains(_searchQuery);
            }).toList();

            double totalSalesCredit = 0.0;
            for (var doc in filtered) {
              totalSalesCredit += ((doc.data() as Map<String, dynamic>)['balance'] ?? 0.0) as num;
            }

            if (filtered.isEmpty && _searchQuery.isEmpty) return _buildEmptyState("No outstanding customer dues.");
            if (filtered.isEmpty) return _buildEmptyState("No results found for '$_searchQuery'");

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length + 1,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) return _buildTotalSummary(totalSalesCredit, kGoogleGreen, "Total receivable");
                return _buildSalesCard(filtered[index - 1]);
              },
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
        if (!collectionSnapshot.hasData) return _buildLoading();
        return StreamBuilder<QuerySnapshot>(
          stream: collectionSnapshot.data!.orderBy('timestamp', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return _buildLoading();

            final docs = snapshot.data?.docs ?? [];
            final filtered = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              final supplier = (data['supplierName'] ?? '').toString().toLowerCase();
              final noteNo = (data['creditNoteNumber'] ?? '').toString().toLowerCase();
              return supplier.contains(_searchQuery) || noteNo.contains(_searchQuery);
            }).toList();

            double totalPurchaseCredit = 0.0;
            for (var doc in filtered) {
              final data = doc.data() as Map<String, dynamic>;
              totalPurchaseCredit += ((data['amount'] ?? 0.0) - (data['paidAmount'] ?? 0.0)) as num;
            }

            if (filtered.isEmpty && _searchQuery.isEmpty) return _buildEmptyState("No pending purchase credits.");
            if (filtered.isEmpty) return _buildEmptyState("No results found for '$_searchQuery'");

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length + 1,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) return _buildTotalSummary(totalPurchaseCredit, kErrorColor, "Total payable");
                return _buildPurchaseCard(filtered[index - 1]);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTotalSummary(double amount, Color color, String title) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text('${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kPrimaryColor)),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.account_balance_wallet_rounded, color: color, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final customerName = (data['name'] ?? 'Guest').toString();
    final balance = (data['balance'] ?? 0.0).toDouble();
    final phone = (data['phone'] ?? 'N/A').toString();
    final rating = (data['rating'] ?? 0) as num;

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showCustomerSettlementDialog(doc.id, data, balance),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: kOrange.withOpacity(0.1),
                      radius: 18,
                      child: const Icon(Icons.person, color: kOrange, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kOrange)),
                              ),
                              if (rating > 0) ...[
                                ...List.generate(5, (i) => Icon(
                                  i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                  size: 12,
                                  color: i < rating ? kOrange : kGrey300,
                                )),
                              ],
                            ],
                          ),
                          Text(phone, style: const TextStyle(color: kBlack54, fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: kGrey100)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Balance due', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54, letterSpacing: 0.5)),
                        Text('${balance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kPrimaryColor)),
                      ],
                    ),
                    _statusBadge("Settle", kGoogleGreen),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPurchaseCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final total = (data['amount'] ?? 0.0) as num;
    final paid = (data['paidAmount'] ?? 0.0) as num;
    final remaining = (total - paid).toDouble();
    final supplierName = (data['supplierName'] ?? 'Supplier').toString();
    final noteNumber = (data['creditNoteNumber'] ?? 'N/A').toString();
    final timestamp = data['timestamp'] as Timestamp?;
    final date = timestamp != null ? DateFormat('dd-MM-yyyy').format(timestamp.toDate()) : 'Recent';

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showSettleDialog(doc.id, data, remaining),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$noteNumber', style: const TextStyle(fontWeight: FontWeight.w900, color: kPrimaryColor, fontSize: 12)),
                    Text(date, style: const TextStyle(color: kBlack54, fontSize: 10, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: kGreyBg, shape: BoxShape.circle),
                      child: const Icon(Icons.store_rounded, size: 16, color: kBlack54),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(supplierName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kBlack87), overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: kGrey100)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pending amount', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54, letterSpacing: 0.5)),
                        Text('${remaining.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kPrimaryColor)),
                      ],
                    ),
                    _statusBadge("RECORD", kGoogleGreen),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
    );
  }

  // --- REFINED DIALOGS ---

  void _showSettleDialog(String docId, Map<String, dynamic> data, double remaining) {
    final TextEditingController amountController = TextEditingController();
    String paymentMode = 'Cash';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: kWhite,
          title: const Text('Settle Purchase', style: TextStyle(fontWeight: FontWeight.w800, color: kBlack87, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: kErrorColor.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: kErrorColor.withOpacity(0.15))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Due amount', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kErrorColor, letterSpacing: 0.5)),
                    Text('${remaining.toStringAsFixed(2)}', style: const TextStyle(color: kErrorColor, fontWeight: FontWeight.w900, fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildDialogField(amountController, 'Amount to Pay', Icons.money_rounded),
              const SizedBox(height: 20),
              _buildPayOption(setDialogState, paymentMode, 'Cash', Icons.payments_outlined, kGoogleGreen, (v) => paymentMode = v),
              const SizedBox(height: 8),
              _buildPayOption(setDialogState, paymentMode, 'Online', Icons.account_balance_outlined, kPrimaryColor, (v) => paymentMode = v),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: kBlack54,fontWeight: FontWeight.bold))),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0 || amount > remaining) return;
                Navigator.pop(ctx);
                _performAsyncAction(() => _settlePurchaseCredit(docId, data, amount, paymentMode), "Purchase settled successfully");
              },
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('CONFIRM', style: TextStyle(color: kWhite,fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomerSettlementDialog(String customerId, Map<String, dynamic> customerData, double currentBalance) {
    final TextEditingController amountController = TextEditingController(text: currentBalance.toStringAsFixed(2));
    String paymentMode = 'Cash';
    final customerRating = (customerData['rating'] ?? 0) as num;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: kWhite,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Customer Payment', style: TextStyle(fontWeight: FontWeight.w800, color: kBlack87, fontSize: 18)),
              const SizedBox(height: 8),
              // Customer Rating Display with Edit Option
              Row(
                children: [
                  ...List.generate(5, (i) => GestureDetector(
                    onTap: () {
                      // Show rating edit dialog
                      _showEditRatingDialog(customerId, customerData, i + 1);
                    },
                    child: Icon(
                      i < customerRating ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 20,
                      color: i < customerRating ? kOrange : kGrey300,
                    ),
                  )),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showEditRatingDialog(customerId, customerData, customerRating.toInt()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.edit_rounded, size: 12, color: kPrimaryColor),
                          SizedBox(width: 4),
                          Text('Edit', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kPrimaryColor)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: kGoogleGreen.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: kGoogleGreen.withOpacity(0.15))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total due', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kGoogleGreen, letterSpacing: 0.5)),
                      Text('${currentBalance.toStringAsFixed(2)}', style: const TextStyle(color: kGoogleGreen, fontWeight: FontWeight.w900, fontSize: 16)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildDialogField(amountController, 'Settlement Amount', Icons.currency_rupee_rounded),
                const SizedBox(height: 20),
                _buildPayOption(setDialogState, paymentMode, 'Cash', Icons.payments_outlined, kGoogleGreen, (v) => paymentMode = v),
                const SizedBox(height: 8),
                _buildPayOption(setDialogState, paymentMode, 'Online', Icons.account_balance_outlined, kPrimaryColor, (v) => paymentMode = v),
                const SizedBox(height: 8),
                _buildPayOption(setDialogState, paymentMode, 'Waive Off', Icons.block_outlined, kOrange, (v) => paymentMode = v),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: kBlack54,fontWeight: FontWeight.bold))),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0 || amount > currentBalance) return;
                Navigator.pop(ctx);
                _performAsyncAction(() => _settleCustomerCredit(customerId, customerData, amount, paymentMode, currentBalance), "Payment recorded successfully");
              },
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Settle', style: TextStyle(color: kWhite,fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogField(TextEditingController ctrl, String label, IconData icon) {
    return Container(
      decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        decoration: InputDecoration(
          labelText: label, prefixIcon: Icon(icon, color: kPrimaryColor, size: 18),
          border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  void _showEditRatingDialog(String customerId, Map<String, dynamic> customerData, int currentRating) {
    int selectedRating = currentRating;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            title: const Text(
              'Rate Customer',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: kBlack87,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Customer info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kGreyBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: kPrimaryColor.withOpacity(0.1),
                        radius: 20,
                        child: Text(
                          (customerData['name'] ?? 'C')[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: kPrimaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customerData['name'] ?? 'Customer',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: kBlack87,
                              ),
                            ),
                            Text(
                              customerData['phone'] ?? '',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: kBlack54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 5-star rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          selectedRating = index + 1;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          index < selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 40,
                          color: index < selectedRating ? kOrange : kGrey300,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),

                // Rating text
                Text(
                  selectedRating == 0
                      ? 'No rating'
                      : selectedRating == 1
                      ? 'Poor'
                      : selectedRating == 2
                      ? 'Fair'
                      : selectedRating == 3
                      ? 'Good'
                      : selectedRating == 4
                      ? 'Very Good'
                      : 'Excellent!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selectedRating > 0 ? kPrimaryColor : kBlack54,
                  ),
                ),
              ],
            ),
            actions: [
              // Remove rating button
              if (currentRating > 0)
                TextButton(
                  onPressed: () {
                    _updateCustomerRating(customerId, 0);
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Remove',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: kErrorColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

              // Cancel button
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: kBlack54,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              // Save button
              ElevatedButton(
                onPressed: selectedRating > 0
                    ? () {
                  _updateCustomerRating(customerId, selectedRating);
                  Navigator.pop(context);
                }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  disabledBackgroundColor: kGrey200,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateCustomerRating(String customerId, int rating) async {
    try {
      final customersCollection = await FirestoreService().getStoreCollection('customers');

      if (rating > 0) {
        await customersCollection.doc(customerId).update({
          'rating': rating,
          'ratedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.star_rounded, color: kOrange, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Customer rated $rating star${rating > 1 ? 's' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              backgroundColor: kGoogleGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else {
        // Remove rating
        await customersCollection.doc(customerId).update({
          'rating': FieldValue.delete(),
          'ratedAt': FieldValue.delete(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rating removed', style: TextStyle(fontWeight: FontWeight.w600)),
              backgroundColor: kOrange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating rating: $e'),
            backgroundColor: kErrorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildPayOption(StateSetter setDialogState, String current, String val, IconData icon, Color color, Function(String) onSel) {
    final sel = current == val;
    return InkWell(
      onTap: () => setDialogState(() => onSel(val)),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: sel ? color.withOpacity(0.08) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: sel ? color : kGrey200)),
        child: Row(
          children: [
            Icon(icon, color: sel ? color : kBlack54, size: 18),
            const SizedBox(width: 12),
            Text(val, style: TextStyle(color: sel ? color : kBlack87, fontWeight: sel ? FontWeight.w900 : FontWeight.w600, fontSize: 13)),
            const Spacer(),
            if (sel) Icon(Icons.check_circle_rounded, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  // --- ASYNC HELPERS ---

  Future<void> _performAsyncAction(Future<void> Function() action, String successMsg) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: kPrimaryColor)));
    try {
      await action();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMsg), backgroundColor: kGoogleGreen, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kErrorColor, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    }
  }

  Future<void> _settlePurchaseCredit(String docId, Map<String, dynamic> data, double amount, String mode) async {
    final paid = (data['paidAmount'] ?? 0.0) as num;
    await FirestoreService().updateDocument('purchaseCreditNotes', docId, {
      'paidAmount': paid + amount,
      'lastPaymentDate': FieldValue.serverTimestamp(),
      'lastPaymentMethod': mode,
    });
    await FirestoreService().addDocument('purchasePayments', {
      'creditNoteId': docId, 'creditNoteNumber': data['creditNoteNumber'], 'supplierName': data['supplierName'],
      'amount': amount, 'paymentMode': mode, 'timestamp': FieldValue.serverTimestamp(), 'date': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _settleCustomerCredit(String id, Map<String, dynamic> data, double amt, String mode, double old) async {
    final custs = await FirestoreService().getStoreCollection('customers');
    final creds = await FirestoreService().getStoreCollection('credits');
    await FirebaseFirestore.instance.runTransaction((tx) async {
      tx.update(custs.doc(id), {'balance': old - amt, 'lastUpdated': FieldValue.serverTimestamp()});
    });
    await creds.add({
      'customerId': id, 'customerName': data['name'], 'amount': amt, 'type': 'settlement', 'method': mode, 'timestamp': FieldValue.serverTimestamp(), 'date': DateTime.now().toIso8601String(),
    });
  }

  Widget _buildEmptyState(String msg) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.receipt_long_outlined, size: 60, color: kPrimaryColor.withOpacity(0.1)),
      const SizedBox(height: 16),
      Text(msg, style: const TextStyle(fontWeight: FontWeight.w700, color: kBlack54)),
    ]));
  }

  Widget _buildLoading() => const Center(child: CircularProgressIndicator(color: kPrimaryColor));
}
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
            style: TextStyle(color: kWhite,fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: kPrimaryColor,
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
                      Text(data['creditNoteNumber'] ?? 'N/A', style: const TextStyle(fontSize: 18,fontWeight: FontWeight.bold, color: kPrimaryColor)),
                      _buildStatusPill(data['status'] ?? 'Available'),
                    ],
                  ),
                  const Divider(height: 32),
                  _buildLabelValue("Supplier", data['supplierName'] ?? 'Unknown'),
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
                  _buildSummaryRow("Purchase Liability", "${total.toStringAsFixed(2)}"),
                  _buildSummaryRow("Settled Amount", "${paid.toStringAsFixed(2)}", color: kSuccessGreen),
                  const Divider(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("UNPAID DUE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: kMediumBlue)),
                      Text("${remaining.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: kErrorRed)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            if (remaining > 0)
              _buildLargeButton(context, label: "Record payment", icon: Icons.receipt_long_rounded, color: kPrimaryColor, onPressed: () {}),
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
          Text(label, style: const TextStyle(color: kMediumBlue,fontWeight: FontWeight.bold, fontSize: 14)),
          Text(value, style: TextStyle(color: color ?? kDeepNavy,fontWeight: FontWeight.bold, fontSize: 15)),
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
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))
      ],
    ),
    child: child,
  );
}

Widget _buildSectionTitle(String title) {
  return Padding(padding: const EdgeInsets.only(left: 6, bottom: 12), child: Text(title, style: const TextStyle(fontSize: 12,fontWeight: FontWeight.bold, color: kMediumBlue, letterSpacing: 1)));
}

Widget _buildLabelValue(String label, String value, {CrossAxisAlignment crossAlign = CrossAxisAlignment.start, Color? color}) {
  return Column(crossAxisAlignment: crossAlign, children: [
    Text(label, style: const TextStyle(fontSize: 10,fontWeight: FontWeight.bold, color: kMediumBlue)),
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
    child: Text(status[0].toUpperCase() + status.substring(1).toLowerCase(), style: TextStyle(color: isInverse ? kWhite : c,fontWeight: FontWeight.bold, fontSize: 10)),
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
        Text("${price.toStringAsFixed(0)} × ${qty.toInt()}", style: const TextStyle(fontSize: 12, color: kMediumBlue)),
      ])),
      Text("${total.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kDeepNavy)),
    ]),
  );
}

Widget _buildDetailTotalRow(num amount, int itemCount) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text("Total return ($itemCount)", style: const TextStyle(fontSize: 11,fontWeight: FontWeight.bold, color: kMediumBlue)),
      Text("${amount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 22,fontWeight: FontWeight.bold, color: kPrimaryColor)),
    ]),
  );
}

Widget _buildIconRow(IconData icon, String label, String value, Color iconColor) {
  return Row(children: [
    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 20)),
    const SizedBox(width: 16),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10,fontWeight: FontWeight.bold, color: kMediumBlue)),
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
      label: Text(label, style: const TextStyle(color: kWhite,fontWeight: FontWeight.bold, fontSize: 16)),
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
// 1. CUSTOMEMANAGEMENT PAGE
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
  String _sortBy = 'sales'; // 'sales' or 'credit'

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


  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sort Customers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kBlack87)),
              const SizedBox(height: 20),
              _buildSortOption('Sort by Sales', 'sales', Icons.trending_up_rounded),
              _buildSortOption('Sort by Credit', 'credit', Icons.account_balance_wallet_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortOption(String label, String value, IconData icon) {
    bool isSelected = _sortBy == value;
    return ListTile(
      onTap: () {
        setState(() => _sortBy = value);
        Navigator.pop(context);
      },
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor.withOpacity(0.1) : kGreyBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: isSelected ? kPrimaryColor : kBlack54, size: 22),
      ),
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? kPrimaryColor : kBlack87)),
      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: kPrimaryColor, size: 20) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        title: Text(context.tr('customer_management'),
            style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kWhite, size: 22),
          onPressed: widget.onBack,
        ),
      ),
      body: Column(
        children: [
          // Updated Search Header Area with Sort Button
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: const BoxDecoration(
              color: kWhite,
              border: Border(bottom: BorderSide(color: kGrey200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kGrey200),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: kBlack87, fontWeight: FontWeight.w600, fontSize: 14),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, color: kPrimaryColor, size: 20),
                        hintText: context.tr('search'),
                        hintStyle: const TextStyle(color: kBlack54, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 7),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // New Sort Button UI
                InkWell(
                  onTap: _showSortMenu,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kGrey200),
                    ),
                    child: const Icon(Icons.sort_rounded, color: kPrimaryColor, size: 22),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => AddCustomerPage(
                          uid: widget.uid,
                          onBack: null,
                        ),
                      ),
                    ).then((value) {
                      if (value == true) {
                        setState(() {}); // Refresh the list
                      }
                    });
                  },
                  child: Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      color: kPrimaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded, color: kWhite, size: 22),
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
                if (!streamSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                return StreamBuilder<QuerySnapshot>(
                  stream: streamSnapshot.data,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildManagerNoDataState(context.tr('no_customers_found'));

                    final docs = snapshot.data!.docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final name = (data['name'] ?? '').toString().toLowerCase();
                      final phone = (data['phone'] ?? '').toString().toLowerCase();
                      return name.contains(_searchQuery) || phone.contains(_searchQuery);
                    }).toList();

                    // Sort docs based on selected sort option
                    docs.sort((a, b) {
                      final dataA = a.data() as Map<String, dynamic>;
                      final dataB = b.data() as Map<String, dynamic>;
                      if (_sortBy == 'sales') {
                        final salesA = (dataA['totalSales'] ?? 0).toDouble();
                        final salesB = (dataB['totalSales'] ?? 0).toDouble();
                        return salesB.compareTo(salesA); // Descending
                      } else {
                        final creditA = (dataA['balance'] ?? 0).toDouble();
                        final creditB = (dataB['balance'] ?? 0).toDouble();
                        return creditB.compareTo(creditA); // Descending
                      }
                    });

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
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
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Use push with MaterialPageRoute instead of CupertinoPageRoute for better performance
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CustomerDetailsPage(
                  customerId: docId,
                  customerData: data,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: kPrimaryColor.withOpacity(0.08),
                      radius: 20,
                      child: Text((data['name'] ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900, fontSize: 16)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['name'] ?? 'Unknown',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kOrange)),
                          Text(data['phone'] ?? '--',
                              style: const TextStyle(color: kBlack54, fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: kGrey400, size: 20),
                  ],
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: kGrey100)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildManagerStatItem("Total sales", "${(data['totalSales'] ?? 0).toStringAsFixed(0)}", kPrimaryColor),
                    _buildManagerStatItem("Credit due", "${(data['balance'] ?? 0).toStringAsFixed(0)}", kErrorRed, align: CrossAxisAlignment.end),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildManagerStatItem(String label, String value, Color color, {CrossAxisAlignment align = CrossAxisAlignment.start}) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text("$value", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: color)),
      ],
    );
  }

  Widget _buildManagerNoDataState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded, size: 64, color: kGrey300),
          const SizedBox(height: 16),
          Text(msg, style: const TextStyle(color: kBlack54, fontWeight: FontWeight.w600)),
        ],
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
        backgroundColor: kPrimaryColor,
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
                      backgroundColor: kPrimaryColor,
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
                if (!storeIdSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').where('storeId', isEqualTo: storeIdSnapshot.data).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                    if (snapshot.data!.docs.isEmpty) return _buildManagerNoDataState("No staff memberegistered");

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
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kSoftAzure, width: 1.5),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: kPrimaryColor.withOpacity(0.1),
                              child: Text((data['name'] ?? 'S')[0].toUpperCase(),
                                  style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900)),
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
        backgroundColor: kPrimaryColor,
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
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kSoftAzure),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRole,
                    isExpanded: true,
                    dropdownColor: kWhite,
                    icon: const Icon(Icons.expand_more, color: kPrimaryColor),
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
                    backgroundColor: kPrimaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kSoftAzure)
      ),
      child: TextFormField(
        controller: ctrl,
        obscureText: isObscure,
        style: const TextStyle(fontWeight: FontWeight.w700, color: kDeepNavy),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: kPrimaryColor, size: 22),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kSoftAzure)
    ),
    child: TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(fontWeight: FontWeight.w700, color: kDeepNavy),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: kPrimaryColor, size: 20),
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
  Map<int, int> returnQuantities = {};
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

  double get totalReturnTax {
    double totalTax = 0;
    final items = widget.invoiceData['items'] as List<dynamic>? ?? [];
    returnQuantities.forEach((index, qty) {
      if (index < items.length) {
        final item = items[index];
        final price = (item['price'] ?? 0).toDouble();
        final taxPercentage = (item['taxPercentage'] ?? 0).toDouble();
        final taxType = item['taxType'] as String?;
        if (taxPercentage > 0) {
          final itemTotal = price * qty;
          if (taxType == 'Price includes Tax') {
            final taxRate = taxPercentage / 100;
            totalTax += itemTotal - (itemTotal / (1 + taxRate));
          } else if (taxType == 'Price is without Tax') {
            totalTax += itemTotal * (taxPercentage / 100);
          }
        }
      }
    });
    return totalTax;
  }

  double get totalReturnWithTax => totalReturnAmount + totalReturnTax;

  @override
  Widget build(BuildContext context) {
    final items = widget.invoiceData['items'] as List<dynamic>? ?? [];
    final timestamp = widget.invoiceData['timestamp'] != null ? (widget.invoiceData['timestamp'] as Timestamp).toDate() : DateTime.now();

    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        title: Text(context.tr('sale_return'), style: const TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.0)),
        backgroundColor: kPrimaryColor, centerTitle: true, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: kWhite, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          // Header Card
          Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(color: kWhite, border: Border(bottom: BorderSide(color: kGrey200))),
            child: Row(
              children: [
                CircleAvatar(backgroundColor: kOrange.withOpacity(0.1), radius: 18, child: const Icon(Icons.person_rounded, color: kOrange, size: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.invoiceData['customerName'] ?? 'Walk-in Customer', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: kBlack87)),
                    Text("Invoice-${widget.invoiceData['invoiceNumber']} • ${DateFormat('dd-MM-yyyy').format(timestamp)}", style: const TextStyle(color: kBlack54, fontSize: 10, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 10),
              itemBuilder: (ctx, index) {
                final item = items[index];
                final name = item['name'] ?? 'Item';
                final maxQty = (item['quantity'] ?? 0) is int ? item['quantity'] : int.tryParse(item['quantity'].toString()) ?? 0;
                final price = (item['price'] ?? 0).toDouble();
                final taxPercentage = (item['taxPercentage'] ?? 0).toDouble();
                final currentReturnQty = returnQuantities[index] ?? 0;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: kGrey200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))]),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kBlack87)),
                            const SizedBox(height: 4),
                            Row(children: [
                              Text('Rate: Rs ${price.toStringAsFixed(0)}', style: const TextStyle(color: kBlack54, fontSize: 11, fontWeight: FontWeight.w600)),
                              if (taxPercentage > 0) ...[
                                const SizedBox(width: 6),
                                Text('($taxPercentage% TAX)', style: const TextStyle(color: kOrange, fontSize: 10, fontWeight: FontWeight.w800)),
                              ]
                            ]),
                          ])),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(8)), child: Text("Available: $maxQty", style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900, fontSize: 10))),
                        ],
                      ),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: kGrey100)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Quantity to return", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kBlack54)),
                          Row(
                            children: [
                              _qtyBtn(Icons.remove_rounded, currentReturnQty > 0 ? () => setState(() {
                                returnQuantities[index] = currentReturnQty - 1;
                                if (returnQuantities[index]! <= 0) returnQuantities.remove(index);
                              }) : null),
                              Container(width: 50, alignment: Alignment.center, child: Text("$currentReturnQty", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kBlack87))),
                              _qtyBtn(Icons.add_rounded, currentReturnQty < maxQty ? () => setState(() => returnQuantities[index] = currentReturnQty + 1) : null),
                            ],
                          ),
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
          ),

          _buildReturnSummaryPanel(),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: onTap == null ? kGrey100 : kPrimaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 18, color: onTap == null ? kGrey400 : kPrimaryColor)),
    );
  }

  Widget _buildReturnSummaryPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(color: kWhite, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -5))], border: const Border(top: BorderSide(color: kGrey200))),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _rowItem('Refund Amount', totalReturnAmount.toStringAsFixed(2)),
            if (totalReturnTax > 0) _rowItem('Tax Reversal', totalReturnTax.toStringAsFixed(2), color: kOrange),
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: kGrey100)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total refund', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: kBlack54, letterSpacing: 0.5)),
                Text('Rs ${totalReturnWithTax.toStringAsFixed(2)}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kPrimaryColor)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _modeBtn('CreditNote', 'Credit note')),
                const SizedBox(width: 12),
                Expanded(child: _modeBtn('Cash', 'CASH REFUND')),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: returnQuantities.isEmpty ? null : _processSaleReturn,
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                child: const Text('Process return', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, color: kWhite, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowItem(String l, String v, {Color? color}) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: kBlack54, fontSize: 13, fontWeight: FontWeight.w600)), Text('Rs $v', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color ?? kBlack87))]));

  Widget _modeBtn(String val, String lbl) {
    bool sel = returnMode == val;
    return GestureDetector(
      onTap: () => setState(() => returnMode = val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: sel ? kPrimaryColor : kWhite, borderRadius: BorderRadius.circular(10), border: Border.all(color: sel ? kPrimaryColor : kGrey200, width: 1.5)),
        child: Center(child: Text(lbl, style: TextStyle(color: sel ? kWhite : kBlack54, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5))),
      ),
    );
  }

  Future<void> _processSaleReturn() async {
    try {
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));

      final items = widget.invoiceData['items'] as List<dynamic>? ?? [];
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
                final currentStock = (productDoc.data() as Map<String, dynamic>?)?['currentStock'] ?? 0.0;
                transaction.update(productRef, {'currentStock': currentStock.toDouble() + returnQty});
              }
            });
          }
        }
      }

      if (returnMode == 'CreditNote' && widget.invoiceData['customerPhone'] != null) {
        final creditNoteNumber = await NumberGeneratorService.generateCreditNoteNumber();
        final creditNotesCollection = await FirestoreService().getStoreCollection('creditNotes');
        await creditNotesCollection.add({
          'creditNoteNumber': creditNoteNumber,
          'invoiceNumber': widget.invoiceData['invoiceNumber'],
          'customerPhone': widget.invoiceData['customerPhone'],
          'customerName': widget.invoiceData['customerName'] ?? 'Unknown',
          'amount': totalReturnWithTax,
          'subtotal': totalReturnAmount,
          'totalTax': totalReturnTax,
          'items': returnQuantities.entries.map((entry) {
            final item = items[entry.key];
            return {
              'name': item['name'], 'quantity': entry.value, 'price': item['price'],
              'total': (item['price'] ?? 0) * entry.value, 'taxAmount': (totalReturnTax / totalReturnAmount) * ((item['price'] ?? 0) * entry.value),
            };
          }).toList(),
          'timestamp': FieldValue.serverTimestamp(), 'status': 'Available', 'reason': 'Sale Return',
        });
      }

      final salesCollection = await FirestoreService().getStoreCollection('sales');
      List<Map<String, dynamic>> updatedItems = [];
      for (int i = 0; i < items.length; i++) {
        final item = Map<String, dynamic>.from(items[i]);
        final originalQty = (item['quantity'] ?? 0) is int ? (item['quantity'] as int) : int.parse(item['quantity'].toString());
        final returnedQty = returnQuantities[i] ?? 0;
        final newQty = originalQty - returnedQty;
        if (newQty > 0) { item['quantity'] = newQty; updatedItems.add(item); }
      }

      await salesCollection.doc(widget.documentId).update({
        'items': updatedItems,
        'total': (widget.invoiceData['total'] ?? 0.0) - totalReturnWithTax,
        'hasReturns': true,
        'returnAmount': (widget.invoiceData['returnAmount'] ?? 0.0) + totalReturnWithTax,
        'lastReturnAt': FieldValue.serverTimestamp(),
        'status': 'returned', // Mark as returned
      });

      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(returnMode == 'CreditNote' ? 'Credit note created successfully' : 'Return processed successfully'), backgroundColor: kGoogleGreen));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kErrorColor)); }
    }
  }
}

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
  // --- Standardized Color Palette ---
  static const Color kHeaderColor = kPrimaryColor;
  static const Color kCardBg = kWhite;
  static const Color kAccentOrange = kOrange;

  late TextEditingController _discountController;
  late String _selectedPaymentMode;
  late String? _selectedCustomerPhone;
  late String? _selectedCustomerName;
  late List<Map<String, dynamic>> _items;
  List<Map<String, dynamic>> _selectedCreditNotes = [];
  double _creditNotesAmount = 0.0;
  bool _isSaving = false;

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
  double get subtotal => _items.fold(0.0, (sum, item) {
    final price = (item['price'] ?? 0).toDouble();
    final qty = (item['quantity'] ?? 0) is int
        ? (item['quantity'] as int).toDouble()
        : double.tryParse(item['quantity'].toString()) ?? 0.0;
    return sum + (price * qty);
  });

  // Calculate total tax from all items
  double get totalTax => _items.fold(0.0, (sum, item) {
    final price = (item['price'] ?? 0).toDouble();
    final qty = (item['quantity'] ?? 0) is int
        ? (item['quantity'] as int).toDouble()
        : double.tryParse(item['quantity'].toString()) ?? 0.0;
    final taxPercentage = (item['taxPercentage'] ?? 0).toDouble();
    final taxType = item['taxType'] as String?;

    if (taxPercentage == 0) return sum;

    final itemTotal = price * qty;
    if (taxType == 'Price includes Tax') {
      // Tax is already included in price, extract it
      final taxRate = taxPercentage / 100;
      return sum + (itemTotal - (itemTotal / (1 + taxRate)));
    } else if (taxType == 'Price is without Tax') {
      // Tax needs to be added to price
      return sum + (itemTotal * (taxPercentage / 100));
    } else {
      // Zero Rated Tax or Exempt Tax
      return sum;
    }
  });

  // Get taxes grouped by name for display
  Map<String, double> get taxBreakdown {
    final Map<String, double> taxMap = {};
    for (var item in _items) {
      final price = (item['price'] ?? 0).toDouble();
      final qty = (item['quantity'] ?? 0) is int
          ? (item['quantity'] as int).toDouble()
          : double.tryParse(item['quantity'].toString()) ?? 0.0;
      final taxPercentage = (item['taxPercentage'] ?? 0).toDouble();
      final taxType = item['taxType'] as String?;
      final taxName = item['taxName'] as String?;

      if (taxPercentage == 0 || taxName == null) continue;

      final itemTotal = price * qty;
      double taxAmount = 0;

      if (taxType == 'Price includes Tax') {
        final taxRate = taxPercentage / 100;
        taxAmount = itemTotal - (itemTotal / (1 + taxRate));
      } else if (taxType == 'Price is without Tax') {
        taxAmount = itemTotal * (taxPercentage / 100);
      }

      if (taxAmount > 0) {
        taxMap[taxName] = (taxMap[taxName] ?? 0) + taxAmount;
      }
    }
    return taxMap;
  }

  double get discount => double.tryParse(_discountController.text) ?? 0;
  double get totalBeforeCreditNotes => subtotal + totalTax - discount;
  double get finalTotal => (totalBeforeCreditNotes - _creditNotesAmount).clamp(0, double.infinity);

  @override
  Widget build(BuildContext context) {
    final DateTime time = widget.invoiceData['timestamp'] != null
        ? (widget.invoiceData['timestamp'] as Timestamp).toDate()
        : DateTime.now();

    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        title: Text(
          context.tr('edit_bill'),
          style: const TextStyle(fontWeight: FontWeight.w900, color: kWhite, fontSize: 15, letterSpacing: 1.0),
        ),
        backgroundColor: kHeaderColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: kWhite, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Fixed Header Bar (Invoice Num & Date)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: kWhite,
              border: Border(bottom: BorderSide(color: kGrey200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Reference invoice", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5)),
                    Text("Invoice-${widget.invoiceData['invoiceNumber'] ?? 'N/A'}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: kHeaderColor)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Date issued", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5)),
                    Text(DateFormat('dd-MM-yyyy').format(time), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kBlack87)),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel('Assigned customer'),
                  _buildCustomerCard(),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionLabel('BILLING ITEMS'),
                      GestureDetector(
                        onTap: _showAddProductDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: kHeaderColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Row(
                            children: [
                              Icon(Icons.add_circle_outline_rounded, size: 14, color: kHeaderColor),
                              SizedBox(width: 6),
                              Text('ADD ITEM', style: TextStyle(color: kHeaderColor, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  _buildItemsList(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          _buildSummaryPanel(),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildCustomerCard() {
    final hasCustomer = _selectedCustomerPhone != null;
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hasCustomer ? kHeaderColor.withOpacity(0.3) : kOrange),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            CommonWidgets.showCustomerSelectionDialog(
              context: context,
              selectedCustomerPhone: _selectedCustomerPhone,
              onCustomerSelected: (phone, name, gst) {
                setState(() {
                  _selectedCustomerPhone = phone.isEmpty ? null : phone;
                  _selectedCustomerName = name.isEmpty ? null : name;
                  // If customer changes, credit notes may no longer be applicable
                  _selectedCreditNotes = [];
                  _creditNotesAmount = 0;
                });
              },
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: hasCustomer ? kHeaderColor : kGreyBg,
                  radius: 20,
                  child: Icon(Icons.person_rounded, color: hasCustomer ? kWhite : kOrange, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedCustomerName ?? 'Guest',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: kBlack87),
                      ),
                      Text(
                        hasCustomer ? _selectedCustomerPhone! : 'Tap to assign customer',
                        style: TextStyle(
                          color: hasCustomer ? Colors.black : kHeaderColor,
                          fontSize: 11,
                          fontWeight: hasCustomer ? FontWeight.w600 : FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasCustomer)
                  IconButton(
                    onPressed: () => setState(() {
                      _selectedCustomerPhone = null;
                      _selectedCustomerName = null;
                      _selectedCreditNotes = [];
                      _creditNotesAmount = 0;
                    }),
                    icon: const Icon(Icons.cancel_rounded, color: kErrorColor, size: 22),
                  )
                else
                  const Icon(Icons.arrow_forward_ios_rounded, color: kOrange, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    if (_items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: kGrey200)),
        child: const Column(
          children: [
            Icon(Icons.shopping_basket_outlined, color: kGrey300, size: 40),
            SizedBox(height: 12),
            Text('No items in this invoice', style: TextStyle(color: kBlack54, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _items[index];
        final double rate = (item['price'] ?? 0).toDouble();
        final double qty = (item['quantity'] ?? 0) is int ? (item['quantity'] as int).toDouble() : double.parse(item['quantity'].toString());

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kGrey200),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(8)),
                child: Text('${qty.toInt()}x', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: kHeaderColor)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kBlack87), maxLines: 2, overflow: TextOverflow.ellipsis),
                    Row(
                      children: [
                        Text('@ ${rate.toStringAsFixed(0)}', style: const TextStyle(color: kOrange, fontSize: 11, fontWeight: FontWeight.w600)),
                        if (item['taxName'] != null && (item['taxPercentage'] ?? 0) > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: kPrimaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${item['taxName']} ${(item['taxPercentage'] as num).toInt()}%',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kPrimaryColor),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(rate * qty).toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kHeaderColor),
                  ),
                  if (item['taxName'] != null && (item['taxPercentage'] ?? 0) > 0) ...[
                    Builder(builder: (context) {
                      final taxPercentage = (item['taxPercentage'] ?? 0).toDouble();
                      final taxType = item['taxType'] as String?;
                      final itemTotal = rate * qty;
                      double taxAmount = 0;
                      if (taxType == 'Price includes Tax') {
                        final taxRate = taxPercentage / 100;
                        taxAmount = itemTotal - (itemTotal / (1 + taxRate));
                      } else if (taxType == 'Price is without Tax') {
                        taxAmount = itemTotal * (taxPercentage / 100);
                      }
                      return Text(
                        '+${taxAmount.toStringAsFixed(1)} tax',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: kBlack54),
                      );
                    }),
                  ],
                ],
              ),
              const SizedBox(width: 12),
              // Changed Delete button to Edit button that opens the same popup as Bill Summary
              GestureDetector(
                onTap: () => _showEditItemDialog(index),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: kHeaderColor.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.edit, color: kHeaderColor, size: 22),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: kWhite,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -5))],
        border: const Border(top: BorderSide(color: kGrey200)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSummaryRow('Subtotal (Gross)', subtotal.toStringAsFixed(2)),
            // Display tax breakdown
            ...taxBreakdown.entries.map((entry) => _buildSummaryRow(
              '${entry.key}',
              '+ ${entry.value.toStringAsFixed(2)}',
              color: kBlack54,
            )).toList(),
            if (totalTax > 0)
              _buildSummaryRow('Total Tax', '+ ${totalTax.toStringAsFixed(2)}', color: kOrange),
            _buildSummaryRow(
                'Applied Discount',
                '- ${discount.toStringAsFixed(2)}',
                color: kGoogleGreen,
                isClickable: true,
                onTap: _showDiscountDialog
            ),
            if (_selectedCustomerPhone != null)
              _buildSummaryRow(
                  _selectedCreditNotes.isEmpty ? 'Apply Credit Note' : 'Applied Credit',
                  '- ${_creditNotesAmount.toStringAsFixed(2)}',
                  color: kAccentOrange,
                  isClickable: true,
                  onTap: _showCreditNotesDialog
              ),

            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: kGrey100)),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total net payable', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: kBlack54, letterSpacing: 0.5)),
                Text('${finalTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kHeaderColor)),
              ],
            ),
            const SizedBox(height: 16),
            _buildPaymentModeSelector(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _updateBill,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kHeaderColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: kWhite)
                    : const Text('Confirm updates', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, color: kWhite, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? color, bool isClickable = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Text(label, style: const TextStyle(color: kBlack54, fontSize: 13, fontWeight: FontWeight.w600)),
              if (isClickable) Padding(padding: const EdgeInsets.only(left: 6), child: Icon(Icons.edit_note_rounded, size: 16, color: color ?? kHeaderColor)),
            ]),
            Text('$value', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color ?? kBlack87)),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentModeSelector() {
    final modes = ['Cash', 'Online', 'Credit', 'Split'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: modes.map((mode) {
        final isSelected = _selectedPaymentMode == mode;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedPaymentMode = mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? kHeaderColor : kWhite,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isSelected ? kHeaderColor : kGrey200, width: 1.5),
              ),
              child: Center(
                child: Text(mode[0].toUpperCase() + mode.substring(1).toLowerCase(), style: TextStyle(
                    color: isSelected ? kWhite : kBlack54,
                    fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5
                )),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- Dialogs (Functionality Optimized) ---

  // Restoration of Edit Item Dialog logic matching Bill Summary page
  void _showEditItemDialog(int idx) async {
    final item = _items[idx];
    final nameController = TextEditingController(text: item['name']);
    final priceController = TextEditingController(text: item['price'].toString());
    final qtyController = TextEditingController(text: item['quantity'].toString());

    // Fetch available taxes
    List<Map<String, dynamic>> availableTaxes = [];
    try {
      final taxesSnapshot = await FirestoreService().getStoreCollection('taxes').then((col) => col.get());
      availableTaxes = taxesSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Tax',
          'percentage': (data['percentage'] ?? 0).toDouble(),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching taxes: $e');
    }

    // Current tax selection - find matching tax by name and percentage
    String? selectedTaxId;
    if (item['taxName'] != null && item['taxPercentage'] != null) {
      try {
        final matchingTax = availableTaxes.firstWhere(
              (tax) {
            final nameMatch = tax['name'] == item['taxName'];
            final taxPercentage = (tax['percentage'] as num).toDouble();
            final itemPercentage = (item['taxPercentage'] as num).toDouble();
            final percentageMatch = (taxPercentage - itemPercentage).abs() < 0.01;
            return nameMatch && percentageMatch;
          },
        );
        selectedTaxId = matchingTax['id'] as String?;
      } catch (e) {
        selectedTaxId = null;
      }
    }

    // Tax type
    String selectedTaxType = item['taxType'] ?? 'Price is without Tax';
    final taxTypes = ['Price includes Tax', 'Price is without Tax', 'Zero Rated Tax', 'Exempt Tax'];

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: kWhite,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Edit Billing Item', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: kBlack87)),
                        GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close_rounded, color: kBlack54, size: 24)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildDialogLabel('Product Name'),
                    _buildDialogInput(nameController, 'Enter product name', setDialogState),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDialogLabel('Price'),
                              _buildDialogInput(priceController, '0.00', setDialogState, isNumber: true),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDialogLabel('Quantity'),
                              Container(
                                height: 48,
                                decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
                                child: Row(
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        int current = int.tryParse(qtyController.text) ?? 1;
                                        if (current > 1) {
                                          setDialogState(() => qtyController.text = (current - 1).toString());
                                        } else {
                                          Navigator.of(context).pop();
                                          setState(() => _items.removeAt(idx));
                                        }
                                      },
                                      icon: Icon(
                                        (int.tryParse(qtyController.text) ?? 1) <= 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
                                        color: (int.tryParse(qtyController.text) ?? 1) <= 1 ? kErrorColor : kHeaderColor,
                                        size: 20,
                                      ),
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: qtyController,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        onChanged: (v) => setDialogState(() {}),
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kBlack87),
                                        decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        int current = int.tryParse(qtyController.text) ?? 0;
                                        setDialogState(() => qtyController.text = (current + 1).toString());
                                      },
                                      icon: const Icon(Icons.add_rounded, color: kHeaderColor, size: 20),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Tax Options - Show different UI based on whether tax is present
                    if (selectedTaxId != null) ...[
                      // Product has tax - Show option to deselect
                      _buildDialogLabel('Tax Applied'),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kGreyBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kGrey200),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    availableTaxes.firstWhere(
                                          (tax) => tax['id'] == selectedTaxId,
                                      orElse: () => {'name': 'Tax', 'percentage': 0},
                                    )['name'] ?? 'Tax',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kBlack87),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${availableTaxes.firstWhere(
                                          (tax) => tax['id'] == selectedTaxId,
                                      orElse: () => {'name': 'Tax', 'percentage': 0},
                                    )['percentage']}%',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kBlack54),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                setDialogState(() => selectedTaxId = null);
                              },
                              icon: const Icon(Icons.close, size: 16, color: kErrorColor),
                              label: const Text('Remove Tax', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kErrorColor)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDialogLabel('Tax Type'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: kGreyBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kGrey200),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedTaxType,
                            isExpanded: true,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kBlack87),
                            items: taxTypes.map((type) {
                              return DropdownMenuItem<String>(
                                value: type,
                                child: Text(type),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() => selectedTaxType = value);
                              }
                            },
                          ),
                        ),
                      ),
                    ] else ...[
                      // Product has no tax - Show option to add tax
                      _buildDialogLabel('Tax'),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kGreyBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kGrey200),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'No tax applied',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kBlack54),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                // Show tax selection dialog
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: const Text('Select Tax', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: availableTaxes.map((tax) {
                                        return ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(tax['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                                          subtitle: Text('${tax['percentage']}%', style: const TextStyle(fontSize: 12)),
                                          onTap: () {
                                            setDialogState(() {
                                              selectedTaxId = tax['id'];
                                              selectedTaxType = 'Price is without Tax';
                                            });
                                            Navigator.pop(ctx);
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add_circle_outline, size: 16, color: kPrimaryColor),
                              label: const Text('Add Tax', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kPrimaryColor)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              setState(() => _items.removeAt(idx));
                            },
                            icon: const Icon(Icons.delete_outline_rounded, size: 18),
                            label: const Text('Remove'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kErrorColor,
                              side: const BorderSide(color: kErrorColor),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final newName = nameController.text.trim();
                              final newPrice = double.tryParse(priceController.text.trim()) ?? item['price'];
                              final newQty = int.tryParse(qtyController.text.trim()) ?? 1;

                              // Get tax details
                              String? taxName;
                              double? taxPercentage;
                              String? taxType;
                              double taxAmount = 0.0;

                              if (selectedTaxId != null) {
                                final selectedTax = availableTaxes.firstWhere(
                                      (tax) => tax['id'] == selectedTaxId,
                                  orElse: () => {},
                                );
                                taxName = selectedTax['name'];
                                taxPercentage = selectedTax['percentage'];
                                taxType = selectedTaxType;

                                // Recalculate tax amount based on new price and quantity
                                if (taxPercentage != null && taxPercentage > 0) {
                                  final itemTotal = newPrice * newQty;
                                  if (taxType == 'Price includes Tax') {
                                    final taxRate = taxPercentage / 100;
                                    taxAmount = itemTotal - (itemTotal / (1 + taxRate));
                                  } else if (taxType == 'Price is without Tax') {
                                    taxAmount = itemTotal * (taxPercentage / 100);
                                  }
                                }
                              }

                              setState(() {
                                _items[idx]['name'] = newName;
                                _items[idx]['price'] = newPrice;
                                _items[idx]['quantity'] = newQty;
                                _items[idx]['taxName'] = taxName;
                                _items[idx]['taxPercentage'] = taxPercentage ?? 0;
                                _items[idx]['taxType'] = taxType;
                                _items[idx]['taxAmount'] = taxAmount;
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: kHeaderColor, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                            child: const Text('Save', style: TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildDialogLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: kBlack54, letterSpacing: 0.5)),
    );
  }

  Widget _buildDialogInput(TextEditingController controller, String hint, StateSetter setDialogState, {bool isNumber = false}) {
    return Container(
      decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        onChanged: (v) => setDialogState(() {}),
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kBlack87),
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  void _showDiscountDialog() {
    final TextEditingController controller = TextEditingController(text: _discountController.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Apply discount', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
        content: Container(
          decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            style: const TextStyle(fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              prefixText: 'Rs ',
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, color: kBlack54))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kHeaderColor),
              onPressed: () {
                setState(() => _discountController.text = controller.text);
                Navigator.pop(context);
              },
              child: const Text('Apply', style: TextStyle(color: kWhite, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  void _showCreditNotesDialog() async {
    if (_selectedCustomerPhone == null) return;

    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final creditNotesCollection = await FirestoreService().getStoreCollection('creditNotes');
      final snapshot = await creditNotesCollection
          .where('customerPhone', isEqualTo: _selectedCustomerPhone)
          .where('status', isEqualTo: 'Available')
          .get();

      Navigator.pop(context); // Close loading

      final availableCreditNotes = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();

      if (!mounted) return;
      if (availableCreditNotes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No available credit notes for this customer')));
        return;
      }

      showDialog(
        context: context,
        builder: (ctx) {
          List<Map<String, dynamic>> tempSelected = List.from(_selectedCreditNotes);
          return StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              backgroundColor: kWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Select credit notes', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableCreditNotes.length,
                  itemBuilder: (context, index) {
                    final cn = availableCreditNotes[index];
                    final isSelected = tempSelected.any((s) => s['id'] == cn['id']);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? kHeaderColor : kGrey200)),
                      child: CheckboxListTile(
                        activeColor: kHeaderColor,
                        value: isSelected,
                        title: Text(cn['creditNoteNumber'] ?? 'CN-N/A', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        subtitle: Text('Balance: ${((cn['amount'] ?? 0) as num).toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        onChanged: (val) => setDialogState(() {
                          if (val == true) tempSelected.add(cn);
                          else tempSelected.removeWhere((s) => s['id'] == cn['id']);
                        }),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, color: kBlack54))),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: kHeaderColor),
                    onPressed: () {
                      setState(() {
                        _selectedCreditNotes = tempSelected;
                        _creditNotesAmount = _selectedCreditNotes.fold(0.0, (sum, cn) => sum + ((cn['amount'] ?? 0) as num).toDouble());
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Apply', style: TextStyle(color: kWhite, fontWeight: FontWeight.bold))
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      Navigator.pop(context);
      debugPrint(e.toString());
    }
  }

  void _showAddProductDialog() async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final productsCollection = await FirestoreService().getStoreCollection('Products');
      final snapshot = await productsCollection.orderBy('itemName').get();
      Navigator.pop(context); // Close loading

      final productsList = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['itemName'] ?? 'Unknown',
          'price': (data['price'] ?? 0).toDouble(),
          'stock': (data['currentStock'] ?? 0).toDouble(),
          'code': data['productCode'] ?? '',
          'taxPercentage': (data['taxPercentage'] ?? 0).toDouble(),
          'taxName': data['taxName'],
          'taxType': data['taxType'],
        };
      }).toList();

      if (!mounted) return;

      final searchCtrl = TextEditingController();

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setSheetState) {
            final query = searchCtrl.text.toLowerCase();
            final filteredProducts = productsList.where((p) {
              final name = p['name'].toString().toLowerCase();
              final code = p['code'].toString().toLowerCase();
              return name.contains(query) || code.contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: const BoxDecoration(color: kWhite, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                children: [
                  Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4, decoration: BoxDecoration(color: kGrey300, borderRadius: BorderRadius.circular(2))),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text('Add product', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  ),
                  // Search Bar inside Item Popup
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: kGreyBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kGrey200),
                      ),
                      child: TextField(
                        controller: searchCtrl,
                        onChanged: (v) => setSheetState(() {}),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: "Search name or product code...",
                          prefixIcon: Icon(Icons.search, color: kPrimaryColor, size: 20),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 7),
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: kGrey200),
                  Expanded(
                    child: filteredProducts.isEmpty
                        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.search_off_rounded, size: 40, color: kGrey300), const SizedBox(height: 12), const Text("No matches found", style: TextStyle(color: kBlack54, fontWeight: FontWeight.w600))]))
                        : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredProducts.length,
                      separatorBuilder: (c, i) => const Divider(height: 1, color: kGrey100),
                      itemBuilder: (context, index) {
                        final p = filteredProducts[index];
                        // Calculate tax amount based on tax type
                        final price = (p['price'] as double?) ?? 0.0;
                        final taxPercentage = (p['taxPercentage'] as double?) ?? 0.0;
                        final taxType = p['taxType'] as String?;
                        double taxAmount = 0.0;
                        if (taxPercentage > 0) {
                          if (taxType == 'Price includes Tax') {
                            final taxRate = taxPercentage / 100;
                            taxAmount = price - (price / (1 + taxRate));
                          } else if (taxType == 'Price is without Tax') {
                            taxAmount = price * (taxPercentage / 100);
                          }
                        }
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          subtitle: Text('Rate: ${p['price']} • Stock: ${p['stock'].toInt()}${taxPercentage > 0 ? ' • Tax: ${taxPercentage.toStringAsFixed(0)}%' : ''}', style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w600)),
                          trailing: const Icon(Icons.add_circle_rounded, color: kHeaderColor, size: 28),
                          onTap: () {
                            setState(() {
                              _items.add({
                                'productId': p['id'],
                                'name': p['name'],
                                'price': p['price'],
                                'quantity': 1,
                                'taxPercentage': taxPercentage,
                                'taxName': p['taxName'],
                                'taxType': taxType,
                                'taxAmount': taxAmount,
                              });
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      debugPrint(e.toString());
    }
  }

  Future<void> _updateBill() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one item to update')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final oldPaymentMode = widget.invoiceData['paymentMode'];
      final oldTotal = (widget.invoiceData['total'] ?? 0).toDouble();
      final currentEditCount = (widget.invoiceData['editCount'] ?? 0) as int;

      final salesCollection = await FirestoreService().getStoreCollection('sales');

      // Prepare taxes list for storage
      final taxList = taxBreakdown.entries.map((e) => {'name': e.key, 'amount': e.value}).toList();

      await salesCollection.doc(widget.documentId).update({
        'items': _items,
        'subtotal': subtotal,
        'discount': discount,
        'total': finalTotal,
        'totalTax': totalTax,
        'taxes': taxList,
        'paymentMode': _selectedPaymentMode,
        'customerPhone': _selectedCustomerPhone,
        'customerName': _selectedCustomerName,
        'selectedCreditNotes': _selectedCreditNotes,
        'creditNotesAmount': _creditNotesAmount,
        'updatedAt': FieldValue.serverTimestamp(),
        'editCount': currentEditCount + 1,
        'status': 'edited', // Mark as edited
      });

      // Handle Partial Credit Note Logic
      if (_selectedCreditNotes.isNotEmpty) {
        double remainingToDeduct = _creditNotesAmount;
        final creditNotesCollection = await FirestoreService().getStoreCollection('creditNotes');

        for (var cn in _selectedCreditNotes) {
          if (remainingToDeduct <= 0) break;
          final double noteAmount = (cn['amount'] as num).toDouble();

          if (noteAmount <= remainingToDeduct) {
            await creditNotesCollection.doc(cn['id']).update({
              'status': 'Used',
              'usedInInvoice': widget.invoiceData['invoiceNumber'],
              'usedAt': FieldValue.serverTimestamp(),
              'amount': 0.0
            });
            remainingToDeduct -= noteAmount;
          } else {
            await creditNotesCollection.doc(cn['id']).update({
              'amount': noteAmount - remainingToDeduct,
              'lastPartialUseAt': FieldValue.serverTimestamp(),
              'lastPartialInvoice': widget.invoiceData['invoiceNumber']
            });
            remainingToDeduct = 0;
          }
        }
      }

      // Customer Balance Sync
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('bill_updated_success')), backgroundColor: kGoogleGreen));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${context.tr('error_updating_bill')}: $e'), backgroundColor: kErrorColor));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}