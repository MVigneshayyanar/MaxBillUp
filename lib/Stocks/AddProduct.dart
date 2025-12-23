import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Sales/BarcodeScanner.dart';
import 'package:maxbillup/utils/permission_helper.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/Stocks/Stock.dart';
import 'package:maxbillup/utils/translation_helper.dart';

class AddProductPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final String? preSelectedCategory;
  final String? productId;
  final Map<String, dynamic>? existingData;

  const AddProductPage({
    super.key,
    required this.uid,
    this.userEmail,
    this.preSelectedCategory,
    this.productId,
    this.existingData,
  });

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _costPriceController = TextEditingController();
  final TextEditingController _mrpController = TextEditingController();
  final TextEditingController _productCodeController = TextEditingController();
  final TextEditingController _hsnController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  // State
  String? _selectedCategory;
  bool _stockEnabled = true;
  String? _selectedStockUnit = 'Piece';
  Stream<List<String>>? _unitsStream;

  // Tax State
  String _selectedTaxType = 'Price is without Tax';
  List<Map<String, dynamic>> _fetchedTaxes = [];
  String? _selectedTaxId;
  double _currentTaxPercentage = 0.0;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.preSelectedCategory;
    _checkPermission();
    _fetchUnits();
    _fetchTaxesFromBackend();

    if (widget.existingData != null) {
      _loadExistingData();
    }
  }

  // --- Firestore Logic ---
  Future<void> _fetchTaxesFromBackend() async {
    try {
      final storeId = await FirestoreService().getCurrentStoreId();
      if (storeId == null) return;
      final snapshot = await FirebaseFirestore.instance
          .collection('store')
          .doc(storeId)
          .collection('taxes')
          .get();
      setState(() {
        _fetchedTaxes = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? 'Unnamed',
            'percentage': (data['percentage'] ?? 0.0).toDouble(),
          };
        }).toList();
        if (widget.existingData != null && widget.existingData!['taxId'] != null) {
          _selectedTaxId = widget.existingData!['taxId'];
          _currentTaxPercentage = (widget.existingData!['taxPercentage'] ?? 0.0).toDouble();
        }
      });
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<void> _addNewTaxToBackend(String name, double percentage) async {
    try {
      final storeId = await FirestoreService().getCurrentStoreId();
      if (storeId == null) return;
      final newTaxDoc = {
        'name': name, 'percentage': percentage, 'isActive': true, 'productCount': 0,
        'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(),
      };
      final docRef = await FirebaseFirestore.instance.collection('store').doc(storeId).collection('taxes').add(newTaxDoc);
      await _fetchTaxesFromBackend();
      setState(() { _selectedTaxId = docRef.id; _currentTaxPercentage = percentage; });
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<void> _incrementTaxProductCount(String taxId) async {
    try {
      final storeId = await FirestoreService().getCurrentStoreId();
      if (storeId == null) return;
      await FirebaseFirestore.instance.collection('store').doc(storeId).collection('taxes').doc(taxId).update({'productCount': FieldValue.increment(1)});
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<void> _checkPermission() async {
    final userData = await PermissionHelper.getUserPermissions(widget.uid);
    final role = userData['role'] as String;
    final permissions = userData['permissions'] as Map<String, dynamic>;
    final isAdmin = role.toLowerCase() == 'admin' || role.toLowerCase() == 'administrator';
    if (permissions['addProduct'] != true && !isAdmin && mounted) {
      Navigator.pop(context);
      await PermissionHelper.showPermissionDeniedDialog(context);
    }
  }

  void _fetchUnits() async {
    final storeId = await FirestoreService().getCurrentStoreId();
    if (storeId == null) return;
    setState(() {
      _unitsStream = FirestoreService().storeCollection.doc(storeId).collection('units').snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
    });
  }

  void _generateProductCode() {
    final code = 'PRD${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    setState(() => _productCodeController.text = code);
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.push(context, CupertinoPageRoute(
      builder: (context) => BarcodeScannerPage(title: 'Scan Product Barcode', onBarcodeScanned: (barcode) => Navigator.pop(context, barcode)),
    ));
    if (result != null && mounted) setState(() => _barcodeController.text = result);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        appBar: AppBar(
          backgroundColor: const Color(0xFF2196F3),
          elevation: 0,
          centerTitle: true,
          title: Text(context.tr(widget.productId != null ? 'edit_product' : 'add_product'),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: "Basic Details"),
              Tab(text: "Advanced"),
            ],
          ),
        ),
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: TabBarView(
                  children: [
                    _buildBasicTab(),
                    _buildAdvancedTab(),
                  ],
                ),
              ),
              _buildBottomSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  // --- Tab 1: Basics ---
  Widget _buildBasicTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTextField(controller: _itemNameController, label: context.tr('item_name'), isRequired: true),
        const SizedBox(height: 16),
        _buildTextField(controller: _priceController, label: "Selling Price", keyboardType: TextInputType.number, isRequired: true),
        const SizedBox(height: 16),
        _buildCategoryDropdown(),
        const SizedBox(height: 16),
        _buildProductCodeField(),
        const SizedBox(height: 16),
        _buildInventorySwitch(),
        const SizedBox(height: 16),
        if (_stockEnabled) ...[
          _buildTextField(controller: _quantityController, label: "Initial Stock Quantity", keyboardType: TextInputType.number),
          const SizedBox(height: 16),
        ] else ...[
          _buildInfinityStockIndicator(),
          const SizedBox(height: 16),
        ],
        _buildUnitDropdown(),
      ],
    );
  }

  // --- Tab 2: Advanced ---
  Widget _buildAdvancedTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTextField(controller: _costPriceController, label: "Cost Price", keyboardType: TextInputType.number),
        const SizedBox(height: 16),
        _buildTextField(controller: _mrpController, label: "MRP", keyboardType: TextInputType.number),
        const SizedBox(height: 16),
        _buildTaxDropdown(),
        const SizedBox(height: 16),
        _buildTaxTypeSelector(),
        const SizedBox(height: 16),
        _buildTextField(controller: _hsnController, label: "HSN/SAC"),
        const SizedBox(height: 16),
        _buildTextField(
            controller: _barcodeController,
            label: "Barcode",
            suffixIcon: Icons.qr_code_scanner,
            onSuffixTap: _scanBarcode
        ),
      ],
    );
  }

  // --- UI Component Helpers ---

  Widget _buildInfinityStockIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.all_inclusive, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Text(
            "Infinity Stock Enabled",
            style: TextStyle(
              color: Colors.green.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, bool isRequired = false, TextInputType keyboardType = TextInputType.text, IconData? suffixIcon, VoidCallback? onSuffixTap}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label + (isRequired ? ' *' : ''),
        suffixIcon: suffixIcon != null ? IconButton(icon: Icon(suffixIcon, size: 20), onPressed: onSuffixTap) : null,
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2196F3), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2196F3), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2196F3), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: isRequired ? (v) => v!.isEmpty ? 'Required' : null : null,
    );
  }

  Widget _buildProductCodeField() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildTextField(controller: _productCodeController, label: "Product Code", isRequired: true)),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: ElevatedButton(
            onPressed: _generateProductCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[50],
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Generate", style: TextStyle(color: Colors.blue, fontSize: 12)),
          ),
        )
      ],
    );
  }

  Widget _buildInventorySwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Track Stock Level", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Switch.adaptive(value: _stockEnabled, activeColor: Colors.blue, onChanged: (v) => setState(() => _stockEnabled = v)),
        ],
      ),
    );
  }

  Widget _buildUnitDropdown() {
    return StreamBuilder<List<String>>(
      stream: _unitsStream,
      builder: (context, snapshot) {
        final availableUnits = ['Piece', 'Kg', 'Liter', 'Box', ...(snapshot.data ?? [])].cast<String>();
        return InputDecorator(
          decoration: _dropdownDecoration("Unit").copyWith(
            suffixIcon: IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
              onPressed: _showAddUnitDialog,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: availableUnits.contains(_selectedStockUnit) ? _selectedStockUnit : availableUnits.first,
              isExpanded: true,
              items: availableUnits.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _selectedStockUnit = v),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaxDropdown() {
    return InputDecorator(
      decoration: _dropdownDecoration("Tax Rate").copyWith(
        suffixIcon: IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.blue), onPressed: _showAddTaxDialog),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedTaxId,
          hint: const Text("Select Rate"),
          isExpanded: true,
          items: _fetchedTaxes.map((tax) {
            return DropdownMenuItem<String>(value: tax['id'], child: Text("${tax['name']} (${tax['percentage']}%)"));
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedTaxId = val;
              _currentTaxPercentage = _fetchedTaxes.firstWhere((t) => t['id'] == val)['percentage'];
            });
          },
        ),
      ),
    );
  }

  Widget _buildTaxTypeSelector() {
    final items = ['Price includes Tax', 'Price is without Tax', 'Zero Rated Tax', 'Exempt Tax'];
    return InputDecorator(
      decoration: _dropdownDecoration("Tax Treatment"),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(_selectedTaxType) ? _selectedTaxType : items[1],
          isExpanded: true,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => _selectedTaxType = v!),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return FutureBuilder<Stream<QuerySnapshot>>(
      future: FirestoreService().getCollectionStream('categories'),
      builder: (context, streamSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: streamSnapshot.data,
          builder: (context, snapshot) {
            List<String> categories = ['UnCategorised'];
            if (snapshot.hasData) {
              categories.addAll(snapshot.data!.docs.map((doc) => (doc.data() as Map<String, dynamic>)['name'] as String).toList());
            }
            return InputDecorator(
              decoration: _dropdownDecoration("Category"),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: categories.contains(_selectedCategory) ? _selectedCategory : categories.first,
                  isExpanded: true,
                  items: categories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v),
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF8F9FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2196F3), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2196F3), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2196F3), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  void _showAddUnitDialog() {
    final unitController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add New Unit"),
        content: TextField(
          controller: unitController,
          decoration: const InputDecoration(labelText: "Unit Name (e.g. Dozen, Box)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (unitController.text.trim().isNotEmpty) {
                final storeId = await FirestoreService().getCurrentStoreId();
                if (storeId != null) {
                  await FirebaseFirestore.instance
                      .collection('store')
                      .doc(storeId)
                      .collection('units')
                      .doc(unitController.text.trim())
                      .set({'createdAt': FieldValue.serverTimestamp()});
                }
                if (mounted) {
                  setState(() => _selectedStockUnit = unitController.text.trim());
                  Navigator.pop(ctx);
                }
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _showAddTaxDialog() {
    final nameC = TextEditingController();
    final rateC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Create New Tax"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameC, decoration: const InputDecoration(labelText: "Tax Name")),
            TextField(controller: rateC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Percentage (%)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(onPressed: () {
            if(nameC.text.isNotEmpty && rateC.text.isNotEmpty) {
              _addNewTaxToBackend(nameC.text, double.parse(rateC.text));
              Navigator.pop(ctx);
            }
          }, child: const Text("Add")),
        ],
      ),
    );
  }

  Widget _buildBottomSaveButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFEEEEEE)))),
      child: ElevatedButton(
        onPressed: _saveProduct,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2196F3),
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(context.tr(widget.productId != null ? 'update' : 'add'),
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _loadExistingData() {
    final d = widget.existingData!;
    _itemNameController.text = d['itemName'] ?? '';
    _priceController.text = d['price']?.toString() ?? '';
    _costPriceController.text = d['costPrice']?.toString() ?? '';
    _mrpController.text = d['mrp']?.toString() ?? '';
    _productCodeController.text = d['productCode'] ?? '';
    _hsnController.text = d['hsn'] ?? '';
    _barcodeController.text = d['barcode'] ?? '';
    _quantityController.text = d['currentStock']?.toString() ?? '';
    _selectedCategory = d['category'];
    _stockEnabled = d['stockEnabled'] ?? true;
    _selectedStockUnit = d['stockUnit'];
    _selectedTaxType = d['taxType'] ?? 'Price is without Tax';
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      String? selectedTaxName;
      if (_selectedTaxId != null) {
        try { selectedTaxName = _fetchedTaxes.firstWhere((t) => t['id'] == _selectedTaxId)['name']; } catch (e) {}
      }

      final productData = {
        'itemName': _itemNameController.text.trim(),
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'costPrice': double.tryParse(_costPriceController.text) ?? 0.0,
        'mrp': double.tryParse(_mrpController.text) ?? 0.0,
        'category': _selectedCategory ?? 'UnCategorised',
        'productCode': _productCodeController.text.trim(),
        'hsn': _hsnController.text.trim(),
        'barcode': _barcodeController.text.trim(),
        'stockUnit': _selectedStockUnit ?? 'Piece',
        'stockEnabled': _stockEnabled,
        'currentStock': _stockEnabled ? (double.tryParse(_quantityController.text) ?? 0.0) : 0.0,
        'taxId': _selectedTaxId,
        'taxName': selectedTaxName,
        'taxPercentage': _currentTaxPercentage,
        'taxType': _selectedTaxType,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.productId != null) {
        await FirestoreService().updateDocument('Products', widget.productId!, productData);
      } else {
        productData['createdAt'] = FieldValue.serverTimestamp();
        await FirestoreService().addDocument('Products', productData);
        if (_selectedTaxId != null) await _incrementTaxProductCount(_selectedTaxId!);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Save error: $e");
    }
  }
}