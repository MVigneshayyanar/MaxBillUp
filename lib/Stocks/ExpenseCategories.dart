import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';

class ExpenseCategoriesPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;

  const ExpenseCategoriesPage({super.key, required this.uid, required this.onBack});

  @override
  State<ExpenseCategoriesPage> createState() => _ExpenseCategoriesPageState();
}

class _ExpenseCategoriesPageState extends State<ExpenseCategoriesPage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late Future<Stream<QuerySnapshot>> _categoriesStreamFuture;
  late Future<Stream<QuerySnapshot>> _expenseNamesStreamFuture;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _categoriesStreamFuture = FirestoreService().getCollectionStream('expenseCategories');
    _expenseNamesStreamFuture = FirestoreService().getCollectionStream('expenseNames');
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        title: Text(context.tr('Expense Types'),
            style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kWhite, size: 20),
          onPressed: widget.onBack,
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: kWhite,
          indicatorWeight: 4,
          labelColor: kWhite,
          unselectedLabelColor: kWhite.withOpacity(0.7),
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5),
          tabs: [
            Tab(text: context.tr('Types').toUpperCase()),
            Tab(text: context.tr('expense_names').toUpperCase()),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategoriesTab(),
          _buildExpenseNamesTab(),
        ],
      ),
    );
  }

  Widget _buildCategoriesTab() {
    return Column(
      children: [
        // ENTERPRISE SEARCH & ADD HEADER
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
              InkWell(
                onTap: () => _showAddCategoryDialog(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: kPrimaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_rounded, color: kWhite, size: 24),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: FutureBuilder<Stream<QuerySnapshot>>(
            future: _categoriesStreamFuture,
            builder: (context, futureSnapshot) {
              if (futureSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
              }
              if (!futureSnapshot.hasData) return const Center(child: Text("Unable to load categories"));

              return StreamBuilder<QuerySnapshot>(
                stream: futureSnapshot.data!,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();

                  final categories = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery);
                  }).toList();

                  if (categories.isEmpty) return _buildNoResults();

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final data = categories[index].data() as Map<String, dynamic>;
                      final name = data['name'] ?? 'Unnamed Type';
                      final ts = data['timestamp'] as Timestamp?;
                      final dateStr = ts != null ? DateFormat('dd MMM yyyy').format(ts.toDate()) : 'N/A';

                      return Container(
                        decoration: BoxDecoration(
                          color: kWhite,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kGrey200),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          leading: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: kPrimaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.category_rounded, color: kPrimaryColor, size: 20),
                          ),
                          title: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kBlack87)),
                          subtitle: Text('Created: $dateStr', style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w500)),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_note_rounded, color: kPrimaryColor, size: 26),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => _EditDeleteCategoryDialog(
                                  docId: categories[index].id,
                                  initialName: name,
                                  onChanged: () => setState(() {}),
                                ),
                              );
                            },
                          ),
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
    );
  }

  Widget _buildExpenseNamesTab() {
    return Column(
      children: [
        // ENTERPRISE SEARCH HEADER
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: const BoxDecoration(
            color: kWhite,
            border: Border(bottom: BorderSide(color: kGrey200)),
          ),
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
                hintText: "Search expense titles...",
                hintStyle: TextStyle(color: kBlack54, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: kPrimaryColor, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 7),
              ),
            ),
          ),
        ),

        Expanded(
          child: FutureBuilder<Stream<QuerySnapshot>>(
            future: _expenseNamesStreamFuture,
            builder: (context, futureSnapshot) {
              if (futureSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
              }
              if (!futureSnapshot.hasData) return const Center(child: Text("Unable to load expense names"));

              return StreamBuilder<QuerySnapshot>(
                stream: futureSnapshot.data!,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyStateExpenseNames();

                  final expenseNames = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery);
                  }).toList();

                  if (expenseNames.isEmpty) return _buildNoResults();

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: expenseNames.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final data = expenseNames[index].data() as Map<String, dynamic>;
                      final name = data['name'] ?? 'Unnamed';
                      final usageCount = data['usageCount'] ?? 1;
                      final ts = data['lastUsed'] as Timestamp?;
                      final dateStr = ts != null ? DateFormat('dd MMM yy').format(ts.toDate()) : 'N/A';

                      return Container(
                        decoration: BoxDecoration(
                          color: kWhite,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kGrey200),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(14),
                          leading: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: kOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.receipt_long_rounded, color: kOrange, size: 20),
                          ),
                          title: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kBlack87)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('Used $usageCount times • Last: $dateStr',
                                style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w500)),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_note_rounded, color: kPrimaryColor, size: 26),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => _EditDeleteExpenseNameDialog(
                                  docId: expenseNames[index].id,
                                  initialName: name,
                                  onChanged: () => setState(() {}),
                                ),
                              );
                            },
                          ),
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
    );
  }

  Widget _buildEmptyStateExpenseNames() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.receipt_long_outlined, size: 64, color: kGrey300), const SizedBox(height: 16), const Text('No expense names found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kBlack87))]));
  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.category_rounded, size: 64, color: kGrey300), const SizedBox(height: 16), const Text('No categories found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kBlack87))]));
  Widget _buildNoResults() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.search_off_rounded, size: 64, color: kGrey300), const SizedBox(height: 16), Text('No results for "$_searchQuery"', style: const TextStyle(color: kBlack54))]));

  void _showAddCategoryDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final List<String> suggestions = ['Salary', 'Rent', 'Fuel', 'Food', 'Electricity', 'Bill', 'Insurance', 'Miscellaneous'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: kWhite,
              title: const Text('Add New Type', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionLabel("QUICK SELECT"),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: suggestions.map((s) {
                        final bool isSel = nameController.text == s;
                        return GestureDetector(
                          onTap: () => setDialogState(() => nameController.text = s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSel ? kPrimaryColor : kGreyBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSel ? kPrimaryColor : kGrey200),
                            ),
                            child: Text(s, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isSel ? kWhite : kBlack54)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionLabel("CATEGORY IDENTITY"),
                    _buildDialogField(nameController, 'Category Name', Icons.category_rounded),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(fontWeight: FontWeight.bold, color: kBlack54))),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;
                    await FirestoreService().addDocument('expenseCategories', {
                      'name': nameController.text.trim(),
                      'timestamp': FieldValue.serverTimestamp(),
                      'uid': widget.uid,
                    });
                    if (mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('ADD Type', style: TextStyle(color: kWhite, fontWeight: FontWeight.w800)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSectionLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 10, left: 4), child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5)));

  Widget _buildDialogField(TextEditingController ctrl, String label, IconData icon) {
    return ValueListenableBuilder(
      valueListenable: ctrl,
      builder: (context, val, child) {
        bool filled = ctrl.text.isNotEmpty;
        return Container(
          decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: filled ? kPrimaryColor : kGrey200, width: filled ? 1.5 : 1.0)),
          child: TextField(
            controller: ctrl,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack87),
            decoration: InputDecoration(hintText: label, prefixIcon: Icon(icon, color: filled ? kPrimaryColor : kBlack54, size: 18), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// INTERNAL DIALOG: EDIT/DELETE CATEGORY
// -----------------------------------------------------------------------------
class _EditDeleteCategoryDialog extends StatefulWidget {
  final String docId;
  final String initialName;
  final VoidCallback onChanged;
  const _EditDeleteCategoryDialog({required this.docId, required this.initialName, required this.onChanged});
  @override State<_EditDeleteCategoryDialog> createState() => _EditDeleteCategoryDialogState();
}

class _EditDeleteCategoryDialogState extends State<_EditDeleteCategoryDialog> {
  late TextEditingController _controller;
  bool _isLoading = false;

  @override
  void initState() { super.initState(); _controller = TextEditingController(text: widget.initialName); }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  Future<void> _update() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await FirestoreService().updateDocument('expenseCategories', widget.docId, {'name': _controller.text.trim()});
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) { print(e.toString()); }
    finally { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('Delete Category?'), content: const Text('This will remove this category from the system.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: kErrorColor), onPressed: () => Navigator.pop(ctx, true), child: const Text('DELETE', style: TextStyle(color: kWhite)))]));
    if (confirm == true) {
      setState(() => _isLoading = true);
      await FirestoreService().deleteDocument('expenseCategories', widget.docId);
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: kWhite,
      title: const Text('Edit Type', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kPrimaryColor, width: 1.5)),
            child: TextField(
              controller: _controller,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.edit_rounded, color: kPrimaryColor, size: 18), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _delete, child: const Text("DELETE", style: TextStyle(color: kErrorColor, fontWeight: FontWeight.bold))),
        ElevatedButton(onPressed: _update, style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0), child: const Text("SAVE", style: TextStyle(color: kWhite))),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// INTERNAL DIALOG: EDIT/DELETE EXPENSE NAME
// -----------------------------------------------------------------------------
class _EditDeleteExpenseNameDialog extends StatefulWidget {
  final String docId;
  final String initialName;
  final VoidCallback onChanged;
  const _EditDeleteExpenseNameDialog({required this.docId, required this.initialName, required this.onChanged});
  @override State<_EditDeleteExpenseNameDialog> createState() => _EditDeleteExpenseNameDialogState();
}

class _EditDeleteExpenseNameDialogState extends State<_EditDeleteExpenseNameDialog> {
  late TextEditingController _controller;
  @override
  void initState() { super.initState(); _controller = TextEditingController(text: widget.initialName); }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: kWhite,
      title: const Text('Edit Expense Title', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      content: Container(
        decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kPrimaryColor, width: 1.5)),
        child: TextField(
          controller: _controller,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.text_fields_rounded, color: kPrimaryColor, size: 18), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
        ),
      ),
      actions: [
        TextButton(onPressed: () async { await FirestoreService().deleteDocument('expenseNames', widget.docId); widget.onChanged(); if(mounted) Navigator.pop(context); }, child: const Text("DELETE", style: TextStyle(color: kErrorColor, fontWeight: FontWeight.bold))),
        ElevatedButton(onPressed: () async { await FirestoreService().updateDocument('expenseNames', widget.docId, {'name': _controller.text.trim()}); widget.onChanged(); if(mounted) Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0), child: const Text("SAVE", style: TextStyle(color: kWhite))),
      ],
    );
  }
}