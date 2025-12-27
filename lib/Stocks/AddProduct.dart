import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/components/barcode_scanner.dart';
import 'package:maxbillup/utils/permission_helper.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/Colors.dart';
import 'AddCategoryPopup.dart';

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
  final TextEditingController _lowStockAlertController = TextEditingController();

  // State
  String? _selectedCategory;
  bool _stockEnabled = true;
  String? _selectedStockUnit = 'Piece';
  Stream<List<String>>? _unitsStream;
  String _lowStockAlertType = 'Count'; // 'Count' or 'Percentage'
  bool _isFavorite = false;

  // Tax State
  String _selectedTaxType = 'Price is without Tax';
  List<Map<String, dynamic>> _fetchedTaxes = [];
  String? _selectedTaxId;
  double _currentTaxPercentage = 0.0;

  @override
  void initState() {
    super.initState();
    // Default fallback to General
    _selectedCategory = widget.preSelectedCategory ?? 'General';

    _checkPermission();
    _fetchUnits();
    _fetchTaxesFromBackend();

    if (widget.existingData != null) {
      _loadExistingData();
    }
    // Don't auto-generate product code - user must click generate button
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

  void _generateProductCode() async {
    try {
      final storeId = await FirestoreService().getCurrentStoreId();
      if (storeId == null) return;
      final productsCollection = await FirestoreService().getStoreCollection('Products');
      int highestNumber = 100; // Start from 100, so next will be 101
      final productsSnapshot = await productsCollection.get();
      for (var doc in productsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        final productCode = data?['productCode'] as String?;
        if (productCode != null) {
          final number = int.tryParse(productCode);
          if (number != null && number > highestNumber) {
            highestNumber = number;
          }
        }
      }
      final nextNumber = highestNumber + 1;
      if (mounted) {
        setState(() => _productCodeController.text = nextNumber.toString());
      }
    } catch (e) {
      final code = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
      setState(() => _productCodeController.text = code);
    }
  }

  Future<bool> _checkProductCodeExists(String code) async {
    try {
      final productsCollection = await FirestoreService().getStoreCollection('Products');
      final existingProduct = await productsCollection.where('productCode', isEqualTo: code).get();
      if (existingProduct.docs.isNotEmpty) {
        final data = existingProduct.docs.first.data() as Map<String, dynamic>?;
        final productName = data?['itemName'] ?? 'Unknown Product';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('This number is already mapped with $productName'),
              backgroundColor: kErrorColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.push(context, CupertinoPageRoute(
      builder: (context) => BarcodeScannerPage(onBarcodeScanned: (barcode) => Navigator.pop(context, barcode)),
    ));
    if (result != null && mounted) setState(() => _barcodeController.text = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite ,
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        title: Text(context.tr(widget.productId != null ? 'edit_product' : 'add_product'),
            style: const TextStyle(fontWeight: FontWeight.bold, color: kWhite)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite), onPressed: () => Navigator.pop(context)),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSectionHeader("Basic Details"),
                  const SizedBox(height: 12),
                  _buildCategoryDropdown(),
                  const SizedBox(height: 16),
                  _buildItemNameWithFavorite(),
                  const SizedBox(height: 16),
                  _buildProductCodeField(),
                  const SizedBox(height: 16),
                  _buildTextField(controller: _priceController, label: "Selling Price", keyboardType: TextInputType.number, isRequired: true),
                  const SizedBox(height: 16),
                  _buildTrackStockLevelAndQuantity(),
                  const SizedBox(height: 16),
                  _buildUnitDropdown(),
                  const SizedBox(height: 24),
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: _buildSectionHeader("Advanced Details"),
                      children: [
                        const SizedBox(height: 16),
                        _buildTextField(
                            controller: _barcodeController,
                            label: "Barcode",
                            suffixIcon: Icons.qr_code_scanner,
                            onSuffixTap: _scanBarcode
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(controller: _costPriceController, label: "Cost Price", keyboardType: TextInputType.number),
                        const SizedBox(height: 16),
                        _buildTextField(controller: _mrpController, label: "MRP", keyboardType: TextInputType.number),
                        const SizedBox(height: 16),
                        _buildTaxDropdown(),
                        const SizedBox(height: 16),
                        _buildTaxTypeSelector(),
                        const SizedBox(height: 16),
                        _buildTextField(controller: _hsnController, label: "HSN/SAC"),

                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
            _buildBottomSaveButton(),
          ],
        ),
      ),
    );
  }

  // --- UI Component Helpers ---

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: kBlack87,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildInfinityStockIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kGoogleGreen.withAlpha((0.1 * 255).toInt()),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kGoogleGreen.withAlpha((0.3 * 255).toInt())),
      ),
      child: Row(
        children: [
          const Icon(Icons.all_inclusive, color: kGoogleGreen, size: 20),
          const SizedBox(width: 12),
          Text(
            "Infinity Stock Enabled",
            style: TextStyle(
              color: kGoogleGreen,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    IconData? suffixIcon,
    VoidCallback? onSuffixTap,
  }) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;

        return TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: kBlack87,
          ),
          decoration: InputDecoration(
            labelText: label,
            floatingLabelBehavior: FloatingLabelBehavior.auto,

            labelStyle: TextStyle(
              color: hasText ? kPrimaryColor : kBlack54,
              fontSize: 15,
            ),
            floatingLabelStyle: const TextStyle(
              color: kPrimaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),

            filled: true,
            fillColor: kGreyBg, // ✅ changed from kWhite

            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),

            suffixIcon: suffixIcon != null
                ? IconButton(
              icon: Icon(
                suffixIcon,
                size: 20,
                color: kPrimaryColor,
              ),
              onPressed: onSuffixTap,
            )
                : null,

            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: hasText ? kPrimaryColor : kGrey300,
                width: hasText ? 1.5 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: kPrimaryColor,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: kErrorColor,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: kErrorColor,
                width: 1.5,
              ),
            ),
            errorStyle: const TextStyle(
              color: kErrorColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          validator: isRequired
              ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
              : null,
        );
      },
    );
  }



  Widget _buildProductCodeField() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildTextField(controller: _productCodeController, label: "Product Code", isRequired: true)),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: InkWell(
            onTap: _generateProductCode,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kPrimaryColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: kPrimaryColor,
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.refresh,
                color: kWhite,
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInventorySwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kGrey200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Track Stock", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kBlack87)),
          Switch.adaptive(value: _stockEnabled, activeColor: kPrimaryColor, onChanged: (v) => setState(() => _stockEnabled = v)),
        ],
      ),
    );
  }

  Widget _buildTrackStockLevelAndQuantity() {
    return Column(
      children: [
        // First Line: Track Stock Level and Stock Quantity
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildInventorySwitch(),
            ),
            if (_stockEnabled) ...[
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _quantityController,
                  label: "Stock Quantity",
                  keyboardType: TextInputType.number,
                  isRequired: true,
                ),
              ),
            ],
          ],
        ),
        if (!_stockEnabled) ...[
          const SizedBox(height: 16),
          _buildInfinityStockIndicator(),
        ],
        // Second Line: Low Stock Alert and Type (only if stock is enabled)
        if (_stockEnabled) ...[
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _buildTextField(
                  controller: _lowStockAlertController,
                  label: "Low Stock Alert",
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: kGreyBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kGrey300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _lowStockAlertType,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, color: kBlack54, size: 20),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kBlack87),
                      items: const [
                        DropdownMenuItem(value: 'Count', child: Text('Count')),
                        DropdownMenuItem(value: 'Percentage', child: Text('Percentage')),
                      ],
                      onChanged: (val) => setState(() => _lowStockAlertType = val!),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildItemNameWithFavorite() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildTextField(
                controller: _itemNameController,
                label: "Item Name",
                isRequired: true,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: InkWell(
                onTap: () => setState(() => _isFavorite = !_isFavorite),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _isFavorite ? kPrimaryColor.withAlpha((0.1 * 255).toInt()) : kGrey100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isFavorite ? kPrimaryColor : kGrey300,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? kPrimaryColor : kBlack54,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_isFavorite) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.check_circle, size: 14, color: kPrimaryColor),
              const SizedBox(width: 4),
              Text(
                "Added as Favorite Product",
                style: TextStyle(
                  fontSize: 12,
                  color: kPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }


  Widget _buildUnitDropdown() {
    return StreamBuilder<List<String>>(
      stream: _unitsStream,
      builder: (context, snapshot) {
        final availableUnits = ['Piece', 'Kg', 'Liter', 'Box', ...(snapshot.data ?? [])].cast<String>();
        return InputDecorator(
          decoration: _dropdownDecoration("Unit").copyWith(
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: _showAddUnitDialog,
                child: const Icon(Icons.add_circle_outline, color: kPrimaryColor, size: 22),
              ),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: availableUnits.contains(_selectedStockUnit) ? _selectedStockUnit : availableUnits.first,
              isExpanded: true,
              isDense: true,
              icon: const Icon(Icons.arrow_drop_down, color: kBlack54),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kBlack87),
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
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            onTap: _showAddTaxDialog,
            child: const Icon(Icons.add_circle_outline, color: kPrimaryColor, size: 22),
          ),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedTaxId,
          hint: const Text("Select Rate"),
          isExpanded: true,
          isDense: true,
          icon: const Icon(Icons.arrow_drop_down, color: kBlack54),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kBlack87),
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
          isDense: true,
          icon: const Icon(Icons.arrow_drop_down, color: kBlack54),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kBlack87),
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
            List<String> categories = ['General'];
            if (snapshot.hasData) {
              categories.addAll(snapshot.data!.docs
                  .map((doc) => (doc.data() as Map<String, dynamic>)['name'] as String)
                  .where((name) => name != 'General')
                  .toList());
            }
            return InputDecorator(
              decoration: _dropdownDecoration("Category"),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: categories.contains(_selectedCategory) ? _selectedCategory : categories.first,
                  isExpanded: true,
                  isDense: true,
                  icon: const Icon(Icons.arrow_drop_down, color: kBlack54),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kBlack87),
                  items: [
                    ...categories.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                    const DropdownMenuItem(value: '__create_new__', child: Text('+ Create New Category', style: TextStyle(color: kPrimaryColor))),
                  ],
                  onChanged: (val) async {
                    if (val == '__create_new__') {
                      final newCategory = await showDialog<String>(
                        context: context,
                        builder: (ctx) => AddCategoryPopup(uid: widget.uid),
                      );
                      if (newCategory != null && newCategory.isNotEmpty) {
                        setState(() {
                          _selectedCategory = newCategory;
                        });
                      }
                    } else {
                      setState(() => _selectedCategory = val!);
                    }
                  },
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
      fillColor: kWhite,
      errorStyle: const TextStyle(color: kErrorColor, fontWeight: FontWeight.bold),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kPrimaryColor, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kGrey300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
      ),
      // Applied kErrorColor to error states
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kErrorColor, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kErrorColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      labelStyle: const TextStyle(color: kBlack54),
    );
  }

  void _showAddUnitDialog() {
    final unitController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Add New Unit",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close, size: 24, color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: unitController,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
                decoration: InputDecoration(
                  labelText: "Unit Name (e.g. Dozen, Box)",
                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                  labelStyle: const TextStyle(color: Colors.black54, fontSize: 15),
                  floatingLabelStyle: const TextStyle(color: kPrimaryColor, fontSize: 13, fontWeight: FontWeight.w600),
                  filled: true,
                  fillColor: kGreyBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kGrey300, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text("Add", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddTaxDialog() {
    final nameC = TextEditingController();
    final rateC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Create New Tax",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close, size: 24, color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: nameC,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
                decoration: InputDecoration(
                  labelText: "Tax Name",
                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                  labelStyle: const TextStyle(color: Colors.black54, fontSize: 15),
                  floatingLabelStyle: const TextStyle(color: kPrimaryColor, fontSize: 13, fontWeight: FontWeight.w600),
                  filled: true,
                  fillColor: kGreyBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kGrey300, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: rateC,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
                decoration: InputDecoration(
                  labelText: "Percentage (%)",
                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                  labelStyle: const TextStyle(color: Colors.black54, fontSize: 15),
                  floatingLabelStyle: const TextStyle(color: kPrimaryColor, fontSize: 13, fontWeight: FontWeight.w600),
                  filled: true,
                  fillColor: kGreyBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kGrey300, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if(nameC.text.isNotEmpty && rateC.text.isNotEmpty) {
                      _addNewTaxToBackend(nameC.text, double.parse(rateC.text));
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text("Add", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSaveButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: kWhite, border: Border(top: BorderSide(color: kGrey200))),
      child: ElevatedButton(
        onPressed: _saveProduct,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryColor,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(context.tr(widget.productId != null ? 'update' : 'add'),
            style: const TextStyle(color: kWhite, fontSize: 16, fontWeight: FontWeight.bold)),
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
    _lowStockAlertController.text = d['lowStockAlert']?.toString() ?? '';
    _selectedCategory = d['category'];
    _stockEnabled = d['stockEnabled'] ?? true;
    _selectedStockUnit = d['stockUnit'];
    _selectedTaxType = d['taxType'] ?? 'Price is without Tax';
    _lowStockAlertType = d['lowStockAlertType'] ?? 'Count';
    _isFavorite = d['isFavorite'] ?? false;
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    // Check for duplicate product code (only for new products or if code changed)
    final productCode = _productCodeController.text.trim();
    if (productCode.isNotEmpty) {
      if (widget.productId == null) {
        // New product - check if code exists
        final exists = await _checkProductCodeExists(productCode);
        if (exists) return;
      } else {
        // Editing existing product - check if code changed and if new code exists
        if (widget.existingData!['productCode'] != productCode) {
          final exists = await _checkProductCodeExists(productCode);
          if (exists) return;
        }
      }
    }

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
        'category': _selectedCategory ?? 'General',
        'productCode': productCode,
        'hsn': _hsnController.text.trim(),
        'barcode': _barcodeController.text.trim(),
        'stockUnit': _selectedStockUnit ?? 'Piece',
        'stockEnabled': _stockEnabled,
        'currentStock': _stockEnabled ? (double.tryParse(_quantityController.text) ?? 0.0) : 0.0,
        'lowStockAlert': _lowStockAlertController.text.trim().isNotEmpty ? double.tryParse(_lowStockAlertController.text) ?? 0.0 : 0.0,
        'lowStockAlertType': _lowStockAlertType,
        'isFavorite': _isFavorite,
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
