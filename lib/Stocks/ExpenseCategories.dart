import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';

// --- UI CONSTANTS ---
const Color _primaryColor = Color(0xFF2F7CF6);
const Color _errorColor = Color(0xFFFF5252);
const Color _cardBorder = Color(0xFFE3F2FD);
const Color _scaffoldBg = Colors.white;

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
        title: Text(context.tr('expense_categories'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            Tab(text: context.tr('categories')),
            Tab(text: context.tr('expense_names')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Expense Categories
          _buildCategoriesTab(),
          // Tab 2: Expense Names
          _buildExpenseNamesTab(),
        ],
      ),
    );
  }

  Widget _buildCategoriesTab() {
    return Column(
      children: [
        // Search Bar and Add Button Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: context.tr('search'),
                      prefixIcon: const Icon(Icons.search, color: _primaryColor),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _showAddCategoryDialog(context),
                icon: const Icon(Icons.add, color: Colors.white, size: 20),
                label: const Text(
                  'Add',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),

        // List of Categories
        Expanded(
          child: FutureBuilder<Stream<QuerySnapshot>>(
            future: _categoriesStreamFuture,
            builder: (context, futureSnapshot) {
              if (futureSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!futureSnapshot.hasData) {
                return const Center(child: Text("Unable to load categories"));
              }

              return StreamBuilder<QuerySnapshot>(
                stream: futureSnapshot.data!,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  final categories = snapshot.data!.docs.where((doc) {
                    if (_searchQuery.isEmpty) return true;
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final description = (data['description'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery) || description.contains(_searchQuery);
                  }).toList();

                  if (categories.isEmpty) {
                    return const Center(
                      child: Text(
                        'No matching categories found',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final data = categories[index].data() as Map<String, dynamic>;
                      final name = data['name'] ?? 'Unnamed Category';
                      final timestamp = data['timestamp'] as Timestamp?;
                      final date = timestamp?.toDate();
                      final dateString =
                      date != null ? DateFormat('dd MMM yyyy').format(date) : 'N/A';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _cardBorder),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.category_outlined,
                              color: _primaryColor,
                              size: 24,
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            'Created: $dateString',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_outlined, color: _primaryColor),
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
        // Search Bar Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _cardBorder),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: context.tr('search'),
                prefixIcon: const Icon(Icons.search, color: _primaryColor),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),

        // List of Expense Names
        Expanded(
          child: FutureBuilder<Stream<QuerySnapshot>>(
            future: _expenseNamesStreamFuture,
            builder: (context, futureSnapshot) {
              if (futureSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!futureSnapshot.hasData) {
                return const Center(child: Text("Unable to load expense names"));
              }

              return StreamBuilder<QuerySnapshot>(
                stream: futureSnapshot.data!,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyStateExpenseNames();
                  }

                  final expenseNames = snapshot.data!.docs.where((doc) {
                    if (_searchQuery.isEmpty) return true;
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery);
                  }).toList();

                  if (expenseNames.isEmpty) {
                    return const Center(
                      child: Text(
                        'No matching expense names found',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: expenseNames.length,
                    itemBuilder: (context, index) {
                      final data = expenseNames[index].data() as Map<String, dynamic>;
                      final name = data['name'] ?? 'Unnamed';
                      final usageCount = data['usageCount'] ?? 1;
                      final timestamp = data['lastUsed'] as Timestamp?;
                      final date = timestamp?.toDate();
                      final dateString =
                      date != null ? DateFormat('dd MMM yyyy').format(date) : 'N/A';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _cardBorder),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.receipt_long_outlined,
                              color: _primaryColor,
                              size: 24,
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'Used $usageCount time${usageCount > 1 ? 's' : ''}',
                                style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Last used: $dateString',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_outlined, color: _primaryColor),
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

  Widget _buildEmptyStateExpenseNames() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 80, color: _primaryColor.withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text(
            'No expense names found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Expense titles will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_outlined, size: 80, color: _primaryColor.withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text(
            'No categories found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();

    final List<String> suggestions = [
      'Salary', 'Bill', 'Fuel', 'Rent', 'Insurance',
      'Food', 'Tax', 'Advertisement', 'Fee', 'Loan',
      'Transportation', 'Miscellaneous'
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Row(
                children: [
                  Icon(Icons.category_outlined, color: _primaryColor),
                  SizedBox(width: 8),
                  Text('Add Category', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Select:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: suggestions.map((suggestion) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              nameController.text = suggestion;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: nameController.text == suggestion
                                  ? _primaryColor
                                  : _primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: nameController.text == suggestion
                                    ? _primaryColor
                                    : _primaryColor.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              suggestion,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: nameController.text == suggestion
                                    ? Colors.white
                                    : _primaryColor,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    _buildDialogField(nameController, 'Category Name *', Icons.category_outlined),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.tr('cancel')),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.tr('enter_category_name'))),
                      );
                      return;
                    }

                    try {
                      await FirestoreService().addDocument('expenseCategories', {
                        'name': nameController.text,
                        'timestamp': Timestamp.now(),
                        'uid': widget.uid,
                      });

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Category added successfully')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(context.tr('add'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDialogField(TextEditingController ctrl, String label, IconData icon,
      {int lines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _primaryColor, size: 20),
        filled: true,
        fillColor: _primaryColor.withOpacity(0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}

// Edit/Delete Category Dialog matching Expense Names style
class _EditDeleteCategoryDialog extends StatefulWidget {
  final String docId;
  final String initialName;
  final VoidCallback onChanged;
  const _EditDeleteCategoryDialog({required this.docId, required this.initialName, required this.onChanged});

  @override
  State<_EditDeleteCategoryDialog> createState() => _EditDeleteCategoryDialogState();
}

class _EditDeleteCategoryDialogState extends State<_EditDeleteCategoryDialog> {
  late TextEditingController _controller;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _update() async {
    final newName = _controller.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a category name')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirestoreService().updateDocument('expenseCategories', widget.docId, {'name': newName});
      widget.onChanged();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category updated successfully'), backgroundColor: _primaryColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: _errorColor),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _errorColor),
            SizedBox(width: 8),
            Text('Delete Category?'),
          ],
        ),
        content: const Text('Are you sure you want to delete this category? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _errorColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await FirestoreService().deleteDocument('expenseCategories', widget.docId);
        widget.onChanged();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category deleted successfully'), backgroundColor: _primaryColor),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e'), backgroundColor: _errorColor),
          );
        }
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Edit Category',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 24, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Input Field
            _buildCategoryInput(),

            const SizedBox(height: 24),

            // Update Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _update,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Text(
                  'Update',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Delete Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: _isLoading ? null : _delete,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _errorColor, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: _errorColor,
                    strokeWidth: 2,
                  ),
                )
                    : const Text(
                  'Delete',
                  style: TextStyle(color: _errorColor, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Custom Input Field matching AddExpenseTypePopup ---
  Widget _buildCategoryInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _controller,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
          decoration: InputDecoration(
            labelText: 'Category Name',
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            labelStyle: const TextStyle(color: Colors.black54, fontSize: 15),
            floatingLabelStyle: const TextStyle(color: _primaryColor, fontSize: 13, fontWeight: FontWeight.w600),
            filled: true,
            fillColor: kGreyBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kGrey300, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primaryColor, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "e.g. Salary, Rent, Fuel, Insurance, etc.",
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
      ],
    );
  }
}

class _EditDeleteExpenseNameDialog extends StatefulWidget {
  final String docId;
  final String initialName;
  final VoidCallback onChanged;
  const _EditDeleteExpenseNameDialog({required this.docId, required this.initialName, required this.onChanged});
  @override
  State<_EditDeleteExpenseNameDialog> createState() => _EditDeleteExpenseNameDialogState();
}

class _EditDeleteExpenseNameDialogState extends State<_EditDeleteExpenseNameDialog> {
  late TextEditingController _controller;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _update() async {
    final newName = _controller.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirestoreService().updateDocument('expenseNames', widget.docId, {'name': newName});
      widget.onChanged();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense name updated successfully'), backgroundColor: _primaryColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: _errorColor),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _errorColor),
            SizedBox(width: 8),
            Text('Delete Expense Name?'),
          ],
        ),
        content: const Text('Are you sure you want to delete this expense name? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _errorColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await FirestoreService().deleteDocument('expenseNames', widget.docId);
        widget.onChanged();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense name deleted successfully'), backgroundColor: _primaryColor),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e'), backgroundColor: _errorColor),
          );
        }
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Edit Expense Name',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 24, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Input Field
            _buildExpenseNameInput(),

            const SizedBox(height: 24),

            // Update Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _update,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Text(
                  'Update',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Delete Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: _isLoading ? null : _delete,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _errorColor, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: _errorColor,
                    strokeWidth: 2,
                  ),
                )
                    : const Text(
                  'Delete',
                  style: TextStyle(color: _errorColor, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Custom Input Field matching AddExpenseTypePopup ---
  Widget _buildExpenseNameInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _controller,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
          decoration: InputDecoration(
            labelText: 'Expense Name',
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            labelStyle: const TextStyle(color: Colors.black54, fontSize: 15),
            floatingLabelStyle: const TextStyle(color: _primaryColor, fontSize: 13, fontWeight: FontWeight.w600),
            filled: true,
            fillColor: kGreyBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kGrey300, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primaryColor, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "e.g. Rent Payment, Electricity Bill, Staff Salary, etc.",
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
      ],
    );
  }
}

