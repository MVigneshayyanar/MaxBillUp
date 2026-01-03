import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/Colors.dart';

class TaxSettingsPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;

  const TaxSettingsPage({super.key, required this.uid, required this.onBack});

  @override
  State<TaxSettingsPage> createState() => _TaxSettingsPageState();
}

class _TaxSettingsPageState extends State<TaxSettingsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _taxPercentController = TextEditingController();

  // Localized and expanded tax categories for UAE (Dubai) and global use
  String _selectedTaxName = 'VAT';
  final List<String> _taxNames = ['VAT', 'GST', 'CGST', 'SGST', 'IGST', 'Excise Tax', 'Zero Rated', 'Exempt'];

  String _defaultTaxType = 'Price is without Tax';
  final List<String> _taxTypes = [
    'Price includes Tax',
    'Price is without Tax',
    'Zero Rated Tax',
    'Exempt Tax',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDefaultTaxType();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _taxPercentController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultTaxType() async {
    try {
      final settingsCollection = await FirestoreService().getStoreCollection('settings');
      final doc = await settingsCollection.doc('taxSettings').get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>?;
        setState(() {
          _defaultTaxType = data?['defaultTaxType'] ?? 'Price is without Tax';
        });
      }
    } catch (e) {
      debugPrint('Error loading tax type: $e');
    }
  }

  Future<void> _saveDefaultTaxType() async {
    try {
      final settingsCollection = await FirestoreService().getStoreCollection('settings');
      await settingsCollection.doc('taxSettings').set({
        'defaultTaxType': _defaultTaxType,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Tax settings updated successfully', style: TextStyle(fontWeight: FontWeight.w600)),
            backgroundColor: kGoogleGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kErrorColor, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _updateTaxStatus(String taxId, bool isActive) async {
    try {
      await FirestoreService().updateDocument('taxes', taxId, {
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating tax status: $e');
    }
  }

  Future<void> _addNewTax() async {
    if (_taxPercentController.text.isEmpty) return;

    final taxPercent = double.tryParse(_taxPercentController.text);
    if (taxPercent == null || taxPercent < 0 || taxPercent > 100) return;

    try {
      final existingTaxes = await FirestoreService().getStoreCollection('taxes');
      final querySnapshot = await existingTaxes
          .where('name', isEqualTo: _selectedTaxName)
          .where('percentage', isEqualTo: taxPercent)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This tax rate already exists'), backgroundColor: kOrange, behavior: SnackBarBehavior.floating),
          );
        }
        return;
      }

      await FirestoreService().addDocument('taxes', {
        'name': _selectedTaxName,
        'percentage': taxPercent,
        'productCount': 0,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _taxPercentController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tax category added successfully'), backgroundColor: kGoogleGreen, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _showCreateTaxNameDialog() {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('NEW TAX CATEGORY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
              child: TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: const InputDecoration(hintText: 'e.g. CUSTOMS DUTY', prefixIcon: Icon(Icons.label_important_rounded, size: 20), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold, color: kBlack54))),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                setState(() {
                  final n = nameController.text.trim().toUpperCase();
                  if (!_taxNames.contains(n)) _taxNames.add(n);
                  _selectedTaxName = n;
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('CREATE', style: TextStyle(color: kWhite, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showTaxProducts(BuildContext context, Map<String, dynamic> taxData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(color: kWhite, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            children: [
              Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4, decoration: BoxDecoration(color: kGrey200, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(taxData['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kBlack87)),
                        Text('${taxData['percentage']}% Tax Rate', style: const TextStyle(color: kBlack54, fontSize: 12, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: kBlack54), style: IconButton.styleFrom(backgroundColor: kGreyBg)),
                  ],
                ),
              ),
              const Divider(height: 1, color: kGrey100),
              Expanded(
              child: FutureBuilder<Stream<QuerySnapshot>>(
                future: FirestoreService().getCollectionStream('Products'),
                builder: (context, streamFutureSnapshot) {
                  if (!streamFutureSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                  return StreamBuilder<QuerySnapshot>(
                    stream: streamFutureSnapshot.data,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                      final taxId = taxData['id'] as String?;
                      final products = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return (taxId != null && data['taxId'] == taxId) || (data['taxPercentage'] == taxData['percentage'] && data['taxName'] == taxData['name']);
                      }).toList();

                      if (products.isEmpty) {
                        return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.filter_list_off_rounded, size: 64, color: kGrey300), const SizedBox(height: 16), const Text('No products mapped here', style: TextStyle(color: kBlack54, fontWeight: FontWeight.w600))]));
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: products.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final p = products[index].data() as Map<String, dynamic>;
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
                            child: Row(children: [
                              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.shopping_bag_outlined, color: kBlack54, size: 20)),
                              const SizedBox(width: 14),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p['itemName'] ?? 'Product', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text('Price:${p['price'] ?? 0}', style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w600))])),
                            ]),
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
      ),
    )
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          widget.onBack();
        }
      },
      child: Scaffold(
        backgroundColor: kGreyBg,
        appBar: AppBar(
          title: Text(context.tr('tax_settings').toUpperCase(), style: const TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
          backgroundColor: kPrimaryColor,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 18), onPressed: widget.onBack),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: kWhite,
            indicatorWeight: 4,
            labelColor: kWhite,
            unselectedLabelColor: kWhite.withOpacity(0.7),
            labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5),
            tabs: const [
              Tab(text: 'TAX RATES'),
              Tab(text: 'QUICK BILLING TAX')
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [_buildTaxesTab(), _buildQuickSaleTaxTab()],
        ),
      ),
    );
  }

  Widget _buildTaxesTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildSectionLabel("Create New Tax Category"),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: kGrey200)),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(flex: 3, child: _buildDialogDropdown("Category", _selectedTaxName, _taxNames, (v) => setState(() => _selectedTaxName = v!))),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: _buildFlatField("Rate (%)", _taxPercentController, TextInputType.number)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showCreateTaxNameDialog,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text("NEW TYPE"),
                      style: OutlinedButton.styleFrom(foregroundColor: kPrimaryColor, side: const BorderSide(color: kPrimaryColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _addNewTax,
                      style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('ADD RATE', style: TextStyle(fontWeight: FontWeight.w900, color: kWhite)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionLabel("Active Tax Categories"),
        _buildLiveTaxList(),
      ],
    );
  }

  Widget _buildLiveTaxList() {
    return FutureBuilder<Stream<QuerySnapshot>>(
      future: FirestoreService().getCollectionStream('taxes'),
      builder: (context, streamFutureSnapshot) {
        if (!streamFutureSnapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
        return StreamBuilder<QuerySnapshot>(
          stream: streamFutureSnapshot.data,
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState("No tax rates configured.");
            final taxes = snapshot.data!.docs;
            return Container(
              decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: kGrey200)),
              child: ListView.separated(
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                itemCount: taxes.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: kGrey100),
                itemBuilder: (context, index) {
                  final taxData = taxes[index].data() as Map<String, dynamic>;
                  final name = taxData['name'] ?? '';
                  final perc = taxData['percentage'] ?? 0.0;
                  final count = taxData['productCount'] ?? 0;
                  return ListTile(
                    onTap: () => _showTaxProducts(context, {...taxData, 'id': taxes[index].id}),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(backgroundColor: kPrimaryColor.withOpacity(0.1), radius: 18, child: Text(name[0], style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900, fontSize: 14))),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: Text('$perc% Rate', style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w600)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(6)), child: Text('$count ITEMS', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54))),
                        const SizedBox(width: 4),
                        IconButton(icon: const Icon(Icons.delete_outline_rounded, color: kErrorColor, size: 20), onPressed: () => _deleteTax(taxes[index].id, name)),
                        const Icon(Icons.arrow_forward_ios_rounded, color: kGrey300, size: 12),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  void _deleteTax(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Tax Category?'),
        content: Text('Remove "$name"? This will affect products mapped to this category.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: kErrorColor), onPressed: () => Navigator.pop(ctx, true), child: const Text('DELETE', style: TextStyle(color: kWhite))),
        ],
      ),
    );
    if (confirm == true) await FirestoreService().deleteDocument('taxes', id);
  }

  Widget _buildQuickSaleTaxTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionLabel("Tax Calculation Method"),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: kGrey200)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('DEFAULT STRATEGY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 1)),
              const SizedBox(height: 12),
              _buildDialogDropdown(null, _defaultTaxType, _taxTypes, (v) => setState(() => _defaultTaxType = v!)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveDefaultTaxType,
                  style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('SAVE PREFERENCES', style: TextStyle(fontWeight: FontWeight.w900, color: kWhite, letterSpacing: 0.5)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionLabel("Active Quick Billing Tax"),
        _buildQuickBillTaxToggles(),
      ],
    );
  }

  Widget _buildQuickBillTaxToggles() {
    return FutureBuilder<Stream<QuerySnapshot>>(
      future: FirestoreService().getCollectionStream('taxes'),
      builder: (context, streamFutureSnapshot) {
        if (!streamFutureSnapshot.hasData) return const Center(child: CircularProgressIndicator());
        return StreamBuilder<QuerySnapshot>(
          stream: streamFutureSnapshot.data,
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState("Configure tax rates in the first tab.");
            final taxes = snapshot.data!.docs;
            return Container(
              decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: kGrey200)),
              child: ListView.separated(
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                itemCount: taxes.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: kGrey100),
                itemBuilder: (context, index) {
                  final taxDoc = taxes[index];
                  final data = taxDoc.data() as Map<String, dynamic>;
                  final active = data['isActive'] ?? false;
                  return SwitchListTile.adaptive(
                    activeColor: kPrimaryColor,
                    title: Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('${data['percentage']}% Standard Rate', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kBlack54)),
                    value: active,
                    onChanged: (v) async {
                      if (v) {
                        // ENFORCE SINGLE SELECTION: Activate this specific tax and deactivate all others in the store
                        final batch = FirebaseFirestore.instance.batch();
                        for (var doc in taxes) {
                          batch.update(doc.reference, {'isActive': doc.id == taxDoc.id});
                        }
                        await batch.commit();
                      } else {
                        await _updateTaxStatus(taxDoc.id, false);
                      }
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 12, left: 4), child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 1.5)));

  Widget _buildFlatField(String label, TextEditingController ctrl, TextInputType type) => Container(decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kGrey200)), child: TextField(controller: ctrl, keyboardType: type, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), decoration: InputDecoration(hintText: label, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))));

  Widget _buildDialogDropdown(String? label, String current, List<String> items, Function(String?) onSel) => Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kGrey200)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: items.contains(current) ? current : (items.isNotEmpty ? items.first : null), isExpanded: true, items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)))).toList(), onChanged: onSel)));

  Widget _buildEmptyState(String msg) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const SizedBox(height: 32), Icon(Icons.receipt_long_outlined, size: 48, color: kGrey300), const SizedBox(height: 16), Text(msg, style: const TextStyle(color: kBlack54, fontWeight: FontWeight.w600))]));
}