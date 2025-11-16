import 'package:flutter/material.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/Sales/Bill.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QuickSalePage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final List<CartItem>? initialCartItems;
  final Function(List<CartItem>)? onCartChanged;

  const QuickSalePage({
    super.key,
    required this.uid,
    this.userEmail,
    this.initialCartItems,
    this.onCartChanged,
  });

  @override
  State<QuickSalePage> createState() => _QuickSalePageState();
}

class QuickSaleItem {
  final String name;
  final double price;
  double quantity;

  QuickSaleItem({
    required this.name,
    required this.price,
    required this.quantity,
  });

  double get total => price * quantity;
}

class _QuickSalePageState extends State<QuickSalePage> {
  final List<QuickSaleItem> _saleItems = [];
  String _currentInput = '';
  int _itemCounter = 1;

  late String _uid;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _uid = widget.uid;
    _userEmail = widget.userEmail;

    // Load initial cart items from SaleAll page
    if (widget.initialCartItems != null && widget.initialCartItems!.isNotEmpty) {
      for (var cartItem in widget.initialCartItems!) {
        _saleItems.add(QuickSaleItem(
          name: cartItem.name,
          price: cartItem.price,
          quantity: cartItem.quantity.toDouble(),
        ));
      }
      _itemCounter = _saleItems.length + 1;
    }
  }

  double get _totalBill {
    return _saleItems.fold(0.0, (sum, item) => sum + item.total);
  }

  void _notifyCartChanged() {
    // Convert QuickSaleItems to CartItems and notify parent
    if (widget.onCartChanged != null) {
      final cartItems = _saleItems.map((item) => CartItem(
        productId: '', // Quick sale items don't have product IDs
        name: item.name,
        price: item.price,
        quantity: item.quantity.toInt(),
      )).toList();
      widget.onCartChanged?.call(cartItems);
    }
  }

  void _showSaveOrderDialog() {
    if (_saleItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cart is empty!'),
          backgroundColor: Color(0xFFFF9800),
        ),
      );
      return;
    }

    final TextEditingController phoneController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    bool isLoadingCustomer = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Save Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Customer Phone Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                onChanged: (value) async {
                  if (value.length >= 10) {
                    setDialogState(() {
                      isLoadingCustomer = true;
                    });

                    // Check if customer exists
                    final customerDoc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(_uid)
                        .collection('customers')
                        .doc(value)
                        .get();

                    if (customerDoc.exists) {
                      final customerData = customerDoc.data();
                      nameController.text = customerData?['name'] ?? '';
                    }

                    setDialogState(() {
                      isLoadingCustomer = false;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              if (isLoadingCustomer)
                const CircularProgressIndicator()
              else
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Customer Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final phone = phoneController.text.trim();
                final name = nameController.text.trim();

                if (phone.isEmpty || name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter phone number and name'),
                      backgroundColor: Color(0xFFFF5252),
                    ),
                  );
                  return;
                }

                Navigator.pop(context);
                await _saveOrder(phone, name);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
              ),
              child: const Text('Save Order'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveOrder(String phone, String name) async {
    try {
      // Save or update customer
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('customers')
          .doc(phone)
          .set({
        'name': name,
        'phone': phone,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Prepare order items
      final items = _saleItems.map((item) => {
        'productId': '',
        'name': item.name,
        'price': item.price,
        'quantity': item.quantity,
        'total': item.total,
      }).toList();

      // Save order
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('savedOrders')
          .add({
        'customerName': name,
        'customerPhone': phone,
        'items': items,
        'total': _totalBill,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order saved successfully!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );

        // Clear cart
        setState(() {
          _saleItems.clear();
          _currentInput = '';
          _itemCounter = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving order: $e'),
            backgroundColor: const Color(0xFFFF5252),
          ),
        );
      }
    }
  }

  void _handleNumberInput(String value) {
    setState(() {
      if (value == '.' && _currentInput.contains('.')) {
        return; // Don't allow multiple decimal points
      }
      _currentInput += value;
    });
  }

  void _handleMultiply() {
    setState(() {
      if (_currentInput.isNotEmpty && !_currentInput.endsWith('x')) {
        _currentInput += 'x';
      }
    });
  }

  void _handleBackspace() {
    setState(() {
      if (_currentInput.isNotEmpty) {
        _currentInput = _currentInput.substring(0, _currentInput.length - 1);
      }
    });
  }

  void _addItem() {
    if (_currentInput.isEmpty) return;

    try {
      double price;
      double quantity;

      if (_currentInput.contains('x')) {
        // Format: price x quantity (e.g., "120x2")
        final parts = _currentInput.split('x');
        if (parts.length != 2) return;

        price = double.parse(parts[0].trim());
        quantity = double.parse(parts[1].trim());
      } else {
        // Only price entered, default quantity to 1
        price = double.parse(_currentInput);
        quantity = 1.0;
      }

      setState(() {
        _saleItems.insert(0, QuickSaleItem(
          name: 'item$_itemCounter',
          price: price,
          quantity: quantity,
        ));
        _itemCounter++;
        _currentInput = '';
      });

      // Notify parent about cart changes
      _notifyCartChanged();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Item added: ₹${price.toStringAsFixed(1)} x ${quantity.toStringAsFixed(1)}'),
          backgroundColor: const Color(0xFF4CAF50),
          duration: const Duration(milliseconds: 800),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid input format'),
          backgroundColor: Color(0xFFFF5252),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _clearOrder() {
    setState(() {
      _saleItems.clear();
      _currentInput = '';
      _itemCounter = 1;
    });
    // Notify parent about cart changes
    _notifyCartChanged();
  }

  void _removeItem(int index) {
    setState(() {
      _saleItems.removeAt(index);
    });
    // Notify parent about cart changes
    _notifyCartChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Tabs at the top

            // Counter display at top right
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _currentInput.isEmpty ? '' : _currentInput,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            // Billing items list
            if (_saleItems.isNotEmpty)
              Container(
                color: Colors.white,
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _saleItems.length,
                  itemBuilder: (context, index) {
                    final item = _saleItems[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.name} (${item.price.toStringAsFixed(1)}) x ${item.quantity.toStringAsFixed(1)}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Text(
                            '+₹${item.total.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF4CAF50),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => _removeItem(index),
                            child: const Icon(
                              Icons.edit,
                              size: 20,
                              color: Color(0xFF2196F3),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            // Clear Order and Items count
            if (_saleItems.isNotEmpty)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _clearOrder,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Clear Order',
                        style: TextStyle(
                          color: Color(0xFFFF5252),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_saleItems.length} Items',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            // Separator line
            Container(
              height: 8,
              color: const Color(0xFFF5F5F5),
            ),

            // Spacer to push content up
            const Spacer(),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Calculator keypad (static above action buttons)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Row 1: 7, 8, 9, backspace
                Row(
                  children: [
                    _buildNumberButton('7'),
                    const SizedBox(width: 8),
                    _buildNumberButton('8'),
                    const SizedBox(width: 8),
                    _buildNumberButton('9'),
                    const SizedBox(width: 8),
                    _buildActionButton(Icons.backspace_outlined, _handleBackspace),
                  ],
                ),
                const SizedBox(height: 8),
                // Row 2: 4, 5, 6, ×
                Row(
                  children: [
                    _buildNumberButton('4'),
                    const SizedBox(width: 8),
                    _buildNumberButton('5'),
                    const SizedBox(width: 8),
                    _buildNumberButton('6'),
                    const SizedBox(width: 8),
                    _buildOperatorButton('×', _handleMultiply),
                  ],
                ),
                const SizedBox(height: 8),
                // Row 3: 1, 2, 3, Add Item (tall button)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              _buildNumberButton('1'),
                              const SizedBox(width: 8),
                              _buildNumberButton('2'),
                              const SizedBox(width: 8),
                              _buildNumberButton('3'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Row 4: 0, 00, .
                          Row(
                            children: [
                              _buildNumberButton('0'),
                              const SizedBox(width: 8),
                              _buildNumberButton('00'),
                              const SizedBox(width: 8),
                              _buildNumberButton('•'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Add Item button (spans 2 rows)
                    _buildAddItemButton(),
                  ],
                ),
              ],
            ),
          ),
          // Action buttons container (static above bottom navbar)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Saved button - Save Order
                GestureDetector(
                  onTap: _saleItems.isNotEmpty ? _showSaveOrderDialog : null,
                  child: Container(
                    height: 56,
                    width: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2196F3), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.bookmark_border, color: Color(0xFF2196F3), size: 26),
                  ),
                ),
                const SizedBox(width: 12),
                // Print button
                Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2196F3), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.print, color: Color(0xFF2196F3), size: 26),
                ),
                const Spacer(),
                // Bill button (on right side)
                GestureDetector(
                  onTap: () {
                    if (_saleItems.isNotEmpty) {
                      // Convert QuickSaleItems to CartItems
                      final cartItems = _saleItems.map((item) => CartItem(
                        productId: '', // Quick sale items don't have product IDs
                        name: item.name,
                        price: item.price,
                        quantity: item.quantity.toInt(),
                      )).toList();

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BillPage(
                            uid: _uid,
                            userEmail: _userEmail,
                            cartItems: cartItems,
                            totalAmount: _totalBill,
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _totalBill.toStringAsFixed(2),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Bill',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Bottom Navigation Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildNumberButton(String number) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _handleNumberInput(number == '•' ? '.' : number),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOperatorButton(String operator, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              operator,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Icon(
              icon,
              size: 24,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddItemButton() {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 56) / 4, // Match width of one button
      height: 148, // 70 + 8 + 70 (two button heights + gap)
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
                Text(
                  'Add',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Item',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}