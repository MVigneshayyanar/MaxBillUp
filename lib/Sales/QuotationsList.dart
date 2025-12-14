import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Menu/Menu.dart';
import 'package:maxbillup/Sales/QuotationDetail.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/quotation_migration_helper.dart';
import 'package:maxbillup/utils/translation_helper.dart';

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
  // Color Palette
  final Color primaryBlue = const Color(0xFF2196F3);
  final Color successGreen = const Color(0xFF4CAF50);
  final Color backgroundGrey = const Color(0xFFF8F9FA);

  // Search & Filter State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  SortOption _currentSort = SortOption.dateNewest;
  FilterStatus _currentFilter = FilterStatus.all;
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

  // Logic to process the raw Firestore list based on UI state
  List<QueryDocumentSnapshot> _processList(List<QueryDocumentSnapshot> docs) {
    // 1. Filter by Search Query & Status
    var filtered = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      // Status Logic
      final status = (data['status'] ?? 'active').toString();
      final billedField = data['billed'];
      final bool isSettled = status == 'settled' || status == 'billed' || (billedField == true);

      if (_currentFilter == FilterStatus.available && isSettled) return false;
      if (_currentFilter == FilterStatus.settled && !isSettled) return false;

      // Search Logic
      if (_searchQuery.isEmpty) return true;

      final customerName = (data['customerName'] ?? '').toString().toLowerCase();
      final quotationNumber = (data['quotationNumber'] ?? '').toString().toLowerCase();

      return customerName.contains(_searchQuery) || quotationNumber.contains(_searchQuery);
    }).toList();

    // 2. Sort
    filtered.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;

      if (_currentSort == SortOption.amountHigh || _currentSort == SortOption.amountLow) {
        double totalA = double.tryParse(dataA['total'].toString()) ?? 0.0;
        double totalB = double.tryParse(dataB['total'].toString()) ?? 0.0;
        return _currentSort == SortOption.amountHigh
            ? totalB.compareTo(totalA)
            : totalA.compareTo(totalB);
      } else {
        // Date Sort
        Timestamp timeA = dataA['timestamp'] ?? Timestamp.now();
        Timestamp timeB = dataB['timestamp'] ?? Timestamp.now();
        return _currentSort == SortOption.dateNewest
            ? timeB.compareTo(timeA)
            : timeA.compareTo(timeB);
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGrey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryBlue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search customer or #ID...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
        )
            : GestureDetector(
          onLongPress: () => QuotationMigrationHelper.migrateSettledQuotations(context),
          child: const Text(
            'Quotations',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                }
              });
            },
          ),
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort, color: Colors.white),
            onSelected: (SortOption result) {
              setState(() => _currentSort = result);
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOption>>[
              const PopupMenuItem(
                value: SortOption.dateNewest,
                child: Text('Date: Newest First'),
              ),
              const PopupMenuItem(
                value: SortOption.dateOldest,
                child: Text('Date: Oldest First'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: SortOption.amountHigh,
                child: Text('Amount: High to Low'),
              ),
              const PopupMenuItem(
                value: SortOption.amountLow,
                child: Text('Amount: Low to High'),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: Colors.white,
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _buildFilterChip('All', FilterStatus.all),
                const SizedBox(width: 8),
                _buildFilterChip('Available', FilterStatus.available),
                const SizedBox(width: 8),
                _buildFilterChip('Settled', FilterStatus.settled),
              ],
            ),
          ),
        ),
      ),
      body: FutureBuilder<Stream<QuerySnapshot>>(
        future: FirestoreService().getCollectionStream('quotations'),
        builder: (context, streamSnapshot) {
          if (!streamSnapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: primaryBlue));
          }

          return StreamBuilder<QuerySnapshot>(
            stream: streamSnapshot.data,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: primaryBlue));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState('No quotations found');
              }

              // Apply Search, Sort, and Filter logic
              final displayList = _processList(snapshot.data!.docs);

              if (displayList.isEmpty) {
                return _buildEmptyState('No results found for your search');
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: displayList.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildQuotationCard(displayList[index]);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, FilterStatus status) {
    final bool isSelected = _currentFilter == status;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          fontSize: 13,
        ),
      ),
      selected: isSelected,
      selectedColor: primaryBlue,
      backgroundColor: Colors.grey[100],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.transparent : Colors.grey[300]!,
        ),
      ),
      showCheckmark: false,
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            _currentFilter = status;
          });
        }
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_list_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotationCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final quotationNumber = data['quotationNumber'] ?? 'N/A';
    final rawCustomerName = data['customerName'];
    final customerName =
    (rawCustomerName == null || rawCustomerName.toString().trim().isEmpty)
        ? 'Walk-in Customer'
        : rawCustomerName.toString();

    double total = 0.0;
    final totalRaw = data['total'];
    if (totalRaw is num) {
      total = totalRaw.toDouble();
    } else if (totalRaw is String) {
      total = double.tryParse(totalRaw) ?? 0.0;
    }

    final status = (data['status'] ?? 'active').toString();
    final billedField = data['billed'];
    final bool isBilled =
        status == 'settled' || status == 'billed' || (billedField == true);

    final timestamp = data['timestamp'] as Timestamp?;
    final formattedDate = timestamp != null
        ? DateFormat('dd MMM yyyy').format(timestamp.toDate())
        : '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => QuotationDetailPage(
                  uid: widget.uid,
                  userEmail: widget.userEmail,
                  quotationId: doc.id,
                  quotationData: data,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '#$quotationNumber',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: primaryBlue,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person_outline,
                          size: 20, color: Colors.grey[700]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        customerName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Amount',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ' ${total.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: successGreen,
                          ),
                        ),
                      ],
                    ),
                    _buildStatusChip(isBilled),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isBilled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isBilled ? Colors.grey[100] : successGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isBilled ? Colors.grey[300]! : successGreen.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isBilled ? Icons.check_circle_outline : Icons.access_time_rounded,
            size: 14,
            color: isBilled ? Colors.grey[600] : successGreen,
          ),
          const SizedBox(width: 6),
          Text(
            isBilled ? 'Settled' : 'Available',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isBilled ? Colors.grey[600] : successGreen,
            ),
          ),
        ],
      ),
    );
  }
}
