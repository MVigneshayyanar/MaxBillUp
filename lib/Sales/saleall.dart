import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/Sales/Bill.dart';
import 'package:maxbillup/components/barcode_scanner.dart';
import 'package:maxbillup/Sales/components/common_widgets.dart';

class SaleAllPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final Map<String, dynamic>? savedOrderData;
  final List<CartItem>? initialCartItems;
  final Function(List<CartItem>)? onCartChanged;
  final String? savedOrderId;

  const SaleAllPage({
    super.key,
    required this.uid,
    this.userEmail,
    this.savedOrderData,
    this.initialCartItems,
    this.onCartChanged,
    this.savedOrderId,
  });

  @override
  State<SaleAllPage> createState() => _SaleAllPageState();
}

class _SaleAllPageState extends State<SaleAllPage> {
  final _searchCtrl = TextEditingController();
  final List<CartItem> _cart = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.toLowerCase()));

    if (widget.initialCartItems != null) {
      _cart.addAll(widget.initialCartItems!);
    } else if (widget.savedOrderData != null) {
      _loadOrder(widget.savedOrderData!);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _loadOrder(Map<String, dynamic> data) {
    final items = data['items'] as List?;
    if (items != null) {
      for (var item in items) {
        _cart.add(CartItem(
          productId: item['productId'] ?? '',
          name: item['name'] ?? '',
          price: (item['price'] ?? 0.0).toDouble(),
          quantity: item['quantity'] ?? 1,
        ));
      }
    }
  }

  double get _total => _cart.fold(0.0, (sum, item) => sum + item.total);

  void _addToCart(String id, String name, double price, bool stockEnabled, double stock) {
    final idx = _cart.indexWhere((item) => item.productId == id);

    if (idx != -1) {
      if (stockEnabled && _cart[idx].quantity + 1 > stock) {
        CommonWidgets.showSnackBar(
          context,
          'Not enough stock! Only ${stock.toInt()} available',
          bgColor: const Color(0xFFFF5252),
        );
        return;
      }
      _cart[idx].quantity++;
      final item = _cart.removeAt(idx);
      _cart.insert(0, item);
    } else {
      if (stockEnabled && stock < 1) {
        CommonWidgets.showSnackBar(context, 'Out of stock!', bgColor: const Color(0xFFFF5252));
        return;
      }
      _cart.insert(0, CartItem(productId: id, name: name, price: price));
    }

    CommonWidgets.showSnackBar(context, '$name added to cart', bgColor: const Color(0xFF4CAF50));
    widget.onCartChanged?.call(_cart);
    setState(() {});
  }

  void _removeFromCart(int idx) {
    _cart.removeAt(idx);
    widget.onCartChanged?.call(_cart);
    setState(() {});
  }

  void _clearOrder() {
    _cart.clear();
    widget.onCartChanged?.call(_cart);
    setState(() {});
  }

  void _showEditDialog(int idx) {
    final item = _cart[idx];
    final qtyCtrl = TextEditingController(text: item.quantity.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Quantity - ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Price: ₹${item.price.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2196F3))),
            const SizedBox(height: 16),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.shopping_cart),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              _cart.removeAt(idx);
              widget.onCartChanged?.call(_cart);
              setState(() {});
              Navigator.pop(ctx);
              CommonWidgets.showSnackBar(context, 'Item removed', bgColor: const Color(0xFFFF5252));
            },
            child: const Text('Remove', style: TextStyle(color: Color(0xFFFF5252))),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(qtyCtrl.text.trim());
              if (qty == null || qty <= 0) {
                CommonWidgets.showSnackBar(context, 'Invalid quantity', bgColor: const Color(0xFFFF5252));
                return;
              }
              _cart[idx].quantity = qty;
              widget.onCartChanged?.call(_cart);
              setState(() {});
              Navigator.pop(ctx);
              CommonWidgets.showSnackBar(context, 'Quantity updated to $qty', bgColor: const Color(0xFF4CAF50));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2196F3)),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _openScanner() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => BarcodeScannerPage(onBarcodeScanned: _searchByBarcode),
      ),
    );
  }

  void _searchByBarcode(String barcode) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('Products')
          .where('barcode', isEqualTo: barcode)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        if (mounted) {
          CommonWidgets.showSnackBar(
            context,
            'Product not found with barcode: $barcode',
            bgColor: const Color(0xFFFF9800),
          );
        }
        return;
      }

      final doc = snap.docs.first;
      final data = doc.data();
      final id = doc.id;

      final name = data['itemName'] ?? 'Unnamed';
      final price = data['price'] ?? 0.0;
      final stockEnabled = data['stockEnabled'] ?? false;
      final stock = data['currentStock'] ?? 0.0;

      if (price > 0) {
        _addToCart(id, name, price.toDouble(), stockEnabled, stock);
      } else {
        if (mounted) {
          CommonWidgets.showSnackBar(context, '$name has no price', bgColor: const Color(0xFFFF9800));
        }
      }
    } catch (e) {
      if (mounted) {
        CommonWidgets.showSnackBar(context, 'Error: $e', bgColor: const Color(0xFFFF5252));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(w * 0.04, w *0, w * 0.04, w * 0.04),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: h * 0.06,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              SizedBox(width: w * 0.03),
              GestureDetector(
                onTap: _openScanner,
                child: Container(
                  height: h * 0.06,
                  width: h * 0.06,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.qr_code_scanner, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
        if (_cart.isNotEmpty)
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(vertical: h * 0.01),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: w * 0.04),
                  child: Row(
                    children: [
                      Text('Cart', style: TextStyle(fontSize: w * 0.04, fontWeight: FontWeight.w600)),
                      SizedBox(width: w * 0.02),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: w * 0.02, vertical: h * 0.003),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${_cart.length}',
                            style: TextStyle(fontSize: w * 0.03, color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                      const Spacer(),
                      Text('₹${_total.toStringAsFixed(2)}',
                          style: TextStyle(
                              fontSize: w * 0.045, color: const Color(0xFF2196F3), fontWeight: FontWeight.w700)),
                      SizedBox(width: w * 0.02),
                      GestureDetector(
                        onTap: _clearOrder,
                        child: Icon(Icons.delete_outline, color: const Color(0xFFFF5252), size: w * 0.055),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: h * 0.015),
                SizedBox(
                  height: h * 0.12,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: w * 0.04),
                    itemCount: _cart.length,
                    itemBuilder: (ctx, idx) {
                      final item = _cart[idx];
                      return GestureDetector(
                        onTap: () => _showEditDialog(idx),
                        child: Container(
                          width: w * 0.4,
                          margin: EdgeInsets.only(right: w * 0.03),
                          padding: EdgeInsets.all(w * 0.025),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(item.name,
                                        style: TextStyle(
                                            fontSize: w * 0.035, fontWeight: FontWeight.w600, color: Colors.black87),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  GestureDetector(
                                    onTap: () => _removeFromCart(idx),
                                    child: Icon(Icons.close, size: w * 0.04, color: const Color(0xFFFF5252)),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text('₹${item.price.toStringAsFixed(0)} × ${item.quantity}',
                                      style: TextStyle(fontSize: w * 0.032, color: Colors.grey[600])),
                                  SizedBox(width: w * 0.01),
                                  Icon(Icons.edit, size: w * 0.03, color: const Color(0xFF2196F3)),
                                ],
                              ),
                              const Spacer(),
                              Text('₹${item.total.toStringAsFixed(1)}',
                                  style: TextStyle(
                                      fontSize: w * 0.04, color: const Color(0xFF4CAF50), fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: Container(
            color: const Color(0xFFF5F5F5),
            child: _buildGrid(w, h),
          ),
        ),
        CommonWidgets.buildActionButtons(
          context: context,
          onSaveOrder: () {
            CommonWidgets.showSaveOrderDialog(
              context: context,
              uid: widget.uid,
              cartItems: _cart,
              totalBill: _total,
              onSuccess: () {
                _cart.clear();
                widget.onCartChanged?.call(_cart);
                setState(() {});
              },
            );
          },
          onBill: () {
            if (_cart.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => BillPage(
                    uid: widget.uid,
                    userEmail: widget.userEmail,
                    cartItems: _cart,
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

  Widget _buildGrid(double w, double h) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('Products')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF2196F3)));
        }

        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}', style: const TextStyle(color: Colors.red)));
        }

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: w * 0.2, color: Colors.grey[300]),
                SizedBox(height: h * 0.02),
                Text('No products available', style: TextStyle(fontSize: w * 0.045, color: Colors.grey[600])),
              ],
            ),
          );
        }

        final products = snap.data!.docs;
        final filtered = products.where((doc) {
          if (_query.isEmpty) return true;
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['itemName'] ?? '').toString().toLowerCase();
          final barcode = (data['barcode'] ?? '').toString().toLowerCase();
          return name.contains(_query) || barcode.contains(_query);
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: w * 0.2, color: Colors.grey[300]),
                Text('No products found', style: TextStyle(fontSize: w * 0.045, color: Colors.grey[600])),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: EdgeInsets.all(w * 0.04),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: w * 0.03,
            mainAxisSpacing: w * 0.03,
            childAspectRatio: 1.5,
          ),
          itemCount: filtered.length,
          itemBuilder: (ctx, idx) {
            final doc = filtered[idx];
            final data = doc.data() as Map<String, dynamic>;
            final id = doc.id;

            final name = data['itemName'] ?? 'Unnamed';
            final price = data['price'] ?? 0.0;
            final stockEnabled = data['stockEnabled'] ?? false;
            final stock = data['currentStock'] ?? 0.0;
            final unit = data['stockUnit'] ?? 'box';

            final outOfStock = stockEnabled && stock <= 0;

            final isLowStock = stockEnabled && stock > 0 && stock < 10;

            return GestureDetector(
              onTap: () {
                if (price > 0) {
                  _addToCart(id, name, price.toDouble(), stockEnabled, stock);
                } else {
                  CommonWidgets.showSnackBar(context, 'Price not set', bgColor: const Color(0xFFFF9800));
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: outOfStock ? const Color(0xFFFFF3F3) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: outOfStock
                        ? const Color(0xFFFF5252).withValues(alpha: 0.3)
                        : Colors.grey[200]!,
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          price > 0 ? '₹${price.toStringAsFixed(0)}' : 'Price on sale',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        if (stockEnabled)
                          Text(
                            outOfStock
                                ? '-${stock.abs().toStringAsFixed(0)} $unit'
                                : '${stock.toStringAsFixed(0)} $unit',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: outOfStock
                                  ? const Color(0xFFFF5252)
                                  : isLowStock
                                  ? const Color(0xFFFF9800)
                                  : const Color(0xFF4CAF50),
                            ),
                          ),
                      ],
                    ),
                    if (outOfStock)
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Transform.rotate(
                            angle: -1.5708,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5252),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Out Of Stock',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}