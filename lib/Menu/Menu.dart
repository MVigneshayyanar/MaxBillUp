import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/components/common_bottom_nav.dart';
import 'package:intl/intl.dart';

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

  @override
  Widget build(BuildContext context) {
    bool isAdmin = _role.toLowerCase() == 'admin' || _role.toLowerCase() == 'administrator';

    // ------------------------------------------
    // CONDITIONAL RENDERING SWITCH
    // ------------------------------------------
    switch (_currentView) {
    // Inline Lists
      case 'Quotation':
        return GenericListPage(title: 'Quotations', collectionPath: 'quotations', uid: widget.uid, onBack: _reset);
      case 'BillHistory':
        return SalesHistoryPage(uid: widget.uid, onBack: _reset);
      case 'CreditNotes':
        return GenericListPage(title: 'Credit Notes', collectionPath: 'sales', uid: widget.uid, filterField: 'creditNote', filterNotEmpty: true, onBack: _reset);
      case 'Customers':
        return CustomersPage(uid: widget.uid, onBack: _reset);
      case 'CreditDetails':
        return GenericListPage(title: 'Credits', collectionPath: 'customers', uid: widget.uid, filterField: 'balance', numericFilterGreaterThan: 0, onBack: _reset);

    // Expenses Sub-menu items
      case 'StockPurchase':
        return GenericListPage(title: 'Stock Purchases', collectionPath: 'stockPurchases', uid: widget.uid, onBack: _reset);
      case 'Expenses':
        return GenericListPage(title: 'Expenses', collectionPath: 'expenses', uid: widget.uid, onBack: _reset);
      case 'OtherExpenses':
        return GenericListPage(title: 'Other Expenses', collectionPath: 'otherExpenses', uid: widget.uid, onBack: _reset);
      case 'ExpenseCategories':
        return GenericListPage(title: 'Expense Categories', collectionPath: 'expenseCategories', uid: widget.uid, onBack: _reset);

    // Staff
      case 'StaffManagement':
        return StaffManagementList(adminUid: widget.uid, onBack: _reset, onAddStaff: () => setState(() => _currentView = 'AddStaff'));
      case 'AddStaff':
        return AddStaffPage(adminUid: widget.uid, onBack: () => setState(() => _currentView = 'StaffManagement'));
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
                Text(_businessName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_email, style: const TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),

          // MENU LIST
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                _buildMenuItem(Icons.assignment_outlined, "Quotation", 'Quotation'),
                _buildMenuItem(Icons.receipt_long_outlined, "Bill History", 'BillHistory'),
                _buildMenuItem(Icons.description_outlined, "Credit Notes", 'CreditNotes'),
                _buildMenuItem(Icons.group_outlined, "Customer Management", 'Customers'),

                // Expenses Expansion
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
                      _buildSubMenuItem("Other Expenses", 'OtherExpenses'),
                      _buildSubMenuItem("Expense Category", 'ExpenseCategories'),
                    ],
                  ),
                ),

                _buildMenuItem(Icons.request_quote_outlined, "Credit Details", 'CreditDetails'),

                if (isAdmin)
                  _buildMenuItem(Icons.badge_outlined, "Staff Management", 'StaffManagement'),

                // Unsettled Orders Button (Admin only)
                if (isAdmin)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ElevatedButton(
                      onPressed: () => displayUnsettledOrders(context, widget.uid),
                      child: const Text('View Unsettled Orders'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CommonBottomNav(
        uid: widget.uid,
        userEmail: widget.userEmail,
        currentIndex: 0,
        screenWidth: MediaQuery.of(context).size.width,
      ),
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
        onTap: () => setState(() => _currentView = viewKey),
      ),
    );
  }

  Widget _buildSubMenuItem(String text, String viewKey) {
    return ListTile(
      title: Text(text, style: TextStyle(fontSize: 15, color: Color.fromRGBO(_textColor.red, _textColor.green, _textColor.blue, 0.8))),
      onTap: () => setState(() => _currentView = viewKey),
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      contentPadding: EdgeInsets.zero,
    );
  }

  Future<List<Map<String, dynamic>>> fetchUnsettledOrders(String uid) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedOrders')
        .get();

    return querySnapshot.docs.map((doc) => doc.data()).toList();
  }

  void displayUnsettledOrders(BuildContext context, String uid) async {
    final unsettledOrders = await fetchUnsettledOrders(uid);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Unsettled Orders'),
          content: SizedBox(
            height: 300,
            child: ListView.builder(
              itemCount: unsettledOrders.length,
              itemBuilder: (context, index) {
                final order = unsettledOrders[index];
                return ListTile(
                  title: Text(order['customerName'] ?? 'Unknown Customer'),
                  subtitle: Text('Total: ${order['total']}'),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
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

  const GenericListPage({
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
    Query collectionRef = FirebaseFirestore.instance.collection(collectionPath);
    if (filterNotEmpty && filterField != null) {
      collectionRef = collectionRef.where(filterField!, isNotEqualTo: null);
    }
    if (numericFilterGreaterThan != null && filterField != null) {
      collectionRef = collectionRef.where(filterField!, isGreaterThan: numericFilterGreaterThan);
    }
    collectionRef = collectionRef.orderBy('timestamp', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF007AFF),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: onBack),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
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

  const SalesHistoryPage({super.key, required this.uid, required this.onBack});

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  late final Stream<List<QueryDocumentSnapshot>> _combinedStream;

  @override
  void initState() {
    super.initState();
    _combinedStream = _createCombinedStream();
  }

  Stream<List<QueryDocumentSnapshot>> _createCombinedStream() {
    final salesStream = FirebaseFirestore.instance.collection('sales').snapshots();
    final savedOrdersStream = FirebaseFirestore.instance
        .collection('savedOrders')
        .snapshots();

    late StreamController<List<QueryDocumentSnapshot>> controller;
    StreamSubscription? salesSub;
    StreamSubscription? savedOrdersSub;
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
      if (!controller.isClosed) {
        controller.add(allDocs);
      }
    }

    controller = StreamController<List<QueryDocumentSnapshot>>(
      onListen: () {
        salesSub = salesStream.listen((snapshot) {
          salesDocs = snapshot.docs;
          updateController();
        });

        savedOrdersSub = savedOrdersStream.listen((snapshot) {
          savedOrdersDocs = snapshot.docs;
          updateController();
        });
      },
      onCancel: () {
        salesSub?.cancel();
        savedOrdersSub?.cancel();
      },
    );

    return controller.stream;
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
            child: StreamBuilder<List<QueryDocumentSnapshot>>(
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
    final isSettled = data['paymentMode'] != null || data['change'] != null;

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
                      // Logic for Settle Bill (Unsettled) or Receipt (Settled)
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => isSettled
                              ? SalesDetailPage(documentId: doc.id, initialData: data) // View Receipt
                              : AddStaffPage(adminUid: widget.uid, onBack: () {}), // Simulate Settle Bill screen (using dummy for now)
                        ),
                      );
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
      body: StreamBuilder<DocumentSnapshot>(
        // Use documentId to fetch the latest state of the bill
        stream: FirebaseFirestore.instance.collection('sales').doc(documentId).snapshots(),
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
                // Header Details
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow("Invoice No.", data['invoiceNumber'] ?? '-'),
                        _buildDetailRow("Issued On", time != null ? DateFormat('dd-MMM-yyyy, hh:mm a').format(time) : '-'),
                        _buildDetailRow("Customer", data['customerName'] ?? 'Walk-in'),
                        _buildDetailRow("Phone", data['customerPhone'] ?? '-'),
                        _buildDetailRow("Created By", data['staffName'] ?? data['staffId'] ?? 'Unknown'),
                        _buildDetailRow("Payment Mode", data['paymentMode'] ?? 'N/A'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Items Section
                const Text("Invoice Items", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF007AFF))),
                const Divider(),
                ...items.map((item) => _buildItemRow(item)).toList(),

                const SizedBox(height: 20),

                // Summary Totals
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildSummaryRow("Sub Total", data['subtotal'] ?? 0.0),
                        _buildSummaryRow("Discount", data['discount'] ?? 0.0),
                        _buildSummaryRow("Grand Total", data['total'] ?? 0.0, isTotal: true),
                        _buildSummaryRow("Cash Received", data['cashReceived'] ?? 0.0),
                        _buildSummaryRow("Change Given", data['change'] ?? 0.0),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Add action buttons here (e.g., Settle Bill, Return Bill, Print Receipt)
                // For simplicity, we'll just add one placeholder button.
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Simulating Print Receipt')));
                    },
                    icon: const Icon(Icons.print, color: Colors.white),
                    label: const Text('Print Receipt', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("$label:", style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildItemRow(Map<String, dynamic> item) {
    final name = item['name'] ?? 'Item';
    final price = item['price'] ?? 0;
    final quantity = item['quantity'] ?? 1;
    final total = (price * quantity) as double? ?? 0.0; // Ensure total is double for fixed decimal

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('${quantity} x ₹${price}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, dynamic value, {bool isTotal = false}) {
    final val = (value as num).toStringAsFixed(2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              fontSize: isTotal ? 18 : 16,
              color: isTotal ? const Color(0xFF007AFF) : Colors.black87,
            ),
          ),
          Text(
            '₹$val',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              fontSize: isTotal ? 18 : 16,
              color: isTotal ? const Color(0xFF007AFF) : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

// ... (The rest of the original file, including CustomersPage, StaffManagementList, etc., remains here)
// ==========================================
// 4. CUSTOMER RELATED PAGES
// ==========================================

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
              await FirebaseFirestore.instance.collection('customers').doc(phone).set({
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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('customers').orderBy('timestamp', descending: true).snapshots(),
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

class CustomerDetailsPage extends StatelessWidget {
  final String customerId;
  final Map<String, dynamic> customerData;

  const CustomerDetailsPage({super.key, required this.customerId, required this.customerData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(customerData['name'] ?? 'Customer Details', style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF007AFF),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: Center(
        child: Text('Details for Customer: ${customerData['name']} (ID: $customerId)'),
      ),
    );
  }
}


// ==========================================
// 5. STAFF RELATED PAGES
// ==========================================

class StaffManagementList extends StatelessWidget {
  final String adminUid;
  final VoidCallback onBack;
  final VoidCallback onAddStaff;

  const StaffManagementList({super.key, required this.adminUid, required this.onBack, required this.onAddStaff});

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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
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
      await FirebaseFirestore.instance.collection('users').add({
        'name': _nameController.text,
        'email': _emailController.text,
        'role': _selectedRole,
        'status': 'Active',
        'parentAdmin': widget.adminUid,
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
