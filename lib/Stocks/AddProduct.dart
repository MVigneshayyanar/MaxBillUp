import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/components/barcode_scanner.dart';
import 'package:maxbillup/utils/permission_helper.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/Colors.dart';
import 'package:intl/intl.dart';
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
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();

  DateTime? _selectedExpiryDate;
  String? _selectedCategory;
  bool _stockEnabled = true;
  String? _selectedStockUnit = 'Piece';
  Stream<List<String>>? _unitsStream;
  String _lowStockAlertType = 'Count';
  bool _isFavorite = false;
  bool _isLoading = false;

  // Tax State
  String _selectedTaxType = 'Price is without Tax';
  List<Map<String, dynamic>> _fetchedTaxes = [];
  String? _selectedTaxId;
  double _currentTaxPercentage = 0.0;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.preSelectedCategory ?? 'General';
    _checkPermission();
    _fetchUnits();
    _fetchTaxesFromBackend();

    if (widget.existingData != null) {
      _loadExistingData();
    } else {
      _generateProductCode();
    }
  }

  // ==========================================
  // LOGIC METHODS
  // ==========================================

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

  Future<void> _checkPermission() async {
    final userData = await PermissionHelper.getUserPermissions(widget.uid);
    if (userData['permissions']['addProduct'] != true && !userData['role'].toLowerCase().contains('admin') && mounted) {
      Navigator.pop(context);
      PermissionHelper.showPermissionDeniedDialog(context);
    }
  }

  void _fetchUnits() async {
    final storeId = await FirestoreService().getCurrentStoreId();
    if (storeId == null) return;
    setState(() {
      _unitsStream = FirebaseFirestore.instance.collection('store').doc(storeId).collection('units').snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
    });
  }

  void _generateProductCode() async {
    try {
      final productsCollection = await FirestoreService().getStoreCollection('Products');
      final snap = await productsCollection.orderBy('productCode', descending: true).limit(1).get();
      int next = 1001;
      if (snap.docs.isNotEmpty) {
        final code = snap.docs.first['productCode'].toString();
        final numPart = int.tryParse(code.replaceAll(RegExp(r'[^0-9]'), ''));
        if (numPart != null) next = numPart + 1;
      }
      setState(() => _productCodeController.text = '$next');
    } catch (e) {
      setState(() => _productCodeController.text = '${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}');
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
              content: Text('Code is already mapped with $productName'),
              backgroundColor: kErrorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return true;
      }
      return false;
    } catch (e) { return false; }
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.push(context, CupertinoPageRoute(
      builder: (context) => BarcodeScannerPage(onBarcodeScanned: (barcode) => Navigator.pop(context, barcode)),
    ));
    if (result != null && mounted) setState(() => _barcodeController.text = result);
  }

  // ==========================================
  // UI BUILD METHODS
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        title: Text(context.tr(widget.productId != null ? 'edit_product' : 'add_product'),
            style: const TextStyle(fontWeight: FontWeight.w700, color: kWhite, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 20), onPressed: () => Navigator.pop(context)),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildSectionHeader("Basic Details"),
                  _buildCategoryDropdown(),
                  const SizedBox(height: 16),
                  _buildItemNameWithFavorite(),
                  const SizedBox(height: 16),
                  _buildProductCodeField(),
                  const SizedBox(height: 16),
                  _buildModernTextField(
                    controller: _priceController,
                    label: "Price",
                    icon: Icons.payments_rounded,
                    keyboardType: TextInputType.number,
                    isRequired: true,
                    hint: "0.00",
                  ),
                  const SizedBox(height: 16),
                  _buildTrackStockAndQuantity(),
                  const SizedBox(height: 16),
                  _buildUnitDropdown(),
                  const SizedBox(height: 24),

                  // ADVANCED SECTION
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: _buildSectionHeader("Advanced Details"),
                      iconColor: kPrimaryColor,
                      collapsedIconColor: kBlack54,
                      children: [
                        const SizedBox(height: 12),
                        _buildModernTextField(
                          controller: _barcodeController,
                          label: "Barcode String",
                          icon: Icons.barcode_reader,
                          hint: "Scan or type barcode",
                          suffixIcon: Icons.qr_code_scanner_rounded,
                          onSuffixTap: _scanBarcode,
                        ),
                        const SizedBox(height: 16),
                        _buildModernTextField(
                          controller: _costPriceController,
                          label: "Base Cost Price",
                          icon: Icons.shopping_cart_rounded,
                          keyboardType: TextInputType.number,
                          hint: "0.00",
                        ),
                        const SizedBox(height: 16),
                        _buildModernTextField(
                          controller: _mrpController,
                          label: "MRP",
                          icon: Icons.tag_rounded,
                          keyboardType: TextInputType.number,
                          hint: "Maximum Retail Price",
                        ),
                        const SizedBox(height: 16),
                        _buildTaxDropdown(),
                        const SizedBox(height: 16),
                        _buildTaxTypeSelector(),
                        const SizedBox(height: 16),
                        _buildModernTextField(
                          controller: _hsnController,
                          label: "HSN / SAC Code",
                          icon: Icons.assignment_outlined,
                        ),
                        const SizedBox(height: 16),
                        _buildModernTextField(
                          controller: _locationController,
                          label: "Product Location",
                          icon: Icons.location_on_outlined,
                          hint: "e.g. Shelf A3, Warehouse B",
                        ),
                        const SizedBox(height: 16),
                        _buildExpiryDateField(),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 10,
          color: kBlack54,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? hint,
    IconData? suffixIcon,
    VoidCallback? onSuffixTap,
    Color? iconColor,
  }) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final bool isFilled = value.text.isNotEmpty;
        return TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack87),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon, color: isFilled ? (iconColor ?? kPrimaryColor) : kBlack54, size: 20),
            suffixIcon: suffixIcon != null
                ? IconButton(icon: Icon(suffixIcon, color: kPrimaryColor, size: 20), onPressed: onSuffixTap)
                : null,
            filled: true,
            fillColor: kWhite,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isFilled ? kPrimaryColor : kGrey200, width: isFilled ? 1.5 : 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kErrorColor),
            ),
            floatingLabelStyle: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w800),
          ),
          validator: isRequired ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
        );
      },
    );
  }

  Widget _buildItemNameWithFavorite() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildModernTextField(
            controller: _itemNameController,
            label: "Item Name",
            icon: Icons.shopping_basket_rounded,
            isRequired: true,
            hint: "Enter product name",
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () => setState(() => _isFavorite = !_isFavorite),
          child: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: _isFavorite ? kPrimaryColor.withOpacity(0.1) : kWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _isFavorite ? kPrimaryColor : kGrey200, width: 1.5),
            ),
            child: Icon(
              _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _isFavorite ? kPrimaryColor : kBlack54,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductCodeField() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildModernTextField(
            controller: _productCodeController,
            label: "Product Code",
            icon: Icons.qr_code_rounded,
            isRequired: true,
            hint: "Unique ID",
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: _generateProductCode,
          child: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: kPrimaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.refresh_rounded, color: kWhite, size: 22),
          ),
        ),
      ],
    );
  }

  Widget _buildTrackStockAndQuantity() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kGrey200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Track Stock", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kBlack87)),
                    Switch.adaptive(
                        value: _stockEnabled,
                        activeColor: kPrimaryColor,
                        onChanged: (v) => setState(() => _stockEnabled = v)
                    ),
                  ],
                ),
              ),
            ),
            if (_stockEnabled) ...[
              const SizedBox(width: 12),
              Expanded(
                child: _buildModernTextField(
                  controller: _quantityController,
                  label: "Initial Stock",
                  icon: Icons.inventory_2_rounded,
                  keyboardType: TextInputType.number,
                  isRequired: true,
                  hint: "0",
                ),
              ),
            ],
          ],
        ),
        if (!_stockEnabled) ...[
          const SizedBox(height: 12),
          _buildInfinityStockIndicator(),
        ],
        // RESTORED: Low Stock Alert row
        if (_stockEnabled) ...[
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _buildModernTextField(
                  controller: _lowStockAlertController,
                  label: "Low Stock Alert",
                  icon: Icons.notification_important_rounded,
                  keyboardType: TextInputType.number,
                  hint: "0",
                  iconColor: kOrange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _wrapDropdown(
                  "Alert Type",
                  DropdownButton<String>(
                    value: _lowStockAlertType,
                    isExpanded: true,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'Count', child: Text('Count')),
                      DropdownMenuItem(value: 'Percentage', child: Text('Percentage')),
                    ],
                    onChanged: (val) => setState(() => _lowStockAlertType = val!),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildInfinityStockIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kGoogleGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGoogleGreen.withOpacity(0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.all_inclusive_rounded, color: kGoogleGreen, size: 18),
          SizedBox(width: 12),
          Text("Infinity Stock Enabled", style: TextStyle(color: kGoogleGreen, fontWeight: FontWeight.w800, fontSize: 12)),
        ],
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
            return _wrapDropdown(
              "Category",
              DropdownButton<String>(
                value: categories.contains(_selectedCategory) ? _selectedCategory : categories.first,
                isExpanded: true,
                isDense: true,
                items: [
                  ...categories.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                  const DropdownMenuItem(value: '__create_new__', child: Text('+ New Category', style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold))),
                ],
                onChanged: (val) async {
                  if (val == '__create_new__') {
                    final newCategory = await showDialog<String>(context: context, builder: (ctx) => AddCategoryPopup(uid: widget.uid));
                    if (newCategory != null && newCategory.isNotEmpty) setState(() => _selectedCategory = newCategory);
                  } else {
                    setState(() => _selectedCategory = val!);
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUnitDropdown() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getUnitsWithMetadata(),
      builder: (context, snapshot) {
        // Default units that cannot be deleted
        final defaultUnits = ['Piece', 'Kg', 'Liter', 'Box', 'Nos', 'Meter', 'Feet', 'Gram', 'ML'];
        final customUnits = snapshot.data ?? [];
        final allUnits = [...defaultUnits, ...customUnits.map((u) => u['name'] as String)];

        return _wrapDropdown(
          "Measurement Unit",
          DropdownButton<String>(
            value: allUnits.contains(_selectedStockUnit) ? _selectedStockUnit : allUnits.first,
            isExpanded: true,
            isDense: true,
            items: allUnits.map((unit) {
              final isCustom = customUnits.any((u) => u['name'] == unit);
              return DropdownMenuItem(
                value: unit,
                child: Row(
                  children: [
                    Expanded(child: Text(unit)),
                    if (isCustom)
                      GestureDetector(
                        onTap: () => _showDeleteUnitDialog(unit),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.delete_outline_rounded, color: kErrorColor, size: 18),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (v) => setState(() => _selectedStockUnit = v),
          ),
          onAdd: _showAddUnitDialog,
        );
      },
    );
  }

  Stream<List<Map<String, dynamic>>> _getUnitsWithMetadata() async* {
    final storeId = await FirestoreService().getCurrentStoreId();
    if (storeId == null) {
      yield [];
      return;
    }
    yield* FirebaseFirestore.instance
        .collection('store')
        .doc(storeId)
        .collection('units')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {'name': doc.id, 'id': doc.id}).toList());
  }

  void _showDeleteUnitDialog(String unitName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Unit?", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text('Are you sure you want to delete "$unitName"? Products using this unit will not be affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              final storeId = await FirestoreService().getCurrentStoreId();
              if (storeId != null) {
                await FirebaseFirestore.instance
                    .collection('store')
                    .doc(storeId)
                    .collection('units')
                    .doc(unitName)
                    .delete();
              }
              if (mounted) {
                // Reset to default if deleted unit was selected
                if (_selectedStockUnit == unitName) {
                  setState(() => _selectedStockUnit = 'Piece');
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Unit "$unitName" deleted'),
                    backgroundColor: kGoogleGreen,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kErrorColor),
            child: const Text("DELETE", style: TextStyle(color: kWhite, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildTaxDropdown() {
    return _wrapDropdown(
      "Tax Rate (%)",
      DropdownButton<String>(
        value: _selectedTaxId,
        hint: const Text("Select Rate"),
        isExpanded: true,
        isDense: true,
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
      onAdd: _showAddTaxDialog,
    );
  }

  Widget _buildTaxTypeSelector() {
    final items = ['Price includes Tax', 'Price is without Tax', 'Exempt Tax'];
    return _wrapDropdown(
      "Tax Treatment",
      DropdownButton<String>(
        value: items.contains(_selectedTaxType) ? _selectedTaxType : items[1],
        isExpanded: true,
        isDense: true,
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (v) => setState(() => _selectedTaxType = v!),
      ),
    );
  }

  Widget _buildExpiryDateField() {
    return GestureDetector(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: _selectedExpiryDate ?? DateTime.now().add(const Duration(days: 365)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 3650)),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: kPrimaryColor)),
            child: child!,
          ),
        );
        if (picked != null) {
          setState(() {
            _selectedExpiryDate = picked;
            _expiryDateController.text = DateFormat('dd/MM/yyyy').format(picked);
          });
        }
      },
      child: AbsorbPointer(
        child: _buildModernTextField(
          controller: _expiryDateController,
          label: "Expiry Date",
          icon: Icons.event_rounded,
          hint: "Select date",
          suffixIcon: Icons.calendar_today_rounded,
        ),
      ),
    );
  }

  Widget _wrapDropdown(String label, Widget child, {VoidCallback? onAdd}) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kBlack54, fontSize: 13),
        filled: true,
        fillColor: kWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrey200)),
        suffixIcon: onAdd != null ? IconButton(icon: const Icon(Icons.add_circle_outline_rounded, color: kPrimaryColor, size: 22), onPressed: onAdd) : null,
        floatingLabelStyle: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w800),
      ),
      child: DropdownButtonHideUnderline(child: child),
    );
  }

  void _showAddUnitDialog() {
    final unitController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("New Unit", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: TextField(
          controller: unitController,
          style: const TextStyle(fontWeight: FontWeight.w600),
          decoration: const InputDecoration(hintText: "e.g. Dozen, Box", border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              if (unitController.text.trim().isEmpty) return;
              final storeId = await FirestoreService().getCurrentStoreId();
              if (storeId != null) {
                await FirebaseFirestore.instance.collection('store').doc(storeId).collection('units').doc(unitController.text.trim()).set({'createdAt': FieldValue.serverTimestamp()});
              }
              if (mounted) { setState(() => _selectedStockUnit = unitController.text.trim()); Navigator.pop(ctx); }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
            child: const Text("ADD", style: TextStyle(color: kWhite, fontWeight: FontWeight.bold)),
          )
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("New Tax Rate", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameC, style: const TextStyle(fontWeight: FontWeight.w600), decoration: const InputDecoration(hintText: "Tax Name (e.g. VAT)", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: rateC, style: const TextStyle(fontWeight: FontWeight.w600), keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: "Percentage (%)", border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              if(nameC.text.isNotEmpty && rateC.text.isNotEmpty) {
                _addNewTaxToBackend(nameC.text, double.parse(rateC.text));
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
            child: const Text("CREATE", style: TextStyle(color: kWhite, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildBottomSaveButton() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        decoration: const BoxDecoration(color: kWhite, border: Border(top: BorderSide(color: kGrey200))),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveProduct,
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _isLoading
                ? const CircularProgressIndicator(color: kWhite)
                : Text(context.tr(widget.productId != null ? 'update' : 'add').toUpperCase(), style: const TextStyle(color: kWhite, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
        ),
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
    _locationController.text = d['location'] ?? '';
    _selectedCategory = d['category'];
    _stockEnabled = d['stockEnabled'] ?? true;
    _selectedStockUnit = d['stockUnit'];
    _selectedTaxType = d['taxType'] ?? 'Price is without Tax';
    _lowStockAlertType = d['lowStockAlertType'] ?? 'Count';
    _isFavorite = d['isFavorite'] ?? false;
    if (d['expiryDate'] != null) {
      _selectedExpiryDate = DateTime.tryParse(d['expiryDate'].toString());
      if (_selectedExpiryDate != null) _expiryDateController.text = DateFormat('dd/MM/yyyy').format(_selectedExpiryDate!);
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    // Get tax name and percentage from the selected tax
    String? taxName;
    double? taxPercentage;
    if (_selectedTaxId != null && _fetchedTaxes.isNotEmpty) {
      final selectedTax = _fetchedTaxes.firstWhere(
        (t) => t['id'] == _selectedTaxId,
        orElse: () => {},
      );
      taxName = selectedTax['name'];
      taxPercentage = selectedTax['percentage'];
    }

    final pData = {
      'itemName': _itemNameController.text.trim(),
      'price': double.tryParse(_priceController.text) ?? 0.0,
      'costPrice': double.tryParse(_costPriceController.text) ?? 0.0,
      'mrp': double.tryParse(_mrpController.text) ?? 0.0,
      'category': _selectedCategory ?? 'General',
      'productCode': _productCodeController.text.trim(),
      'stockEnabled': _stockEnabled,
      'currentStock': _stockEnabled ? (double.tryParse(_quantityController.text) ?? 0.0) : 0.0,
      'lowStockAlert': double.tryParse(_lowStockAlertController.text) ?? 0.0,
      'lowStockAlertType': _lowStockAlertType,
      'hsn': _hsnController.text.trim(),
      'barcode': _barcodeController.text.trim(),
      'stockUnit': _selectedStockUnit ?? 'Piece',
      'taxId': _selectedTaxId,
      'taxType': _selectedTaxType,
      'taxName': taxName ?? 'GST',
      'taxPercentage': taxPercentage ?? 0.0,
      'location': _locationController.text.trim(),
      'expiryDate': _selectedExpiryDate?.toIso8601String(),
      'isFavorite': _isFavorite,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (widget.productId != null) await FirestoreService().updateDocument('Products', widget.productId!, pData);
    else await FirestoreService().addDocument('Products', pData);
    if (mounted) Navigator.pop(context);
  }
}