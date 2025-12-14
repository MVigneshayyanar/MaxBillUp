import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';

const Color kPrimaryColor = Color(0xFF2196F3);
const Color kBgColor = Color(0xFFF5F5F5);

class TaxSettingsPage extends StatefulWidget {
  final String uid;

  const TaxSettingsPage({Key? key, required this.uid}) : super(key: key);

  @override
  State<TaxSettingsPage> createState() => _TaxSettingsPageState();
}

class _TaxSettingsPageState extends State<TaxSettingsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controllers for Add New Tax
  final TextEditingController _taxPercentController = TextEditingController();
  String _selectedTaxName = 'GST';

  // Predefined tax names
  final List<String> _taxNames = ['GST', 'SGST', 'CGST', 'IGST', 'VAT'];

  // Default tax type for Quick Sale
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

  // Load default tax type from backend
  Future<void> _loadDefaultTaxType() async {
    try {
      final doc = await FirestoreService().getDocument('settings', 'taxSettings');
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        setState(() {
          _defaultTaxType = data?['defaultTaxType'] ?? 'Price is without Tax';
        });
      }
    } catch (e) {
      debugPrint('Error loading tax type: $e');
    }
  }

  // Save default tax type to backend
  Future<void> _saveDefaultTaxType() async {
    try {
      await FirestoreService().setDocument('settings', 'taxSettings', {
        'defaultTaxType': _defaultTaxType,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tax settings updated successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Update tax active status
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

  // Add new tax
  Future<void> _addNewTax() async {
    if (_taxPercentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter tax percentage'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final taxPercent = double.tryParse(_taxPercentController.text);
    if (taxPercent == null || taxPercent < 0 || taxPercent > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter valid tax percentage (0-100)'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    try {
      // Check if tax already exists
      final existingTaxes = await FirestoreService().getStoreCollection('taxes');
      final querySnapshot = await existingTaxes
          .where('name', isEqualTo: _selectedTaxName)
          .where('percentage', isEqualTo: taxPercent)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('This tax already exists'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating),
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
          const SnackBar(
              content: Text('Tax added successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  // Show create new tax name dialog
  void _showCreateTaxNameDialog() {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create New Tax Type',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter a name for the new tax category (e.g., UTGST)',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Tax Name',
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kPrimaryColor),
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (nameController.text.trim().isNotEmpty) {
                      setState(() {
                        if (!_taxNames.contains(nameController.text.trim().toUpperCase())) {
                          _taxNames.add(nameController.text.trim().toUpperCase());
                          _selectedTaxName = nameController.text.trim().toUpperCase();
                        }
                      });
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Create Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show products associated with a tax
  void _showTaxProducts(BuildContext context, Map<String, dynamic> taxData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${taxData['name']} Products',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Tax Rate: ${taxData['percentage']}%',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(backgroundColor: Colors.grey[100]),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: FutureBuilder<Stream<QuerySnapshot>>(
                  future: FirestoreService().getCollectionStream('products'),
                  builder: (context, streamFutureSnapshot) {
                    if (streamFutureSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (streamFutureSnapshot.hasError || !streamFutureSnapshot.hasData) {
                      return Center(child: Text('Unable to load products'));
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: streamFutureSnapshot.data,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(
                                  'No products found for this tax',
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          );
                        }

                        // Filter products for this tax locally
                        // Assumes products have 'taxPercentage' or 'taxName' field
                        // Adjust 'taxPercentage' to match your actual Product schema field
                        final products = snapshot.data!.docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          // Check against percentage or name
                          return (data['taxPercentage'] == taxData['percentage']) ||
                              (data['tax'] == taxData['percentage']) || // Common field name alternative
                              (data['taxName'] == taxData['name']);
                        }).toList();

                        if (products.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.filter_list_off, size: 48, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(
                                  'No products match this tax rate',
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          controller: controller,
                          itemCount: products.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 20, endIndent: 20),
                          itemBuilder: (context, index) {
                            final product = products[index].data() as Map<String, dynamic>;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: product['imageUrl'] != null && product['imageUrl'].isNotEmpty
                                    ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(product['imageUrl'], fit: BoxFit.cover),
                                )
                                    : Icon(Icons.shopping_bag_outlined, color: Colors.grey[400]),
                              ),
                              title: Text(
                                product['name'] ?? 'Unknown Product',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'Price: ${product['price'] ?? 0}',
                                style: TextStyle(color: Colors.grey[600]),
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        title: Text(context.tr('tax_settings'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          tabs: const [
            Tab(text: 'Taxes'),
            Tab(text: 'Tax for Quick Sale'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTaxesTab(),
          _buildQuickSaleTaxTab(),
        ],
      ),
    );
  }

  // Taxes Tab
  Widget _buildTaxesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Add New Tax Section Card
          Card(
            elevation: 2,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Add New Tax Rate',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      // Shortcut to add new tax name
                      TextButton.icon(
                        onPressed: _showCreateTaxNameDialog,
                        icon: const Icon(Icons.add_circle_outline, size: 16),
                        label: const Text("New Type"),
                        style: TextButton.styleFrom(
                          foregroundColor: kPrimaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          backgroundColor: kPrimaryColor.withOpacity(0.05),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      // Tax Name Dropdown
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Tax Type",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedTaxName,
                                  isExpanded: true,
                                  icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
                                  style: TextStyle(fontSize: 16, color: Colors.grey[800], fontWeight: FontWeight.w500),
                                  items: _taxNames.map((name) {
                                    return DropdownMenuItem(value: name, child: Text(name));
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedTaxName = value!;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Tax Percentage Input
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Percentage (%)",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _taxPercentController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                hintText: '0.0',
                                filled: true,
                                fillColor: Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: kPrimaryColor),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _addNewTax,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Add Tax Rate', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              'Active Tax Rates',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Tax List
          FutureBuilder<Stream<QuerySnapshot>>(
            // 1. Get the stream Future first
            future: FirestoreService().getCollectionStream('taxes'),
            builder: (context, streamFutureSnapshot) {
              if (streamFutureSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ));
              }
              if (streamFutureSnapshot.hasError) {
                return Center(child: Text('Error: ${streamFutureSnapshot.error}'));
              }
              if (!streamFutureSnapshot.hasData) {
                return const Center(child: Text('Unable to load taxes'));
              }

              // 2. Use the retrieved stream
              return StreamBuilder<QuerySnapshot>(
                stream: streamFutureSnapshot.data,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(),
                    ));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'No taxes added yet',
                              style: TextStyle(color: Colors.grey[500], fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final taxes = snapshot.data!.docs;

                  return Card(
                    elevation: 1,
                    color: Colors.white,
                    shadowColor: Colors.black12,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: taxes.length,
                      separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[100]),
                      itemBuilder: (context, index) {
                        final taxDoc = taxes[index];
                        final taxData = taxDoc.data() as Map<String, dynamic>;
                        final taxName = taxData['name'] ?? '';
                        final taxPercentage = taxData['percentage'] ?? 0.0;
                        final productCount = taxData['productCount'] ?? 0;

                        return ListTile(
                          onTap: () => _showTaxProducts(context, taxData),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: kPrimaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                taxName.substring(0, 1),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryColor),
                              ),
                            ),
                          ),
                          title: Text(
                            taxName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Text(
                            '${taxPercentage.toStringAsFixed(1)}% Rate',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$productCount',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Products',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // Quick Sale Tax Tab
  Widget _buildQuickSaleTaxTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Default Tax Type Card
          Card(
            elevation: 2,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.settings_suggest, color: kPrimaryColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Default Configuration',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            Text(
                              'How tax is calculated for quick sales',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _defaultTaxType,
                        isExpanded: true,
                        icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
                        style: TextStyle(fontSize: 15, color: Colors.grey[800], fontWeight: FontWeight.w500),
                        items: _taxTypes.map((type) {
                          return DropdownMenuItem(value: type, child: Text(type));
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _defaultTaxType = value!;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          // Update the backend with the new default tax configuration
                          // Using 'settings/quick_sale_config' as the path - adjust if needed
                          await FirebaseFirestore.instance
                              .collection('settings')
                              .doc('quick_sale_config')
                              .set({
                            'defaultTaxType': _defaultTaxType,
                            'lastUpdated': FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Settings updated successfully'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error updating settings: $e'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(context.tr('update_settings'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              'Quick Sale Tax Toggles',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Tax Toggles
          FutureBuilder<Stream<QuerySnapshot>>(
            future: FirestoreService().getCollectionStream('taxes'),
            builder: (context, streamFutureSnapshot) {
              if (streamFutureSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ));
              }
              if (streamFutureSnapshot.hasError) {
                return Center(child: Text('Error: ${streamFutureSnapshot.error}'));
              }
              if (!streamFutureSnapshot.hasData) {
                return const Center(child: Text('Unable to load taxes'));
              }

              return StreamBuilder<QuerySnapshot>(
                stream: streamFutureSnapshot.data,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(),
                    ));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'No taxes available. Add taxes in the "Taxes" tab.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[500], fontSize: 16),
                        ),
                      ),
                    );
                  }

                  final taxes = snapshot.data!.docs;

                  return Card(
                    elevation: 1,
                    shadowColor: Colors.black12,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: taxes.length,
                      separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[100]),
                      itemBuilder: (context, index) {
                        final taxDoc = taxes[index];
                        final taxData = taxDoc.data() as Map<String, dynamic>;
                        final taxName = taxData['name'] ?? '';
                        final taxPercentage = taxData['percentage'] ?? 0.0;
                        final isActive = taxData['isActive'] ?? false;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${taxPercentage.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                taxName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          trailing: Switch(
                            value: isActive,
                            activeColor: kPrimaryColor,
                            onChanged: (newValue) async {
                              if (newValue) {
                                // CASE: Turning ON a tax.
                                // We must turn this one ON and all others OFF.

                                final batch = FirebaseFirestore.instance.batch();

                                for (var doc in taxes) {
                                  if (doc.id == taxDoc.id) {
                                    // Set the selected tax to active
                                    batch.update(doc.reference, {'isActive': true});
                                  } else {
                                    // Set all other taxes to inactive
                                    final otherData = doc.data() as Map<String, dynamic>;
                                    // Only update if it is currently active (saves writes)
                                    if (otherData['isActive'] == true) {
                                      batch.update(doc.reference, {'isActive': false});
                                    }
                                  }
                                }

                                // Commit all changes simultaneously
                                await batch.commit();

                              } else {
                                // CASE: Turning OFF the current tax.
                                // Just turn it off (user might want 0 taxes selected).
                                _updateTaxStatus(taxDoc.id, false);
                              }
                            },
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
