import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/Sales/QuotationDetail.dart';
import 'package:maxbillup/Sales/saleall.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/quotation_migration_helper.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'nq.dart';

// --- UI CONSTANTS ---
const Color _primaryColor = Color(0xFF2F7CF6);
const Color _successColor = Color(0xFF4CAF50);
const Color _cardBorder = Color(0xFFE3F2FD);

class QuotationsListPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final VoidCallback onBack;

  const QuotationsListPage({
    super.key,
    required this.uid,
    this.userEmail,
    required this.onBack,
  });

  @override
  State<QuotationsListPage> createState() => _QuotationsListPageState();
}

enum SortOption { dateNewest, dateOldest, amountHigh, amountLow }
enum FilterStatus { all, available, settled }

class _QuotationsListPageState extends State<QuotationsListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  SortOption _currentSort = SortOption.dateNewest;
  FilterStatus _currentFilter = FilterStatus.all;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() { _searchQuery = _searchController.text.toLowerCase(); });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot> _processList(List<QueryDocumentSnapshot> docs) {
    var filtered = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] ?? 'active').toString();
      final billedField = data['billed'];
      final bool isSettled = status == 'settled' || status == 'billed' || (billedField == true);

      if (_currentFilter == FilterStatus.available && isSettled) return false;
      if (_currentFilter == FilterStatus.settled && !isSettled) return false;

      if (_searchQuery.isEmpty) return true;
      final customerName = (data['customerName'] ?? '').toString().toLowerCase();
      final quotationNumber = (data['quotationNumber'] ?? '').toString().toLowerCase();
      return customerName.contains(_searchQuery) || quotationNumber.contains(_searchQuery);
    }).toList();

    filtered.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;
      if (_currentSort == SortOption.amountHigh || _currentSort == SortOption.amountLow) {
        double totalA = (dataA['total'] ?? 0.0).toDouble();
        double totalB = (dataB['total'] ?? 0.0).toDouble();
        return _currentSort == SortOption.amountHigh ? totalB.compareTo(totalA) : totalA.compareTo(totalB);
      } else {
        Timestamp timeA = dataA['timestamp'] ?? Timestamp.now();
        Timestamp timeB = dataB['timestamp'] ?? Timestamp.now();
        return _currentSort == SortOption.dateNewest ? timeB.compareTo(timeA) : timeA.compareTo(timeB);
      }
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: context.tr('search'),
            hintStyle: const TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
        )
            : GestureDetector(
          onLongPress: () => QuotationMigrationHelper.migrateSettledQuotations(context),
          child: Text(context.tr('quotations'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () => setState(() { _isSearching = !_isSearching; if (!_isSearching) _searchController.clear(); }),
          ),
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (result) => setState(() => _currentSort = result),
            itemBuilder: (ctx) => [
              PopupMenuItem(value: SortOption.dateNewest, child: Text(context.tr('date_newest_first'))),
              PopupMenuItem(value: SortOption.dateOldest, child: Text(context.tr('date_oldest_first'))),
              const PopupMenuDivider(),
              PopupMenuItem(value: SortOption.amountHigh, child: Text(context.tr('amount_high_to_low'))),
              PopupMenuItem(value: SortOption.amountLow, child: Text(context.tr('amount_low_to_high'))),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            color: Colors.white,
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip(context.tr('all'), FilterStatus.all),
                const SizedBox(width: 8),
                _buildFilterChip(context.tr('available'), FilterStatus.available),
                const SizedBox(width: 8),
                _buildFilterChip(context.tr('settled'), FilterStatus.settled),
              ],
            ),
          ),
        ),
      ),
      body: FutureBuilder<Stream<QuerySnapshot>>(
        future: FirestoreService().getCollectionStream('quotations'),
        builder: (context, streamSnapshot) {
          if (!streamSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          return StreamBuilder<QuerySnapshot>(
            stream: streamSnapshot.data,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState(context.tr('no_quotations_found'));

              final displayList = _processList(snapshot.data!.docs);
              if (displayList.isEmpty) return _buildEmptyState('No results found');

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: displayList.length,
                separatorBuilder: (c, i) => const SizedBox(height: 12),
                itemBuilder: (c, i) => _buildQuotationCard(displayList[i]),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => NewQuotationPage(
                uid: widget.uid,
                userEmail: widget.userEmail,
              ),
            ),
          );
        },
        backgroundColor: _primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          context.tr('create_quotation'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, FilterStatus status) {
    final isSelected = _currentFilter == status;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
      selected: isSelected,
      selectedColor: _primaryColor,
      backgroundColor: _primaryColor.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? _primaryColor : _cardBorder)),
      showCheckmark: false,
      onSelected: (v) => setState(() => _currentFilter = status),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.description_outlined, size: 80, color: _primaryColor.withOpacity(0.1)),
      const SizedBox(height: 16),
      Text(message, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
    ]));
  }

  Widget _buildQuotationCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final quotationNumber = data['quotationNumber'] ?? 'N/A';
    final customerName = (data['customerName'] ?? '').toString().trim().isEmpty ? 'Walk-in Customer' : data['customerName'].toString();
    final total = (data['total'] ?? 0.0).toDouble();
    final isBilled = (data['status'] == 'settled' || data['status'] == 'billed' || data['billed'] == true);
    final timestamp = data['timestamp'] as Timestamp?;
    final date = timestamp != null ? DateFormat('dd MMM yyyy').format(timestamp.toDate()) : '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (c) => QuotationDetailPage(uid: widget.uid, userEmail: widget.userEmail, quotationId: doc.id, quotationData: data))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('QTN-$quotationNumber', style: const TextStyle(fontWeight: FontWeight.w900, color: _primaryColor, fontSize: 14)),
                    Text(date, style: TextStyle(color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey[50], shape: BoxShape.circle), child: const Icon(Icons.person_outline, size: 18, color: Colors.grey)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: _cardBorder)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TOTAL AMOUNT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        Text('${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _successColor)),
                      ],
                    ),
                    _statusBadge(isBilled),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(bool isBilled) {
    final color = isBilled ? Colors.grey : _successColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.2))),
      child: Row(children: [
        Icon(isBilled ? Icons.check_circle_outline : Icons.access_time, size: 12, color: color),
        const SizedBox(width: 4),
        Text(isBilled ? 'SETTLED' : 'AVAILABLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }
}