import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/Sales/Bill.dart';
import 'package:maxbillup/Sales/Quotation.dart';
import 'package:maxbillup/Sales/components//common_widgets.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';

class QuickSalePage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final List<CartItem>? initialCartItems;
  final Function(List<CartItem>)? onCartChanged;
  final String? savedOrderId;

  const QuickSalePage({
    super.key,
    required this.uid,
    this.userEmail,
    this.initialCartItems,
    this.onCartChanged,
    this.savedOrderId,
  });

  @override
  State<QuickSalePage> createState() => _QuickSalePageState();
}

class QuickSaleItem {
  final String name;
  final double price;
  int quantity;

  QuickSaleItem({required this.name, required this.price, required this.quantity});

  double get total => price * quantity;
}

class _QuickSalePageState extends State<QuickSalePage> {
  final List<QuickSaleItem> _items = [];
  String _input = '';
  int _counter = 1;
  int? editingIndex;

  // Default tax settings
  String _defaultTaxType = 'Price is without Tax';
  double _defaultTaxPercentage = 0.0;
  String _defaultTaxName = '';

  @override
  void initState() {
    super.initState();
    _loadDefaultTaxSettings();
    if (widget.initialCartItems != null) {
      for (var item in widget.initialCartItems!) {
        _items.add(QuickSaleItem(
          name: item.name,
          price: item.price,
          quantity: item.quantity,
        ));
      }
      _counter = _items.length + 1;
    }
  }

  @override
  void didUpdateWidget(QuickSalePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync changes from parent when initialCartItems changes
    if (widget.initialCartItems != oldWidget.initialCartItems) {
      if (widget.initialCartItems != null) {
        setState(() {
          _items.clear();
          for (var item in widget.initialCartItems!) {
            _items.add(QuickSaleItem(
              name: item.name,
              price: item.price,
              quantity: item.quantity,
            ));
          }
          // Update counter to continue from the highest item number
          _counter = _items.length + 1;
        });
      }
    }
  }

