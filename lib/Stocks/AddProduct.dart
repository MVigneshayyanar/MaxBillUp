import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddProductPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final String? preSelectedCategory;

  const AddProductPage({
    super.key,
    required this.uid,
    this.userEmail,
    this.preSelectedCategory,
  });

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _costPriceController = TextEditingController();
  final TextEditingController _mrpController = TextEditingController();
  final TextEditingController _productCodeController = TextEditingController();
  final TextEditingController _hsnController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();

  String? _selectedCategory;
  String? _selectedStockUnit;
  bool _moreDetailsExpanded = false; // Set to false to show collapsed by default
  bool _stockEnabled = false;

  // Tax switches
  bool _tax5Enabled = false;
  bool _tax12Enabled = false;
  bool _tax15Enabled = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.preSelectedCategory;
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _priceController.dispose();
    _costPriceController.dispose();
    _mrpController.dispose();
    _productCodeController.dispose();
    _hsnController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00B0FF),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Product',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Item Information Section
                  const Text(
                    'Item Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Item Name
                  _buildTextField(
                    controller: _itemNameController,
                    hint: 'Item Name',
                    isRequired: true,
                  ),
                  const SizedBox(height: 16),

                  // Category Dropdown
                  _buildCategoryDropdown(),
                  const SizedBox(height: 16),

                  // Price
                  _buildTextField(
                    controller: _priceController,
                    hint: 'Price',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),

                  // Info message
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info,
                        color: Color(0xFF00B0FF),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Leave field blank for price upon sale.',
                          style: TextStyle(
                            fontSize: 14,
                            color: const Color(0xFF00B0FF),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // More Details Section Header - Clickable
                  InkWell(
                    onTap: () {
                      setState(() {
                        _moreDetailsExpanded = !_moreDetailsExpanded;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'More Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          Icon(
                            _moreDetailsExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: Colors.black,
                            size: 28,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // More Details Content - Animated
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Column(
                      children: [
                        const SizedBox(height: 20),

                        // Cost Price
                        _buildTextField(
                          controller: _costPriceController,
                          hint: 'Cost Price (Optional)',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),

                        // MRP
                        _buildTextField(
                          controller: _mrpController,
                          hint: 'MRP (Optional)',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),

                        // Product Code with Generate button
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _productCodeController,
                                hint: 'Product Code',
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _generateProductCode,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00B0FF),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Generate',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // HSN/SCN with Find button
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _hsnController,
                                hint: 'hsn/scn',
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () {
                                // Implement HSN finder
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00B0FF),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Find',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Barcode with scanner icon
                        _buildTextField(
                          controller: _barcodeController,
                          hint: 'Barcode',
                          suffixIcon: Icons.qr_code_scanner,
                          onSuffixTap: () {
                            // Implement barcode scanner
                          },
                        ),
                        const SizedBox(height: 12),

                        // Barcode info
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info,
                              color: Color(0xFF00B0FF),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'For adding barcode by an external barcode reader, tap barcode field & scan the barcode',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: const Color(0xFF00B0FF),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Stock Unit Dropdown
                        _buildStockUnitDropdown(),
                        const SizedBox(height: 20),

                        // Tax Section
                        const Text(
                          'Tax',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Tax options
                        _buildTaxSwitch('5.0%', 'GST', _tax5Enabled, (value) {
                          setState(() {
                            _tax5Enabled = value;
                            if (value) {
                              _tax12Enabled = false;
                              _tax15Enabled = false;
                            }
                          });
                        }),
                        const SizedBox(height: 8),

                        _buildTaxSwitch('12.0%', 'GST', _tax12Enabled, (value) {
                          setState(() {
                            _tax12Enabled = value;
                            if (value) {
                              _tax5Enabled = false;
                              _tax15Enabled = false;
                            }
                          });
                        }),
                        const SizedBox(height: 8),

                        _buildTaxSwitch('15.0%', 'GST', _tax15Enabled, (value) {
                          setState(() {
                            _tax15Enabled = value;
                            if (value) {
                              _tax5Enabled = false;
                              _tax12Enabled = false;
                            }
                          });
                        }),
                        const SizedBox(height: 20),

                        // Stock Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Stock',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF00B0FF),
                              ),
                            ),
                            Switch(
                              value: _stockEnabled,
                              onChanged: (value) {
                                setState(() {
                                  _stockEnabled = value;
                                });
                              },
                              activeColor: const Color(0xFF00B0FF),
                            ),
                          ],
                        ),
                      ],
                    ),
                    crossFadeState: _moreDetailsExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 300),
                    sizeCurve: Curves.easeInOut,
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),

            // Add Button - Fixed at bottom
            Container(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              color: const Color(0xFFF5F5F5),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B0FF),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Add',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    IconData? suffixIcon,
    VoidCallback? onSuffixTap,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint + (isRequired ? '*' : ''),
        hintStyle: TextStyle(
          color: Colors.grey[400],
          fontSize: 15,
        ),
        suffixIcon: suffixIcon != null
            ? IconButton(
          icon: Icon(suffixIcon, color: Colors.grey[400], size: 22),
          onPressed: onSuffixTap,
        )
            : null,
        filled: true,
        fillColor: const Color(0xFFF0F0F0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF00B0FF), width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: isRequired
          ? (value) {
        if (value == null || value.isEmpty) {
          return 'This field is required';
        }
        return null;
      }
          : null,
    );
  }

  Widget _buildCategoryDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('categories')
          .snapshots(),
      builder: (context, snapshot) {
        List<String> categories = ['UnCategorised'];

        if (snapshot.hasData) {
          final fetchedCategories = snapshot.data!.docs
              .map((doc) => (doc.data() as Map<String, dynamic>)['name'] as String)
              .toList();
          categories.addAll(fetchedCategories);
        }

        // Initialize from preSelectedCategory if not already set
        if (_selectedCategory == null && widget.preSelectedCategory != null) {
          _selectedCategory = widget.preSelectedCategory;
        }

        // Ensure selected category is in the list
        if (_selectedCategory != null && !categories.contains(_selectedCategory)) {
          // If it's the preselected category, add it to the list temporarily
          if (_selectedCategory == widget.preSelectedCategory) {
            categories.add(_selectedCategory!);
          } else {
            // Otherwise reset to first category
            _selectedCategory = categories.first;
          }
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory,
              hint: Text(
                'Category',
                style: TextStyle(color: Colors.grey[400], fontSize: 15),
              ),
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[400]),
              items: categories.map((category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(
                    category,
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value;
                });
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildStockUnitDropdown() {
    final units = ['Piece', 'Kg', 'Liter', 'Box', 'Meter'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedStockUnit,
          hint: Text(
            'Stock Unit',
            style: TextStyle(color: Colors.grey[400], fontSize: 15),
          ),
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[400]),
          items: units.map((unit) {
            return DropdownMenuItem<String>(
              value: unit,
              child: Text(unit, style: const TextStyle(fontSize: 15)),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedStockUnit = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildTaxSwitch(String percentage, String type, bool value, Function(bool) onChanged) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Text(
                percentage,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                type,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF00B0FF),
        ),
      ],
    );
  }

  void _generateProductCode() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final code = 'PRD${timestamp.toString().substring(timestamp.toString().length - 8)}';
    setState(() {
      _productCodeController.text = code;
    });
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      double selectedTax = 0.0;
      if (_tax5Enabled) selectedTax = 5.0;
      if (_tax12Enabled) selectedTax = 12.0;
      if (_tax15Enabled) selectedTax = 15.0;

      final productData = {
        'itemName': _itemNameController.text.trim(),
        'price': _priceController.text.isNotEmpty
            ? double.tryParse(_priceController.text)
            : null,
        'category': _selectedCategory ?? 'UnCategorised',
        'costPrice': _costPriceController.text.isNotEmpty
            ? double.tryParse(_costPriceController.text)
            : null,
        'mrp': _mrpController.text.isNotEmpty
            ? double.tryParse(_mrpController.text)
            : null,
        'productCode': _productCodeController.text.trim(),
        'hsn': _hsnController.text.trim(),
        'barcode': _barcodeController.text.trim(),
        'stockUnit': _selectedStockUnit,
        'stockEnabled': _stockEnabled,
        'currentStock': 0.0,
        'taxes': selectedTax > 0 ? [selectedTax] : [],
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('Products')
          .add(productData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product added successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
