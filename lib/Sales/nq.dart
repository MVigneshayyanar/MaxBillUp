import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:maxbillup/Sales/QuickSale.dart';
import 'package:maxbillup/Sales/Saved.dart';
import 'package:maxbillup/Sales/Quotation.dart';
import 'package:maxbillup/Sales/components/sale_app_bar.dart';
import 'package:maxbillup/Sales/components/common_widgets.dart';
import 'package:maxbillup/Sales/saleall.dart';
import 'package:maxbillup/models/cart_item.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/utils/translation_helper.dart';

class NewQuotationPage extends StatefulWidget {
  final String uid;
  final String? userEmail;

  const NewQuotationPage({
    super.key,
    required this.uid,
    this.userEmail,
  });

  @override
  State<NewQuotationPage> createState() => _NewQuotationPageState();
}

class _NewQuotationPageState extends State<NewQuotationPage> with SingleTickerProviderStateMixin {
  int _selectedTabIndex = 1; // Start with View All tab (index 1)
  List<CartItem>? _sharedCartItems;
  bool _isSearchFocused = false;

  String? _highlightedProductId;
  int _animationCounter = 0;
  AnimationController? _highlightController;
  Animation<Color?>? _highlightAnimation;

  double _cartHeight = 200;
  final double _minCartHeight = 200;
  double _maxCartHeight = 800;

  String? _selectedCustomerPhone;
  String? _selectedCustomerName;
  String? _selectedCustomerGST;
  int _cartVersion = 0;