  Future<void> _loadDefaultTaxSettings() async {
    try {
      // Import FirestoreService at the top if not already imported
      final firestoreService = FirestoreService();

      // Load default tax type from store-scoped settings
      final settingsCollection = await firestoreService.getStoreCollection('settings');
      final settingsDoc = await settingsCollection.doc('taxSettings').get();

      if (settingsDoc.exists) {
        final data = settingsDoc.data() as Map<String, dynamic>?;
        _defaultTaxType = data?['defaultTaxType'] ?? 'Price is without Tax';
      }

      // Load first active tax for quick sale from store-scoped taxes
      final taxesCollection = await firestoreService.getStoreCollection('taxes');
      final taxesSnapshot = await taxesCollection
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (taxesSnapshot.docs.isNotEmpty) {
        final taxData = taxesSnapshot.docs.first.data() as Map<String, dynamic>;
        _defaultTaxPercentage = (taxData['percentage'] ?? 0.0).toDouble();
        _defaultTaxName = taxData['name'] ?? '';
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading tax settings: $e');
    }
  }

  double get _total => _items.fold(0.0, (sum, item) => sum + item.total);

  List<CartItem> get _cartItems => _items
      .map((item) => CartItem(
    productId: '',
    name: item.name,
    price: item.price,
    quantity: item.quantity,
    taxName: _defaultTaxPercentage > 0 ? _defaultTaxName : null,
    taxPercentage: _defaultTaxPercentage > 0 ? _defaultTaxPercentage : null,
    taxType: _defaultTaxType,
  ))
      .toList();

  void _notifyChange() => widget.onCartChanged?.call(_cartItems);

  void _handleInput(String val) {
    setState(() {
      if (val == '.' && _input.contains('.')) return;
      _input += val;
    });
  }

  void _handleMultiply() {
    setState(() {
      if (_input.isNotEmpty && !_input.endsWith('x')) _input += 'x';
    });
  }

  void _handleBackspace() {
    setState(() {
      if (_input.isNotEmpty) _input = _input.substring(0, _input.length - 1);
    });
  }

  void _addItem() {
    if (_input.isEmpty) return;
    try {
      double price;
      int qty;
      if (_input.contains('x')) {
        final parts = _input.split('x');
        if (parts.length != 2) return;
        price = double.parse(parts[0].trim());
        qty = int.tryParse(parts[1].trim()) ?? 1;
      } else {
        price = double.parse(_input);
        qty = 1;
      }
      setState(() {
        _items.insert(
            0,
            QuickSaleItem(
              name: 'item$_counter',
              price: price,
              quantity: qty,
            ));
        _counter++;
        _input = '';
      });
      _notifyChange();
      CommonWidgets.showSnackBar(
        context,
        'Item added:  ${price.toStringAsFixed(1)} x $qty',
        bgColor: const Color(0xFF4CAF50),
      );
    } catch (e) {
      CommonWidgets.showSnackBar(
        context,
        'Invalid input format',
        bgColor: const Color(0xFFFF5252),
      );
    }
  }

  void _clearOrder() {
    setState(() {
      _items.clear();
      _input = '';
      _counter = 1;
      editingIndex = null;
    });
    _notifyChange();
  }

  void _removeItem(int idx) {
    setState(() => _items.removeAt(idx));
    _notifyChange();
  }

  void _startEditQuantity(int idx) {
    setState(() {
      editingIndex = idx;
      _input = _items[idx].quantity.toString();
    });
  }

  void _confirmEditQuantity() {
    if (editingIndex != null) {
      final qty = int.tryParse(_input);
      if (qty != null && qty > 0) {
        setState(() {
          _items[editingIndex!].quantity = qty;
          editingIndex = null;
          _input = '';
        });
        _notifyChange();
        CommonWidgets.showSnackBar(
          context,
          'Quantity updated to $qty',
          bgColor: const Color(0xFF4CAF50),
        );
      } else {
        CommonWidgets.showSnackBar(
          context,
          'Invalid quantity',
          bgColor: const Color(0xFFFF5252),
        );
      }
    }
  }

  void _handleEnter() {
    _addItem();
  }

  void _handleAdd() {
    setState(() {
      if (_input.isNotEmpty && !_input.endsWith('+')) _input += '+';
    });
  }

  void _handleSubtract() {
    setState(() {
      if (_input.isNotEmpty && !_input.endsWith('-')) _input += '-';
    });
  }

  void _handleDivide() {
    setState(() {
      if (_input.isNotEmpty && !_input.endsWith('/')) _input += '/';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Spacer to push content to bottom
        const Spacer(),

        // Fixed components at bottom: Input + Keypad + Action Buttons
        Container(
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Input Display
              Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF2F7CF6), width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _input.isEmpty ? '' : _input,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        if (editingIndex != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: ElevatedButton(
                              onPressed: _confirmEditQuantity,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2F7CF6),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              ),
                              child: Text(context.tr('update'), style: const TextStyle(fontSize: 12)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),


                // Calculator Keypad
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          _numBtn('7'),
                          const SizedBox(width: 6),
                          _numBtn('8'),
                          const SizedBox(width: 6),
                          _numBtn('9'),
                          const SizedBox(width: 6),
                          _actBtn(Icons.backspace_outlined, _handleBackspace),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _numBtn('4'),
                          const SizedBox(width: 6),
                          _numBtn('5'),
                          const SizedBox(width: 6),
                          _numBtn('6'),
                          const SizedBox(width: 6),
                          _opBtn('×', _handleMultiply),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    _numBtn('1'),
                                    const SizedBox(width: 6),
                                    _numBtn('2'),
                                    const SizedBox(width: 6),
                                    _numBtn('3'),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    _numBtn('0'),
                                    const SizedBox(width: 6),
                                    _numBtn('00'),
                                    const SizedBox(width: 6),
                                    _numBtn('•'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          editingIndex == null
                              ? _addBtn()
                              : SizedBox(
                                  width: (MediaQuery.of(context).size.width - 48) / 4,
                                  height: 146,
                                  child: GestureDetector(
                                    onTap: _confirmEditQuantity,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2F7CF6),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text('Update', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                                            SizedBox(height: 4),
                                            Text('Qty', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Action Buttons
                CommonWidgets.buildActionButtons(
                  context: context,
                  onSaveOrder: () {
                    CommonWidgets.showSaveOrderDialog(
                      context: context,
                      uid: widget.uid,
                      cartItems: _cartItems,
                      totalBill: _total,
                      onSuccess: () {
                        setState(() {
                          _items.clear();
                          _input = '';
                          _counter = 1;
                          editingIndex = null;
                        });
                      },
                    );
                  },
                  onQuotation: () {
                    if (_items.isNotEmpty) {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => QuotationPage(
                            uid: widget.uid,
                            userEmail: widget.userEmail,
                            cartItems: _cartItems,
                            totalAmount: _total,
                          ),
                        ),
                      );
                    } else {
                      CommonWidgets.showSnackBar(
                        context,
                        'Cart is empty!',
                        bgColor: const Color(0xFFFF9800),
                      );
                    }
                  },
                  onBill: () {
                    if (_items.isNotEmpty) {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => BillPage(
                            uid: widget.uid,
                            userEmail: widget.userEmail,
                            cartItems: _cartItems,
                            totalAmount: _total,
                            savedOrderId: widget.savedOrderId,
                          ),
                        ),
                      );
                    }
                  },
                  totalBill: _total,
                ),

                // Bottom spacer - 150px above bottom nav
              ],
            ),
          ),
        ],
      );
  }

  Widget _numBtn(String num) => Expanded(
    child: GestureDetector(
      onTap: () => _handleInput(num == '•' ? '.' : num),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(num,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500, color: Colors.black87)),
        ),
      ),
    ),
  );

  Widget _opBtn(String op, VoidCallback onTap) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(op,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500, color: Colors.black87)),
        ),
      ),
    ),
  );

  Widget _actBtn(IconData icon, VoidCallback onTap) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: Icon(icon, size: 24, color: Colors.black87)),
      ),
    ),
  );

  Widget _addBtn() => SizedBox(
    width: (MediaQuery.of(context).size.width - 48) / 4,
    height: 146,
    child: GestureDetector(
      onTap: _addItem,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2F7CF6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Add', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              SizedBox(height: 4),
              Text('Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
        ),
      ),
    ),
  );

  // Dynamic button widgets with adaptive height
  Widget _numBtnDynamic(String num, double height) => Expanded(
    child: GestureDetector(
      onTap: () => _handleInput(num == '•' ? '.' : num),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(num,
              style: TextStyle(fontSize: height * 0.38, fontWeight: FontWeight.w500, color: Colors.black87)),
        ),
      ),
    ),
  );

  Widget _opBtnDynamic(String op, VoidCallback onTap, double height) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(op,
              style: TextStyle(fontSize: height * 0.38, fontWeight: FontWeight.w500, color: Colors.black87)),
        ),
      ),
    ),
  );

  Widget _actBtnDynamic(IconData icon, VoidCallback onTap, double height) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(child: Icon(icon, size: height * 0.38, color: Colors.black87)),
      ),
    ),
  );

  Widget _addBtnDynamic(double height) => SizedBox(
    width: (MediaQuery.of(context).size.width - 48) / 4,
    height: height,
    child: GestureDetector(
      onTap: _addItem,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2F7CF6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Add', style: TextStyle(fontSize: height * 0.13, fontWeight: FontWeight.w600, color: Colors.white)),
              SizedBox(height: 2),
              Text('Item', style: TextStyle(fontSize: height * 0.13, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
        ),
      ),
    ),
  );
}
