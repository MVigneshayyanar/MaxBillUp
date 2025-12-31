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
  final String uid; final String? userEmail; final VoidCallback onBack;
  const QuotationsListPage({super.key, required this.uid, this.userEmail, required this.onBack});
  @override State<QuotationsListPage> createState() => _QuotationsListPageState();
}

enum FilterStatus { all, available, settled }

class _QuotationsListPageState extends State<QuotationsListPage> {
  final _searchController = TextEditingController();
  String _query = '';
  FilterStatus _filter = FilterStatus.all;
  bool _isSearching = false;

  @override void initState() { super.initState(); _searchController.addListener(() => setState(() => _query = _searchController.text.toLowerCase())); }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        backgroundColor: kPrimaryColor, centerTitle: true, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 22), onPressed: () => Navigator.pop(context)),
        title: _isSearching
            ? TextField(
            controller: _searchController,
            autofocus: true,
            style: const TextStyle(color: kWhite, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
                hintText: 'Search quotation...',
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none
            )
        )
            : Text(context.tr('quotations'), style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [IconButton(icon: Icon(_isSearching ? Icons.close : Icons.search, color: kWhite), onPressed: () => setState(() { _isSearching = !_isSearching; if (!_isSearching) _searchController.clear(); }))],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            color: kWhite, height: 56, padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _filterTab("ALL", FilterStatus.all),
              const SizedBox(width: 8),
              _filterTab("OPEN", FilterStatus.available),
              const SizedBox(width: 8),
              _filterTab("BILLED", FilterStatus.settled),
            ]),
          ),
        ),
      ),
      body: FutureBuilder<Stream<QuerySnapshot>>(
        future: FirestoreService().getCollectionStream('quotations'),
        builder: (context, streamSnap) {
          if (!streamSnap.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          return StreamBuilder<QuerySnapshot>(
            stream: streamSnap.data,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmpty();
              final docs = snapshot.data!.docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final bool billed = data['billed'] == true || data['status'] == 'settled';
                if (_filter == FilterStatus.available && billed) return false;
                if (_filter == FilterStatus.settled && !billed) return false;
                return (data['customerName'] ?? '').toString().toLowerCase().contains(_query) || (data['quotationNumber'] ?? '').toString().contains(_query);
              }).toList();
              return ListView.separated(
                  padding: const EdgeInsets.all(12), // Reduced from 16
                  itemCount: docs.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 8), // Reduced from 12
                  itemBuilder: (c, i) => _buildCard(docs[i])
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
        backgroundColor: kPrimaryColor,
        elevation: 4,
        icon: const Icon(Icons.add, color: kWhite),
        label: Text(
          context.tr('create_quotation'),
          style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _filterTab(String l, FilterStatus s) {
    bool active = _filter == s;
    return ChoiceChip(
        label: Text(l, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: active ? kWhite : kBlack54)), // Reduced font size
        selected: active,
        onSelected: (_) => setState(() => _filter = s),
        selectedColor: kPrimaryColor,
        backgroundColor: kGreyBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: active ? kPrimaryColor : kGrey200, width: 1),
        showCheckmark: false
    );
  }

  Widget _buildCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final bool billed = data['billed'] == true || data['status'] == 'settled';
    return Container(
      decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kGrey200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (c) => QuotationDetailPage(uid: widget.uid, userEmail: widget.userEmail, quotationId: doc.id, quotationData: data))),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), // Reduced vertical padding
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text("QTN-${data['quotationNumber']}", style: const TextStyle(fontWeight: FontWeight.w900, color: kPrimaryColor, fontSize: 13)),
                  Text(data['date'] != null ? DateFormat('dd MMM yy').format(DateTime.parse(data['date'])) : '', style: const TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w500))
                ]),
                const SizedBox(height: 10), // Reduced gap
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6), // Reduced padding
                    decoration: BoxDecoration(color: kGreyBg, shape: BoxShape.circle),
                    child: const Icon(Icons.person_rounded, size: 16, color: kBlack54),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(data['customerName'] ?? 'Walk-in Customer', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kBlack87))),
                ]),
                const Divider(height: 20, color: kGrey100), // Reduced from 28
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("TOTAL VALUATION", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kBlack54, letterSpacing: 0.5)),
                    Text("Rs ${(data['total'] ?? 0.0).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kGoogleGreen))
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

  Widget _badge(bool billed) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: (billed ? kBlack54 : kPrimaryColor).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: (billed ? kBlack54 : kPrimaryColor).withOpacity(0.2))
      ),
      child: Text(billed ? "BILLED" : "OPEN", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: billed ? kBlack54 : kPrimaryColor))
  );

  Widget _buildEmpty() => Center(
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.description_outlined, size: 64, color: kGrey300),
            const SizedBox(height: 16),
            Text(context.tr('no_quotations_found'), style: const TextStyle(color: kBlack54, fontWeight: FontWeight.w600))
          ]
      )
  );
}