  @override
  void initState() {
    super.initState();
    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _highlightAnimation = ColorTween(
      begin: kGoogleGreen.withOpacity(0.2),
      end: Colors.transparent,
    ).animate(CurvedAnimation(
      parent: _highlightController!,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _highlightController?.dispose();
    super.dispose();
  }

  void _handleTabChange(int index) {
    setState(() {
      _selectedTabIndex = index;
    });
  }

  void _updateCartItems(List<CartItem> items, {String? triggerId}) {
    List<CartItem> updatedItems = List<CartItem>.from(items);

    if (items.isNotEmpty) {
      final firstItemId = items[0].productId;
      _triggerHighlight(firstItemId, updatedItems);
    } else {
      setState(() {
        _sharedCartItems = updatedItems.isNotEmpty ? updatedItems : null;
        if (updatedItems.isEmpty) {
          _cartVersion++;
        }
      });
    }
  }

  void _triggerHighlight(String productId, List<CartItem> updatedItems) {
    _highlightController?.reset();
    setState(() {
      _highlightedProductId = productId;
      _animationCounter++;
      _sharedCartItems = updatedItems.isNotEmpty ? updatedItems : null;
    });

    _highlightController?.forward();

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _highlightedProductId == productId) {
        setState(() {
          _highlightedProductId = null;
        });
      }
    });
  }

  void _removeSingleItem(int idx) {
    if (_sharedCartItems == null) return;
    final updatedList = List<CartItem>.from(_sharedCartItems!);
    updatedList.removeAt(idx);
    setState(() {
      _cartVersion++;
    });
    _updateCartItems(updatedList);
  }

  void _showEditCartItemDialog(int idx) async {
    final item = _sharedCartItems![idx];
    final nameController = TextEditingController(text: item.name);
    final priceController = TextEditingController(text: item.price.toString());
    final qtyController = TextEditingController(text: item.quantity.toString());

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: kWhite,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(context.tr('edit_item'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: kBlack87)),
                      GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close_rounded, color: kBlack54, size: 24)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _dialogLabel(context.tr('item_name')),
                  _dialogInput(nameController, 'Enter product name'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _dialogLabel(context.tr('price')),
                            _dialogInput(priceController, '0.00', isNumber: true),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _dialogLabel(context.tr('quantity')),
                            Container(
                              height: 48,
                              decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      int current = int.tryParse(qtyController.text) ?? 1;
                                      if (current > 1) {
                                        setDialogState(() => qtyController.text = (current - 1).toString());
                                      } else {
                                        Navigator.pop(context);
                                        _removeSingleItem(idx);
                                      }
                                    },
                                    icon: Icon(
                                      (int.tryParse(qtyController.text) ?? 1) <= 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
                                      color: (int.tryParse(qtyController.text) ?? 1) <= 1 ? kErrorColor : kPrimaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: qtyController,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      onChanged: (v) => setDialogState(() {}),
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: kBlack87),
                                      decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      int current = int.tryParse(qtyController.text) ?? 0;
                                      setDialogState(() => qtyController.text = (current + 1).toString());
                                    },
                                    icon: const Icon(Icons.add_rounded, color: kPrimaryColor, size: 20),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () { Navigator.pop(context); _removeSingleItem(idx); },
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: kErrorColor), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: Text(context.tr('remove').toUpperCase(), style: const TextStyle(color: kErrorColor, fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final newName = nameController.text.trim();
                            final newPrice = double.tryParse(priceController.text.trim()) ?? item.price;
                            final newQty = int.tryParse(qtyController.text.trim()) ?? 1;
                            if (newQty > 0) {
                              final List<CartItem> nextItems = List<CartItem>.from(_sharedCartItems!);
                              nextItems[idx] = CartItem(productId: item.productId, name: newName, price: newPrice, quantity: newQty, taxName: item.taxName, taxPercentage: item.taxPercentage, taxType: item.taxType);
                              _updateCartItems(nextItems);
                            }
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                          child: Text(context.tr('save').toUpperCase(), style: const TextStyle(color: kWhite, fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  void _handleClearCart() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: kErrorColor, size: 40),
              const SizedBox(height: 16),
              Text(context.tr('clear_cart'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: kBlack87)),
              const SizedBox(height: 12),
              const Text('Are you sure you want to clear this quotation? All line items will be removed.', textAlign: TextAlign.center, style: TextStyle(color: kBlack54, fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL', style: TextStyle(color: kBlack54,fontWeight: FontWeight.bold)))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(backgroundColor: kErrorColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      child: Text(context.tr('clear').toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      setState(() {
        _sharedCartItems = null;
        _cartVersion++;
        _highlightedProductId = null;
        _isSearchFocused = false;
      });
      _updateCartItems([]);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) FocusManager.instance.primaryFocus?.unfocus();
      });
    }
  }

  Widget _dialogLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5)),
  );

  Widget _dialogInput(TextEditingController ctrl, String hint, {bool isNumber = false, bool enabled = true}) {
    return TextField(
      controller: ctrl,
      enabled: enabled,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: enabled ? kBlack87 : Colors.black45),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: enabled ? kGreyBg : Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrey200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5)),
      ),
    );
  }

  void _handleSearchFocusChange(bool isFocused) {
    setState(() {
      _isSearchFocused = isFocused;
    });
  }

  void _setSelectedCustomer(String? phone, String? name, String? gst) {
    setState(() {
      _selectedCustomerPhone = phone;
      _selectedCustomerName = name;
      _selectedCustomerGST = gst;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;

    _maxCartHeight = screenHeight - topPadding - 180;

    final double dynamicCartHeight = _isSearchFocused ? 115 : _cartHeight;
    final bool shouldShowCart = _sharedCartItems != null && _sharedCartItems!.isNotEmpty;
    final double reservedCartSpace = shouldShowCart ? (_isSearchFocused ? 100 : _minCartHeight) : 0;

    return Scaffold(
      backgroundColor: kWhite, // Changed from kGreyBg to kWhite
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(height: topPadding + 10 + (reservedCartSpace > 0 ? reservedCartSpace + 10 : 0)),

              if (!_isSearchFocused)
                SaleAppBar(
                  selectedTabIndex: _selectedTabIndex,
                  onTabChanged: _handleTabChange,
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                  uid: widget.uid,
                  userEmail: widget.userEmail,
                  hideSavedTab: true,
                  showBackButton: true,
                ),

              Expanded(
                child: _selectedTabIndex == 0
                    ? SavedOrdersPage(uid: widget.uid, userEmail: widget.userEmail)
                    : _selectedTabIndex == 1
                    ? SaleAllPage(
                  key: ValueKey('sale_all_$_cartVersion'),
                  uid: widget.uid,
                  userEmail: widget.userEmail,
                  onCartChanged: _updateCartItems,
                  initialCartItems: _sharedCartItems,
                  isQuotationMode: true,
                  onSearchFocusChanged: _handleSearchFocusChange,
                  customerPhone: _selectedCustomerPhone,
                  customerName: _selectedCustomerName,
                  customerGST: _selectedCustomerGST,
                  onCustomerChanged: _setSelectedCustomer,
                )
                    : QuickSalePage(
                  key: ValueKey('quick_sale_$_cartVersion'),
                  uid: widget.uid,
                  userEmail: widget.userEmail,
                  initialCartItems: _sharedCartItems,
                  onCartChanged: _updateCartItems,
                  isQuotationMode: true,
                  customerPhone: _selectedCustomerPhone,
                  customerName: _selectedCustomerName,
                  customerGST: _selectedCustomerGST,
                  onCustomerChanged: _setSelectedCustomer,
                ),
              ),
            ],
          ),

          if (shouldShowCart)
            Positioned(
              top: topPadding + 10,
              left: 0,
              right: 0,
              child: _buildCartSection(screenWidth, dynamicCartHeight),
            ),
        ],
      ),
      bottomNavigationBar: _buildEnterpriseBottomBar(),
    );
  }

  Widget _buildEnterpriseBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: kWhite,
        border: Border(top: BorderSide(color: kGrey200, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SafeArea(
        child: Row(
          children: [
            // Enterprise Customer Action Icon
            InkWell(
              onTap: _showCustomerSelectionDialog,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kPrimaryColor.withOpacity(0.2), width: 1.5),
                ),
                child: Icon(
                  _selectedCustomerName != null && _selectedCustomerName!.isNotEmpty
                      ? Icons.person_rounded
                      : Icons.person_add_rounded,
                  color: kPrimaryColor,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // High-Density Quotation Button
            Expanded(
              child: GestureDetector(
                onTap: _createQuotation,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: kPrimaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.description_rounded, color: kWhite, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        "Rs ${(_sharedCartItems?.fold(0.0, (sum, item) => sum + (item.price * item.quantity)) ?? 0.0).toStringAsFixed(0)}",
                        style: const TextStyle(color: kWhite, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(width: 10),
                      Container(width: 1, height: 16, color: kWhite.withOpacity(0.3)),
                      const SizedBox(width: 10),
                      Text(
                        context.tr('QUOTE').toUpperCase(),
                        style: const TextStyle(color: kWhite, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomerSelectionDialog() {
    CommonWidgets.showCustomerSelectionDialog(
      context: context,
      onCustomerSelected: (phone, name, gst) {
        setState(() {
          _selectedCustomerPhone = phone.isEmpty ? null : phone;
          _selectedCustomerName = name.isEmpty ? null : name;
          _selectedCustomerGST = gst;
        });
      },
      selectedCustomerPhone: _selectedCustomerPhone,
    );
  }

  void _createQuotation() {
    if (_sharedCartItems == null || _sharedCartItems!.isEmpty) {
      CommonWidgets.showSnackBar(context, 'Add items to create quotation', bgColor: kOrange);
      return;
    }

    final total = _sharedCartItems!.fold(0.0, (sum, item) => sum + (item.price * item.quantity));

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => QuotationPage(
          uid: widget.uid,
          userEmail: widget.userEmail,
          cartItems: _sharedCartItems!,
          totalAmount: total,
          customerPhone: _selectedCustomerPhone,
          customerName: _selectedCustomerName,
          customerGST: _selectedCustomerGST,
        ),
      ),
    ).then((_) {
      setState(() {
        _sharedCartItems = null;
        _isSearchFocused = false;
      });
      _updateCartItems([]);
    });
  }

  Widget _buildCartSection(double w, double currentHeight) {
    final bool isSearchFocused = currentHeight <= 150;

    return GestureDetector(
      onVerticalDragUpdate: isSearchFocused ? null : (details) {
        setState(() {
          if (details.delta.dy > 10) _cartHeight = _maxCartHeight;
          else if (details.delta.dy < -10) _cartHeight = _minCartHeight;
          else _cartHeight = (_cartHeight + details.delta.dy).clamp(_minCartHeight, _maxCartHeight);
        });
      },
      onDoubleTap: isSearchFocused ? null : () {
        setState(() => _cartHeight = (_cartHeight < _maxCartHeight * 0.95) ? _maxCartHeight : _minCartHeight);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        height: currentHeight,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kOrange, width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: isSearchFocused ? 8 : 12),
              decoration: const BoxDecoration(
                color: kOrange,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  Expanded(flex: 4, child: Text(context.tr('product').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: kBlack87, letterSpacing: 0.5))),
                  Expanded(flex: 2, child: Text(context.tr('qty').toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: kBlack87, letterSpacing: 0.5))),
                  Expanded(flex: 2, child: Text(context.tr('price').toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: kBlack87, letterSpacing: 0.5))),
                  Expanded(flex: 2, child: Text(context.tr('total').toUpperCase(), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: kBlack87, letterSpacing: 0.5))),
                ],
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: _highlightAnimation!,
                builder: (context, child) {
                  return ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: _sharedCartItems?.length ?? 0,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16, color: kGrey100),
                    itemBuilder: (ctx, idx) {
                      final item = _sharedCartItems![idx];
                      final bool isHighlighted = item.productId == _highlightedProductId;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: isSearchFocused ? 6 : 10),
                        decoration: BoxDecoration(
                          color: isHighlighted ? _highlightAnimation!.value : Colors.transparent,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Row(
                                children: [
                                  Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kBlack87), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  const SizedBox(width: 4),
                                  GestureDetector(onTap: () => _showEditCartItemDialog(idx), child: const Icon(Icons.edit_note_rounded, color: kPrimaryColor, size: 20)),
                                ],
                              ),
                            ),
                            Expanded(flex: 2, child: Text('${item.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: kBlack87))),
                            Expanded(flex: 2, child: Text(item.price.toStringAsFixed(0), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: kBlack54, fontWeight: FontWeight.w600))),
                            Expanded(flex: 2, child: Text(item.total.toStringAsFixed(0), textAlign: TextAlign.right, style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900, fontSize: 14))),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: isSearchFocused ? 6 : 10),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.03),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                border: const Border(top: BorderSide(color: kGrey200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _handleClearCart,
                    child: Row(
                      children: [
                        const Icon(Icons.delete_sweep_rounded, color: kErrorColor, size: 18),
                        const SizedBox(width: 4),
                        Text(context.tr('clear').toUpperCase(), style: const TextStyle(color: kErrorColor, fontWeight: FontWeight.w800, fontSize: 11)),
                      ],
                    ),
                  ),
                  const Icon(Icons.drag_handle_rounded, color: kGrey300, size: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: kPrimaryColor, borderRadius: BorderRadius.circular(12)),
                    child: Text('${_sharedCartItems?.length ?? 0} ITEMS', style: const TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}