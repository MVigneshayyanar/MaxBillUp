import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/Sales/QuotationDetail.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'nq.dart'; // Import for NewQuotationPage

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

  // Processes the raw Firestore documents: filtering and sorting in memory
  List<QueryDocumentSnapshot> _processList(List<QueryDocumentSnapshot> docs) {
    var filtered = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final bool billed = data['billed'] == true || data['status'] == 'settled';

      // Status filter
      if (_currentFilter == FilterStatus.available && billed) return false;
      if (_currentFilter == FilterStatus.settled && !billed) return false;

      // Search filter
      if (_searchQuery.isEmpty) return true;
      final customerName = (data['customerName'] ?? '').toString().toLowerCase();
      final quotationNumber = (data['quotationNumber'] ?? '').toString().toLowerCase();
      return customerName.contains(_searchQuery) || quotationNumber.contains(_searchQuery);
    }).toList();

    filtered.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;

      switch (_currentSort) {
        case SortOption.amountHigh:
          double valA = (dataA['total'] ?? 0.0).toDouble();
          double valB = (dataB['total'] ?? 0.0).toDouble();
          return valB.compareTo(valA);
        case SortOption.amountLow:
          double valA = (dataA['total'] ?? 0.0).toDouble();
          double valB = (dataB['total'] ?? 0.0).toDouble();
          return valA.compareTo(valB);
        case SortOption.dateOldest:
          Timestamp tA = dataA['timestamp'] ?? Timestamp.now();
          Timestamp tB = dataB['timestamp'] ?? Timestamp.now();
          return tA.compareTo(tB);
        case SortOption.dateNewest:
        default:
          Timestamp tA = dataA['timestamp'] ?? Timestamp.now();
          Timestamp tB = dataB['timestamp'] ?? Timestamp.now();
          return tB.compareTo(tA);
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) widget.onBack();
      },
      child: Scaffold(
        backgroundColor: kGreyBg,
        appBar: AppBar(
          backgroundColor: kPrimaryColor,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: kWhite, size: 22),
            onPressed: widget.onBack,
          ),
          title: Text(context.tr('quotations'),
              style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        ),
      body: Column(
        children: [
          _buildHeaderSection(),
          Expanded(
            child: FutureBuilder<Stream<QuerySnapshot>>(
              future: FirestoreService().getCollectionStream('quotations'),
              builder: (context, streamSnap) {
                if (!streamSnap.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                return StreamBuilder<QuerySnapshot>(
                  stream: streamSnap.data,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmpty();

                    final processedList = _processList(snapshot.data!.docs);
                    if (processedList.isEmpty) return _buildNoResults();

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: processedList.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 10),
                      itemBuilder: (c, i) => _buildCard(processedList[i]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Using MaterialPageRoute for faster/smoother transition on press
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NewQuotationPage(
                uid: widget.uid,
                userEmail: widget.userEmail,
              ),
            ),
          );
        },
        backgroundColor: kPrimaryColor,
        icon: const Icon(Icons.add, color: kWhite),
        label: const Text('New Quotation', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700)),
      ),
      ), // WillPopScope closing
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: kWhite,
        // Removed BoxShadow
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
                  hintStyle: const TextStyle(color: kBlack54, fontSize: 14),
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
        height: 46,
        width: 46,
        decoration: BoxDecoration(
          color: kPrimaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kGrey200),
        ),
        child: Icon(icon, color: kPrimaryColor, size: 22),
      ),
    );
  }

  Widget _buildCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final bool billed = data['billed'] == true || data['status'] == 'settled';
    final double total = (data['total'] ?? 0.0).toDouble();
    final String quotedBy = data['staffName'] ?? 'Staff';

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
        // Removed BoxShadow
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (c) => QuotationDetailPage(
                      uid: widget.uid,
                      userEmail: widget.userEmail,
                      quotationId: doc.id,
                      quotationData: data))),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text("QTN-${data['quotationNumber']}",
                      style: const TextStyle(fontWeight: FontWeight.w900, color: kPrimaryColor, fontSize: 13)),
                  Text(
                      data['date'] != null
                          ? DateFormat('dd MMM yyyy • hh:mm a').format(DateTime.parse(data['date']))
                          : '',
                      style: const TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w500))
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
                      child: Text(data['customerName'] ?? 'Guest',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kOrange))),
                  Text("${total.toStringAsFixed(2)}",
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: kPrimaryColor)),
                ]),
                const Divider(height: 20, color: kGreyBg),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Quoted by",
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kBlack54, letterSpacing: 0.5)),
                    Text(quotedBy,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: kBlack87))
                  ]),
                  _badge(billed)
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(bool billed) {
    // Logic: OPEN is Green, BILLED (Closed) is Red
    final Color statusColor = billed ? kErrorColor : kGoogleGreen;

    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withOpacity(0.2))),
        child: Text(billed ? "BILLED" : "OPEN",
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: statusColor)));
  }

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sort Quotations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kBlack87)),
            const SizedBox(height: 16),
            _sortItem("Newest First", SortOption.dateNewest),
            _sortItem("Oldest First", SortOption.dateOldest),
            _sortItem("Amount: High to Low", SortOption.amountHigh),
            _sortItem("Amount: Low to High", SortOption.amountLow),
          ],
        ),
      ),
    );
  }

  Widget _sortItem(String label, SortOption option) {
    bool isSelected = _currentSort == option;
    return ListTile(
      onTap: () {
        setState(() => _currentSort = option);
        Navigator.pop(context);
      },
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? kPrimaryColor : kBlack87)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: kPrimaryColor) : null,
    );
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kBlack87)),
            const SizedBox(height: 16),
            _filterItem("All Quotations", FilterStatus.all),
            _filterItem("Open Only", FilterStatus.available),
            _filterItem("Billed Only", FilterStatus.settled),
          ],
        ),
      ),
    );
  }

  Widget _filterItem(String label, FilterStatus status) {
    bool isSelected = _currentFilter == status;
    return ListTile(
      onTap: () {
        setState(() => _currentFilter = status);
        Navigator.pop(context);
      },
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? kPrimaryColor : kBlack87)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: kPrimaryColor) : null,
    );
  }

  Widget _buildEmpty() => Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.description_outlined, size: 64, color: kGrey300),
        const SizedBox(height: 16),
        Text(context.tr('no_quotations_found'),
            style: const TextStyle(color: kBlack54, fontWeight: FontWeight.w600))
      ]));

  Widget _buildNoResults() => Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.search_off_rounded, size: 64, color: kGrey300),
        const SizedBox(height: 16),
        const Text("No matches found for your search",
            style: TextStyle(color: kBlack54, fontWeight: FontWeight.w600))
      ]));
}