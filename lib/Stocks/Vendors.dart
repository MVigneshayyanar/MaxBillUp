import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/utils/firestore_service.dart';

class VendorsPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;

  const VendorsPage({super.key, required this.uid, required this.onBack});

  @override
  State<VendorsPage> createState() => _VendorsPageState();
}

class _VendorsPageState extends State<VendorsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _vendors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVendors();
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

  // ==========================================
  // LOGIC METHODS (PRESERVED)
  // ==========================================

  Future<void> _loadVendors() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final vendorsCollection = await FirestoreService().getStoreCollection('vendors');
      final snapshot = await vendorsCollection.orderBy('createdAt', descending: true).get();

      if (mounted) {
        setState(() {
          _vendors = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'name': data['name'] ?? '',
              'phone': data['phone'] ?? '',
              'gstin': data['gstin'] ?? '',
              'address': data['address'] ?? '',
              'totalPurchases': (data['totalPurchases'] ?? 0.0).toDouble(),
              'purchaseCount': data['purchaseCount'] ?? 0,
              'source': data['source'] ?? '',
              'createdAt': data['createdAt'],
              'lastPurchaseDate': data['lastPurchaseDate'],
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading vendors: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredVendors {
    if (_searchQuery.isEmpty) return _vendors;
    return _vendors.where((vendor) {
      final name = (vendor['name'] ?? '').toString().toLowerCase();
      final phone = (vendor['phone'] ?? '').toString().toLowerCase();
      final gstin = (vendor['gstin'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) ||
          phone.contains(_searchQuery) ||
          gstin.contains(_searchQuery);
    }).toList();
  }

  // ==========================================
  // UI BUILD METHODS (ENTERPRISE FLAT)
  // ==========================================

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
          title: const Text('Vendors',
              style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
          backgroundColor: kPrimaryColor,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: kWhite, size: 20),
            onPressed: widget.onBack,
          ),
          centerTitle: true,
          elevation: 0,
        ),
        body: Column(
        children: [
          // ENTERPRISE SEARCH HEADER
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
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kBlack87),
                      decoration: const InputDecoration(
                        hintText: "Search vendors...",
                        hintStyle: TextStyle(color: kBlack54, fontSize: 14),
                        prefixIcon: Icon(Icons.search, color: kPrimaryColor, size: 20),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 7),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => _showAddVendorDialog(context),
                  borderRadius: BorderRadius.circular(12),
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

          // SUMMARY STATS ROW
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            color: kWhite,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('VENDORS', _vendors.length.toString(), Icons.people_outline_rounded),
                _buildStat(
                  'TOTAL SPENT',
                  '${_vendors.fold(0.0, (sum, v) => sum + ((v['totalPurchases'] ?? 0).toDouble())).toStringAsFixed(0)}',
                  Icons.payments_rounded,
                ),
                _buildStat(
                  'BILLS',
                  _vendors.fold(0, (sum, v) => sum + ((v['purchaseCount'] ?? 0) as int)).toString(),
                  Icons.receipt_long_rounded,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // VENDORS LIST
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
                : _filteredVendors.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              color: kPrimaryColor,
              onRefresh: _loadVendors,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: _filteredVendors.length,
                separatorBuilder: (c, i) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _buildVendorCard(_filteredVendors[index]);
                },
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: kPrimaryColor, size: 18),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kBlack87)),
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildVendorCard(Map<String, dynamic> vendor) {
    final totalPurchases = vendor['totalPurchases'] as double;
    final purchaseCount = vendor['purchaseCount'] as int;
    final isFromStockPurchase = vendor['source'] == 'stock_purchase';

    String lastPurchaseText = '';
    if (vendor['lastPurchaseDate'] != null) {
      try {
        final lastDate = (vendor['lastPurchaseDate'] as Timestamp).toDate();
        lastPurchaseText = 'Last: ${DateFormat('dd-MM-yy').format(lastDate)}';
      } catch (e) {
        lastPurchaseText = '';
      }
    }

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
          onTap: () => _showEditVendorDialog(context, vendor), // Quick access to edit
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: kPrimaryColor.withOpacity(0.1),
                      radius: 20,
                      child: Text(
                        (vendor['name'] ?? 'V').toString().isNotEmpty
                            ? (vendor['name'] ?? 'V').toString()[0].toUpperCase()
                            : 'V',
                        style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  vendor['name'] ?? 'Unknown',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kOrange),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isFromStockPurchase)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: kGoogleGreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'SUPPLIER',
                                    style: TextStyle(fontSize: 8, color: kGoogleGreen, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.phone_android_rounded, size: 12, color: kBlack54),
                              const SizedBox(width: 6),
                              Text(vendor['phone'] ?? '--', style: const TextStyle(fontSize: 12, color: kBlack54, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _buildPopupMenu(vendor),
                  ],
                ),
                const Divider(height: 24, color: kGrey100),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$purchaseCount BILLS',
                        style: const TextStyle(fontSize: 9, color: kPrimaryColor, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: kOrange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${totalPurchases.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 9, color: kOrange, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                    ),
                    const Spacer(),
                    if (lastPurchaseText.isNotEmpty)
                      Text(lastPurchaseText.toUpperCase(), style: const TextStyle(fontSize: 9, color: kBlack54, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopupMenu(Map<String, dynamic> vendor) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: kGrey400, size: 20),
      elevation: 0,
      offset: const Offset(0, 40),
      color: kWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kPrimaryColor, width: 1),
      ),
      onSelected: (value) {
        if (value == 'edit') {
          _showEditVendorDialog(context, vendor);
        } else if (value == 'delete') {
          _showDeleteConfirmation(context, vendor);
        }
      },
      itemBuilder: (context) => [
        _buildPopupItem('edit', Icons.edit_note_rounded, 'Edit Profile', kPrimaryColor),
        const PopupMenuDivider(height: 1),
        _buildPopupItem('delete', Icons.delete_forever_rounded, 'Remove Vendor', kErrorColor),
      ],
    );
  }

  PopupMenuItem<String> _buildPopupItem(String value, IconData icon, String label, Color color) {
    return PopupMenuItem(
      value: value,
      height: 50,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded, size: 64, color: kGrey300),
          const SizedBox(height: 16),
          const Text(
            'No vendors found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kBlack87),
          ),
          const SizedBox(height: 8),
          const Text(
            'Vendors will be added automatically\nduring stock purchases.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: kBlack54),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DIALOGS
  // ==========================================

  void _showAddVendorDialog(BuildContext context) {
    final nameCtrl = TextEditingController(), phoneCtrl = TextEditingController(), gstinCtrl = TextEditingController(), addressCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: kWhite,
        title: const Text('Add New Vendor', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSectionLabel("IDENTITY"),
              _buildDialogField(nameCtrl, 'Vendor Name *', Icons.person_rounded),
              const SizedBox(height: 12),
              _buildDialogField(phoneCtrl, 'Phone Number', Icons.phone_android_rounded, type: TextInputType.phone),
              const SizedBox(height: 20),
              _buildSectionLabel("TAX & LOCATION"),
              _buildDialogField(gstinCtrl, 'GSTIN (Optional)', Icons.description_rounded),
              const SizedBox(height: 12),
              _buildDialogField(addressCtrl, 'Physical Address', Icons.location_on_rounded, maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(fontWeight: FontWeight.bold, color: kBlack54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              try {
                final vendorsCollection = await FirestoreService().getStoreCollection('vendors');
                await vendorsCollection.add({
                  'name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'gstin': gstinCtrl.text.trim().isEmpty ? null : gstinCtrl.text.trim(),
                  'address': addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                  'totalPurchases': 0.0,
                  'purchaseCount': 0,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (mounted) { Navigator.pop(context); _loadVendors(); }
              } catch (e) { debugPrint(e.toString()); }
            },
            child: const Text('ADD VENDOR', style: TextStyle(color: kWhite, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }

  void _showEditVendorDialog(BuildContext context, Map<String, dynamic> vendor) {
    final nameCtrl = TextEditingController(text: vendor['name']), phoneCtrl = TextEditingController(text: vendor['phone']), gstinCtrl = TextEditingController(text: vendor['gstin']), addressCtrl = TextEditingController(text: vendor['address']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: kWhite,
        title: const Text('Edit Vendor Details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSectionLabel("IDENTITY"),
              _buildDialogField(nameCtrl, 'Vendor Name', Icons.person_rounded),
              const SizedBox(height: 12),
              _buildDialogField(phoneCtrl, 'Phone Number', Icons.phone_android_rounded, type: TextInputType.phone),
              const SizedBox(height: 20),
              _buildSectionLabel("TAX & LOCATION"),
              _buildDialogField(gstinCtrl, 'GSTIN', Icons.description_rounded),
              const SizedBox(height: 12),
              _buildDialogField(addressCtrl, 'Physical Address', Icons.location_on_rounded, maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(fontWeight: FontWeight.bold, color: kBlack54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              try {
                final vendorsCollection = await FirestoreService().getStoreCollection('vendors');
                await vendorsCollection.doc(vendor['id']).update({
                  'name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'gstin': gstinCtrl.text.trim().isEmpty ? null : gstinCtrl.text.trim(),
                  'address': addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                  'lastUpdated': FieldValue.serverTimestamp(),
                });
                if (mounted) { Navigator.pop(context); _loadVendors(); }
              } catch (e) { debugPrint(e.toString()); }
            },
            child: const Text('Save changes', style: TextStyle(color: kWhite, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Map<String, dynamic> vendor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: kWhite,
        title: const Text('Remove Vendor?', style: TextStyle(fontWeight: FontWeight.w800, color: kBlack87)),
        content: Text('Are you sure you want to remove "${vendor['name']}"? This action cannot be undone.', style: const TextStyle(color: kBlack54, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(fontWeight: FontWeight.bold, color: kBlack54))),
          ElevatedButton(
            onPressed: () async {
              try {
                final vendorsCollection = await FirestoreService().getStoreCollection('vendors');
                await vendorsCollection.doc(vendor['id']).delete();
                if (mounted) { Navigator.pop(context); _loadVendors(); }
              } catch (e) { debugPrint(e.toString()); }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kErrorColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text("Delete", style: TextStyle(color: kWhite,fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) => Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(bottom: 8, left: 4), child: Text(text, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54, letterSpacing: 0.5))));

  Widget _buildNoResults() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.search_off_rounded, size: 64, color: kGrey300), const SizedBox(height: 16), Text('No results for "$_searchQuery"', style: const TextStyle(color: kBlack54))]));

  Widget _buildDialogField(TextEditingController ctrl, String label, IconData icon, {TextInputType type = TextInputType.text, int maxLines = 1}) {
    return ValueListenableBuilder(
      valueListenable: ctrl,
      builder: (context, val, child) {
        bool filled = ctrl.text.isNotEmpty;
        return Container(
          decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: filled ? kPrimaryColor : kGrey200, width: filled ? 1.5 : 1.0)),
          child: TextField(
            controller: ctrl, keyboardType: type, maxLines: maxLines,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack87),
            decoration: InputDecoration(hintText: label, prefixIcon: Icon(icon, color: filled ? kPrimaryColor : kBlack54, size: 18), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          ),
        );
      },
    );
  }
}