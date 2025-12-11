import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/Sales/Bill.dart';
import 'package:maxbillup/Sales/Quotation.dart';
import 'package:maxbillup/Sales/components//common_widgets.dart';

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

  @override
  void initState() {
    super.initState();
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

  double get _total => _items.fold(0.0, (sum, item) => sum + item.total);

  List<CartItem> get _cartItems => _items
      .map((item) => CartItem(
    productId: '',
    name: item.name,
    price: item.price,
    quantity: item.quantity,
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Input Display at top
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF2196F3), width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _input.isEmpty ? '' : _input,
                  style: const TextStyle(
                    fontSize: 24,
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
                        backgroundColor: const Color(0xFF2196F3),
                      ),
                      child: const Text('Update'),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Scrollable Items List and Clear Button
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  color: Colors.white,
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height * 0.30,
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: _items.isEmpty
                      ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No items added',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _items.length,
                    itemBuilder: (context, idx) {
                      final item = _items[idx];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${item.name} (${item.price.toStringAsFixed(1)}) x ${item.quantity}',
                                style: const TextStyle(fontSize: 16, color: Colors.black87),
                              ),
                            ),
                            Text(
                              '+ ${item.total.toStringAsFixed(1)}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF4CAF50),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => _startEditQuantity(idx),
                              child: const Icon(Icons.edit, size: 20, color: Color(0xFF2196F3)),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Product'),
                                    content: Text('Are you sure you want to delete ${item.name}?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFFF5252),
                                        ),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  setState(() => _items.removeAt(idx));
                                  _notifyChange();
                                }
                              },
                              child: const Icon(Icons.delete, size: 20, color: Color(0xFFFF5252)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _items.isEmpty ? null : _clearOrder,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _items.isEmpty ? Colors.grey[300] : const Color(0xFFFF5252),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Clear Order',
                            style: TextStyle(
                              color: _items.isEmpty ? Colors.grey[600] : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_items.length} Items',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Calculator Keypad at Bottom (Fixed Position)
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _numBtn('7'),
                  const SizedBox(width: 8),
                  _numBtn('8'),
                  const SizedBox(width: 8),
                  _numBtn('9'),
                  const SizedBox(width: 8),
                  _actBtn(Icons.backspace_outlined, _handleBackspace),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _numBtn('4'),
                  const SizedBox(width: 8),
                  _numBtn('5'),
                  const SizedBox(width: 8),
                  _numBtn('6'),
                  const SizedBox(width: 8),
                  _opBtn('×', _handleMultiply),
                ],
              ),
              const SizedBox(height: 8),
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
                            const SizedBox(width: 8),
                            _numBtn('2'),
                            const SizedBox(width: 8),
                            _numBtn('3'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _numBtn('0'),
                            const SizedBox(width: 8),
                            _numBtn('00'),
                            const SizedBox(width: 8),
                            _numBtn('•'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  editingIndex == null ? _addBtn() : SizedBox(
                    width: (MediaQuery.of(context).size.width - 56) / 4,
                    height: 148,
                    child: GestureDetector(
                      onTap: _confirmEditQuantity,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Update', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                              Text('Quantity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
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

        // Action Buttons at Bottom
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
              Navigator.pushReplacement(
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
              Navigator.pushReplacement(
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
    width: (MediaQuery.of(context).size.width - 56) / 4,
    height: 148,
    child: GestureDetector(
      onTap: _addItem,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Add', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
              Text('Item', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
        ),
      ),
    ),
  );
}
